import SwiftUI
import SwiftData
import UIKit

struct SetlistDetailView: View {
    let setlist: APISetlist

    @EnvironmentObject private var auth: AuthVM
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var ctx

    // Auth sheet
    @State private var showLogin = false
    private var signedIn: Bool { auth.session != nil }

    // Save state (scoped to current user)
    @State private var alreadySaved = false
    @State private var saving = false
    @State private var savedNote: String?

    // Setlist collapse
    @State private var expandedSets = Set<Int>()

    // Reviews
    @State private var reviews: [ReviewRead] = []
    @State private var myVotes: [Int64: Int] = [:] // review_id -> -1/1
    @State private var loadingReviews = false
    @State private var reviewError: String?

    // Composer / edit
    @State private var showComposer = false
    @State private var isEditingMine = false
    @State private var myRating = 0
    @State private var myComment = ""

    // Derived
    private var setsArray: [APISetlist.SetBlock] { setlist.sets?.set ?? [] }
    private var songsFlat: [String] {
        setlist.sets?.set?.flatMap { $0.song?.compactMap { $0.name } ?? [] } ?? []
    }
    private var myReview: ReviewRead? {
        guard let uid = auth.session?.user.id else { return nil }
        return reviews.first(where: { $0.user_id == uid })
    }

    var body: some View {
        List {
            headerSection
            setlistSection
            actionSection
            reviewsSection
            composerSection
            linkSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Setlist")
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") { hideKeyboard() }
            }
        }
        .task { await initialLoad() }
        .sheet(isPresented: $showLogin) { LoginSheet().environmentObject(auth) }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(setlist.artist.name).font(.title2).bold()
                Text(setlist.eventDate ?? "—")
                let place = [setlist.venue?.name, setlist.venue?.city?.name]
                    .compactMap { $0 }
                    .joined(separator: " • ")
                if !place.isEmpty {
                    Text(place).foregroundStyle(.secondary)
                }
            }
            SaveButtonModern(
                isSaved: alreadySaved,
                isBusy: saving,
                titleSaved: "Saved",
                titleSave: signedIn ? "Save Concert" : "Sign in to Save",
                onTap: { Task { await handleSaveTapped() } }
            )
            if let note = savedNote {
                Text(note).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var setlistSection: some View {
        Section {
            if setsArray.isEmpty {
                if songsFlat.isEmpty {
                    Text("No songs found in this setlist yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(songsFlat.enumerated()), id: \.offset) { pair in
                        SongRow(number: pair.offset + 1, title: pair.element)
                    }
                }
            } else {
                if setsArray.count > 1 {
                    ExpandCollapseToggle(isAllExpanded: expandedSets.count == setsArray.count) {
                        if expandedSets.count == setsArray.count {
                            expandedSets.removeAll()
                        } else {
                            expandedSets = Set(setsArray.indices)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                }

                ForEach(Array(setsArray.enumerated()), id: \.offset) { idx, block in
                    let names: [String] = block.song?.compactMap { $0.name } ?? []
                    let label = setLabel(name: block.name, index: idx)

                    DisclosureGroup(isExpanded: bindingForSet(idx)) {
                        if names.isEmpty {
                            Text("No songs in this section.")
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(Array(names.enumerated()), id: \.offset) { n, title in
                                SongRow(number: n + 1, title: title)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(label).font(.headline)
                            Spacer()
                            if !names.isEmpty {
                                Chip(text: "\(names.count) \(names.count == 1 ? "song" : "songs")",
                                     systemImage: "music.note.list")
                            }
                        }
                    }
                }
            }
        } header: { Text("Setlist") }
    }

    private var actionSection: some View {
        Section {
            if myReview != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You already left a review!").bold()
                    if !showComposer {
                        BlueWideButton(title: "See Your Review") {
                            // Could add ScrollViewReader jump in a future pass
                        }
                        .accessibilityHint("Scroll to your review below")
                    }
                }
            } else if !showComposer {
                BlueWideButton(title: "Leave Review") {
                    if !signedIn { showLogin = true; return }
                    isEditingMine = false
                    myRating = 0
                    myComment = ""
                    showComposer = true
                }
            }
        }
    }

    private var reviewsSection: some View {
        Section {
            if loadingReviews {
                ProgressView("Loading reviews…")
            } else if let err = reviewError {
                Text(err).foregroundStyle(.red)
            } else if reviews.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No Reviews Yet!").font(.headline)
                    Text("Be the first to review this concert.")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(reviews) { r in
                    ReviewRow(
                        review: r,
                        isMine: r.user_id == auth.session?.user.id,
                        myVote: myVotes[r.id],
                        onMenuEdit: {
                            guard signedIn else { showLogin = true; return }
                            isEditingMine = true
                            showComposer = true
                            myRating = r.rating
                            myComment = r.comment ?? ""
                        },
                        onMenuDelete: { Task { await deleteReview(r.id) } },
                        onUp: { Task { await toggleVote(r, newValue: 1) } },
                        onDown: { Task { await toggleVote(r, newValue: -1) } },
                        onClearVote: { Task { await clearVote(r) } }
                    )
                }
            }
        } header: { Text("Concert Reviews") }
    }

    private var composerSection: some View {
        Group {
            if showComposer {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(isEditingMine ? "Edit Review" : "Leave a Review")
                            .font(.headline)

                        StarRating(value: $myRating)

                        TextField("Optional comment…", text: $myComment, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .textInputAutocapitalization(.sentences)

                        HStack(spacing: 10) {
                            BlueWideButton(
                                title: isEditingMine ? "Update Review" : "Submit Review",
                                isDisabled: myRating == 0
                            ) {
                                Task { await submitOrUpdateReview() }
                            }
                            Button("Cancel") {
                                showComposer = false
                                isEditingMine = false
                                myRating = 0
                                myComment = ""
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var linkSection: some View {
        Group {
            if let urlStr = setlist.url, let url = URL(string: urlStr) {
                Section {
                    Button { openURL(url) } label: {
                        Label("View on setlist.fm", systemImage: "safari")
                            .font(.footnote)
                    }
                }
            }
        }
    }

    // MARK: - Initial load

    private func initialLoad() async {
        // Default: expand all sets
        expandedSets = Set(setsArray.indices)

        // Already saved locally for THIS user?
        let id = setlist.id
        let uid = auth.session?.user.id
        let pred = #Predicate<SavedConcert> { $0.setlistId == id && $0.ownerUserId == uid }
        let f = FetchDescriptor<SavedConcert>(predicate: pred)
        alreadySaved = (try? ctx.fetch(f).isEmpty == false) ?? false

        await refreshReviewsAndVotes()
    }

    // MARK: - Save flow (auth-gated)

    @MainActor
    private func handleSaveTapped() async {
        guard signedIn else { showLogin = true; return }
        await saveConcert()
    }

    /// Cloud-first; mirror to local (scoped to current user).
    @MainActor
    private func saveConcert() async {
        if alreadySaved || saving { return }
        saving = true; defer { saving = false }
        guard let uid = auth.session?.user.id else { showLogin = true; return }

        let df = SetlistAPI.shared.eventDateFormatter
        let parsedDate = setlist.eventDate.flatMap { df.date(from: $0) }
        let id = setlist.id
        let songsLocal = songsFlat

        do {
            // 1) Ensure setlist exists in cloud
            try await CloudStore.shared.upsertSetlist(from: setlist)

            // 2) Save to user (cloud)
            try await CloudStore.shared.saveToUser(setlistId: id, attendedOn: parsedDate)

            // 3) Mirror locally (THIS user only)
            let pred = #Predicate<SavedConcert> { $0.setlistId == id && $0.ownerUserId == uid }
            let f = FetchDescriptor<SavedConcert>(predicate: pred)
            let existing = try ctx.fetch(f)
            if let local = existing.first {
                local.artistName = setlist.artist.name
                local.venueName = setlist.venue?.name
                local.city = setlist.venue?.city?.name
                local.country = setlist.venue?.city?.country?.name ?? setlist.venue?.city?.country?.code
                local.eventDate = parsedDate
                local.songs = songsLocal
                local.attributionURL = setlist.url
                local.pendingCloudSave = false
                local.lastCloudSyncAt = Date()
                local.ownerUserId = uid
            } else {
                let model = SavedConcert(
                    setlistId: id,
                    artistName: setlist.artist.name,
                    venueName: setlist.venue?.name,
                    city: setlist.venue?.city?.name,
                    country: setlist.venue?.city?.country?.name ?? setlist.venue?.city?.country?.code,
                    eventDate: parsedDate,
                    songs: songsLocal,
                    attributionURL: setlist.url,
                    pendingCloudSave: false,
                    ownerUserId: uid
                )
                model.lastCloudSyncAt = Date()
                ctx.insert(model)
            }
            try? ctx.save()

            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                alreadySaved = true
                savedNote = "Saved to your account."
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)

        } catch {
            savedNote = "Couldn’t save. Please try again."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            print("Save concert failed:", error)
        }
    }

    // MARK: - Reviews

    @MainActor
    private func refreshReviewsAndVotes() async {
        loadingReviews = true; reviewError = nil
        defer { loadingReviews = false }
        do {
            let list = try await CloudStore.shared.loadReviews(setlistId: setlist.id)
            reviews = list
            if signedIn {
                let ids = list.map { $0.id }
                myVotes = try await CloudStore.shared.loadMyVotes(reviewIDs: ids)
            } else {
                myVotes = [:]
            }
        } catch {
            reviewError = error.localizedDescription
        }
    }

    @MainActor
    private func submitOrUpdateReview() async {
        guard signedIn else { showLogin = true; return }
        guard myRating > 0 else { return }

        do {
            try await CloudStore.shared.submitReview(
                setlist: setlist,
                rating: myRating,
                comment: myComment.isEmpty ? nil : myComment
            )

            if !alreadySaved { await saveConcert() }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isEditingMine = false
            showComposer = false
            myRating = 0
            myComment = ""
            await refreshReviewsAndVotes()
        } catch {
            reviewError = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    @MainActor
    private func deleteReview(_ id: Int64) async {
        guard signedIn else { showLogin = true; return }
        do {
            try await CloudStore.shared.deleteMyReview(id: id)
            await refreshReviewsAndVotes()
        } catch {
            reviewError = error.localizedDescription
        }
    }

    @MainActor
    private func toggleVote(_ r: ReviewRead, newValue: Int) async {
        guard signedIn else { showLogin = true; return }
        do {
            let current = myVotes[r.id]
            if current == newValue {
                try await CloudStore.shared.clearVote(reviewId: r.id)
            } else {
                try await CloudStore.shared.upsertVote(reviewId: r.id, value: newValue)
            }
            await refreshReviewsAndVotes()
        } catch {
            reviewError = error.localizedDescription
        }
    }

    @MainActor
    private func clearVote(_ r: ReviewRead) async {
        guard signedIn else { showLogin = true; return }
        do {
            try await CloudStore.shared.clearVote(reviewId: r.id)
            await refreshReviewsAndVotes()
        } catch {
            reviewError = error.localizedDescription
        }
    }

    // MARK: - Utils

    private func bindingForSet(_ idx: Int) -> Binding<Bool> {
        Binding(
            get: { expandedSets.contains(idx) },
            set: { newVal in
                if newVal { expandedSets.insert(idx) } else { expandedSets.remove(idx) }
            }
        )
    }

    private func setLabel(name: String?, index: Int) -> String {
        if let name, !name.isEmpty { return name }
        return "Set \(index + 1)"
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

// MARK: - Small UI bits

fileprivate struct SaveButtonModern: View {
    var isSaved: Bool
    var isBusy: Bool
    var titleSaved: String
    var titleSave: String
    var onTap: () -> Void

    var body: some View {
        Button {
            guard !isSaved && !isBusy else { return }
            onTap()
        } label: {
            HStack(spacing: 10) {
                if isBusy {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "bookmark.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .modifier(SymbolSwapEffect(enabled: isSaved))
                }
                Text(isSaved ? titleSaved : titleSave)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .modifier(FadeSwapEffect(enabled: isSaved))
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: isSaved ? [.green, .green.opacity(0.85)]
                                    : [.accentColor, .accentColor.opacity(0.85)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: (isSaved ? Color.green : Color.accentColor).opacity(0.35),
                    radius: 14, x: 0, y: 10)
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? titleSaved : titleSave)
        .disabled(isSaved || isBusy)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSaved)
    }
}

fileprivate struct SymbolSwapEffect: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.contentTransition(.symbolEffect(.replace)).symbolEffect(.bounce, value: enabled)
        } else { content }
    }
}
fileprivate struct FadeSwapEffect: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) { content.contentTransition(.opacity) } else { content }
    }
}

fileprivate struct ExpandCollapseToggle: View {
    var isAllExpanded: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isAllExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                Text(isAllExpanded ? "Collapse All" : "Expand All").bold()
                Spacer()
            }
            .padding(12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct SongRow: View {
    var number: Int
    var title: String
    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)").font(.footnote).bold()
                .frame(width: 26, height: 26)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(title)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

fileprivate struct Chip: View {
    var text: String
    var systemImage: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.12))
        .clipShape(Capsule())
    }
}

fileprivate struct StarRating: View {
    @Binding var value: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= value ? "star.fill" : "star")
                    .onTapGesture { value = i }
            }
        }
        .font(.title3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(value) out of 5")
    }
}

fileprivate struct ReviewRow: View {
    let review: ReviewRead
    let isMine: Bool
    let myVote: Int?
    let onMenuEdit: () -> Void
    let onMenuDelete: () -> Void
    let onUp: () -> Void
    let onDown: () -> Void
    let onClearVote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(review.username ?? "Anonymous").bold()
                Spacer()
                Text(String(repeating: "★", count: max(0, min(5, review.rating))))
                    .font(.caption)
            }
            if let c = review.comment, !c.isEmpty {
                Text(c)
            }
            HStack(spacing: 12) {
                // Counts must come from your Supabase view as up_votes/down_votes
                VoteButton(system: "hand.thumbsup",   isActive: myVote == 1,  count: review.up_votes ?? 0,  action: onUp)
                VoteButton(system: "hand.thumbsdown", isActive: myVote == -1, count: review.down_votes ?? 0, action: onDown)

                Spacer()

                if isMine {
                    Menu {
                        Button("Edit Review", action: onMenuEdit)
                        Button("Delete Review", role: .destructive, action: onMenuDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                } else if myVote != nil {
                    Menu {
                        Button("Clear my vote", action: onClearVote)
                    } label: {
                        Image(systemName: "ellipsis")
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

fileprivate struct VoteButton: View {
    let system: String
    let isActive: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: system)
                    .symbolVariant(isActive ? .fill : .none)
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                Text("\(count)")
            }
        }
        .buttonStyle(.borderless)
    }
}

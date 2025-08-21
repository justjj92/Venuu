import SwiftUI

/// Detail + reviews for a venue.
struct VenueDetailView: View {
    let venue: CloudStore.VenueRow

    @EnvironmentObject private var auth: AuthVM
    @Environment(\.openURL) private var openURL

    @State private var loading = false
    @State private var reviews: [CloudStore.VenueReviewRead] = []
    @State private var summary: String?
    @State private var errorText: String?
    @State private var didLoadReviews = false

    // Inline composer (used for create + edit)
    @State private var showComposer = false
    @State private var parking = 0
    @State private var staff   = 0
    @State private var food    = 0
    @State private var sound   = 0
    @State private var access  = 0   // Accessibility (0 = not set)
    @State private var comment = ""

    // Review detail sheet
    @State private var showDetail: CloudStore.VenueReviewRead?

    private var signedIn: Bool { auth.session != nil }

    // MARK: - Derived

    private var myReview: CloudStore.VenueReviewRead? {
        guard let me = auth.session?.user.id.uuidString.lowercased() else { return nil }
        return reviews.first { $0.user_id.lowercased() == me }
    }

    private var overallAverage: Double? {
        guard didLoadReviews else { return venue.avg_rating }  // first paint = server cache if present
        guard !reviews.isEmpty else { return nil }             // show "—" if none
        let vals = reviews.map(overall(of:))
        return vals.reduce(0, +) / Double(vals.count)
    }

    // per-category averages
    private var avgParking: Double? { average(\.parking) }
    private var avgStaff:   Double? { average(\.staff) }
    private var avgFood:    Double? { average(\.food) }
    private var avgSound:   Double? { average(\.sound) }
    private var avgAccess:  Double? {
        let xs = reviews.compactMap { $0.access }.map(Double.init)
        guard !xs.isEmpty else { return nil }
        return xs.reduce(0,+) / Double(xs.count)
    }

    var body: some View {
        List {
            header
            summarySection
            myReviewSection
            leaveReviewCTA
            reviewsSection
            composerSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(venue.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // Starting a fresh review via pencil always clears the composer
                    prefillFrom(nil)
                    showComposer = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .disabled(!signedIn)
                .accessibilityLabel("Write a review")
            }
        }
        .task { await loadAll() }
        .refreshable { await loadAll() }
        .sheet(item: $showDetail) { r in
            VenueReviewDetailView(review: r)
        }
    }

    // MARK: - Sections

    private var header: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(venue.name).font(.title3).bold()
                        Text(locationLine(venue)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        openURL(mapsURL(for: venue))
                    } label: {
                        Label("Open in Maps", systemImage: "map")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("Open this venue in Apple Maps")
                }

                HStack(spacing: 8) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text(formatted(overallAverage ?? venue.avg_rating))
                        .font(.headline.monospacedDigit())
                    Text("Overall").foregroundStyle(.secondary)
                    Spacer()
                    if let count = reviewsCountText() {
                        Text(count).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        }
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                CategoryRow(label: "Parking",        value: avgParking)
                CategoryRow(label: "Staff",          value: avgStaff)
                CategoryRow(label: "Food",           value: avgFood)
                CategoryRow(label: "Sound",          value: avgSound)
                CategoryRow(label: "Accessibility",  value: avgAccess)

                if let s = summary, !s.isEmpty {
                    Text(s).font(.subheadline)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        } header: { Text("Summary") }
    }

    private var leaveReviewCTA: some View {
        Group {
            if signedIn, myReview == nil, !showComposer {
                Section {
                    BlueWideButton(title: "Leave a Review") {
                        prefillFrom(nil)
                        showComposer = true
                    }
                }
            }
        }
    }

    private var myReviewSection: some View {
        Group {
            if let mine = myReview {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Your Review").font(.headline)
                            Spacer()
                            StarsInline(overall(of: mine))
                        }
                        if let c = mine.comment, !c.isEmpty {
                            Text(c).lineLimit(2)
                        }
                        HStack {
                            Button("View full review") { showDetail = mine }
                            Spacer()
                            Button("Edit") {
                                prefillFrom(mine)
                                showComposer = true
                            }
                            Button("Delete", role: .destructive) {
                                Task { await deleteReview(mine.id) }
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.footnote)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                }
            }
        }
    }

    private var reviewsSection: some View {
        Section {
            if loading && reviews.isEmpty {
                ProgressView("Loading…")
            } else if let e = errorText {
                Text(e).foregroundStyle(.red)
            } else if reviews.isEmpty {
                Text("No reviews yet. Be the first!")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reviews, id: \.id) { r in
                    Button { showDetail = r } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(displayName(r)).bold()
                                Spacer()
                                StarsInline(overall(of: r))
                            }
                            if let c = r.comment, !c.isEmpty {
                                Text(c).lineLimit(2).foregroundStyle(.secondary)
                            } else {
                                Text("View full review").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: { Text("Reviews") }
    }

    private var composerSection: some View {
        Group {
            if showComposer {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(myReview == nil ? "Leave a Review" : "Edit Review")
                            .font(.headline)

                        StarsPicker(label: "Parking",        value: $parking)
                        StarsPicker(label: "Staff",          value: $staff)
                        StarsPicker(label: "Food",           value: $food)
                        StarsPicker(label: "Sound",          value: $sound)
                        StarsPicker(label: "Accessibility",  value: $access)

                        TextField("Optional comment…", text: $comment, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .textInputAutocapitalization(.sentences)

                        HStack {
                            Button(myReview == nil ? "Submit Review" : "Update Review") {
                                Task { await submit() }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Cancel") {
                                showComposer = false
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func loadAll() async {
        loading = true; errorText = nil
        defer { loading = false }
        do {
            reviews = try await CloudStore.shared.loadVenueReviews(venueId: venue.id)
            didLoadReviews = true
            // summarize (optional, ignore failure)
            if let s = try? await AISummaryEngine.shared.summarize(venueReviews: reviews) {
                summary = s
            } else {
                summary = nil
            }
        } catch {
            errorText = (error as NSError).localizedDescription
        }
    }

    @MainActor
    private func submit() async {
        guard signedIn else { return }
        do {
            try await CloudStore.shared.submitVenueReview(
                venueId: venue.id,
                parking: parking,
                staff: staff,
                food: food,
                sound: sound,
                access: access > 0 ? access : nil,   // only send if > 0
                comment: comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : comment
            )
            showComposer = false
            clearComposer()
            await loadAll()
        } catch {
            errorText = (error as NSError).localizedDescription
        }
    }

    @MainActor
    private func deleteReview(_ id: Int64) async {
        do {
            try await CloudStore.shared.deleteMyVenueReview(id: id)
            // Optimistic local update for snappy UI
            reviews.removeAll { $0.id == id }
            showComposer = false
            // Re-summarize locally then pull fresh
            if let s = try? await AISummaryEngine.shared.summarize(venueReviews: reviews) {
                summary = s
            } else {
                summary = nil
            }
            await loadAll()
        } catch {
            errorText = (error as NSError).localizedDescription
        }
    }

    // MARK: - Helpers

    private func prefillFrom(_ r: CloudStore.VenueReviewRead?) {
        parking = r?.parking ?? 0
        staff   = r?.staff   ?? 0
        food    = r?.food    ?? 0
        sound   = r?.sound   ?? 0
        access  = r?.access  ?? 0
        comment = r?.comment ?? ""
    }

    private func clearComposer() {
        parking = 0; staff = 0; food = 0; sound = 0; access = 0; comment = ""
    }

    private func locationLine(_ v: CloudStore.VenueRow) -> String {
        var parts: [String] = []
        if let c = v.city,  !c.isEmpty { parts.append(c) }
        if let s = v.state, !s.isEmpty { parts.append(s) }
        return parts.joined(separator: ", ")
    }

    private func mapsURL(for v: CloudStore.VenueRow) -> URL {
        let query = [v.name, v.city, v.state]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let encoded = (query.isEmpty ? v.name : query)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v.name
        return URL(string: "http://maps.apple.com/?q=\(encoded)")!
    }

    private func reviewsCountText() -> String? {
        let count = reviews.count
        return "\(count) review\(count == 1 ? "" : "s")"
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }

    private func displayName(_ r: CloudStore.VenueReviewRead) -> String {
        if let me = auth.session?.user.id.uuidString, r.user_id == me { return "You" }
        if let name = r.display_name, !name.isEmpty { return name }
        if let u = r.username, !u.isEmpty { return u }
        return "User"
    }

    private func overall(of r: CloudStore.VenueReviewRead) -> Double {
        var nums: [Double] = [Double(r.parking), Double(r.staff), Double(r.food), Double(r.sound)]
        if let a = r.access { nums.append(Double(a)) }
        guard !nums.isEmpty else { return 0 }
        return nums.reduce(0,+) / Double(nums.count)
    }

    private func average(_ keyPath: KeyPath<CloudStore.VenueReviewRead, Int>) -> Double? {
        let arr = reviews.map { Double($0[keyPath: keyPath]) }
        guard !arr.isEmpty else { return nil }
        return arr.reduce(0,+) / Double(arr.count)
    }
}

// MARK: - Bits

private struct CategoryRow: View {
    let label: String
    let value: Double?  // nil shows "—"
    var body: some View {
        HStack {
            Text(label).frame(width: 130, alignment: .leading)
            Spacer()
            StarsInline(value ?? 0)
            Text(value == nil ? "—" : String(format: "%.1f", value!))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value ?? 0, specifier: "%.1f") stars")
    }
}

private struct StarsPicker: View {
    let label: String
    @Binding var value: Int
    var body: some View {
        HStack {
            Text(label).frame(width: 130, alignment: .leading)
            Spacer()
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { i in
                    Image(systemName: i <= value ? "star.fill" : "star")
                        .onTapGesture { value = i }
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("\(label) \(i) star\(i == 1 ? "" : "s")")
                }
            }
        }
    }
}

// Full-screen review detail
private struct VenueReviewDetailView: View {
    let review: CloudStore.VenueReviewRead
    @Environment(\.dismiss) private var dismiss

    private func overall(_ r: CloudStore.VenueReviewRead) -> Double {
        var xs = [Double(r.parking), Double(r.staff), Double(r.food), Double(r.sound)]
        if let a = r.access { xs.append(Double(a)) }
        return xs.reduce(0,+) / Double(xs.count)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(review.display_name ?? review.username ?? "User").bold()
                        Spacer()
                        StarsInline(overall(review))
                    }
                    if let c = review.comment, !c.isEmpty {
                        Text(c)
                    }
                }
                Section("Ratings") {
                    CategoryRow(label: "Parking",       value: Double(review.parking))
                    CategoryRow(label: "Staff",         value: Double(review.staff))
                    CategoryRow(label: "Food",          value: Double(review.food))
                    CategoryRow(label: "Sound",         value: Double(review.sound))
                    if let a = review.access {
                        CategoryRow(label: "Accessibility", value: Double(a))
                    }
                }
            }
            .navigationTitle("Review")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}

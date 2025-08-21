// MyReviewsView.swift
import SwiftUI

struct MyReviewsView: View {
    @State private var rows: [ReviewRead] = []
    @State private var loading = false
    @State private var errorMessage: String?

    @State private var selection = Set<Int64>()
    @State private var editMode: EditMode = .inactive

    // Delete handling
    private enum DeleteTarget { case single(ReviewRead), multiple([Int64]) }
    @State private var pendingDelete: DeleteTarget?
    @State private var deleting = false

    var body: some View {
        NavigationStack {
            Group {
                if loading && rows.isEmpty {
                    ProgressView("Loading…")
                } else if let err = errorMessage {
                    ContentUnavailableView(
                        "Couldn’t load reviews",
                        systemImage: "xmark.octagon",
                        description: Text(err)
                    )
                } else if rows.isEmpty {
                    ContentUnavailableView(
                        "No Reviews Yet",
                        systemImage: "text.bubble",
                        description: Text("Your concert reviews will show up here.")
                    )
                } else {
                    List(selection: $selection) {
                        ForEach(rows, id: \.id) { r in
                            NavigationLink {
                                SetlistLoaderScreen(
                                    setlistId: r.setlist_id,
                                    fallbackArtist: r.artist_name ?? "",
                                    fallbackVenue: r.venue_name,
                                    fallbackDate: r.event_date.flatMap { MRDate.ymd.date(from: $0) }
                                )
                            } label: {
                                ReviewRow(r: r)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    pendingDelete = .single(r)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .environment(\.editMode, $editMode)
                }
            }
            .navigationTitle("My Reviews")
            .toolbar {
                // Trailing: Delete (when in edit & have selection), then Edit
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if editMode == .active && !selection.isEmpty {
                        Button("Delete (\(selection.count))", role: .destructive) {
                            pendingDelete = .multiple(Array(selection))
                        }
                    }
                    EditButton()
                }
            }
            .refreshable { await reload() }
            .task { await reload() }
            .confirmationDialog(
                "Delete review?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                if deleting {
                    Button("Deleting…") {}.disabled(true)
                } else {
                    Button("Delete", role: .destructive) { Task { await performDelete() } }
                    Button("Cancel", role: .cancel) { pendingDelete = nil }
                }
            } message: {
                Text("This removes the review for everyone on this setlist.")
            }
            .scrollContentBackground(.hidden)
            .background(Theme.appBackground)              // behind list
            .toolbarBackground(Theme.gradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)

        }
    }
    

    // MARK: Data
    private func reload() async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        do {
            rows = try await CloudStore.shared.loadMyReviews()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    private func performDelete() async {
        guard let target = pendingDelete, !deleting else { return }
        deleting = true
        defer { deleting = false; pendingDelete = nil }

        do {
            switch target {
            case .single(let r):
                try await CloudStore.shared.deleteMyReview(id: r.id)
                await MainActor.run { rows.removeAll { $0.id == r.id } }

            case .multiple(let ids):
                // Safest approach: loop (works across SDK versions)
                for rid in ids {
                    try await CloudStore.shared.deleteMyReview(id: rid)
                }
                await MainActor.run {
                    rows.removeAll { ids.contains($0.id) }
                    selection.removeAll()
                    editMode = .inactive
                }
            }
        } catch {
            await MainActor.run { errorMessage = (error as NSError).localizedDescription }
        }
    }
}

// MARK: - Row UI
private struct ReviewRow: View {
    let r: ReviewRead

    private var artist: String { r.artist_name ?? "Unknown Artist" }
    private var venue: String  { r.venue_name ?? "Unknown Venue" }

    private var eventDateText: String {
        if let s = r.event_date, let d = MRDate.ymd.date(from: s) {
            return MRDate.mdyOut.string(from: d) // MM-dd-yyyy
        }
        return "—"
    }

    private var postedText: String {
        guard let s = r.created_at, !s.isEmpty else { return "" }
        if let d = ISO8601WithFraction.shared.date(from: s) {
            return MRDate.mdyOut.string(from: d)
        }
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(artist).font(.headline)
                Spacer()
                Stars(rating: r.rating)
            }

            Text("\(venue) • \(eventDateText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let c = r.comment, !c.isEmpty {
                Text(c).lineLimit(3)
            }

            if !postedText.isEmpty {
                Text("Posted \(postedText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct Stars: View {
    let rating: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
            }
        }
        .font(.caption)
        .foregroundStyle(.yellow)
        .accessibilityLabel("\(rating) out of 5 stars")
    }
}

// MARK: - Local date helpers (no global collisions)
private enum MRDate {
    static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = .init(identifier: "en_US_POSIX")
        f.timeZone = .init(secondsFromGMT: 0)
        return f
    }()
    static let mdyOut: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MM-dd-yyyy"
        df.locale = .init(identifier: "en_US_POSIX")
        return df
    }()
}

// MARK: - ISO8601 helper
private final class ISO8601WithFraction {
    static let shared: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

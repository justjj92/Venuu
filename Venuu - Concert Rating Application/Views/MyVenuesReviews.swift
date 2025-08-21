import SwiftUI

struct MyVenuesReviews: View {
    @State private var reviews: [CloudStore.VenueReviewRead] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var pushVenue: CloudStore.VenueRow?

    var body: some View {
        NavigationStack {
            Group {
                if loading && reviews.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if let e = errorText {
                    Text(e).foregroundStyle(.red).padding()
                } else if reviews.isEmpty {
                    ContentUnavailableView(
                        "No venue reviews",
                        systemImage: "building.columns",
                        description: Text("Write a review on a venue and it will appear here.")
                    )
                } else {
                    List {
                        ForEach(reviews, id: \.id) { r in
                            Button {
                                pushVenue = CloudStore.VenueRow(
                                    id: r.venue_id,
                                    name: r.venue_name ?? "Venue",
                                    city: r.venue_city,
                                    state: r.venue_state,
                                    avg_rating: nil,
                                    reviews_count: nil
                                )
                            } label: { ReviewCell(r) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await deleteReview(r.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("My Venue Reviews")
            .navigationDestination(item: $pushVenue) { v in
                VenueDetailView(venue: v)
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    // MARK: - Data
    @MainActor
    private func reload() async {
        loading = true; errorText = nil
        defer { loading = false }
        do {
            reviews = try await CloudStore.shared.loadMyVenueReviews()
        } catch {
            errorText = (error as NSError).localizedDescription
        }
    }

    @MainActor
    private func deleteReview(_ id: Int64) async {
        do {
            try await CloudStore.shared.deleteMyVenueReview(id: id)
            await reload()
        } catch {
            errorText = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Cell
private struct ReviewCell: View {
    let r: CloudStore.VenueReviewRead
    init(_ r: CloudStore.VenueReviewRead) { self.r = r }

    private var overall: Double {
        var xs: [Double] = [Double(r.parking), Double(r.staff), Double(r.food), Double(r.sound)]
        if let a = r.access { xs.append(Double(a)) }
        return xs.reduce(0, +) / max(1, Double(xs.count))
    }

    private var place: String {
        [r.venue_city, r.venue_state].compactMap { $0?.nilIfEmpty }.joined(separator: ", ")
    }

    private var author: String {
        r.display_name?.nilIfEmpty ?? r.username?.nilIfEmpty ?? "You"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(r.venue_name ?? "Venue").font(.headline)
                Spacer()
                StarsInline(overall) // your existing tiny star view
            }
            if !place.isEmpty {
                Text(place).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(author).font(.footnote).foregroundStyle(.secondary)
            if let c = r.comment, !c.isEmpty {
                Text(c).lineLimit(3)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

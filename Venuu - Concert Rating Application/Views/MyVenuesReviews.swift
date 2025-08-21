import SwiftUI

// Post this name when a review changes (see VenueDetailView step below)
let venueReviewDidChange = Notification.Name("venueReviewDidChange")

struct MyVenuesReviews: View {
    @EnvironmentObject private var auth: AuthVM

    @State private var reviews: [CloudStore.VenueReviewRead] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var pushVenue: CloudStore.VenueRow?

    var body: some View {
        NavigationStack {
            Group {
                if !auth.isSignedIn {
                    ContentUnavailableView(
                        "Sign in to see your venue reviews",
                        systemImage: "person.crop.circle.badge.exclam",
                        description: Text("Your reviews are tied to your account.")
                    )
                } else if loading && reviews.isEmpty {
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
                            } label: {
                                ReviewRow(r)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await deleteReview(r.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button("Open Venue") {
                                    pushVenue = CloudStore.VenueRow(
                                        id: r.venue_id,
                                        name: r.venue_name ?? "Venue",
                                        city: r.venue_city,
                                        state: r.venue_state,
                                        avg_rating: nil,
                                        reviews_count: nil
                                    )
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
            .scrollContentBackground(.hidden)
            .background(Theme.appBackground)              // behind list
            .toolbarBackground(Theme.gradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)


            .task(id: auth.session?.user.id.uuidString) { await reload() }
            .onAppear { Task { await reload() } }
            .refreshable { await reload() }

            // Reload right after submit/edit/delete elsewhere
            .onReceive(NotificationCenter.default.publisher(for: venueReviewDidChange)) { _ in
                Task { await reload() }
            }
        }
    }

    // MARK: - Data

    @MainActor
    private func reload() async {
        guard auth.isSignedIn else { reviews = []; errorText = nil; return }
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
            reviews.removeAll { $0.id == id }
            NotificationCenter.default.post(name: venueReviewDidChange, object: nil)
        } catch {
            errorText = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Row

private struct ReviewRow: View {
    let r: CloudStore.VenueReviewRead
    init(_ r: CloudStore.VenueReviewRead) { self.r = r }

    private var overall: Double {
        var xs: [Double] = [Double(r.parking), Double(r.staff), Double(r.food), Double(r.sound)]
        if let a = r.access { xs.append(Double(a)) }
        return xs.reduce(0, +) / Double(xs.count)
    }
    private var place: String {
        [r.venue_city, r.venue_state].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(r.venue_name ?? "Venue").font(.headline)
                Spacer()
                StarsInline(overall)
            }
            if !place.isEmpty {
                Text(place).font(.subheadline).foregroundStyle(.secondary)
            }
            if let c = r.comment, !c.isEmpty {
                Text(c).lineLimit(2)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

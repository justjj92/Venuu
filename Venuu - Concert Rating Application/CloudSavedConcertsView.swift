import SwiftUI

struct CloudSavedConcertsView: View {
    @State private var rows: [SetlistRow] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        List {
            if loading { ProgressView().frame(maxWidth: .infinity, alignment: .center) }
            if let error { Text(error).foregroundStyle(.red) }

            ForEach(rows) { s in
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.artist_name).font(.headline)
                    Text("\(s.venue_name ?? "—") • \(s.city ?? "—")")
                        .font(.subheadline)
                    Text(s.event_date ?? "—")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if rows.isEmpty && !loading && error == nil {
                ContentUnavailableView("No saved concerts", systemImage: "bookmark",
                                       description: Text("Tap “Save Concert” on a setlist."))
            }
        }
        .navigationTitle("Saved (Cloud)")
        .task { await load() }
    }

    private func load() async {
        loading = true; error = nil
        defer { loading = false }
        do { rows = try await CloudStore.shared.loadMySavedSetlists() }
        catch { self.error = error.localizedDescription }
    }
}

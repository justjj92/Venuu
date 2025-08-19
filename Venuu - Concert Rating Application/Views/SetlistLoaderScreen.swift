import SwiftUI

/// Reusable loader that fetches an APISetlist by ID and then shows SetlistDetailView.
/// Use this when navigating from a SavedConcert (local) so you get collapsible sets.
struct SetlistLoaderScreen: View {
    let setlistId: String
    let fallbackArtist: String?
    let fallbackVenue: String?
    let fallbackDate: Date?

    @State private var api: APISetlist?
    @State private var error: String?

    var body: some View {
        Group {
            if let api {
                SetlistDetailView(setlist: api)
            } else if let error {
                ContentUnavailableView("Couldn't open setlist",
                                       systemImage: "exclamationmark.triangle",
                                       description: Text(error))
            } else {
                VStack(spacing: 10) {
                    ProgressView("Opening setlist…")
                    if let hint = fallbackHint {
                        Text(hint).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task { await load() }
        .navigationTitle("Setlist")
    }

    private var fallbackHint: String? {
        var parts: [String] = []
        if let a = fallbackArtist { parts.append(a) }
        if let v = fallbackVenue { parts.append(v) }
        if let d = fallbackDate { parts.append(DateFormatter.mdyOut.string(from: d)) }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func load() async {
        do {
            let s = try await SetlistAPI.shared.getSetlist(id: setlistId)
            await MainActor.run { self.api = s }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}



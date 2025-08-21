import SwiftUI

/// Bridges a Setlist.fm venue result into your Supabase `venues` table (creating it if needed),
/// then navigates into the standard VenueDetailView.
struct VenueLoaderScreen: View {
    let apiVenue: SetlistAPI.APIVenueSummary

    @State private var row: CloudStore.VenueRow?
    @State private var errorText: String?
    @State private var busy = false

    var body: some View {
        Group {
            if let v = row {
                VenueDetailView(venue: v)
            } else if let e = errorText {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.red)
                    Text(e)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Try again") { Task { await load() } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ProgressView("Loading…")
                    .task { await load() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .navigationTitle(apiVenue.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func load() async {
        guard !busy else { return }
        busy = true; defer { busy = false }

        do {
            // Normalize inputs once (no ambiguity for the compiler)
            let trimmedName = apiVenue.name.trimmingCharacters(in: .whitespacesAndNewlines)

            // Use the raw API model directly (no dependency on helper extensions).
            let rawCity  = apiVenue.city?.name ?? ""
            // Prefer stateCode; fall back to state if needed.
            let rawState = apiVenue.city?.stateCode ?? apiVenue.city?.state ?? ""

            let cityTrimmed  = rawCity.trimmingCharacters(in: .whitespacesAndNewlines)
            let stateTrimmed = rawState.trimmingCharacters(in: .whitespacesAndNewlines)

            let cityArg: String?  = cityTrimmed.isEmpty  ? nil : cityTrimmed
            let stateArg: String? = stateTrimmed.isEmpty ? nil : stateTrimmed

            // 1) Try to find an existing venue (read from the *table* to avoid decode issues)
            if let existing = try await CloudStore.shared.findVenue(
                name: trimmedName,
                city: cityArg,
                state: stateArg
            ) {
                row = existing
                return
            }

            // 2) Create minimal row, then use it directly
            let created = try await CloudStore.shared.upsertVenue(
                name: trimmedName,
                city: cityArg,
                state: stateArg
            )
            row = created
        } catch {
            errorText = (error as NSError).localizedDescription
        }
    }
}

// VenueLoadedScreen.swift
import SwiftUI

struct VenueLoadedScreen: View {
    let apiVenue: SetlistAPI.APIVenueSummary

    @State private var row: CloudStore.VenueRow?
    @State private var errorText: String?

    var body: some View {
        Group {
            if let v = row {
                VenueDetailView(venue: v)          // ← your detailed view
            } else if let e = errorText {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle)
                    Text(e).foregroundStyle(.red).multilineTextAlignment(.center)
                    Button("Try again") { Task { await open() } }
                }
                .padding()
            } else {
                ProgressView("Opening venue…")
            }
        }
        .task { await open() }
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func open() async {
        errorText = nil
        do {
            row = try await CloudStore.shared.fetchOrCreateVenue(from: apiVenue)
        } catch {
            row = nil
            errorText = (error as NSError).localizedDescription
        }
    }
}

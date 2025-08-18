// MyConcertsView.swift
import SwiftUI
import SwiftData
import UIKit

struct MyConcertsView: View {
    /// Optional override. If you don't pass it, we'll use the current signed-in user.
    let ownerId: UUID? = nil

    @EnvironmentObject private var auth: AuthVM
    @Environment(\.modelContext) private var ctx

    // Fetch everything, then filter by owner in-memory so switching accounts live-updates.
    @Query(sort: [SortDescriptor(\SavedConcert.eventDate, order: .reverse)])
    private var allSaved: [SavedConcert]

    @State private var syncing = false
    @State private var syncError: String?
    @State private var unsaveError: String?

    // The user whose items we’re showing
    private var currentOwner: UUID? { ownerId ?? auth.session?.user.id }

    private var visible: [SavedConcert] {
        allSaved.filter { $0.ownerUserId == currentOwner }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visible.isEmpty {
                    ContentUnavailableView(
                        currentOwner == nil ? "No concerts (Guest)" : "No concerts yet",
                        systemImage: "music.note.list",
                        description: Text("Search for a show and tap Save to add it here.")
                    )
                } else {
                    List {
                        ForEach(visible) { c in
                            NavigationLink {
                                SetlistLoaderScreen(
                                    setlistId: c.setlistId,
                                    fallbackArtist: c.artistName,
                                    fallbackVenue: c.venueName,
                                    fallbackDate: c.eventDate
                                )
                            } label: {
                                SavedConcertRow(concert: c)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await unsaveItem(c) }
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { indexSet in
                            let targets = indexSet.map { visible[$0] }
                            Task { await unsaveMany(targets) }
                        }
                    }
                }
            }
            .navigationTitle("My Concerts")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { EditButton() } }
            .refreshable { await syncNow() }
            .task { await initialSync() }
            .alert("Sync failed", isPresented: .constant(syncError != nil)) {
                Button("OK") { syncError = nil }
            } message: { Text(syncError ?? "") }
            .alert("Couldn’t remove", isPresented: .constant(unsaveError != nil)) {
                Button("OK") { unsaveError = nil }
            } message: { Text(unsaveError ?? "") }
        }
    }

    // MARK: - Sync

    private func initialSync() async { await syncNow(mergeFirst: true) }

    private func syncNow(mergeFirst: Bool = false) async {
        guard !syncing else { return }
        syncing = true; defer { syncing = false }
        do {
            if (try? await supa.auth.session) != nil {
                if mergeFirst { await CloudStore.shared.mergeCloudSavedIntoLocal(using: ctx) }
                await CloudStore.shared.syncPendingSaves(using: ctx)
            }
        } catch {
            syncError = (error as NSError).localizedDescription
        }
    }

    // MARK: - Unsave

    private func unsaveMany(_ items: [SavedConcert]) async {
        for item in items { await unsaveItem(item) }
    }

    private func unsaveItem(_ item: SavedConcert) async {
        // If signed in: remove from cloud then local (scoped to this user).
        // If guest: delete local only.
        if (try? await supa.auth.session) != nil {
            do {
                try await CloudStore.shared.unsaveEverywhere(setlistId: item.setlistId, using: ctx)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } catch {
                unsaveError = (error as NSError).localizedDescription
            }
        } else {
            // Guest removal = local only
            ctx.delete(item)
            try? ctx.save()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - Row
private struct SavedConcertRow: View {
    let concert: SavedConcert

    private var placeText: String {
        let v = concert.venueName ?? "—"
        let c = concert.city ?? "—"
        return v + " • " + c
    }
    private var dateText: String {
        if let d = concert.eventDate { return MCDate.mdyOut.string(from: d) }
        return "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(concert.artistName).font(.headline)
            Text(placeText).font(.subheadline)
            HStack(spacing: 8) {
                Text(dateText).font(.footnote).foregroundStyle(.secondary)
                if concert.pendingCloudSave {
                    SyncBadge(text: "Pending sync", tint: .orange)
                } else if let ts = concert.lastCloudSyncAt {
                    SyncBadge(text: "Synced " + MCDate.shortTime.string(from: ts), tint: .green)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SyncBadge: View {
    let text: String
    let tint: Color
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

// Local date helpers (scoped to avoid name collisions)
private enum MCDate {
    static let mdyOut: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MM-dd-yyyy"
        df.locale = .init(identifier: "en_US_POSIX")
        return df
    }()
    static let shortTime: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df
    }()
}

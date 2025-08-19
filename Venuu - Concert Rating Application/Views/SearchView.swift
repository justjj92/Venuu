// SearchView.swift
import SwiftUI
import SwiftData
import UIKit

struct SearchView: View {
    @EnvironmentObject private var auth: AuthVM
    @Environment(\.modelContext) private var ctx
    @StateObject private var location = LocationProvider()   // from LocationHelper.swift

    // Inputs
    @State private var artistText = ""
    @State private var venueText  = ""
    @State private var cityText   = ""

    // Search results
    @State private var results: [APISetlist] = []
    @State private var page = 1
    @State private var hasMore = false
    @State private var loading = false

    // Nearby (auto when no criteria)
    @State private var nearbyLoading = false
    @State private var nearbyCity: String?
    @State private var nearby: [APISetlist] = []

    // Debounce
    @State private var searchTask: Task<Void, Never>?

    // Login sheet
    @State private var showLogin = false

    // Popular suggestions from local saves (backed by SwiftData)
    @Query private var saved: [SavedConcert]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: Search fields
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        IconField(system: "person.fill",
                                  placeholder: "Artist (optional)",
                                  text: $artistText,
                                  submit: performInstantSearch)
                        IconField(system: "building.columns.fill",
                                  placeholder: "Venue (optional)",
                                  text: $venueText,
                                  submit: performInstantSearch)
                    }
                    IconField(system: "mappin.and.ellipse",
                              placeholder: "City (optional)",
                              text: $cityText,
                              submit: performInstantSearch)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal)
                .padding(.top, 12)

                // Popular chips (only if nothing typed)
                if !hasCriteria {
                    PopularArtistsChips(artists: popularArtists(from: saved, ownerId: auth.session?.user.id)) { chip in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        artistText = chip
                        performInstantSearch()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                // MARK: Content
                Group {
                    if hasCriteria {
                        // Search results
                        if loading && results.isEmpty {
                            ProgressView("Searching…")
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else if results.isEmpty {
                            EmptyFriendly(
                                title: "No matching setlists",
                                detail: "Try a different artist, venue, or city."
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else {
                            ResultsList(items: results,
                                        hasMore: hasMore,
                                        loading: loading,
                                        loadMore: { await loadNextPage() },
                                        onSave: { await save(api: $0) })
                            .refreshable { await refresh() }
                        }
                    } else {
                        // Nearby section (auto when allowed)
                        if let tag = nearbyTag {
                            NearbyHeader(tag: tag)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }

                        if nearbyLoading && nearby.isEmpty {
                            ProgressView("Finding concerts near you…")
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else if !nearby.isEmpty {
                            ResultsList(items: nearby,
                                        hasMore: false,
                                        loading: false,
                                        loadMore: {},
                                        onSave: { await save(api: $0) })
                            .refreshable { await fetchNearbyIfPossible(force: true) }
                        } else {
                            EmptyFriendly(
                                title: "Find a setlist",
                                detail: "Search by artist, venue or city. Turn on location to see concerts near you."
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                }
                .animation(.default, value: results)
                .animation(.default, value: nearby)
            }
            .navigationTitle("Concerts")
            .onAppear { location.requestWhenInUse() }
            .task(id: location.city) { await fetchNearbyIfPossible() }
            .onChange(of: artistText, debounce: 0.35) { _ in scheduleDebouncedSearch() }
            .onChange(of: venueText,  debounce: 0.35) { _ in scheduleDebouncedSearch() }
            .onChange(of: cityText,   debounce: 0.35) { _ in scheduleDebouncedSearch() }
        }
        .sheet(isPresented: $showLogin) {
            LoginSheet().environmentObject(auth)
        }
    }

    // MARK: Computed

    private var hasCriteria: Bool {
        !(artistText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        || !(venueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        || !(cityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var nearbyTag: String? {
        guard !hasCriteria else { return nil }
        guard let city = nearbyCity, !city.isEmpty, !nearby.isEmpty else { return nil }
        return "Concerts Near Me — \(city)"
    }

    // MARK: Search helpers

    private func performInstantSearch() {
        searchTask?.cancel()
        Task { await refresh() }
    }

    private func scheduleDebouncedSearch() {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            await refresh()
        }
    }

    @MainActor
    private func refresh() async {
        guard hasCriteria, !loading else {
            if !hasCriteria { results = []; hasMore = false }
            return
        }
        loading = true; page = 1
        defer { loading = false }
        do {
            let items = try await SetlistAPI.shared.searchSetlists(
                artistName: trimmedOrNil(artistText),
                cityName:  trimmedOrNil(cityText),
                venueName: trimmedOrNil(venueText),
                page: page
            )
            results = items
            hasMore = !items.isEmpty
        } catch {
            results = []
            hasMore = false
        }
    }

    @MainActor
    private func loadNextPage() async {
        guard hasCriteria, !loading, hasMore else { return }
        loading = true; defer { loading = false }
        do {
            page += 1
            let items = try await SetlistAPI.shared.searchSetlists(
                artistName: trimmedOrNil(artistText),
                cityName:  trimmedOrNil(cityText),
                venueName: trimmedOrNil(venueText),
                page: page
            )
            results.append(contentsOf: items)
            hasMore = !items.isEmpty
        } catch {
            // ignore
        }
    }

    private func trimmedOrNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    // MARK: Nearby

    @MainActor
    private func fetchNearbyIfPossible(force: Bool = false) async {
        // Only when not actively searching
        guard !hasCriteria else { return }
        guard let city = location.city, !city.isEmpty else { return }
        if !force, city == nearbyCity, !nearby.isEmpty { return }

        nearbyLoading = true
        defer { nearbyLoading = false }

        do {
            // City + state + country first
            var items = try await SetlistAPI.shared.searchSetlists(
                cityName: city,
                stateCode: location.stateCode,
                countryCode: location.countryCode,
                page: 1
            )
            if items.isEmpty {
                // City-only fallback
                items = try await SetlistAPI.shared.searchSetlists(cityName: city, page: 1)
            }
            nearbyCity = city
            nearby = items
        } catch {
            nearbyCity = city
            nearby = []
        }
    }

    // MARK: Save (cloud + local, requires sign-in)
    private func save(api: APISetlist) async -> Bool {
        // Require sign-in
        guard let session = try? await supa.auth.session else {
            await MainActor.run { showLogin = true }
            return false
        }
        let uid = session.user.id

        // Prepare data
        let songs = api.sets?.set?.flatMap { $0.song?.compactMap { $0.name } ?? [] } ?? []
        let df = SetlistAPI.shared.eventDateFormatter
        let parsedDate = api.eventDate.flatMap { df.date(from: $0) }
        let id = api.id

        do {
            // Cloud: ensure setlist exists then save to user
            try await CloudStore.shared.upsertSetlist(from: api)
            try await CloudStore.shared.saveToUser(setlistId: id, attendedOn: parsedDate)

            // Local mirror (scoped to this user)
            try await MainActor.run {
                let pred = #Predicate<SavedConcert> { $0.setlistId == id && $0.ownerUserId == uid }
                let f = FetchDescriptor<SavedConcert>(predicate: pred)
                let existing = try? ctx.fetch(f)
                if let local = existing?.first {
                    local.artistName = api.artist.name
                    local.venueName = api.venue?.name
                    local.city = api.venue?.city?.name
                    local.country = api.venue?.city?.country?.name ?? api.venue?.city?.country?.code
                    local.eventDate = parsedDate
                    local.songs = songs
                    local.attributionURL = api.url
                    local.pendingCloudSave = false
                    local.lastCloudSyncAt = Date()
                    local.ownerUserId = uid
                } else {
                    let model = SavedConcert(
                        setlistId: id,
                        artistName: api.artist.name,
                        venueName: api.venue?.name,
                        city: api.venue?.city?.name,
                        country: api.venue?.city?.country?.name ?? api.venue?.city?.country?.code,
                        eventDate: parsedDate,
                        songs: songs,
                        attributionURL: api.url,
                        pendingCloudSave: false,
                        ownerUserId: uid
                    )
                    model.lastCloudSyncAt = Date()
                    ctx.insert(model)
                }
                try? ctx.save()
            }
            return true
        } catch {
            // Don’t mark as saved if the cloud call fails
            print("Save from SearchView failed:", error)
            return false
        }
    }
}

// MARK: - Popular artists helpers
extension SearchView {
    /// Build a simple popularity list from local saves for THIS user.
    fileprivate func popularArtists(from saved: [SavedConcert], ownerId: UUID?) -> [String] {
        var counts: [String: Int] = [:]
        for s in saved where s.ownerUserId == ownerId {
            let name = s.artistName
            if isCollab(name) { continue }
            counts[name, default: 0] += 1
        }
        let top = counts.sorted { $0.value > $1.value }.prefix(12).map { $0.key }
        if !top.isEmpty { return top }

        // Fallback set you can tweak
        return [
            "Taylor Swift","Drake","Beyoncé","Bad Bunny","Kendrick Lamar",
            "Billie Eilish","Ed Sheeran","Coldplay","Travis Scott","Doja Cat","Post Malone","Zach Bryan"
        ]
    }

    fileprivate func isCollab(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains(" feat") || lower.contains(" featuring")
            || lower.contains("&") || lower.contains(" and ")
            || lower.contains(" x ") || lower.contains(" + ")
            || lower.contains(",")
    }
}

// MARK: - Components

fileprivate struct IconField: View {
    let system: String
    let placeholder: String
    @Binding var text: String
    var submit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: system).foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .onSubmit(submit)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
    }
}

fileprivate struct PopularArtistsChips: View {
    let artists: [String]
    var tap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Popular Artists")
                .font(.subheadline).bold()
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(artists, id: \.self) { name in
                        Button { tap(name) } label: {
                            Text(name)
                                .font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.primary.opacity(0.06))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

fileprivate struct ResultsList: View {
    let items: [APISetlist]
    let hasMore: Bool
    let loading: Bool
    var loadMore: () async -> Void
    var onSave: (APISetlist) async -> Bool

    var body: some View {
        List {
            ForEach(items, id: \.id) { s in
                SetlistCard(setlist: s) { await onSave(s) }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
            }
            if hasMore {
                HStack {
                    Spacer()
                    Button {
                        Task { await loadMore() }
                    } label: {
                        if loading { ProgressView() }
                        else { Label("Load more", systemImage: "arrow.down") }
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
    }
}

fileprivate struct SetlistCard: View {
    let setlist: APISetlist
    var onSave: () async -> Bool

    private var title: String { setlist.artist.name }
    private var subtitle: String {
        let v = setlist.venue?.name ?? "—"
        let c = setlist.venue?.city?.name ?? "—"
        return v + " • " + c
    }
    private var dateText: String {
        if let s = setlist.eventDate,
           let d = SetlistAPI.shared.eventDateFormatter.date(from: s) {
            let df = DateFormatter()
            df.dateFormat = "MM-dd-yyyy"
            df.locale = .init(identifier: "en_US_POSIX")
            return df.string(from: d)
        }
        return "—"
    }

    private var songCount: Int { setlist.sets?.set?.flatMap { $0.song ?? [] }.count ?? 0 }

    var body: some View {
        NavigationLink {
            SetlistDetailView(setlist: setlist)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.headline)
                    Spacer()
                    Text(dateText).font(.footnote).foregroundStyle(.secondary)
                }
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Chip(text: "\(songCount) songs", systemImage: "music.note.list")
                    if let url = setlist.url, !url.isEmpty { Chip(text: "setlist.fm", systemImage: "link") }
                    Spacer()
                    SavePill(tap: onSave)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct Chip: View {
    let text: String
    let systemImage: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.caption2)
            Text(text).font(.caption2)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.primary.opacity(0.06))
        .clipShape(Capsule())
    }
}

fileprivate struct SavePill: View {
    var tap: () async -> Bool
    @State private var busy = false
    @State private var done = false

    var body: some View {
        Button {
            Task { await tapped() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: done ? "checkmark.circle.fill" : "bookmark.fill")
                Text(done ? "Saved" : "Save")
            }
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                LinearGradient(colors: done ? [Color.green, Color.green.opacity(0.85)]
                               : [Color.accentColor, Color.accentColor.opacity(0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .shadow(color: (done ? Color.green : Color.accentColor).opacity(0.3), radius: 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(done || busy)
    }

    private func tapped() async {
        guard !busy, !done else { return }
        busy = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let ok = await tap()
        if ok {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { done = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        busy = false
    }
}

fileprivate struct EmptyFriendly: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title).font(.title3.weight(.semibold))
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }
}

fileprivate struct NearbyHeader: View {
    let tag: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope").font(.caption)
            Text(tag).font(.footnote.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.05))
        .clipShape(Capsule())
        .padding(.top, 2)
    }
}

// MARK: - Debounced onChange helper (file scope)
private extension View {
    /// Debounced variant of onChange so we don't hammer the network while typing.
    func onChange<T: Equatable>(of value: T, debounce: Double, perform: @escaping (T) -> Void) -> some View {
        modifier(DebouncedChangeModifier(value: value, delay: debounce, action: perform))
    }
}

private struct DebouncedChangeModifier<T: Equatable>: ViewModifier {
    let value: T
    let delay: Double
    let action: (T) -> Void
    @State private var workItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        content.onChange(of: value) { _, newVal in
            workItem?.cancel()
            let wi = DispatchWorkItem { action(newVal) }
            workItem = wi
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: wi)
        }
    }
}

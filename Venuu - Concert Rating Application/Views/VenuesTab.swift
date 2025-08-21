// Views/VenuesTab.swift
import SwiftUI

struct VenuesTab: View {
    @StateObject private var location = LocationProvider()

    // Input
    @State private var nameText = ""

    // Results
    @State private var results: [SetlistAPI.APIVenueSummary] = []
    @State private var loading = false
    @State private var errorText: String?

    // Nearby
    @State private var nearby: [SetlistAPI.APIVenueSummary] = []
    @State private var nearbyLoading = false
    @State private var nearbyCity: String?

    // Navigation
    @State private var pushVenue: SetlistAPI.APIVenueSummary?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Search field
                VStack(spacing: 12) {
                    VenueIconField(
                        system: "building.columns.fill",
                        placeholder: "Venue name",
                        text: $nameText,
                        submit: refresh
                    )
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
                .padding(.horizontal)
                .padding(.top, 12)

                // Content
                Group {
                    if hasCriteria {
                        if loading && results.isEmpty {
                            ProgressView("Searching…")
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else if let e = errorText {
                            Text(e).foregroundStyle(.red)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else if results.isEmpty {
                            EmptyFriendlyVenues(title: "No venues found",
                                                detail: "Try a different name.")
                        } else {
                            List {
                                ForEach(results, id: \.id) { v in
                                    Button { pushVenue = v } label: { VenueRowCell(v) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .listStyle(.plain)
                        }
                    } else {
                        if let tag = nearbyTag {
                            NearbyHeaderVenues(tag: tag)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                        if nearbyLoading && nearby.isEmpty {
                            ProgressView("Finding venues near you…")
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else if !nearby.isEmpty {
                            List {
                                ForEach(nearby, id: \.id) { v in
                                    Button { pushVenue = v } label: { VenueRowCell(v) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .listStyle(.plain)
                        } else {
                            EmptyFriendlyVenues(title: "Search venues",
                                                detail: "Enter a venue. Turn on location to see nearby.")
                        }
                    }
                }
                .animation(.default, value: results)
                .animation(.default, value: nearby)
            }
            .navigationTitle("Venues")
            .onAppear { location.requestWhenInUse() }
            .task(id: location.city) { await reloadNearbyIfPossible() }
            .onChange(of: nameText) { _ in debounceRefresh() }
            .navigationDestination(item: $pushVenue) { v in
                VenueLoaderScreen(apiVenue: v)   // Bridges API venue → Cloud row, then shows detail
            }
            .scrollContentBackground(.hidden)
            .background(Theme.appBackground)              // behind list
            .toolbarBackground(Theme.gradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)

        }
    }

    // MARK: - Derived

    private var hasCriteria: Bool {
        !nameText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
    }

    private var nearbyTag: String? {
        guard !hasCriteria else { return nil }
        guard let city = location.city, !city.isEmpty, !nearby.isEmpty else { return nil }
        return "Venues Near Me — \(city)"
    }

    // MARK: - Search

    @State private var searchTask: Task<Void, Never>?

    private func debounceRefresh() {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            await refresh()
        }
    }

    @MainActor
    private func refresh() async {
        guard hasCriteria, !loading else {
            if !hasCriteria { results = [] }
            return
        }
        loading = true; errorText = nil
        defer { loading = false }
        do {
            let trimmed = nameText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let list = try await SetlistAPI.shared.searchVenues(name: trimmed)
            // Drop entries with empty name and dedupe by id
            var seen = Set<String>()
            results = list.compactMap { v in
                let hasName = !v.name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
                guard hasName, !seen.contains(v.id) else { return nil }
                seen.insert(v.id); return v
            }
        } catch {
            results = []
            errorText = (error as NSError).localizedDescription
        }
    }

    // MARK: - Nearby using current city/state

    @MainActor
    private func reloadNearbyIfPossible() async {
        guard !hasCriteria else { return }
        guard let city = location.city, !city.isEmpty else { return }
        if city == nearbyCity, !nearby.isEmpty { return }

        nearbyLoading = true
        defer { nearbyLoading = false }

        do {
            let list = try await SetlistAPI.shared.venuesInCity(city, stateCode: location.stateCode)
            // Filter out any blank-name rows and dedupe by id
            var seen = Set<String>()
            nearby = list.compactMap { v in
                let hasName = !v.name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
                guard hasName, !seen.contains(v.id) else { return nil }
                seen.insert(v.id); return v
            }
            nearbyCity = city
        } catch {
            nearbyCity = city
            nearby = []
            errorText = (error as NSError).localizedDescription
        }
    }
}

// MARK: - Local UI bits

private struct VenueIconField: View {
    let system: String
    let placeholder: String
    @Binding var text: String
    var submit: () async -> Void

    var body: some View {
        RoundedIconField(system: system, placeholder: placeholder, text: $text) {
            Task { await submit() }
        }
    }
}

private struct VenueRowCell: View {
    let v: SetlistAPI.APIVenueSummary
    init(_ v: SetlistAPI.APIVenueSummary) { self.v = v }

    var place: String {
        var parts: [String] = []
        let city = v.cityName
        if !city.isEmpty { parts.append(city) }
        let st = v.stateText
        if !st.isEmpty { parts.append(st) }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Theme.gradient)
                    Image(systemName: "building.columns.fill")
                        .foregroundStyle(.white)
                        .font(.subheadline.weight(.semibold))
                }
                .frame(width: 30, height: 30)

                Text(v.name)
                    .font(.headline)
                    .lineLimit(2)
                    .padding(.vertical, 2)
            }

            if !place.isEmpty {
                Text(place)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }
}


private struct EmptyFriendlyVenues: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.gradient.opacity(0.25)).frame(width: 80, height: 80)
                Image(systemName: "building.columns")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.gradient)
            }
            Text(title).font(.title3.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct NearbyHeaderVenues: View {
    let tag: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope").font(.caption)
            Text(tag).font(.footnote.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.gradient.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.gradient.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.top, 2)
    }
}


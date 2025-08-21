// Data/API/APIClient+Venues.swift
import Foundation

extension SetlistAPI {

    // MARK: - Models (keep ONLY here; remove any duplicates)
    public struct APIVenueSummary: Decodable, Identifiable, Hashable {
        public let id: String                // setlist.fm venue id (string)
        public let name: String
        public let city: City?

        public struct City: Decodable, Hashable {
            public let name: String?
            public let state: String?
            public let stateCode: String?
            public let country: Country?

            public struct Country: Decodable, Hashable {
                public let code: String?
                public let name: String?
            }
        }

    }

    private struct APIVenuesList: Decodable {
        let venue: [APIVenueSummary]?
    }

    // MARK: - Endpoints

    /// search/venues?name=... (supports setlist.fm fuzzy name search)
    public func searchVenues(name: String, page: Int = 1) async throws -> [APIVenueSummary] {
        let req = try request(
            path: "/search/venues",
            query: [
                URLQueryItem(name: "name", value: name),
                URLQueryItem(name: "p", value: String(page))
            ]
        )
        let list = try await execute(req, as: APIVenuesList.self)
        return list.venue ?? []
    }

    /// search/venues by location (we use this for “Nearby”)
    public func venuesInCity(_ cityName: String, stateCode: String? = nil, page: Int = 1) async throws -> [APIVenueSummary] {
        var qs: [URLQueryItem] = [
            URLQueryItem(name: "cityName", value: cityName),
            URLQueryItem(name: "p", value: String(page))
        ]
        if let s = stateCode, !s.isEmpty {
            qs.append(URLQueryItem(name: "stateCode", value: s))
        }
        let req = try request(path: "/search/venues", query: qs)
        let list = try await execute(req, as: APIVenuesList.self)
        return list.venue ?? []
    }
}


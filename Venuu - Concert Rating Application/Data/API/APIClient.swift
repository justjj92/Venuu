import Foundation

// MARK: - Errors
public enum SetlistAPIError: LocalizedError {
    case badURL
    case missingKey
    case http(Int, String?)
    case decoding
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .badURL: return "Bad URL."
        case .missingKey: return "Missing SETLIST_FM_API_KEY in Info.plist."
        case .http(let code, let msg):
            if let msg, !msg.isEmpty { return "HTTP \(code): \(msg)" }
            return "HTTP \(code)."
        case .decoding: return "Could not decode server response."
        case .unknown(let s): return s
        }
    }
}

private struct APIErrorPayload: Decodable { let code: Int?; let message: String? }

// MARK: - Client
public final class SetlistAPI {
    public static let shared = SetlistAPI()
    private init() {}

    private let base = URL(string: "https://api.setlist.fm/rest/1.0")!
    private let json = "application/json"

    /// setlist.fm uses dd-MM-yyyy for `date` in /search/setlists
    public let eventDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd-MM-yyyy"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()

    // Build request (adds headers, language, key)
    fileprivate func request(path: String, query: [URLQueryItem] = []) throws -> URLRequest {
        guard var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw SetlistAPIError.badURL
        }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw SetlistAPIError.badURL }

        guard let key = Bundle.main.object(forInfoDictionaryKey: "SETLIST_FM_API_KEY") as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SetlistAPIError.missingKey
        }

        var req = URLRequest(url: url)
        req.setValue(json, forHTTPHeaderField: "Accept")
        req.setValue(key, forHTTPHeaderField: "x-api-key")

        // Accept-Language must be one of: en, de, es, fr, it, pt
        let supported: Set<String> = ["en","de","es","fr","it","pt"]
        let preferred2 = Locale.preferredLanguages.first.map { String($0.prefix(2)).lowercased() } ?? "en"
        let lang = supported.contains(preferred2) ? preferred2 : "en"
        req.setValue(lang, forHTTPHeaderField: "Accept-Language")

        req.setValue("ConcertTracker/1.0 (+you@example.com)", forHTTPHeaderField: "User-Agent")
        return req
    }

    // Execute with gentle 429 backoff
    fileprivate func execute<T: Decodable>(_ req: URLRequest, as type: T.Type) async throws -> T {
        var attempt = 0
        while true {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw SetlistAPIError.decoding }

            if http.statusCode == 429, attempt < 2 {
                let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")).flatMap(Double.init)
                let wait = retryAfter ?? pow(2.0, Double(attempt)) // 1s, 2s
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                attempt += 1
                continue
            }

            guard (200..<300).contains(http.statusCode) else {
                let msg: String? = (try? JSONDecoder().decode(APIErrorPayload.self, from: data))?.message
                throw SetlistAPIError.http(http.statusCode, msg)
            }

            do { return try JSONDecoder().decode(T.self, from: data) }
            catch { throw SetlistAPIError.decoding }
        }
    }

    // MARK: - Artists / Setlists (uses your existing models)

    public func getSetlist(id: String) async throws -> APISetlist {
        let req = try request(path: "setlist/\(id)")
        return try await execute(req, as: APISetlist.self)
    }

    public func searchArtists(named name: String, page: Int = 1) async throws -> [ArtistSummary] {
        let req = try request(path: "search/artists",
                              query: [URLQueryItem(name: "artistName", value: name),
                                      URLQueryItem(name: "p", value: String(page))])
        let list = try await execute(req, as: APIList<ArtistSummary>.self)
        return list.artist ?? []
    }

    public func searchSetlists(artistName: String,
                               cityName: String? = nil,
                               date: Date? = nil,
                               page: Int = 1) async throws -> [APISetlist] {
        var q: [URLQueryItem] = [
            URLQueryItem(name: "artistName", value: artistName),
            URLQueryItem(name: "p", value: String(page))
        ]
        if let cityName, !cityName.isEmpty { q.append(URLQueryItem(name: "cityName", value: cityName)) }
        if let date { q.append(URLQueryItem(name: "date", value: eventDateFormatter.string(from: date))) }
        let req = try request(path: "search/setlists", query: q)
        let list = try await execute(req, as: APIList<APISetlist>.self)
        return list.setlist ?? []
    }

    public func searchSetlists(artistName: String? = nil,
                               cityName: String? = nil,
                               venueName: String? = nil,
                               stateCode: String? = nil,
                               countryCode: String? = nil,
                               page: Int = 1) async throws -> [APISetlist] {
        var items: [URLQueryItem] = [URLQueryItem(name: "p", value: String(page))]
        if let a = artistName, !a.isEmpty { items.append(URLQueryItem(name: "artistName", value: a)) }
        if let c = cityName,  !c.isEmpty { items.append(URLQueryItem(name: "cityName", value: c)) }
        if let v = venueName, !v.isEmpty { items.append(URLQueryItem(name: "venueName", value: v)) }
        if let s = stateCode, !s.isEmpty { items.append(URLQueryItem(name: "stateCode", value: s)) }
        if let cc = countryCode, !cc.isEmpty { items.append(URLQueryItem(name: "countryCode", value: cc)) }

        let req = try request(path: "search/setlists", query: items)
        let list = try await execute(req, as: APIList<APISetlist>.self)
        return list.setlist ?? []
    }
}

// MARK: - Venues (Setlist.fm)
public extension SetlistAPI {

    // Public so views can use it; Hashable/Identifiable for SwiftUI lists/navigation.
    struct APIVenueSummary: Decodable, Identifiable, Hashable {
        public let id: String              // setlist.fm venue id
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
    } // <— CLOSES APIVenueSummary

    private struct APIVenuesList: Decodable {
        let venue: [APIVenueSummary]?
        let total: Int?
        let page: Int?
        let itemsPerPage: Int?
    }

    /// Live fuzzy venue search by name (used for "type-ahead").
    func searchVenues(name: String, page: Int = 1) async throws -> [APIVenueSummary] {
        let req = try request(
            path: "search/venues",
            query: [
                URLQueryItem(name: "name", value: name),
                URLQueryItem(name: "p", value: String(page))
            ]
        )
        let list = try await execute(req, as: APIVenuesList.self)
        return list.venue ?? []
    }

    /// Venues in a city (used for Nearby).
    func venuesInCity(_ cityName: String, stateCode: String? = nil, page: Int = 1) async throws -> [APIVenueSummary] {
        var qs: [URLQueryItem] = [
            URLQueryItem(name: "cityName", value: cityName),
            URLQueryItem(name: "p", value: String(page))
        ]
        if let s = stateCode, !s.isEmpty { qs.append(URLQueryItem(name: "stateCode", value: s)) }

        let req = try request(path: "search/venues", query: qs)
        let list = try await execute(req, as: APIVenuesList.self)
        return list.venue ?? []
    }
} // <— CLOSES `public extension SetlistAPI`

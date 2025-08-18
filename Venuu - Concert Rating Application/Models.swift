import Foundation

// MARK: - Public API models (single source of truth)

public struct ArtistSummary: Decodable, Hashable {
    public let name: String
    public let mbid: String?
}

public struct APISetlist: Decodable, Hashable {
    public struct Artist: Decodable, Hashable { public let name: String; public let mbid: String? }
    public struct Country: Decodable, Hashable { public let code: String?; public let name: String? }
    public struct City: Decodable, Hashable { public let name: String?; public let country: Country? }
    public struct Venue: Decodable, Hashable { public let name: String?; public let city: City? }
    public struct Song: Decodable, Hashable { public let name: String? }
    public struct SetBlock: Decodable, Hashable { public let name: String?; public let song: [Song]? }
    public struct Sets: Decodable, Hashable { public let set: [SetBlock]? }

    public let id: String
    public let eventDate: String?           // dd-MM-yyyy
    public let artist: Artist
    public let venue: Venue?
    public let sets: Sets?
    public let url: String?                 // attribution link (show in UI)
}

// Generic list envelope used by setlist.fm endpoints
public struct APIList<T: Decodable>: Decodable {
    public let type: String?
    public let itemsPerPage: Int?
    public let page: Int?
    public let total: Int?
    public let setlist: [T]?
    public let artist: [T]?
}

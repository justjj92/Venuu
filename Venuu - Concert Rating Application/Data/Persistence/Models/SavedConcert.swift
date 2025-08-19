// SavedConcert.swift
import Foundation
import SwiftData

/// Local cache of a saved concert, scoped per signed-in user via `ownerUserId`.
@Model
final class SavedConcert {

    // Stable key from setlist.fm (e.g. "7bd4ae6a")
    @Attribute(.unique)
    var setlistId: String

    /// Which user “owns” this local row (prevents cross-account leakage on device)
    var ownerUserId: UUID?

    // Display fields
    var artistName: String
    var venueName: String?
    var city: String?
    var country: String?
    var eventDate: Date?

    // Store songs in a plain String to keep SwiftData happy (no transformable needed)
    /// Songs joined by line breaks. Persisted.
    private var songsBlob: String = ""

    /// Convenience computed accessor. Not persisted.
    @Transient
    var songs: [String] {
        get { songsBlob.split(whereSeparator: \.isNewline).map { String($0) } }
        set { songsBlob = newValue.joined(separator: "\n") }
    }

    var attributionURL: String?

    // Local-only notes
    var localRating: Int?
    var localComment: String?

    // Cloud sync bookkeeping
    var pendingCloudSave: Bool
    var lastCloudSyncAt: Date?

    // MARK: - Init

    init(
        setlistId: String,
        artistName: String,
        venueName: String?,
        city: String?,
        country: String?,
        eventDate: Date?,
        songs: [String],
        attributionURL: String?,
        pendingCloudSave: Bool,
        ownerUserId: UUID? = nil
    ) {
        self.setlistId = setlistId
        self.artistName = artistName
        self.venueName = venueName
        self.city = city
        self.country = country
        self.eventDate = eventDate
        self.songsBlob = songs.joined(separator: "\n")
        self.attributionURL = attributionURL
        self.pendingCloudSave = pendingCloudSave
        self.ownerUserId = ownerUserId
        self.lastCloudSyncAt = nil
        self.localRating = nil
        self.localComment = nil
    }
}

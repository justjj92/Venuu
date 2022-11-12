//
//  SFMSetlist.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import Foundation

public struct SfmSetlist: Codable {

    public var artist: SfmArtist?
    public var venue: SfmVenue?
    public var tour: SfmTour?
    /** all sets of this setlist */
    public var _set: [SfmSet]?
    /** additional information on the concert - see the &lt;a href&#x3D;\&quot;https://www.setlist.fm/guidelines\&quot;&gt;setlist.fm guidelines&lt;/a&gt; for a complete list of allowed content. */
    public var info: String?
    /** the attribution url to which you have to link to wherever you use data from this setlist in your application */
    public var url: String?
    /** unique identifier */
    public var _id: String?
    /** unique identifier of the version */
    public var versionId: String?
    /** the id this event has on &lt;a href&#x3D;\&quot;http://last.fm/\&quot;&gt;last.fm&lt;/a&gt; (deprecated) */
    public var lastFmEventId: Int?
    /** date of the concert in the format &amp;quot;dd-MM-yyyy&amp;quot; */
    public var eventDate: String?
    /** date, time and time zone of the last update to this setlist in the format &amp;quot;yyyy-MM-dd&#x27;T&#x27;HH:mm:ss.SSSZZZZZ&amp;quot; */
    public var lastUpdated: String?

    public init(artist: SfmArtist? = nil, venue: SfmVenue? = nil, tour: SfmTour? = nil, _set: [SfmSet]? = nil, info: String? = nil, url: String? = nil, _id: String? = nil, versionId: String? = nil, lastFmEventId: Int? = nil, eventDate: String? = nil, lastUpdated: String? = nil) {
        self.artist = artist
        self.venue = venue
        self.tour = tour
        self._set = _set
        self.info = info
        self.url = url
        self._id = _id
        self.versionId = versionId
        self.lastFmEventId = lastFmEventId
        self.eventDate = eventDate
        self.lastUpdated = lastUpdated
    }

    public enum CodingKeys: String, CodingKey {
        case artist
        case venue
        case tour
        case _set = "set"
        case info
        case url
        case _id = "id"
        case versionId
        case lastFmEventId
        case eventDate
        case lastUpdated
    }

}

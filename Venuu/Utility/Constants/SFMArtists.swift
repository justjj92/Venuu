//
//  SFMArtists.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import Foundation

public struct SfmArtists: Codable {

    public var artist: [SfmArtist]?
    public var total: Double?
    public var page: Double?
    public var itemsPerPage: Double?

    public init(artist: [SfmArtist]? = nil, total: Double? = nil, page: Double? = nil, itemsPerPage: Double? = nil) {
        self.artist = artist
        self.total = total
        self.page = page
        self.itemsPerPage = itemsPerPage
    }


}

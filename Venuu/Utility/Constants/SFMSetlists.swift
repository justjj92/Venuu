//
//  SFMSetlists.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import Foundation

public struct SfmSetlists: Codable {

    public var setlist: [SfmSetlist]?
    public var total: Int?
    public var page: Int?
    public var itemsPerPage: Int?

    public init(setlist: [SfmSetlist]? = nil, total: Int? = nil, page: Int? = nil, itemsPerPage: Int? = nil) {
        self.setlist = setlist
        self.total = total
        self.page = page
        self.itemsPerPage = itemsPerPage
    }


}

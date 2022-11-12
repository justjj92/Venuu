//
//  SFMVenue.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import Foundation

public struct SfmVenue: Codable {

    public var sfmCity: SfmCity?
    /** the attribution url */
    public var url: String?
    /** unique identifier */
    public var _id: String?
    /** the name of the venue, usually without city and country. E.g. &lt;em&gt;&amp;quot;Madison Square Garden&amp;quot;&lt;/em&gt; or &lt;em&gt;&amp;quot;Royal Albert Hall&amp;quot;&lt;/em&gt; */
    public var name: String?

    public init(sfmCity: SfmCity? = nil, url: String? = nil, _id: String? = nil, name: String? = nil) {
        self.sfmCity = sfmCity
        self.url = url
        self._id = _id
        self.name = name
    }

    public enum CodingKeys: String, CodingKey {
        case sfmCity = "sfm_city"
        case url
        case _id = "id"
        case name
    }

}

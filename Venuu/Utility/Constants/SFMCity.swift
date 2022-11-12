//
//  SFMCity.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import Foundation

public struct SfmCity: Codable {

    public var _id: String?
    public var name: String?
    public var stateCode: String?
    public var state: String?
    public var coords: SfmCoords?
    public var country: SfmCountry?

    public init(_id: String? = nil, name: String? = nil, stateCode: String? = nil, state: String? = nil, coords: SfmCoords? = nil, country: SfmCountry? = nil) {
        self._id = _id
        self.name = name
        self.stateCode = stateCode
        self.state = state
        self.coords = coords
        self.country = country
    }

    public enum CodingKeys: String, CodingKey {
        case _id = "id"
        case name
        case stateCode
        case state
        case coords
        case country
    }

}

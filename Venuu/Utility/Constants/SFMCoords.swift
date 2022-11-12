//
//  SFMCoords.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import Foundation

public struct SfmCoords: Codable {
    
    public var long: Double?
    public var lat: Double?
    
    public init(long: Double? = nil, lat: Double? = nil) {
        self.long = long
        self.lat = lat
    }
    
}

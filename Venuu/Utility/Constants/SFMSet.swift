//
//  SFMSet.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import Foundation

public struct SfmSet: Codable {

    
    public var name: String?
    public var encore: Int?
    public var song: [SfmSong]?

    public init(name: String? = nil, encore: Int? = nil, song: [SfmSong]? = nil) {
        self.name = name
        self.encore = encore
        self.song = song
    }


}

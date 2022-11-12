//
//  SFMSong.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import Foundation

public struct SfmSong: Codable {

    public var name: String?
    public var with: SfmArtist?
    public var cover: SfmArtist?
    public var info: String?
    public var tape: Bool?

    public init(name: String? = nil, with: SfmArtist? = nil, cover: SfmArtist? = nil, info: String? = nil, tape: Bool? = nil) {
        self.name = name
        self.with = with
        self.cover = cover
        self.info = info
        self.tape = tape
    }


}

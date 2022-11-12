//
//  SFMCountry.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import Foundation

public struct SfmCountry: Codable {


    public var code: String?
    public var name: String?

    public init(code: String? = nil, name: String? = nil) {
        self.code = code
        self.name = name
    }


}

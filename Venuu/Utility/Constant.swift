//
//  Constant.swift
//  Venuu
//
//  Created by J J on 9/16/22.
//

import SwiftUI
import Contentful
import Combine
import SDWebImageSwiftUI

//DATA

let headers: [Header] = Bundle.main.decode("header.json")
//let categories: [Category] = Bundle.main.decode("category.json")
//let products: [Product] = Bundle.main.decode("product.json")
//let brands: [Brand] = Bundle.main.decode("brand.json")
//let sampleProduct: Product = products[0]

//COLOR

let colorBackground: Color = Color("ColorBackground")
let colorGray: Color = Color(UIColor.systemGray4)

//LAYOUT

let columnSpacing: CGFloat = 10
let rowSpacing: CGFloat = 10
var gridLayout: [GridItem] {
    return Array(repeating: GridItem(.flexible(), spacing: rowSpacing), count: 1)
}

//UX

let feedback = UIImpactFeedbackGenerator(style: .medium)

//API
enum Constants {
    static let apiKey = "c-EG8Kq1LunhGfAdASOUyETeqafwk4sx1pRe"
    static let baseURL = "https://api.setlist.fm/rest/1.0/search/"
}

class APIService {
    let urlString: String
    init(urlString: String) {
        self.urlString = urlString
    }
    
   func getJSON<T: Decodable>(dateDecodingStategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
                                      keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) async throws -> T {
        guard let url = URL(string: urlString) else {
           fatalError("Error: Invalid URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
       request.addValue(Constants.apiKey, forHTTPHeaderField: "x-api-key")
       request.addValue("application/json", forHTTPHeaderField: "Accept")
       let (data, response) = try await URLSession.shared.data(for: request)
       guard let _ = response as? HTTPURLResponse else {
           fatalError("Error: Data Request error.")
       }
       let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStategy
        decoder.keyDecodingStrategy = keyDecodingStrategy
       do {
           return try decoder.decode(T.self, from: data)
       } catch {
           throw error
       }
//        guard let decodedData =  try? decoder.decode(T.self, from: data) else {
//            print(String(decoding: data, as: UTF8.self))
//            throw err
//        }
//        return decodedData
    }
}


struct SetListFM: Codable {
    // MARK: - Setlist
    struct Setlist: Codable {
        let id, versionID, eventDate, lastUpdated: String
        let artist: Artist
        let venue: Venue
        let sets: Sets
        let info: String?
        let url: String
        let tour: Tour?

        enum CodingKeys: String, CodingKey {
            case id
            case versionID = "versionId"
            case eventDate, lastUpdated, artist, venue, sets, info, url, tour
        }
    }
    
    // MARK: - Artist
    struct Artist: Codable {
        let mbid, name, sortName: String
        let disambiguation: String?
        let url: String
    }
    
    // MARK: - Sets
    struct Sets: Codable {
        let setsSet: [Set]

        enum CodingKeys: String, CodingKey {
            case setsSet = "set"
        }
    }
    
    // MARK: - Set
    struct Set: Codable {
        let name: String?
        let song: [Song]
        let encore: Int?
    }

    // MARK: - Song
    struct Song: Codable {
        let name: String
        let tape: Bool?
        let cover, with: Artist?
        let info: String?
    }

    // MARK: - Tour
    struct Tour: Codable {
        let name: TourName
    }

    enum TourName: String, Codable {
        case dondaListeningParties = "Donda Listening Parties"
        case sundayService = "Sunday Service"
    }

    // MARK: - Venue
    struct Venue: Codable {
        let id, name: String
        let city: City
        let url: String
    }

    // MARK: - City
    struct City: Codable {
        let id, name: String
        let state, stateCode: String?
        let coords: Coords
        let country: Country
    }

    // MARK: - Coords
    struct Coords: Codable {
        let lat, long: Double
    }

    // MARK: - Country
    struct Country: Codable {
        let code: Code
        let name: String
    }

    enum Code: String, Codable {
        case us = "US"
    }

    let type: String
    let itemsPerPage: Int
    let page: Int
    let total: Int
    let artist: [Artist]
}









//MARK: - Contentful API

//MARK: - BlogPostStore API helper








//IMAGE


//FONT


//STRING


//MISC

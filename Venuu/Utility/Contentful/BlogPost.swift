//
//  BlogPost.swift
//  Venuu
//
//  Created by J J on 11/10/22.
//

import Foundation
import Contentful
import SDWebImageSwiftUI

struct BlogPost: Identifiable {
    let id = UUID()
    
    var title: String
    var date: String
    var body: String
    var blogPicture: URL
    var isFeatured: Bool
}

var articleList: [BlogPost] = []

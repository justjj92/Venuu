//
//  FeaturedView.swift
//  Venuu
//
//  Created by J J on 9/16/22.
//

import SwiftUI

struct FeaturedView: View {
    //MARK: - PROPERTIES
    
    let header: Header
    
    //MARK: - BODY
    
    
    var body: some View {
        Image(header.image)
            .resizable()
            .scaledToFit()
            .cornerRadius(12)
    }
}


//MARK: - BODY
struct FeaturedView_Previews: PreviewProvider {
    static var previews: some View {
        FeaturedView(header: headers[0])
            .previewLayout(.sizeThatFits)
            .padding()
            .background(.white)
    }
}

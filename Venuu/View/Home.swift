//
//  Home.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import SwiftUI

struct Home: View {
    var body: some View {
        
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 15) {
                
                ScrollView(.vertical, showsIndicators: false, content: {
                    VStack(spacing: 0) {
                        FeaturedTabView()
                            .frame(minHeight: 256)
                            .padding(.vertical, 10)
                        
                        
                    }
                }) //end scroll view
            } //end vstack
        } // end scroll view
    }
    
    struct Home_Previews: PreviewProvider {
        static var previews: some View {
            Home()
        }
    }
}

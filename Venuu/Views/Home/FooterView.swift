//
//  FooterView.swift
//  Venuu
//
//  Created by J J on 9/16/22.
//

import SwiftUI

struct FooterView: View {
    //MARK: - PROPERTIES
    
    //MARK: - BODY
    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text("Venuu \nThe Ultimate Venue Experience")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .layoutPriority(2)
            
//            Image("logo-lineal")
//                    .renderingMode(.template)
//                    .foregroundColor(.gray)
//                    .layoutPriority(0)
            
            Text("Copyright © Justin Jordan\nALL Rights reserved")
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .layoutPriority(1)
            
        }//VSTACK
        .padding()
    }
}


    //MARK: - PREVIEW
struct FooterView_Previews: PreviewProvider {
    static var previews: some View {
        FooterView()
            .previewLayout(.sizeThatFits)
            .background(colorBackground)
            
    }
}

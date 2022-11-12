//
//  LogoView.swift
//  Venuu
//
//  Created by J J on 9/16/22.
//

import SwiftUI

struct LogoView: View {
    //MARK: - PROPERTIES
    
    //MARK: - BODY
    var body: some View {
        HStack(spacing: 4) {
            
            Image("Venuu_Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20, alignment: .center)

            
        } //: HSTACK
    }
}


//MARK: - PREVEIW
struct LogoView_Previews: PreviewProvider {
    static var previews: some View {
        LogoView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}

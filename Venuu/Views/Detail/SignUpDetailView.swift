//
//  SignUpDetailView.swift
//  Venuu
//
//  Created by J J on 9/16/22.
//

import SwiftUI

struct SignUpDetailView: View {
    //MARK: - PROPRTIES
    
//    @EnvironmentObject var shop: Shop
    
    //MARK: - BODY
    var body: some View {
        Button(action: {
            feedback.impactOccurred()
        }, label: {
            Spacer()
            Text("Sign Up".uppercased())
                .font(.system(.title2, design: .rounded))
                .foregroundColor(.black)
            Spacer()
            
        })//: Button
        .padding(15)
        .background(Color(UIColor.systemGray))
        .clipShape(Capsule())
        
        }
    }


//MARK: - PREVIEW
struct SignUpDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpDetailView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}

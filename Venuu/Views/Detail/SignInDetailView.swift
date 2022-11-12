//
//  SignInDetailView.swift
//  Venuu
//
//  Created by J J on 9/16/22.
//

import SwiftUI

struct SignInDetailView: View {
    //MARK: - PROPRTIES
    
    //    @EnvironmentObject var shop: Shop
    
    //MARK: - BODY
    var body: some View {
            NavigationLink(destination: ContentView()) {
                Button(action: {
                    feedback.impactOccurred()
                }, label: {
                    Spacer()
                    Text("Sign In".uppercased())
                        .font(.system(.title2, design: .rounded))
                        .foregroundColor(.black)
                    Spacer()
                    
                })//: Button
                .padding(15)
                .background(Color(UIColor.systemGray4))
                .clipShape(Capsule())
                
            
        }
    }
}

//MARK: - PREVIEW
struct SignInDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SignInDetailView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}

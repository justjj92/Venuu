//
//  ContentView.swift
//  Venuu
//
//  Created by J J on 9/13/22.
//

import SwiftUI


struct LoginView: View {
    private let localVideoName = "intro3"
    @State private var isActive: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                BgdFullScreenVideoView(videoName: localVideoName)
                    .overlay(Color.white.opacity(0.2))
                VStack {
                    Image("Venuu_Logo")
                        .resizable()
                        .scaledToFit()
                        .position(x:200, y:100)
                        
                    
                    Spacer()
                    
                    NavigationLink(destination: ContentView(), isActive: self.$isActive) {
                        
                    }
                    Button(action: {
                        self.isActive = true
                        feedback.impactOccurred()
                    }, label: {
                        Spacer()
                        Text("Sign In".uppercased())
                            .font(.system(.title2, design: .rounded))
                            .foregroundColor(.black)
                        Spacer()
                        
                        
                    }) //: Button
                    
                    .padding(15)
                    .background(Color(UIColor.systemGray4))
                    .clipShape(Capsule())
                        .padding(.bottom, 10)
                    //                    .position(x:200, y:500)
                    
                    
                    SignUpDetailView()
                        .padding(.bottom, 20)
                    
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}

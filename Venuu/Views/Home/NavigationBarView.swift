//
//  NavigationBarView.swift
//  Venuu
//
//  Created by J J on 9/16/22.
//

import SwiftUI

struct NavigationBarView: View {
    //MARK: - PROPERTIES
    @State private var isSearchActivated: Bool = false
    @State private var isAnimated: Bool = false
    
    //MARK: - BODY
    var body: some View {
            HStack {
                
                //: BUTTON
                
                Spacer()
                
                LogoView()
                    .opacity(isAnimated ? 1 : 0)
                    .offset(x: 0, y: isAnimated ? 0 : -50)
                    .onAppear(perform : {
                        withAnimation(.easeOut(duration: 0.5)) {
                            isAnimated.toggle()
                        }
                    })
                
                Spacer()
                
                NavigationLink(destination: SearchView(), isActive: self.$isSearchActivated) {
                    Button(action: {
                        feedback.impactOccurred()
                        self.isSearchActivated = true
                    }, label: {
                        
                        Image(systemName: "magnifyingglass")
                            .font(.title)
                            .foregroundColor(.black)
                    })
                } //: BUTTON
                
            } //: HSTACK
    }
}


//MARK: - PREVIEW
struct NavigationBarView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationBarView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}

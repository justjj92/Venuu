//
//  ContentView.swift
//  Venuu
//
//  Created by J J on 9/16/22.
//

import SwiftUI

struct ContentView: View {
    
    //MARK: - PROPERTIES
    
    
    //MARK: - BODY
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                
                MainView()
                
            } //: VSTACK
        }.navigationBarBackButtonHidden(true)
    }
    
    //MARK: - PREVIEW
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
}

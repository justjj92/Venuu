//
//  CustomTabView.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import SwiftUI

struct CustomTabView: View {
    @Binding var currentTab: String
    @Binding var showMenu: Bool
    
    @State private var isSearchActivated: Bool = false
    @State private var isAnimated: Bool = false

    var body: some View {
        VStack {
            //Static Header View for all Pages
            HStack {
                //Menu Button
                Button {
                    //Toggling Menu Option
                    withAnimation(.spring()){
                        showMenu = true
                    }
                } label: {
                    
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                // Hiding when Menu is Open
                .opacity(showMenu ? 0 : 1)
                
                Spacer()
                
                NavigationLink(destination: SearchView(), isActive: self.$isSearchActivated) {
                    Button(action: {
                        feedback.impactOccurred()
                        self.isSearchActivated = true
                    }, label: {
                        
                        Image(systemName: "magnifyingglass")
                            .resizable()
                            .foregroundColor(.white)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 30, height: 30)
                            .cornerRadius(5)
                    })
                } //: BUTTON
                
            }
            //Page title
            .overlay(
            Text(currentTab)
                .font(.title2.bold())
                .foregroundColor(.white)
            // same hiding when menu is visible...
                .opacity(showMenu ? 0 : 1)
            )
            
            .padding([.horizontal,.top])
            .padding(.bottom, 8)
            .padding(.top,getSafeArea().top)
            
            TabView(selection: $currentTab) {
                Home()
                    .tag("Home")
                
                SearchView()
                    .tag("Discover")
            
                    
                        
                
            }
        }
        //Disbaling action when menu is Visible...
        .disabled(showMenu)
        .frame(maxWidth: .infinity, maxHeight:  .infinity)
        .overlay(
            
            //Close Button
            Button {
                //Toggling Menu Option
                withAnimation(.spring()){
                    showMenu = false
                }
            } label: {
                
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // Hiding when Menu is Open
            .opacity(showMenu ? 1 : 0)
            .padding()
            .padding(.top)
            ,alignment: .topLeading
        )
        .background(
            Color.black
        )
    }
}

struct CustomTabView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

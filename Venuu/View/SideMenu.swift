//
//  SideMenu.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import SwiftUI

struct SideMenu: View {
    @Binding var currentTab: String
    
    // Adding smooth transition between tabs with Matched Geometry Effect
    @Namespace var animation
    var body: some View {
        VStack {
            
            HStack(spacing: 10) {
                Text("Venuu")
                    .font(.title.bold())
                    .foregroundColor(.white)
                
                    
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            //For small screens
                
                //MARK: - Tab Buttons
                VStack(alignment: .leading, spacing: 15) {
                    CustomTabButton(icon: "music.note.house", title: "Home")
                    
                    CustomTabButton(icon: "safari.fill", title: "Discover")
                    
                    CustomTabButton(icon: "music.note", title: "Blog")
                    
                    CustomTabButton(icon: "heart.fill", title: "Favorites")
                    
                    CustomTabButton(icon: "music.note.tv", title: "Interviews")
                    
                    CustomTabButton(icon: "gearshape.fill", title: "Setting")
                    
                    CustomTabButton(icon: "questionmark.circle", title: "Help")
                    
                    Spacer()
                    
                    CustomTabButton(icon: "rectangle.portrait.and.arrow.right", title: "Logout")
                }
                .padding()
                .padding(.top,45)
            
            // Max Width of Screen width...
            .frame(width: getRect().width / 2, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            Color(.darkGray)
        
        )
    }
    
    //MARK: - Custom Button
    @ViewBuilder
    func CustomTabButton(icon: String, title: String)->some View {
        
        Button {
  
            if title == "Logout" {
                print("Logout")
            }
            else {
                withAnimation{
                    currentTab = title
                }
            }
            
        } label: {
            
            HStack(spacing: 12) {
                
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: currentTab == title ? 48 : nil, height: 48)
                    .foregroundColor(currentTab == title ? (Color.purple) : (title == "Logout" ? Color.orange : .white))
                    .background(
      
                        ZStack{
                            if currentTab == title {
                                    Color.white
                                        .clipShape(Circle())
                                        .matchedGeometryEffect(id: "TABCIRCLE", in: animation)
                            }
                        }
                    )
                
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(title == "Logout" ? Color.orange : .white)
            }
            .padding(.trailing, 18)
            .background(
            
                ZStack {
                    if currentTab == title {
                        Color(.purple)
                            .clipShape(Capsule())
                            .matchedGeometryEffect(id: "TABCAPSULE", in: animation)

                    }
                }
            )
        }
        .offset(x: currentTab == title ? 15 : 0)
    }
}

struct SideMenu_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

//MARK: - Extending View to get Screen Bounds
extension View{
    func getRect()->CGRect{
        return UIScreen.main.bounds
    }
}

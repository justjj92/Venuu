//
//  MainView.swift
//  Venuu
//
//  Created by J J on 11/9/22.
//

import SwiftUI

struct MainView: View {
    
    @State var currentTab: String = "Home"
    
    // Menu Option
    @State var showMenu: Bool = false
    
    //Hiding Native Tab Bar
    init(){
        UITabBar.appearance().isHidden = true
    }
    
    //MARK: - Current Tab
    var body: some View {
        ZStack {
            //MARK: - Custom Side Menu
            SideMenu(currentTab: $currentTab)

            
            //MARK: - Main Tab View
            CustomTabView(currentTab: $currentTab, showMenu: $showMenu)
            //Applying corner radius
                .cornerRadius(showMenu ? 25 : 0)
            //making 3d rotation
                .rotation3DEffect(.init(degrees: showMenu ? -15 : 0), axis: (x: 0, y: 1, z: 0),anchor: .trailing)
            //Moving view apart
                .offset(x: showMenu ? getRect().width / 2: 0)
                .ignoresSafeArea()

            
        }//end ZSTACK
        
        //Always Dark Mode
        .preferredColorScheme(.dark)
        
        
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}


extension View {
    
    func getSafeArea()-> UIEdgeInsets {
        guard let screen = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return .zero
        }
        
        guard let safeArea = screen.windows.first?.safeAreaInsets
        else{
            return .zero
        }
        
        return safeArea
    }
    
}

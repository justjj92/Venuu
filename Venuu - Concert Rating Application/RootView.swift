import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            ConcertsTab()
                .tabItem { Label("Concerts", systemImage: "music.mic") }

            ProfileTab()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

// Simple placeholder for now; you can wire your blog feed later.
struct HomeView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Venuu News",
                systemImage: "newspaper",
                description: Text("Music news & posts coming soon.")
            )
            .navigationTitle("Home")
        }
    }
}

// Concerts tab = your Search screen
struct ConcertsTab: View {
    var body: some View {
        NavigationStack {
            SearchView()
                .navigationTitle("Concerts")
        }
    }
}

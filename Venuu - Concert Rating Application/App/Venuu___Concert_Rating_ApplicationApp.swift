import SwiftUI
import SwiftData

@main
struct Venuu___Concert_Rating_ApplicationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthVM()

    // Splash visibility
    @State private var showSplash = true

    // For deep-link/open-from-notification presentation
    @State private var deepLinkSetlistId: String?
    @State private var showDeepLinkSheet = false

    var body: some Scene {
        WindowGroup {
            // Overlay the animated splash on top of your root view
            SplashGate(isActive: $showSplash) {
                RootView()
                    .environmentObject(auth)
            }
            // Kick off splash dismissal on first launch of the scene
            .task {
                // If you later want to dismiss based on auth bootstrap, replace this timer
                try? await Task.sleep(nanoseconds: 1_150_000_000)
                withAnimation(.easeInOut(duration: 1.0)) { showSplash = false }
            }
            // Your existing app bootstrap
            .onAppear {
                Task { await NotificationsManager.shared.requestIfNeeded() }
                GeoConcertMonitor.shared.enable()
            }
            // Handle push/deep-link to setlist
            .onReceive(NotificationCenter.default.publisher(for: .venuuOpenSetlistFromNotification)) { note in
                if let id = note.userInfo?["setlistId"] as? String {
                    deepLinkSetlistId = id
                    // If splash is still up, let the sheet flag be set; it will present once splash goes away
                    if !showSplash { showDeepLinkSheet = true }
                    else {
                        // Present just after splash fades so there’s no visual fight
                        Task { @MainActor in
                            while showSplash { try? await Task.sleep(nanoseconds: 100_000_000) }
                            showDeepLinkSheet = true
                        }
                    }
                }
            }
            // Deep link sheet
            .sheet(isPresented: $showDeepLinkSheet, onDismiss: { deepLinkSetlistId = nil }) {
                if let id = deepLinkSetlistId {
                    NavigationStack {
                        SetlistLoaderScreen(
                            setlistId: id,
                            fallbackArtist: "",
                            fallbackVenue: nil,
                            fallbackDate: nil
                        )
                    }
                }
            }
        }
        .modelContainer(for: [SavedConcert.self])
    }
}

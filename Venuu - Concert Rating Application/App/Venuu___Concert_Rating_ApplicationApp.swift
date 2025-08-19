import SwiftUI
import SwiftData

@main
struct Venuu___Concert_Rating_ApplicationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var auth = AuthVM()

    // For deep-link/open-from-notification presentation
    @State private var deepLinkSetlistId: String?
    @State private var showDeepLinkSheet = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .onAppear {
                    Task { await NotificationsManager.shared.requestIfNeeded() }
                    GeoConcertMonitor.shared.enable()
                }
                // If your notification code posts .venuuOpenSetlistFromNotification,
                // present a sheet with that setlist
                .onReceive(NotificationCenter.default.publisher(for: .venuuOpenSetlistFromNotification)) { note in
                    if let id = note.userInfo?["setlistId"] as? String {
                        deepLinkSetlistId = id
                        showDeepLinkSheet = true
                    }
                }
                .sheet(isPresented: $showDeepLinkSheet, onDismiss: { deepLinkSetlistId = nil }) {
                    if let id = deepLinkSetlistId {
                        NavigationStack {
                            SetlistLoaderScreen(setlistId: id,
                                                fallbackArtist: "",
                                                fallbackVenue: nil,
                                                fallbackDate: nil)
                        }
                    }
                }
        }
        .modelContainer(for: [SavedConcert.self])
    }
}

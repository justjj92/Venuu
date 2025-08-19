
import Foundation
import UserNotifications
import UIKit

@MainActor
final class NotificationsManager: ObservableObject {
    static let shared = NotificationsManager()
    @Published var authorized = false

    private init() { }

    func requestIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let ok = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
            authorized = ok ?? false
            if authorized { UIApplication.shared.registerForRemoteNotifications() }
        case .denied:
            authorized = false
        default:
            authorized = true
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func postConcertPrompt(setlistId: String, artist: String?, venue: String?) {
        let content = UNMutableNotificationContent()
        if let artist, let venue {
            content.title = "At \(artist) • \(venue)?"
            content.body  = "Want to save this concert to Venuu?"
        } else {
            content.title = "At a concert?"
            content.body  = "Save it to Venuu for your history."
        }
        content.sound = .default
        content.categoryIdentifier = "CONCERT_PROMPT"
        content.userInfo = ["setlistId": setlistId]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: "concert-\(setlistId)-\(UUID().uuidString)",
                                        content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
}

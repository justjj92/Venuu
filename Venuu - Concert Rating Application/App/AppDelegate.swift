import UIKit
import UserNotifications
import Supabase

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // Notifications center delegate for foreground banners
        UNUserNotificationCenter.current().delegate = self

        // Register custom category (w/ optional “Save now” action)
        let save = UNNotificationAction(identifier: "SAVE_NOW", title: "Save Concert", options: [.foreground])
        let cat  = UNNotificationCategory(identifier: "CONCERT_PROMPT",
                                          actions: [save],
                                          intentIdentifiers: [],
                                          options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
        return true
    }

    // Foreground presentation (banner + sound)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // Handle action taps (optional: deep link or save)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let setlistId = info["setlistId"] as? String else { return }

        switch response.actionIdentifier {
        case "SAVE_NOW":
            // Bring app to foreground and broadcast an intent to save this setlist
            NotificationCenter.default.post(name: .venuuSaveSetlistFromNotification,
                                            object: nil,
                                            userInfo: ["setlistId": setlistId])
        default:
            // Default tap: open detail
            NotificationCenter.default.post(name: .venuuOpenSetlistFromNotification,
                                            object: nil,
                                            userInfo: ["setlistId": setlistId])
        }
    }

    // (Optional) APNs device token – stored for future server pushes
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        struct PushToken: Encodable { let user_id: UUID; let token: String; let platform: String }
        Task {
            if let session = try? await supa.auth.session {
                let row = PushToken(user_id: session.user.id, token: token, platform: "ios")
                _ = try? await supa.database.from("push_tokens").upsert(row, onConflict: "user_id,token").execute()
            }
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs register failed:", error.localizedDescription)
    }
}

extension Notification.Name {
    static let venuuOpenSetlistFromNotification = Notification.Name("venuu.openSetlistFromNotification")
    static let venuuSaveSetlistFromNotification = Notification.Name("venuu.saveSetlistFromNotification")
}


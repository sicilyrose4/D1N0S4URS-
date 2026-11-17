import SwiftUI
import UserNotifications

@main
struct TeamAlarmApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if app.onboarded {
                    AlarmHome()  // one screen: the stopwatch. Teams + Settings live in its top corners
                } else {
                    Onboarding()
                }
            }
            .environment(app)
            .preferredColorScheme(.dark)
            .tint(.blue)
        }
    }
}

/// Show notification banners while the app is open.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.content.userInfo["ring"] != nil else { return }
        let now = Date.now.timeIntervalSince1970
        await MainActor.run {
            UserDefaults.standard.set(now, forKey: "wokeAt")
            UserDefaults.standard.set(true, forKey: "pendingRing")
            NotificationCenter.default.post(name: .ringNow, object: nil)
        }
    }
}

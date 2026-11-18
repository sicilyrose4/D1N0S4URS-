import SwiftUI
import UserNotifications

@main
struct TeamAlarmApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var app = AppState()

    init() {   // nav bar titles in the display face, green
        let a = UINavigationBarAppearance()
        a.configureWithOpaqueBackground()
        a.backgroundColor = UIColor(Clique.ink)
        a.shadowColor = .clear
        let green = UIColor(Clique.green)
        if let f = UIFont(name: "Basketball", size: 40) { a.largeTitleTextAttributes = [.font: f, .foregroundColor: green] }
        if let f = UIFont(name: "Basketball", size: 24) { a.titleTextAttributes = [.font: f, .foregroundColor: green] }
        if let f = UIFont(name: "Gotham-Medium", size: 17) {
            a.buttonAppearance.normal.titleTextAttributes = [.font: f]
        }
        UINavigationBar.appearance().standardAppearance = a
        UINavigationBar.appearance().scrollEdgeAppearance = a
        UINavigationBar.appearance().compactAppearance = a
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if app.onboarded {
                    AlarmHome()  // one screen: the dial. Teams + Settings live in its top corners
                } else {
                    Onboarding()
                }
            }
            .environment(app)
            .preferredColorScheme(.dark)
            .font(.gotham(17))
            .tint(Clique.green)
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

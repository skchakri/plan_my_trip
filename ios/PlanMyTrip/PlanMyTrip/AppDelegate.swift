import HotwireNative
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Registered before the first URL is routed. This is also what puts
        // "speech" in the user agent, which is what makes the web-side bridge
        // component load — WKWebView has no SpeechRecognition, so without this
        // the concierge/day-trip mic stays dead.
        Hotwire.registerBridgeComponents([
            SpeechComponent.self
        ])
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
    }
}

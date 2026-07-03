import HotwireNative
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        Hotwire.config.applicationUserAgentPrefix = "Hotwire Native iOS"
        // Native chrome: a share button on every web page, and a Done button on modals.
        Hotwire.config.defaultViewController = { url in WebViewController(url: url) }
        Hotwire.config.showDoneButtonOnModals = true
        Hotwire.loadPathConfiguration(from: [
            .server(AppConfig.pathConfigurationURL)
        ])

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = TabBarController()
        self.window = window
        window.makeKeyAndVisible()
    }
}

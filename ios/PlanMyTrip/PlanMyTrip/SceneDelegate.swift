import HotwireNative
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let navigator = Navigator()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        Hotwire.config.applicationUserAgentPrefix = "Hotwire Native iOS"
        Hotwire.loadPathConfiguration(from: [
            .server(AppConfig.pathConfigurationURL)
        ])

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigator.rootViewController
        self.window = window
        window.makeKeyAndVisible()

        navigator.route(AppConfig.rootURL)
    }
}

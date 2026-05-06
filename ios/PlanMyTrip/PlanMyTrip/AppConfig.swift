import Foundation

enum AppConfig {
    /// Override at build time with a `BASE_URL` user-defined build setting,
    /// or by editing the fallback below to the host serving the Rails app.
    /// In the iOS Simulator on macOS, `http://localhost:3010` works directly.
    /// On a physical device, use your Mac's LAN IP (e.g. `http://192.168.1.42:3010`).
    static let baseURLString: String = {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String,
           !configured.isEmpty {
            return configured
        }
        return "http://localhost:3010"
    }()

    static var rootURL: URL {
        URL(string: baseURLString)!
    }

    static var pathConfigurationURL: URL {
        URL(string: "\(baseURLString)/configurations/ios.json")!
    }
}

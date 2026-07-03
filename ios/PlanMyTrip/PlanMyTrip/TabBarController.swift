import HotwireNative
import UIKit

/// A native bottom tab bar. Each tab owns its own Hotwire `Navigator`, so the
/// web app renders inside native navigation stacks with a real UIKit tab bar —
/// native chrome the web app can't provide, and the primary reason this is more
/// than a website wrapper (App Store Guideline 4.2 "Minimum Functionality").
final class TabBarController: UITabBarController {
    /// One native tab, backed by a web section of the Rails app.
    struct Tab {
        let title: String
        let systemImage: String
        let path: String
    }

    static let defaultTabs: [Tab] = [
        Tab(title: "Trips",   systemImage: "map.fill",           path: "/trips"),
        Tab(title: "Places",  systemImage: "mappin.and.ellipse", path: "/places"),
        Tab(title: "Quizzes", systemImage: "gamecontroller.fill", path: "/quizzes"),
        Tab(title: "Account", systemImage: "person.crop.circle", path: "/users/edit"),
    ]

    private let tabItems: [Tab]
    private(set) var navigators: [Navigator] = []

    init(tabs: [Tab] = TabBarController.defaultTabs) {
        self.tabItems = tabs
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewControllers = tabItems.enumerated().map { index, tab in
            let navigator = Navigator(
                configuration: .init(name: tab.title.lowercased(), startLocation: AppConfig.url(tab.path))
            )
            navigators.append(navigator)

            let root = navigator.rootViewController
            root.tabBarItem = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.systemImage),
                tag: index
            )
            navigator.start()
            return root
        }
    }
}

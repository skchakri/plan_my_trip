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
    private var startedTabIndices = Set<Int>()

    init(tabs: [Tab] = TabBarController.defaultTabs) {
        self.tabItems = tabs
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

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
            return root
        }

        // Only the visible tab loads at launch; the rest load on first
        // selection. Eagerly starting every tab pre-sign-in rendered the
        // login page into the auth-gated tabs, which then went stale after
        // the user signed in elsewhere (App Store rejection, Guideline 2.1a).
        startTabIfNeeded(at: 0)
    }

    private func startTabIfNeeded(at index: Int) {
        guard navigators.indices.contains(index),
              startedTabIndices.insert(index).inserted else { return }
        navigators[index].start()
    }

    /// A tab that loaded while signed out keeps showing the login page even
    /// after the user signs in on another tab — cookies are shared between
    /// the tabs' web views, rendered pages are not. When such a tab is
    /// selected, revisit its start location: the shared session cookie now
    /// authenticates it. If the user really is signed out, the server just
    /// redirects back to sign-in, so this is safe in both states.
    private func revisitIfShowingStaleAuthPage(at index: Int) {
        guard navigators.indices.contains(index) else { return }
        let navigator = navigators[index]
        guard let visitable = navigator.rootViewController.topViewController as? VisitableViewController,
              isAuthPath(visitable.currentVisitableURL.path) else { return }
        navigator.route(AppConfig.url(tabItems[index].path))
    }

    private func isAuthPath(_ path: String) -> Bool {
        path.hasPrefix("/users/sign_in")
            || path.hasPrefix("/users/sign_up")
            || path.hasPrefix("/users/password")
    }
}

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard let index = viewControllers?.firstIndex(of: viewController) else { return }
        startTabIfNeeded(at: index)
        revisitIfShowingStaleAuthPage(at: index)
    }
}

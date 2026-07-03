import HotwireNative
import UIKit

/// The view controller Hotwire uses for every web page. Subclassing
/// `VisitableViewController` lets us add native chrome the web can't provide —
/// here, a native iOS **share** button in the nav bar that opens the system
/// share sheet for the current page (send a trip link via Messages/Mail,
/// "Open in AllTrails", copy, etc.). Registered as
/// `Hotwire.config.defaultViewController` in `SceneDelegate`.
final class WebViewController: VisitableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareCurrentPage)
        )
    }

    @objc private func shareCurrentPage() {
        let activity = UIActivityViewController(
            activityItems: [currentVisitableURL],
            applicationActivities: nil
        )
        // Anchor the popover to the share button on iPad.
        activity.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activity, animated: true)
    }
}

import UIKit

struct RootController {
    let viewController: () -> UIViewController?
    func callAsFunction() -> UIViewController? {
        viewController()
    }
}

extension RootController {
    static var live: Self {
        Self {
            UIApplication.shared.windows.last?.visibleViewController
        }
    }
}


import Combine
public let share: ([Any]) -> AnyPublisher<Never, Never> = { items in
    
    let activityVC = UIActivityViewController(
        activityItems: items,
        applicationActivities: nil
    )
    activityVC.popoverPresentationController?.sourceView =
        RootController.live()?.view
    
    activityVC.popoverPresentationController?.sourceRect =
        CGRect(
            origin: .zero,
            size: CGSize(width: 100, height: 100)
        )
    
    RootController.live()?.present(activityVC, animated: true)
    
    return Empty(completeImmediately: true)
        .eraseToAnyPublisher()
    
}

public extension UIWindow {
    var visibleViewController: UIViewController? {
        return UIWindow.getVisibleViewControllerFrom(self.rootViewController)
    }

    static func getVisibleViewControllerFrom(_ vc: UIViewController?) -> UIViewController? {
        if let nc = vc as? UINavigationController {
            return UIWindow.getVisibleViewControllerFrom(nc.visibleViewController)
        } else if let tc = vc as? UITabBarController {
            return UIWindow.getVisibleViewControllerFrom(tc.selectedViewController)
        } else {
            if let pvc = vc?.presentedViewController {
                return UIWindow.getVisibleViewControllerFrom(pvc)
            } else {
                return vc
            }
        }
    }
}

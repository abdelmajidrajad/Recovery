import SwiftUI
import UIKit

extension View {
    public func anyView() -> AnyView { AnyView(self) }
}

public func asAnyView<V: View>(_ input: V) -> AnyView {
    AnyView(input)
}

extension View {
    public func snapShot(
        origin: CGPoint = .zero,
        size: CGSize = CGSize(width: 400, height: 400),
        _ callback: (UIImage) -> Void
    ) {
        let window = UIWindow(frame: CGRect(origin: origin, size: size))
        let hosting = UIHostingController(rootView: self)
        hosting.view.frame = window.frame
        window.addSubview(hosting.view)
        window.makeKeyAndVisible()
        callback(hosting.view.renderedImage)
    }
}

extension UIView {
    public var renderedImage: UIImage {
        let rect = self.bounds
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        let context: CGContext = UIGraphicsGetCurrentContext()!
        self.layer.render(in: context)
        let capturedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return capturedImage
    }
}




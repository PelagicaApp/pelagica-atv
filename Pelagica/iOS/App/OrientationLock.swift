//
//  OrientationLock.swift
//  Pelagica
//

import UIKit

@MainActor
enum OrientationLock {
    private static var phoneMask: UIInterfaceOrientationMask = .portrait

    static var supported: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : phoneMask
    }

    static func set(_ mask: UIInterfaceOrientationMask) {
        guard UIDevice.current.userInterfaceIdiom == .phone, mask != phoneMask else { return }
        phoneMask = mask
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            var controller = scene.keyWindow?.rootViewController
            while let current = controller {
                current.setNeedsUpdateOfSupportedInterfaceOrientations()
                controller = current.presentedViewController
            }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.supported
    }
}

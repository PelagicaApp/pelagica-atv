//
//  PelagicaApp.swift
//  Pelagica
//

import SwiftUI

@main
struct PelagicaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

//
//  MeditationAppIOSApp.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 3/21/26.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct CallystoMeditationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            HomeScreen()
                .preferredColorScheme(.dark)
        }
    }
}

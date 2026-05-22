//
//  MeditationAppIOSApp.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 3/21/26.
//

import SwiftUI

@main
struct MeditationAppIOSApp: App {
    var body: some Scene {
        WindowGroup {
            HomeScreen()
                .preferredColorScheme(.dark)
        }
    }
}

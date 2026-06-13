//
//  AppConstants.swift
//  meditation-app-ios
//

import Foundation

enum AppConstants {
    /// Free meditation time (minutes) before login or sign up is required to start a new session.
    static let freeTrialLimitMinutes = 1

    static var freeTrialLimitSeconds: Int {
        freeTrialLimitMinutes * 60
    }
}

//
//  SessionUsageStore.swift
//  meditation-app-ios
//

import Foundation

/// Locally persisted meditation time and free-trial gate for unsigned users.
final class SessionUsageStore: ObservableObject {
    static let shared = SessionUsageStore()

    private enum Keys {
        static let totalCompletedSessionSeconds = "totalCompletedSessionSeconds"
        static let isAuthenticated = "isAuthenticated"
    }

    private let defaults: UserDefaults

    @Published private(set) var totalCompletedSeconds: Int
    @Published private(set) var isAuthenticated: Bool

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.totalCompletedSeconds = defaults.integer(forKey: Keys.totalCompletedSessionSeconds)
        self.isAuthenticated = defaults.bool(forKey: Keys.isAuthenticated)
    }

    var requiresAuthenticationBeforeNewSession: Bool {
        !isAuthenticated && totalCompletedSeconds >= AppConstants.freeTrialLimitSeconds
    }

    func recordCompletedSession(elapsedSeconds: Int) {
        guard elapsedSeconds > 0 else { return }
        let apply = {
            self.totalCompletedSeconds += elapsedSeconds
            self.defaults.set(self.totalCompletedSeconds, forKey: Keys.totalCompletedSessionSeconds)
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.sync(execute: apply)
        }
    }

    func setAuthenticated(_ authenticated: Bool) {
        isAuthenticated = authenticated
        defaults.set(authenticated, forKey: Keys.isAuthenticated)
    }
}

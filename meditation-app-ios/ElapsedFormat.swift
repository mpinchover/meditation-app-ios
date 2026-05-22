//
//  ElapsedFormat.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 3/21/26.
//

import Foundation

enum ElapsedFormat {
    static func mmss(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Session countdown / chosen duration: includes hours when needed (`H:MM:SS` or `M:SS`).
    static func sessionCountdown(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }
}

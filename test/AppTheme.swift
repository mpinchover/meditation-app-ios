//
//  AppTheme.swift
//  test
//
//  Shared charcoal shell for every screen.
//

import SwiftUI

enum AppTheme {
    /// Main canvas behind content and navigation chrome.
    static let background = Color(red: 0.14, green: 0.14, blue: 0.15)
    /// Slightly lifted surfaces (tappable rows, cards).
    static let cardFill = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.09)
    /// Hero / large titles (“Callysto”, screen titles).
    static let heroTitle = Color(red: 0.96, green: 0.95, blue: 0.93)
    /// Small row labels (“Soundscape”, captions).
    static let rowLabel = Color(red: 0.58, green: 0.57, blue: 0.55)
    /// Primary line values in rows.
    static let rowValue = Color(red: 0.92, green: 0.91, blue: 0.88)
    /// Chevrons and tertiary affordances.
    static let rowChevron = Color.white.opacity(0.38)
    /// Toolbar text buttons, play/menu, key controls.
    static let controlPrimary = Color(red: 0.90, green: 0.88, blue: 0.84)
    /// Empty states, de-emphasized body.
    static let bodyMuted = Color(red: 0.55, green: 0.54, blue: 0.52)
    /// Section subtitles, secondary lines, footnotes.
    static let secondaryText = Color(red: 0.62, green: 0.61, blue: 0.59)
    /// List row separators.
    static let listSeparator = Color.white.opacity(0.14)
    /// Selected row title and “now playing” accent.
    static let selectionAccent = Color(red: 0.72, green: 0.82, blue: 0.76)
    /// Bottom inset bars (interval slider strip).
    static let insetBarBackground = Color(red: 0.11, green: 0.11, blue: 0.12)
    /// Unselected list title opacity relative to `rowValue`.
    static let listTitleUnselectedOpacity: CGFloat = 0.62
}

#if canImport(UIKit)
import UIKit

extension AppTheme {
    static var uiRowValue: UIColor { UIColor(red: 0.92, green: 0.91, blue: 0.88, alpha: 1) }
    static var uiSecondary: UIColor { UIColor(red: 0.62, green: 0.61, blue: 0.59, alpha: 1) }
}
#endif

extension View {
    /// Charcoal background, navigation bar match, and tint for bar buttons.
    func appThemedScreen() -> some View {
        self
            .background(AppTheme.background.ignoresSafeArea())
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(AppTheme.controlPrimary)
    }

    /// For `List`: removes default list material, then applies `appThemedScreen()`.
    func appThemedListScreen() -> some View {
        self
#if os(iOS) || os(tvOS) || os(visionOS)
            .scrollContentBackground(.hidden)
#endif
            .appThemedScreen()
    }
}

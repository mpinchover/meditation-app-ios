//
//  NavigationChrome.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 3/28/26.
//

import SwiftUI

/// Shared layout metrics.
enum AppScreenChrome {
    /// Horizontal inset for the root home layout (no bar-button gutter).
    static let headerHorizontalPadding: CGFloat = 20
    /// Horizontal inset for content on **pushed** screens and the custom navigation header.
    static let navigationContentHorizontalPadding: CGFloat = 16
}

/// Screen title as the first `List` row. Hides row separators so nothing appears under the navigation bar.
struct ListScreenTitleRow: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.heroTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: AppScreenChrome.navigationContentHorizontalPadding, bottom: 12, trailing: AppScreenChrome.navigationContentHorizontalPadding))
        .listRowBackground(Color.clear)
    }
}

extension View {
    /// Leading **Back** and optional trailing text action, aligned with `navigationContentHorizontalPadding`.
    func navigationScreenChrome(
        trailingTitle: String? = nil,
        trailingAction: (() -> Void)? = nil
    ) -> some View {
        modifier(NavigationScreenChromeModifier(trailingTitle: trailingTitle, trailingAction: trailingAction))
    }

    /// Hides the system back chevron and shows a leading **Back** text button.
    func navigationTextBackButton() -> some View {
        navigationScreenChrome()
    }

    /// Trailing icon on the root home screen (no back button).
    func homeScreenTopChrome(
        trailingSystemImage: String,
        trailingAccessibilityLabel: String,
        trailingAction: @escaping () -> Void
    ) -> some View {
        modifier(HomeScreenTopChromeModifier(
            trailingSystemImage: trailingSystemImage,
            trailingAccessibilityLabel: trailingAccessibilityLabel,
            trailingAction: trailingAction
        ))
    }
}

private struct HomeScreenTopChromeModifier: ViewModifier {
    let trailingSystemImage: String
    let trailingAccessibilityLabel: String
    let trailingAction: () -> Void

    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    Button(action: trailingAction) {
                        Image(systemName: trailingSystemImage)
                            .font(.system(size: 22, weight: .medium))
                    }
                    .foregroundStyle(AppTheme.controlPrimary)
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel(trailingAccessibilityLabel)
                    .accessibilityHint("Opens account")
                }
                .padding(.horizontal, AppScreenChrome.navigationContentHorizontalPadding)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(AppTheme.background)
            }
    }
}

private struct NavigationScreenChromeModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let trailingTitle: String?
    let trailingAction: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Button("Back") { dismiss() }
                        .foregroundStyle(AppTheme.controlPrimary)
                        .buttonStyle(.plain)
                    Spacer(minLength: 0)
                    if let trailingTitle, let trailingAction {
                        Button(trailingTitle, action: trailingAction)
                            .foregroundStyle(AppTheme.controlPrimary)
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppScreenChrome.navigationContentHorizontalPadding)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(AppTheme.background)
            }
    }
}

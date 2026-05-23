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
    /// Horizontal inset for content on **pushed** screens. Matches the navigation bar’s leading/trailing
    /// margin for items like **Back** (~16pt on iPhone). Using 20pt `listRowInsets` here makes list text
    /// sit **right** of the Back label because bar buttons use the tighter system inset.
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
    /// Hides the system back chevron and shows a leading **Back** text button.
    func navigationTextBackButton() -> some View {
        modifier(NavigationTextBackButtonModifier())
    }
}

private struct NavigationTextBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
#if os(iOS) || os(tvOS) || os(visionOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                        .foregroundStyle(AppTheme.controlPrimary)
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Back") { dismiss() }
                        .foregroundStyle(AppTheme.controlPrimary)
                }
#endif
            }
    }
}

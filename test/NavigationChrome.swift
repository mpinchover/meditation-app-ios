//
//  NavigationChrome.swift
//  test
//
//  Created by Matt Pinchover on 3/28/26.
//

import SwiftUI

/// Shared metrics for pushed screens (titles, rows aligned with navigation chrome).
enum AppScreenChrome {
    static let headerHorizontalPadding: CGFloat = 20
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
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button("Back") { dismiss() }
                }
#endif
            }
    }
}

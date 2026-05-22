//
//  PreviewPlayingWaveformView.swift
//  meditation-app-ios
//
//  Animated “now playing” indicator for soundscape / bell list previews.
//

import SwiftUI

struct PreviewPlayingWaveformView: View {
    var isActive: Bool

    var body: some View {
        Image(systemName: "waveform")
            .font(.body.weight(.semibold))
            .foregroundStyle(AppTheme.selectionAccent)
            .symbolRenderingMode(.hierarchical)
            .symbolEffect(.variableColor.iterative, options: .repeating.speed(0.9), isActive: isActive)
    }
}

//
//  ActiveSessionView.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import SwiftUI

/// Full-screen session: live countdown and Finish; audio is driven by `SoundscapePlayer`.
struct ActiveSessionView: View {
    @ObservedObject var player: SoundscapePlayer

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)

            Text(ElapsedFormat.sessionCountdown(player.sessionRemainingSeconds))
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.primary)
                .accessibilityLabel("Time remaining")
                .accessibilityValue(ElapsedFormat.sessionCountdown(player.sessionRemainingSeconds))

            Spacer(minLength: 0)

            Button("Finish", role: .destructive) {
                player.finish()
            }
            .font(.body.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.85))
            .padding(.bottom, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            if player.sessionActive || player.isPlaying {
                player.finish()
            }
        }
    }
}

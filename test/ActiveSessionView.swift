//
//  ActiveSessionView.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import SwiftUI

/// Full-screen session: countdown, optional bells, then soundscape continues until Finish.
struct ActiveSessionView: View {
    @ObservedObject var player: SoundscapePlayer

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            if player.countdownFinished {
                Text("Session complete")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(ElapsedFormat.sessionCountdown(player.sessionRemainingSeconds))
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.primary)
                .accessibilityLabel(player.countdownFinished ? "Time remaining, session complete" : "Time remaining")
                .accessibilityValue(ElapsedFormat.sessionCountdown(player.sessionRemainingSeconds))

            if player.countdownFinished {
                Text("Soundscape continues until you finish.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

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

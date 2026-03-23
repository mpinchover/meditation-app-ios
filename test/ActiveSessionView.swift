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

    /// Shown after the timer hits 0:00, or any time the user pauses (so they can end early).
    private var showFinishButton: Bool {
        player.countdownFinished || (player.sessionActive && !player.isPlaying)
    }

    /// Keeps the pause/play icon at a constant Y; Finish fades into this slot without shifting the icon.
    private static let finishSlotHeight: CGFloat = 56
    /// Distance above the bottom safe area (smaller = controls sit lower).
    private static let controlsBottomInset: CGFloat = 52

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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            VStack(spacing: 12) {
                if player.sessionActive {
                    Button {
                        if player.isPlaying {
                            player.pauseSession()
                        } else {
                            player.resumeSession()
                        }
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(player.isPlaying ? "Pause session" : "Resume session")
                }

                ZStack {
                    if showFinishButton {
                        Button {
                            player.finish()
                        } label: {
                            Text("Finish")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.gray.opacity(0.32))
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Finish session")
                    }
                }
                .frame(height: Self.finishSlotHeight)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom, Self.controlsBottomInset)
        }
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            if player.sessionActive || player.isPlaying {
                player.finish()
            }
        }
    }
}

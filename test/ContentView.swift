//
//  ContentView.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import SwiftUI
import AVFoundation

private enum PlayerSlot {
    case a, b
}

private final class CrossfadeLoopDelegate: NSObject, AVAudioPlayerDelegate {
    weak var owner: AlphaWavesPlayer?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        owner?.handlePlayerFinished(player)
    }
}

private final class AlphaWavesPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    /// Seconds left in the 3-minute session; updates while playing.
    @Published private(set) var countdownSecondsRemaining: Int

    /// Aligns with the asset’s baked-in 5s fade-in / 5s fade-out overlap.
    private static let crossfadeLeadSeconds = 5.0
    private static let sessionDurationSeconds = 3 * 60

    private var playerA: AVAudioPlayer?
    private var playerB: AVAudioPlayer?
    /// The track whose tail overlaps the next pass (fade-out over the other’s fade-in).
    private var primary: PlayerSlot = .a

    private var pollTimer: Timer?
    private var countdownTimer: Timer?
    private var resumeA = false
    private var resumeB = false

    private let loopDelegate = CrossfadeLoopDelegate()

    init() {
        countdownSecondsRemaining = Self.sessionDurationSeconds
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        configureAudioSessionForSimultaneousPlayback()
#endif
    }

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    /// Single shared session; both players mix on the session output without exclusive locking.
    private func configureAudioSessionForSimultaneousPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try session.setActive(true, options: [])
        } catch { }
    }
#endif

    deinit {
        pollTimer?.invalidate()
        countdownTimer?.invalidate()
    }

    func toggle() {
        ensurePlayers()
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    fileprivate func handlePlayerFinished(_ player: AVAudioPlayer) {
        if player === playerA {
            primary = .b
            playerA?.currentTime = 0
        } else if player === playerB {
            primary = .a
            playerB?.currentTime = 0
        }
    }

    private func ensurePlayers() {
        guard playerA == nil else { return }
        guard let url = Bundle.main.url(forResource: "Alpha Waves", withExtension: "mp3") else { return }
        do {
            let a = try AVAudioPlayer(contentsOf: url)
            let b = try AVAudioPlayer(contentsOf: url)
            a.numberOfLoops = 0
            b.numberOfLoops = 0
            loopDelegate.owner = self
            a.delegate = loopDelegate
            b.delegate = loopDelegate
            a.prepareToPlay()
            b.prepareToPlay()
            playerA = a
            playerB = b
        } catch { }
    }

    private func startPlayback() {
        guard playerA != nil else { return }
        if resumeA || resumeB {
            resumeFromPause()
        } else {
            startFromStopped()
        }
    }

    private func startFromStopped() {
        guard let a = playerA else { return }
        countdownSecondsRemaining = Self.sessionDurationSeconds
        resumeA = true
        resumeB = false
        primary = .a
        a.currentTime = 0
        playerB?.stop()
        playerB?.currentTime = 0
        a.play()
        isPlaying = true
        startPolling()
        startCountdownTimer()
    }

    private func pausePlayback() {
        resumeA = playerA?.isPlaying ?? false
        resumeB = playerB?.isPlaying ?? false
        playerA?.pause()
        playerB?.pause()
        pollTimer?.invalidate()
        pollTimer = nil
        stopCountdownTimer()
        isPlaying = false
    }

    private func resumeFromPause() {
        if resumeA { playerA?.play() }
        if resumeB { playerB?.play() }
        if resumeA || resumeB {
            isPlaying = true
            startPolling()
            startCountdownTimer()
        }
    }

    private func startCountdownTimer() {
        stopCountdownTimer()
        guard countdownSecondsRemaining > 0 else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.isPlaying else { return }
            guard self.countdownSecondsRemaining > 0 else {
                self.stopCountdownTimer()
                return
            }
            self.countdownSecondsRemaining -= 1
            if self.countdownSecondsRemaining == 0 {
                self.stopCountdownTimer()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        countdownTimer = t
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func startPolling() {
        pollTimer?.invalidate()
        let interval = 0.1
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.pollCrossfade()
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func primaryPlayer() -> AVAudioPlayer? {
        switch primary {
        case .a: return playerA
        case .b: return playerB
        }
    }

    private func secondaryPlayer() -> AVAudioPlayer? {
        switch primary {
        case .a: return playerB
        case .b: return playerA
        }
    }

    private func pollCrossfade() {
        guard isPlaying else { return }
        let threshold = Self.crossfadeLeadSeconds
        guard let lead = primaryPlayer(), lead.isPlaying else { return }
        let remaining = max(0, lead.duration - lead.currentTime)
        guard remaining <= threshold else { return }
        guard let other = secondaryPlayer(), !other.isPlaying else { return }
        other.currentTime = 0
        other.play()
    }
}

private enum CountdownFormat {
    static func mmss(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct ContentView: View {
    @StateObject private var audio = AlphaWavesPlayer()

    var body: some View {
        VStack(spacing: 16) {
            Text("Alpha Waves")
                .font(.title2.weight(.medium))

            Text(CountdownFormat.mmss(audio.countdownSecondsRemaining))
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Session time remaining")
                .accessibilityValue(CountdownFormat.mmss(audio.countdownSecondsRemaining))

            Button {
                audio.toggle()
            } label: {
                Label(
                    audio.isPlaying ? "Pause" : "Play",
                    systemImage: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill"
                )
                .font(.system(size: 44))
                .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(audio.isPlaying ? "Pause" : "Play Alpha Waves")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

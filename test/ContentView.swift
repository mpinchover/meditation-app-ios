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

/// Crossfades using one `AVAudioEngine` graph so both streams sum in a single stereo path (cleaner imaging than two `AVAudioPlayer`s).
private final class AlphaWavesPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    /// Seconds left in the 3-minute session; updates while playing.
    @Published private(set) var countdownSecondsRemaining: Int

    /// Aligns with the asset’s baked-in 5s fade-in / 5s fade-out overlap.
    private static let crossfadeLeadSeconds = 5.0
    private static let sessionDurationSeconds = 3 * 60

    private var engine: AVAudioEngine?
    private var fileA: AVAudioFile?
    private var fileB: AVAudioFile?
    private var nodeA: AVAudioPlayerNode?
    private var nodeB: AVAudioPlayerNode?
    private var mixerA: AVAudioMixerNode?
    private var mixerB: AVAudioMixerNode?

    /// The track whose tail overlaps the next pass (fade-out over the other’s fade-in).
    private var primary: PlayerSlot = .a

    private var pollTimer: Timer?
    private var countdownTimer: Timer?
    private var resumeA = false
    private var resumeB = false

    init() {
        countdownSecondsRemaining = Self.sessionDurationSeconds
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        configureAudioSessionForPlayback()
#endif
    }

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private func configureAudioSessionForPlayback() {
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
        engine?.stop()
    }

    func toggle() {
        ensureEngine()
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    private func handleNodeFinished(slot: PlayerSlot) {
        if slot == primary {
            primary = (slot == .a) ? .b : .a
        }
    }

    private func ensureEngine() {
        guard engine == nil else { return }
        guard let url = Bundle.main.url(forResource: "Alpha Waves", withExtension: "mp3") else { return }
        do {
            let fa = try AVAudioFile(forReading: url)
            let fb = try AVAudioFile(forReading: url)
            let na = AVAudioPlayerNode()
            let nb = AVAudioPlayerNode()
            let ma = AVAudioMixerNode()
            let mb = AVAudioMixerNode()
            let eng = AVAudioEngine()
            let format = fa.processingFormat

            eng.attach(na)
            eng.attach(nb)
            eng.attach(ma)
            eng.attach(mb)
            eng.connect(na, to: ma, format: format)
            eng.connect(nb, to: mb, format: format)
            eng.connect(ma, to: eng.mainMixerNode, format: format)
            eng.connect(mb, to: eng.mainMixerNode, format: format)

            fileA = fa
            fileB = fb
            nodeA = na
            nodeB = nb
            mixerA = ma
            mixerB = mb
            engine = eng
        } catch { }
    }

    private func node(for slot: PlayerSlot) -> AVAudioPlayerNode? {
        switch slot {
        case .a: return nodeA
        case .b: return nodeB
        }
    }

    private func file(for slot: PlayerSlot) -> AVAudioFile? {
        switch slot {
        case .a: return fileA
        case .b: return fileB
        }
    }

    private func duration(of file: AVAudioFile) -> Double {
        Double(file.length) / file.fileFormat.sampleRate
    }

    private func remainingSeconds(primarySlot: PlayerSlot) -> Double? {
        guard let n = node(for: primarySlot),
              let f = file(for: primarySlot),
              n.isPlaying,
              let last = n.lastRenderTime,
              let pt = n.playerTime(forNodeTime: last) else { return nil }
        let elapsed = Double(pt.sampleTime) / pt.sampleRate
        let total = duration(of: f)
        return max(0, total - elapsed)
    }

    private func startPlayback() {
        guard engine != nil else { return }
        if resumeA || resumeB {
            resumeFromPause()
        } else {
            startFromStopped()
        }
    }

    private func startFromStopped() {
        guard let na = nodeA, let nb = nodeB, let eng = engine else { return }
        countdownSecondsRemaining = Self.sessionDurationSeconds
        resumeA = true
        resumeB = false
        primary = .a

        na.stop()
        nb.stop()

        do {
            if !eng.isRunning {
                try eng.start()
            }
        } catch {
            return
        }

        scheduleFullFile(on: .a) { [weak self] in
            self?.handleNodeFinished(slot: .a)
        }
        isPlaying = true
        startPolling()
        startCountdownTimer()
    }

    /// Schedules one pass through the file (no looping on the node — handoff logic repeats).
    private func scheduleFullFile(on slot: PlayerSlot, completion: @escaping () -> Void) {
        guard let n = node(for: slot), let f = file(for: slot) else { return }
        n.scheduleFile(f, at: nil) { [weak self] in
            DispatchQueue.main.async {
                completion()
            }
        }
        n.play()
    }

    private func pausePlayback() {
        resumeA = nodeA?.isPlaying ?? false
        resumeB = nodeB?.isPlaying ?? false
        nodeA?.pause()
        nodeB?.pause()
        pollTimer?.invalidate()
        pollTimer = nil
        stopCountdownTimer()
        isPlaying = false
    }

    private func resumeFromPause() {
        if let eng = engine, !eng.isRunning {
            try? eng.start()
        }
        if resumeA { nodeA?.play() }
        if resumeB { nodeB?.play() }
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

    private func secondarySlot() -> PlayerSlot {
        primary == .a ? .b : .a
    }

    private func pollCrossfade() {
        guard isPlaying else { return }

        let threshold = Self.crossfadeLeadSeconds
        guard let remaining = remainingSeconds(primarySlot: primary) else { return }
        guard remaining <= threshold else { return }

        let other = secondarySlot()
        guard let sn = node(for: other), !sn.isPlaying else { return }

        sn.stop()
        scheduleFullFile(on: other) { [weak self] in
            self?.handleNodeFinished(slot: other)
        }
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

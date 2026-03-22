//
//  SoundscapePlayer.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import AVFoundation
import SwiftUI

fileprivate enum PlayerSlot {
    case a, b
}

final class SoundscapePlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    /// True after Play starts until the user finishes (including after the countdown hits zero while soundscape keeps playing).
    @Published private(set) var sessionActive = false
    @Published private(set) var sessionRemainingSeconds: Int = 0
    /// True once the session timer reaches zero; soundscape keeps playing until `finish()`.
    @Published private(set) var countdownFinished = false

    /// Session length in seconds (what was configured when playback started).
    private(set) var sessionDurationSeconds: Int = 180

    var onSessionStarted: (() -> Void)?
    var onCountdownTick: ((_ remaining: Int, _ total: Int) -> Void)?
    var onNaturalCountdownComplete: (() -> Void)?

    private static let crossfadeLeadSeconds = 10.0
    private var sessionTotalSeconds: Int = 180

    private var soundscapeURL: URL?
    private var engine: AVAudioEngine?
    private var fileA: AVAudioFile?
    private var fileB: AVAudioFile?
    private var nodeA: AVAudioPlayerNode?
    private var nodeB: AVAudioPlayerNode?
    private var primary: PlayerSlot = .a
    private var slotStartDates: [PlayerSlot: Date] = [:]
    private var fileDuration: Double = 0
    private var pollTimer: Timer?
    private var elapsedTimer: Timer?
    private var resumeA = false
    private var resumeB = false

    init() {
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        configureAudioSessionForPlayback()
#endif
    }

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private func configureAudioSessionForPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch { }
    }
#endif

    deinit {
        pollTimer?.invalidate()
        elapsedTimer?.invalidate()
        engine?.stop()
    }

    /// Call when the user picks a file; does nothing while playing. Rebuilds engine on next play.
    func applySoundscape(fileName: String) {
        guard !isPlaying, !sessionActive else { return }
        guard let url = SoundscapeCatalog.urlInBundle(fileName: fileName) else { return }
        soundscapeURL = url
        tearDownEngine()
        if !sessionActive {
            sessionRemainingSeconds = 0
        }
    }

    func configureSessionDuration(_ totalSeconds: Int) {
        guard !isPlaying, !sessionActive else { return }
        sessionTotalSeconds = max(60, totalSeconds)
        sessionDurationSeconds = sessionTotalSeconds
    }

    func toggle() {
        ensureEngine()
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    func finish() {
        onSessionStarted = nil
        onCountdownTick = nil
        onNaturalCountdownComplete = nil
        tearDownEngine()
        sessionRemainingSeconds = 0
        sessionActive = false
        isPlaying = false
        countdownFinished = false
    }

    private func handleNodeFinished(slot: PlayerSlot) {
        node(for: slot)?.stop()
        slotStartDates[slot] = nil

        if slot == primary {
            primary = (slot == .a) ? .b : .a
        }
    }

    private func tearDownEngine() {
        pollTimer?.invalidate()
        pollTimer = nil
        stopSessionCountdownTimer()
        nodeA?.stop()
        nodeB?.stop()
        engine?.stop()
        engine = nil
        fileA = nil
        fileB = nil
        nodeA = nil
        nodeB = nil
        slotStartDates.removeAll()
        primary = .a
        resumeA = false
        resumeB = false
        fileDuration = 0
    }

    private func ensureEngine() {
        guard engine == nil else { return }
        guard let url = soundscapeURL else { return }

        do {
            let fa = try AVAudioFile(forReading: url)
            let fb = try AVAudioFile(forReading: url)

            fileDuration = Double(fa.length) / fa.fileFormat.sampleRate

            let na = AVAudioPlayerNode()
            let nb = AVAudioPlayerNode()
            let eng = AVAudioEngine()
            let format = fa.processingFormat

            eng.attach(na)
            eng.attach(nb)
            eng.connect(na, to: eng.mainMixerNode, format: format)
            eng.connect(nb, to: eng.mainMixerNode, format: format)

            fileA = fa
            fileB = fb
            nodeA = na
            nodeB = nb
            engine = eng
        } catch { }
    }

    private func node(for slot: PlayerSlot) -> AVAudioPlayerNode? {
        slot == .a ? nodeA : nodeB
    }

    private func file(for slot: PlayerSlot) -> AVAudioFile? {
        slot == .a ? fileA : fileB
    }

    private func remainingSeconds(for slot: PlayerSlot) -> Double? {
        guard let start = slotStartDates[slot] else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        return max(0, fileDuration - elapsed)
    }

    private func startPlayback() {
        guard soundscapeURL != nil else { return }
        ensureEngine()
        guard engine != nil else { return }
        if resumeA || resumeB {
            resumeFromPause()
        } else {
            startFromStopped()
        }
    }

    private func startFromStopped() {
        guard let na = nodeA, let nb = nodeB, let eng = engine else { return }

        slotStartDates.removeAll()
        resumeA = true
        resumeB = false
        primary = .a

        sessionRemainingSeconds = sessionTotalSeconds
        sessionDurationSeconds = sessionTotalSeconds
        sessionActive = true
        countdownFinished = false

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
        startSessionCountdownTimer()
        onSessionStarted?()
    }

    private func scheduleFullFile(on slot: PlayerSlot, completion: @escaping () -> Void) {
        guard let n = node(for: slot), let f = file(for: slot) else { return }

        f.framePosition = 0
        slotStartDates[slot] = Date()

        n.scheduleFile(f, at: nil) {
            DispatchQueue.main.async {
                completion()
            }
        }

        n.play()
    }

    private func pausePlayback() {
        resumeA = slotStartDates[.a] != nil
        resumeB = slotStartDates[.b] != nil

        nodeA?.pause()
        nodeB?.pause()

        pollTimer?.invalidate()
        pollTimer = nil
        stopSessionCountdownTimer()
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
            if !countdownFinished, sessionRemainingSeconds > 0 {
                startSessionCountdownTimer()
            }
        }
    }

    private func startSessionCountdownTimer() {
        stopSessionCountdownTimer()
        guard !countdownFinished else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }
            if self.countdownFinished { return }

            if self.sessionRemainingSeconds > 0 {
                self.sessionRemainingSeconds -= 1
            }
            self.onCountdownTick?(self.sessionRemainingSeconds, self.sessionTotalSeconds)

            if self.sessionRemainingSeconds <= 0 {
                self.completeNaturalCountdown()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        elapsedTimer = t
    }

    private func completeNaturalCountdown() {
        guard !countdownFinished else { return }
        countdownFinished = true
        sessionRemainingSeconds = 0
        stopSessionCountdownTimer()
        onNaturalCountdownComplete?()
    }

    private func stopSessionCountdownTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func startPolling() {
        pollTimer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.pollCrossfade()
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func pollCrossfade() {
        guard isPlaying else { return }

        let other: PlayerSlot = (primary == .a) ? .b : .a

        guard let remaining = remainingSeconds(for: primary),
              remaining <= Self.crossfadeLeadSeconds,
              slotStartDates[other] == nil else {
            return
        }

        node(for: other)?.stop()
        scheduleFullFile(on: other) { [weak self] in
            self?.handleNodeFinished(slot: other)
        }
    }
}

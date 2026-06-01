//
//  SoundscapePlayer.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 3/21/26.
//

import AVFoundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

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
    private var sessionCountdownEndDate: Date?
    private var interruptionObserver: NSObjectProtocol?

    init() {
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        configureAudioSessionForPlayback()
        registerForAudioSessionNotifications()
#endif
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if sessionActive {
            setKeepsScreenAwake(false)
        }
        pollTimer?.invalidate()
        elapsedTimer?.invalidate()
        engine?.stop()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            syncCountdownFromWallClock()
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            if sessionActive, isPlaying {
                configureAudioSessionForPlayback()
                resumeEngineIfNeeded()
            }
#endif
        case .inactive, .background:
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            if sessionActive, isPlaying {
                configureAudioSessionForPlayback()
                resumeEngineIfNeeded()
            }
#endif
        @unknown default:
            break
        }
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

    /// Clears the selected soundscape so the session can run silently.
    func clearSoundscape() {
        guard !isPlaying, !sessionActive else { return }
        soundscapeURL = nil
        tearDownEngine()
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

    /// Pauses soundscape, crossfade polling, and countdown; stops any in-flight session bells.
    func pauseSession() {
        guard sessionActive, isPlaying else { return }
        SessionBellPlayback.stopAll()
        pausePlayback()
    }

    /// Resumes soundscape and countdown (countdown only if it had not reached zero).
    func resumeSession() {
        guard sessionActive, !isPlaying else { return }
        ensureEngine()
        startPlayback()
    }

    func finish() {
        onSessionStarted = nil
        onCountdownTick = nil
        onNaturalCountdownComplete = nil
        SessionBellPlayback.stopAll()
        tearDownEngine()
        sessionRemainingSeconds = 0
        sessionCountdownEndDate = nil
        sessionActive = false
        setKeepsScreenAwake(false)
        isPlaying = false
        countdownFinished = false
    }

    private func handleNodeFinished(slot: PlayerSlot) {
        node(for: slot)?.stop()
        slotStartDates[slot] = nil

        if slot == primary {
            primary = (slot == .a) ? .b : .a
            let nextIdle: PlayerSlot = slot
            if fileDuration > Self.crossfadeLeadSeconds {
                scheduleCrossfade(from: primary, to: nextIdle)
            } else {
                scheduleFullFile(on: nextIdle) { [weak self] in
                    self?.handleNodeFinished(slot: nextIdle)
                }
            }
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
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        configureAudioSessionForPlayback()
#endif
        if sessionActive {
            resumeFromPause()
        } else {
            startFromStopped()
        }
    }

    private func startFromStopped() {
        slotStartDates.removeAll()
        resumeA = false
        resumeB = false
        primary = .a

        sessionRemainingSeconds = sessionTotalSeconds
        sessionDurationSeconds = sessionTotalSeconds
        sessionCountdownEndDate = Date().addingTimeInterval(TimeInterval(sessionTotalSeconds))
        sessionActive = true
        setKeepsScreenAwake(true)
        countdownFinished = false
        isPlaying = true

        startSessionCountdownTimer()
        onSessionStarted?()

        // If a soundscape is selected, start audio playback. If not, the countdown still runs (bells still fire).
        if soundscapeURL != nil {
            ensureEngine()
            if let eng = engine, nodeA != nil, nodeB != nil {
                nodeA?.stop()
                nodeB?.stop()

                do {
                    if !eng.isRunning {
                        try eng.start()
                    }
                } catch { }

                scheduleFullFile(on: .a) { [weak self] in
                    self?.handleNodeFinished(slot: .a)
                }
                scheduleCrossfade(from: .a, to: .b)
                startPolling()
            }
        }
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

    /// Pre-schedules the next loop segment so crossfades continue while the app is backgrounded.
    private func scheduleCrossfade(from source: PlayerSlot, to dest: PlayerSlot) {
        guard fileDuration > Self.crossfadeLeadSeconds else { return }
        guard slotStartDates[dest] == nil else { return }
        guard let sourceNode = node(for: source),
              let destNode = node(for: dest),
              let destFile = file(for: dest) else { return }

        let sampleRate = destFile.processingFormat.sampleRate
        let crossfadeFrame = AVAudioFramePosition((fileDuration - Self.crossfadeLeadSeconds) * sampleRate)

        let startTime: AVAudioTime
        if let nodeTime = sourceNode.lastRenderTime,
           let playerTime = sourceNode.playerTime(forNodeTime: nodeTime) {
            let startFrame = playerTime.sampleTime + max(0, crossfadeFrame - playerTime.sampleTime)
            startTime = AVAudioTime(sampleTime: startFrame, atRate: sampleRate)
        } else {
            startTime = AVAudioTime(sampleTime: crossfadeFrame, atRate: sampleRate)
        }

        destFile.framePosition = 0
        slotStartDates[dest] = Date().addingTimeInterval(fileDuration - Self.crossfadeLeadSeconds)

        destNode.scheduleFile(destFile, at: startTime) { [weak self] in
            DispatchQueue.main.async {
                self?.handleNodeFinished(slot: dest)
            }
        }
        destNode.play()
    }

    private func pausePlayback() {
        resumeA = slotStartDates[.a] != nil
        resumeB = slotStartDates[.b] != nil

        nodeA?.pause()
        nodeB?.pause()

        pollTimer?.invalidate()
        pollTimer = nil
        stopSessionCountdownTimer()
        syncCountdownFromWallClock()
        isPlaying = false
    }

    private func resumeFromPause() {
        resumeEngineIfNeeded()

        if resumeA { nodeA?.play() }
        if resumeB { nodeB?.play() }

        // Resume the session countdown even if there is no soundscape selected.
        isPlaying = true
        if resumeA || resumeB {
            startPolling()
        }
        if !countdownFinished, sessionRemainingSeconds > 0 {
            sessionCountdownEndDate = Date().addingTimeInterval(TimeInterval(sessionRemainingSeconds))
            startSessionCountdownTimer()
        }
    }

    private func resumeEngineIfNeeded() {
        guard let eng = engine else { return }
        if !eng.isRunning {
            try? eng.start()
        }
    }

    private func startSessionCountdownTimer() {
        stopSessionCountdownTimer()
        guard !countdownFinished else { return }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickSessionCountdown()
        }
        RunLoop.main.add(t, forMode: .common)
        elapsedTimer = t
    }

    private func tickSessionCountdown() {
        guard isPlaying, !countdownFinished else { return }
        syncCountdownFromWallClock()
    }

    private func syncCountdownFromWallClock() {
        guard let endDate = sessionCountdownEndDate, !countdownFinished else { return }

        let previous = sessionRemainingSeconds
        let remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.down)))
        sessionRemainingSeconds = remaining

        if remaining != previous {
            onCountdownTick?(remaining, sessionTotalSeconds)
        }

        if remaining <= 0 {
            completeNaturalCountdown()
        }
    }

    private func completeNaturalCountdown() {
        guard !countdownFinished else { return }
        countdownFinished = true
        sessionRemainingSeconds = 0
        sessionCountdownEndDate = nil
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
        scheduleCrossfade(from: other, to: primary)
    }

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private func configureAudioSessionForPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch { }
    }

    private func registerForAudioSessionNotifications() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioSessionInterruption(notification)
        }
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            break
        case .ended:
            let options = (userInfo[AVAudioSessionInterruptionOptionKey] as? UInt)
                .flatMap { AVAudioSession.InterruptionOptions(rawValue: $0) }
            let shouldResume = options?.contains(.shouldResume) ?? true
            guard shouldResume, sessionActive, isPlaying else { return }
            configureAudioSessionForPlayback()
            resumeEngineIfNeeded()
        @unknown default:
            break
        }
    }
#endif

#if os(iOS)
    private func setKeepsScreenAwake(_ keepsAwake: Bool) {
        UIApplication.shared.isIdleTimerDisabled = keepsAwake
    }
#else
    private func setKeepsScreenAwake(_ keepsAwake: Bool) {}
#endif
}

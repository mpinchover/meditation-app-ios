//
//  HomeScreen.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import SwiftUI

struct HomeScreen: View {
    @StateObject private var audio = SoundscapePlayer()
    @AppStorage("selectedSoundscapeFile") private var selectedSoundscapeFile = ""
    @AppStorage("startingBellFile") private var startingBellFile = ""
    @AppStorage("endingBellFile") private var endingBellFile = ""
    @AppStorage("intervalBellFile") private var intervalBellFile = ""
    @AppStorage("intervalBellMinutes") private var intervalBellMinutes: Int = 5
    @AppStorage("sessionDurationSeconds") private var sessionDurationSeconds: Int = 180
    @State private var showSoundscapePicker = false
    @State private var showBellPicker = false
    @State private var bellMenuPresentationSeed = 0
    @State private var showDurationPicker = false
    @State private var showActiveSession = false

    /// Bottom inset for the play control as a fraction of home layout height (tuned so ~50pt at 812pt reference).
    private static let homePlayBottomInsetHeightFraction: CGFloat = 50.0 / 812.0
    private static let playButtonIconSize: CGFloat = 88
    private static let menuButtonTapSize: CGFloat = 44

    private var soundscapeFiles: [String] {
        SoundscapeCatalog.bundledSoundscapeFileNames()
    }

    private var bellFiles: [String] {
        BellsCatalog.bundledBellFileNames()
    }

    private var selectedTitle: String {
        if selectedSoundscapeFile.isEmpty {
            return "No selection"
        }
        return SoundscapeCatalog.displayTitle(fileName: selectedSoundscapeFile)
    }

    private var timerDisplayText: String {
        if audio.sessionActive {
            return ElapsedFormat.sessionCountdown(audio.sessionRemainingSeconds)
        }
        return ElapsedFormat.sessionCountdown(sessionDurationSeconds)
    }

    private var noSoundscapesLoadedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No sounds loaded")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var homeMainVStack: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                VStack(spacing: 12) {
                    Button {
                        showSoundscapePicker = true
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Soundscape")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(selectedTitle)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .disabled(audio.isPlaying || audio.sessionActive)
                    .accessibilityLabel("Soundscape, \(selectedTitle)")
                    .accessibilityHint("Opens list to preview and choose a soundscape")

                    Button {
                        showDurationPicker = true
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Duration")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(ElapsedFormat.sessionCountdown(sessionDurationSeconds))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .disabled(audio.isPlaying || audio.sessionActive)
                    .accessibilityLabel("Duration, \(ElapsedFormat.sessionCountdown(sessionDurationSeconds))")
                    .accessibilityHint("Opens screen to set session length")
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                Text("Callysto")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !showActiveSession {
                    GeometryReader { barGeo in
                        let w = barGeo.size.width
                        let h = max(barGeo.size.height, Self.playButtonIconSize)
                        let playCenterX = w / 2
                        let playTrailingX = playCenterX + Self.playButtonIconSize / 2
                        // Midpoint between play’s trailing edge and the bar’s trailing edge.
                        let menuCenterX = playTrailingX + (w - playTrailingX) / 2
                        ZStack(alignment: .topLeading) {
                            Color.clear
                                .frame(width: w, height: h)
                            Button {
                                audio.configureSessionDuration(sessionDurationSeconds)
                                attachSessionBellHandlers()
                                audio.toggle()
                                if audio.sessionActive {
                                    showActiveSession = true
                                }
                            } label: {
                                Label("Play", systemImage: "play.circle.fill")
                                    .font(.system(size: Self.playButtonIconSize))
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                            .disabled(audio.isPlaying || audio.sessionActive)
                            .position(x: playCenterX, y: h / 2)
                            Button {
                                bellMenuPresentationSeed += 1
                                showBellPicker = true
                            } label: {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 22, weight: .medium))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(.borderless)
                            .frame(width: Self.menuButtonTapSize, height: Self.menuButtonTapSize)
                            .contentShape(Rectangle())
                            .accessibilityLabel("Bells")
                            .accessibilityHint("Opens bell sounds")
                            .position(x: menuCenterX, y: h / 2)
                        }
                        .frame(width: w, height: h)
                    }
                    .frame(height: Self.playButtonIconSize)
                    .padding(.bottom, geo.size.height * Self.homePlayBottomInsetHeightFraction)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if soundscapeFiles.isEmpty {
                    noSoundscapesLoadedView
                } else {
                    homeMainVStack
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: audio.isPlaying)
            .navigationDestination(isPresented: $showSoundscapePicker) {
                SoundscapeSelectionView(files: soundscapeFiles, selectedFileName: $selectedSoundscapeFile)
            }
            .navigationDestination(isPresented: $showBellPicker) {
                BellMenuView(
                    bellFiles: bellFiles,
                    presentationSeed: bellMenuPresentationSeed,
                    isPresented: $showBellPicker
                )
            }
            .navigationDestination(isPresented: $showDurationPicker) {
                DurationSelectionView(durationSeconds: $sessionDurationSeconds)
            }
            .navigationDestination(isPresented: $showActiveSession) {
                ActiveSessionView(player: audio)
            }
            .onChange(of: audio.sessionActive) { _, active in
                if !active {
                    showActiveSession = false
                }
            }
            .onAppear {
                syncSelectionWithCatalog()
                syncBellSelectionWithCatalog()
                audio.configureSessionDuration(sessionDurationSeconds)
                if selectedSoundscapeFile.isEmpty {
                    audio.clearSoundscape()
                } else if SoundscapeCatalog.urlInBundle(fileName: selectedSoundscapeFile) != nil {
                    audio.applySoundscape(fileName: selectedSoundscapeFile)
                }
            }
            .onChange(of: selectedSoundscapeFile) { _, newValue in
                if newValue.isEmpty {
                    audio.clearSoundscape()
                } else if SoundscapeCatalog.urlInBundle(fileName: newValue) != nil {
                    audio.applySoundscape(fileName: newValue)
                }
            }
            .onChange(of: sessionDurationSeconds) { _, newValue in
                audio.configureSessionDuration(newValue)
            }
        }
    }

    private func syncSelectionWithCatalog() {
        let files = soundscapeFiles
        guard !files.isEmpty else {
            selectedSoundscapeFile = ""
            return
        }
        if !selectedSoundscapeFile.isEmpty, !files.contains(selectedSoundscapeFile) {
            selectedSoundscapeFile = files[0]
        }
    }

    private func syncBellSelectionWithCatalog() {
        let files = bellFiles
        guard !files.isEmpty else {
            if !startingBellFile.isEmpty { startingBellFile = "" }
            if !endingBellFile.isEmpty { endingBellFile = "" }
            if !intervalBellFile.isEmpty { intervalBellFile = "" }
            return
        }
        if !startingBellFile.isEmpty && !files.contains(startingBellFile) {
            startingBellFile = ""
        }
        if !endingBellFile.isEmpty && !files.contains(endingBellFile) {
            endingBellFile = ""
        }
        if !intervalBellFile.isEmpty && !files.contains(intervalBellFile) {
            intervalBellFile = ""
        }
        if intervalBellMinutes < 1 { intervalBellMinutes = 1 }
        if intervalBellMinutes > 30 { intervalBellMinutes = 30 }
    }

    /// Wires one-shot bells for this session. Interval chimes never fire on the final tick (`remaining == 0`); the ending bell plays there if selected, so they do not overlap.
    private func attachSessionBellHandlers() {
        let start = startingBellFile
        let end = endingBellFile
        let interval = intervalBellFile
        let minutes = intervalBellMinutes

        audio.onSessionStarted = {
            if !start.isEmpty {
                SessionBellPlayback.play(fileName: start)
            }
        }
        audio.onCountdownTick = { remaining, total in
            guard remaining > 0 else { return }
            guard !interval.isEmpty else { return }
            let intervalSec = max(1, minutes) * 60
            let elapsed = total - remaining
            guard elapsed > 0, intervalSec > 0, elapsed.isMultiple(of: intervalSec) else { return }
            SessionBellPlayback.play(fileName: interval)
        }
        audio.onNaturalCountdownComplete = {
            if !end.isEmpty {
                SessionBellPlayback.play(fileName: end)
            }
        }
    }
}

#Preview {
    HomeScreen()
}

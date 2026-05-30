//
//  HomeScreen.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 3/21/26.
//

import SwiftUI

struct HomeScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var audio = SoundscapePlayer()
    @ObservedObject private var soundStore = SoundStore.shared
    @AppStorage("selectedSoundscapeFile") private var selectedSoundscapeFile = ""
    @AppStorage("startingBellFile") private var startingBellFile = ""
    @AppStorage("endingBellFile") private var endingBellFile = ""
    @AppStorage("intervalBellFile") private var intervalBellFile = ""
    @AppStorage("intervalBellMinutes") private var intervalBellMinutes: Int = 5
    @AppStorage("sessionDurationSeconds") private var sessionDurationSeconds: Int = 180
    @State private var showSoundscapePicker = false
    @State private var showBellMenu = false
    @State private var bellMenuPresentationSeed = 0
    @State private var showDurationPicker = false
    @State private var showAccountScreen = false
    @State private var showActiveSession = false
    @State private var showInsights = false

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

    private var startingBellTitle: String {
        if startingBellFile.isEmpty {
            return "None"
        }
        guard bellFiles.contains(startingBellFile) else { return "None" }
        return BellsCatalog.displayTitle(fileName: startingBellFile)
    }

    private var timerDisplayText: String {
        if audio.sessionActive {
            return ElapsedFormat.sessionCountdown(audio.sessionRemainingSeconds)
        }
        return ElapsedFormat.sessionCountdown(sessionDurationSeconds)
    }

    private var loadingSoundsView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.bodyMuted)
            Text("Loading sound library\u{2026}")
                .font(.body)
                .foregroundStyle(AppTheme.bodyMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var soundsErrorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.bodyMuted)
            Text(soundStore.error ?? "Could not load sounds.")
                .font(.body)
                .foregroundStyle(AppTheme.bodyMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                Task { await soundStore.retryDownload() }
            } label: {
                Text("Try again")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.heroTitle)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.cardFill)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noSoundscapesLoadedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.bodyMuted)
            Text("No sounds loaded")
                .font(.body)
                .foregroundStyle(AppTheme.bodyMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var homeMainVStack: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Text("Callysto")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.heroTitle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            homeSelectionRows

            Spacer(minLength: 0)

            Button {
                showInsights = true
            } label: {
                Text("Insight")
                    .font(.body)
                    .foregroundStyle(AppTheme.rowValue)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            if !showActiveSession {
                homePlayControlBar
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var homeSelectionRows: some View {
        VStack(spacing: 12) {
            Button {
                showSoundscapePicker = true
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Soundscape")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.rowLabel)
                        Text(selectedTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.rowValue)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.rowChevron)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.cardFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
                        }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppScreenChrome.headerHorizontalPadding)
            .disabled(audio.isPlaying || audio.sessionActive)
            .accessibilityLabel("Soundscape, \(selectedTitle)")
            .accessibilityHint("Opens list to preview and choose a soundscape")

            Button {
                showDurationPicker = true
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.rowLabel)
                        Text(ElapsedFormat.sessionCountdown(sessionDurationSeconds))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.rowValue)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.rowChevron)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.cardFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
                        }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppScreenChrome.headerHorizontalPadding)
            .disabled(audio.isPlaying || audio.sessionActive)
            .accessibilityLabel("Duration, \(ElapsedFormat.sessionCountdown(sessionDurationSeconds))")
            .accessibilityHint("Opens screen to set session length")

            Button {
                bellMenuPresentationSeed += 1
                showBellMenu = true
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Starting bell")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.rowLabel)
                        Text(startingBellTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.rowValue)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.rowChevron)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.cardFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
                        }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppScreenChrome.headerHorizontalPadding)
            .disabled(audio.isPlaying || audio.sessionActive)
            .accessibilityLabel("Starting bell, \(startingBellTitle)")
            .accessibilityHint("Opens settings to choose session bells")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var homePlayControlBar: some View {
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
                        .foregroundStyle(AppTheme.controlPrimary)
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .tint(AppTheme.controlPrimary)
                .disabled(audio.isPlaying || audio.sessionActive)
                .position(x: playCenterX, y: h / 2)
                Button {
                    showAccountScreen = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(AppTheme.controlPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.borderless)
                .tint(AppTheme.controlPrimary)
                .frame(width: Self.menuButtonTapSize, height: Self.menuButtonTapSize)
                .contentShape(Rectangle())
                .accessibilityLabel("Account")
                .accessibilityHint("Opens account")
                .position(x: menuCenterX, y: h / 2)
            }
            .frame(width: w, height: h)
        }
        .frame(height: Self.playButtonIconSize)
    }

    var body: some View {
        NavigationStack {
            Group {
                if soundStore.isLoading {
                    loadingSoundsView
                } else if soundStore.error != nil {
                    soundsErrorView
                } else if !soundStore.isReady || soundscapeFiles.isEmpty {
                    noSoundscapesLoadedView
                } else {
                    homeMainVStack
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .appThemedScreen()
            .animation(.easeInOut(duration: 0.2), value: audio.isPlaying)
            .navigationDestination(isPresented: $showSoundscapePicker) {
                SoundscapeSelectionView(files: soundscapeFiles, selectedFileName: $selectedSoundscapeFile)
            }
            .navigationDestination(isPresented: $showBellMenu) {
                BellMenuView(bellFiles: bellFiles, presentationSeed: bellMenuPresentationSeed, isPresented: $showBellMenu)
            }
            .navigationDestination(isPresented: $showAccountScreen) {
                AccountScreen()
            }
            .navigationDestination(isPresented: $showDurationPicker) {
                DurationSelectionView(durationSeconds: $sessionDurationSeconds)
            }
            .navigationDestination(isPresented: $showActiveSession) {
                ActiveSessionView(player: audio)
            }
            .sheet(isPresented: $showInsights) {
                InsightsView()
                    .presentationDetents([.fraction(0.8)])
            }
            .onChange(of: audio.sessionActive) { _, active in
                if !active {
                    showActiveSession = false
                }
            }
            .onChange(of: scenePhase) { _, phase in
                audio.handleScenePhase(phase)
            }
            .task {
                await soundStore.ensureSoundsAvailable()
            }
            .onAppear {
                guard soundStore.isReady else { return }
                initializeAudioState()
            }
            .onChange(of: soundStore.isReady) { _, ready in
                guard ready else { return }
                initializeAudioState()
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

    private func initializeAudioState() {
        syncSelectionWithCatalog()
        syncBellSelectionWithCatalog()
        audio.configureSessionDuration(sessionDurationSeconds)
        if selectedSoundscapeFile.isEmpty {
            audio.clearSoundscape()
        } else if SoundscapeCatalog.urlInBundle(fileName: selectedSoundscapeFile) != nil {
            audio.applySoundscape(fileName: selectedSoundscapeFile)
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

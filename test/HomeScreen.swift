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
    @AppStorage("selectedBellFile") private var selectedBellFile = ""
    @AppStorage("sessionDurationSeconds") private var sessionDurationSeconds: Int = 180
    @State private var showSoundscapePicker = false
    @State private var showBellPicker = false
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
        SoundscapeCatalog.displayTitle(fileName: selectedSoundscapeFile)
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
            VStack(spacing: 0) {
                Spacer(minLength: 0)
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
                Spacer(minLength: 0)
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
                                guard SoundscapeCatalog.urlInBundle(fileName: selectedSoundscapeFile) != nil else { return }
                                audio.configureSessionDuration(sessionDurationSeconds)
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
                BellSelectionView(files: bellFiles, selectedFileName: $selectedBellFile)
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
                if SoundscapeCatalog.urlInBundle(fileName: selectedSoundscapeFile) != nil {
                    audio.applySoundscape(fileName: selectedSoundscapeFile)
                }
            }
            .onChange(of: selectedSoundscapeFile) { _, newValue in
                guard SoundscapeCatalog.urlInBundle(fileName: newValue) != nil else { return }
                audio.applySoundscape(fileName: newValue)
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
        if selectedSoundscapeFile.isEmpty || !files.contains(selectedSoundscapeFile) {
            selectedSoundscapeFile = files[0]
        }
    }

    private func syncBellSelectionWithCatalog() {
        let files = bellFiles
        guard !files.isEmpty else {
            selectedBellFile = ""
            return
        }
        if selectedBellFile.isEmpty || !files.contains(selectedBellFile) {
            selectedBellFile = files[0]
        }
    }
}

#Preview {
    HomeScreen()
}

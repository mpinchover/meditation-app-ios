//
//  SoundscapeSelectionView.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 3/21/26.
//

import AVFoundation
import SwiftUI

/// Short previews on the soundscape picker (separate from session `SoundscapePlayer`).
private final class SoundscapePreviewPlayer: ObservableObject {
    @Published private(set) var playingFileName: String?

    private var player: AVAudioPlayer?

    func play(fileName: String) {
        stop()
        guard let url = SoundscapeCatalog.urlInBundle(fileName: fileName) else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = 0
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
#endif
            p.play()
            player = p
            playingFileName = fileName
        } catch { }
    }

    func stop() {
        player?.stop()
        player = nil
        playingFileName = nil
    }
}

struct SoundscapeSelectionView: View {
    @Binding var selectedFileName: String
    @ObservedObject private var soundStore = SoundStore.shared
    @State private var draftFileName: String
    @StateObject private var preview = SoundscapePreviewPlayer()
    @Environment(\.dismiss) private var dismiss

    init(selectedFileName: Binding<String>) {
        self._selectedFileName = selectedFileName
        _draftFileName = State(initialValue: selectedFileName.wrappedValue)
    }

    var body: some View {
        Group {
            if soundStore.needsInitialCatalogLoad {
                catalogLoadingView
            } else {
                soundscapeList
            }
        }
        .appThemedListScreen()
        .navigationScreenChrome(trailingTitle: "Save") {
            selectedFileName = draftFileName
            preview.stop()
            dismiss()
        }
        .onAppear {
            draftFileName = selectedFileName
            soundStore.ensureSoundsAvailable()
        }
        .onDisappear {
            preview.stop()
        }
    }

    private var catalogLoadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.bodyMuted)
            Text("Loading soundscapes\u{2026}")
                .font(.body)
                .foregroundStyle(AppTheme.bodyMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var soundscapeList: some View {
        List {
            ListScreenTitleRow(title: "Soundscapes")

            noSoundscapeRow()
                .listRowSeparator(.hidden, edges: .top)

            ForEach(soundStore.soundscapeSummaries) { summary in
                let index = soundStore.soundscapeSummaries.firstIndex(where: { $0.id == summary.id }) ?? 0
                soundscapeRow(
                    summary: summary,
                    isFirstInSection: index == 0,
                    isLastInSection: index == soundStore.soundscapeSummaries.count - 1
                )
            }
        }
#if os(iOS) || os(tvOS) || os(visionOS)
        .listStyle(.plain)
        .contentMargins(.horizontal, 0, for: .scrollContent)
#else
        .listStyle(.inset)
#endif
        .environment(\.defaultMinListRowHeight, 48)
        .listRowSeparatorTint(AppTheme.listSeparator)
    }

    @ViewBuilder
    private func soundscapeRow(summary: SoundSummary, isFirstInSection: Bool, isLastInSection: Bool) -> some View {
        let file = summary.id
        let isSelected = draftFileName == file
        let isPlaying = preview.playingFileName == file
        SelectableSoundRow(
            title: summary.name,
            isSelected: isSelected,
            isPlaying: isPlaying,
            isDownloading: isSoundDownloading(file),
            titleStyle: titleStyle(selected: isSelected),
            showTopSeparator: !isFirstInSection,
            showBottomSeparator: !isLastInSection
        ) {
            draftFileName = file
            preview.play(fileName: file)
        }
    }

    @ViewBuilder
    private func noSoundscapeRow() -> some View {
        let isSelected = draftFileName.isEmpty
        SelectableSoundRow(
            title: "No selection",
            isSelected: isSelected,
            isPlaying: false,
            titleStyle: titleStyle(selected: isSelected),
            showTopSeparator: false,
            showBottomSeparator: false
        ) {
            draftFileName = ""
            preview.stop()
        }
    }

    private func isSoundDownloading(_ id: String) -> Bool {
        switch soundStore.downloadState(for: id) {
        case .pending, .downloading: return true
        case .downloaded, nil: return false
        }
    }

    private func titleStyle(selected: Bool) -> AnyShapeStyle {
        if selected {
            return AnyShapeStyle(AppTheme.selectionAccent)
        }
        return AnyShapeStyle(AppTheme.rowValue.opacity(AppTheme.listTitleUnselectedOpacity))
    }
}

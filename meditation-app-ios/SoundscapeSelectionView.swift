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
    let files: [String]
    @Binding var selectedFileName: String
    @State private var draftFileName: String
    @StateObject private var preview = SoundscapePreviewPlayer()
    @Environment(\.dismiss) private var dismiss

    init(files: [String], selectedFileName: Binding<String>) {
        self.files = files
        self._selectedFileName = selectedFileName
        _draftFileName = State(initialValue: selectedFileName.wrappedValue)
    }

    var body: some View {
        List {
            Section {
                Text("Soundscapes")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.heroTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: AppScreenChrome.navigationContentHorizontalPadding, bottom: 12, trailing: AppScreenChrome.navigationContentHorizontalPadding))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                noSoundscapeRow()
            }

            Section {
                ForEach(files.indices, id: \.self) { index in
                    soundscapeRow(
                        file: files[index],
                        isFirstInSection: index == 0,
                        isLastInSection: index == files.count - 1
                    )
                }
            }
        }
#if os(iOS) || os(tvOS) || os(visionOS)
        .listStyle(.plain)
        /// Pulls section content toward the `List` edges so it reads wider (less gap vs. the list’s bounds).
        .contentMargins(.horizontal, 0, for: .scrollContent)
#else
        .listStyle(.inset)
#endif
        .environment(\.defaultMinListRowHeight, 48)
        .listRowSeparatorTint(AppTheme.listSeparator)
        .appThemedListScreen()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    selectedFileName = draftFileName
                    preview.stop()
                    dismiss()
                }
            }
        }
        .navigationTextBackButton()
        .onAppear {
            draftFileName = selectedFileName
        }
        .onDisappear {
            preview.stop()
        }
    }

    @ViewBuilder
    private func soundscapeRow(file: String, isFirstInSection: Bool, isLastInSection: Bool) -> some View {
        let isSelected = draftFileName == file
        let isPlaying = preview.playingFileName == file
        SelectableSoundRow(
            title: SoundscapeCatalog.displayTitle(fileName: file),
            isSelected: isSelected,
            isPlaying: isPlaying,
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

    private func titleStyle(selected: Bool) -> AnyShapeStyle {
        if selected {
            return AnyShapeStyle(AppTheme.selectionAccent)
        }
        return AnyShapeStyle(AppTheme.rowValue.opacity(AppTheme.listTitleUnselectedOpacity))
    }
}

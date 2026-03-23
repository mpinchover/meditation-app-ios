//
//  SoundscapeSelectionView.swift
//  test
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
    @Environment(\.colorScheme) private var colorScheme

    init(files: [String], selectedFileName: Binding<String>) {
        self.files = files
        self._selectedFileName = selectedFileName
        _draftFileName = State(initialValue: selectedFileName.wrappedValue)
    }

    private var sections: [(title: String, files: [String])] {
        SoundscapeCatalog.groupedSoundscapeSections(files: files)
    }

    var body: some View {
        List {
            Section {
                Text("Soundscapes")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 12, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            ForEach(sections, id: \.title) { section in
                Section {
                    ForEach(section.files, id: \.self) { file in
                        soundscapeRow(file: file)
                    }
                } header: {
                    Text(section.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
#if os(iOS) || os(tvOS) || os(visionOS)
        .listStyle(.insetGrouped)
#else
        .listStyle(.inset)
#endif
        .environment(\.defaultMinListRowHeight, 48)
        .listRowSeparatorTint(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.1))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    selectedFileName = draftFileName
                    preview.stop()
                    dismiss()
                }
            }
        }
        .onAppear {
            draftFileName = selectedFileName
        }
        .onDisappear {
            preview.stop()
        }
    }

    @ViewBuilder
    private func soundscapeRow(file: String) -> some View {
        let isSelected = draftFileName == file
        let isPlaying = preview.playingFileName == file
        Button {
            draftFileName = file
            preview.play(fileName: file)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text(SoundscapeCatalog.displayTitle(fileName: file))
                    .font(.body)
                    .fontWeight(isPlaying ? .semibold : (isSelected ? .medium : .regular))
                    .foregroundStyle(titleStyle(selected: isSelected))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack(alignment: .trailing) {
                    Color.clear.frame(width: 32, height: 32)
                    if isPlaying {
                        PreviewPlayingWaveformView(isActive: isPlaying)
                    }
                }
                .accessibilityHidden(!isPlaying)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowBackground(Color.clear)
    }

    private func titleStyle(selected: Bool) -> AnyShapeStyle {
        if selected {
            return AnyShapeStyle(Color.accentColor)
        }
        return AnyShapeStyle(Color.primary.opacity(0.62))
    }
}

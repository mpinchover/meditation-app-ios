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

    init(files: [String], selectedFileName: Binding<String>) {
        self.files = files
        self._selectedFileName = selectedFileName
        _draftFileName = State(initialValue: selectedFileName.wrappedValue)
    }

    var body: some View {
        List {
            ForEach(files, id: \.self) { file in
                Button {
                    draftFileName = file
                    preview.play(fileName: file)
                } label: {
                    HStack {
                        Text(SoundscapeCatalog.displayTitle(fileName: file))
                            .foregroundStyle(.primary)
                        Spacer()
                        if draftFileName == file {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                        if preview.playingFileName == file {
                            Image(systemName: "waveform")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
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
}

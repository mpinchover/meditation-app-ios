//
//  BellSelectionView.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import AVFoundation
import SwiftUI

final class BellPreviewPlayer: ObservableObject {
    @Published private(set) var playingFileName: String?

    private var player: AVAudioPlayer?

    func play(fileName: String) {
        stop()
        guard let url = BellsCatalog.urlInBundle(fileName: fileName) else { return }
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

// MARK: - Shared list

private struct BellPickerList: View {
    let screenTitle: String
    let files: [String]
    @Binding var draftFileName: String
    @ObservedObject var preview: BellPreviewPlayer
    @Environment(\.colorScheme) private var colorScheme

    private var sections: [(title: String, files: [String])] {
        BellsCatalog.groupedBellSections(files: files)
    }

    var body: some View {
        List {
            Section {
                Text(screenTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 12, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                noBellRow()
            }
            if files.isEmpty {
                Section {
                    Text("Add WAV or MP3 files to the target (names should include “bell” or “gong”).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                }
            } else {
                ForEach(sections, id: \.title) { section in
                    Section {
                        ForEach(section.files, id: \.self) { file in
                            bellRow(file: file)
                        }
                    } header: {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
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
    }

    @ViewBuilder
    private func noBellRow() -> some View {
        let isSelected = draftFileName.isEmpty
        Button {
            draftFileName = ""
            preview.stop()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text("No bell")
                    .font(.body)
                    .fontWeight(isSelected ? .medium : .regular)
                    .foregroundStyle(titleStyle(selected: isSelected))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: 32, height: 32)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func bellRow(file: String) -> some View {
        let isSelected = draftFileName == file
        let isPlaying = preview.playingFileName == file
        Button {
            draftFileName = file
            preview.play(fileName: file)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text(BellsCatalog.displayTitle(fileName: file))
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

// MARK: - Starting / ending bell

struct BellSelectionView: View {
    let screenTitle: String
    let files: [String]
    /// Current menu draft when this screen is opened (re-read each presentation).
    let initialFileName: String
    /// Prefer this over `Binding` through `navigationDestination` — parent `@State` updates are unreliable there.
    let onSelect: (String) -> Void

    @State private var draftFileName: String
    @StateObject private var preview = BellPreviewPlayer()
    @Environment(\.dismiss) private var dismiss

    init(files: [String], initialFileName: String, screenTitle: String, onSelect: @escaping (String) -> Void) {
        self.screenTitle = screenTitle
        self.files = files
        self.initialFileName = initialFileName
        self.onSelect = onSelect
        _draftFileName = State(initialValue: initialFileName)
    }

    var body: some View {
        BellPickerList(screenTitle: screenTitle, files: files, draftFileName: $draftFileName, preview: preview)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        onSelect(draftFileName)
                        preview.stop()
                        dismiss()
                    }
                }
            }
            .onAppear {
                draftFileName = initialFileName
            }
            .onDisappear {
                preview.stop()
            }
    }
}

// MARK: - Interval bell (catalog + minutes)

struct IntervalBellSelectionView: View {
    let files: [String]
    let initialFileName: String
    let initialIntervalMinutes: Int
    let onSelect: (String, Int) -> Void

    @State private var draftFileName: String
    @State private var draftIntervalMinutes: Int
    @StateObject private var preview = BellPreviewPlayer()
    @Environment(\.dismiss) private var dismiss

    init(
        files: [String],
        initialFileName: String,
        initialIntervalMinutes: Int,
        onSelect: @escaping (String, Int) -> Void
    ) {
        self.files = files
        self.initialFileName = initialFileName
        self.initialIntervalMinutes = initialIntervalMinutes
        self.onSelect = onSelect
        _draftFileName = State(initialValue: initialFileName)
        _draftIntervalMinutes = State(initialValue: max(1, min(30, initialIntervalMinutes)))
    }

    var body: some View {
        BellPickerList(screenTitle: "Interval bell", files: files, draftFileName: $draftFileName, preview: preview)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !draftFileName.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Slider(
                                value: Binding(
                                    get: { Double(draftIntervalMinutes) },
                                    set: { draftIntervalMinutes = min(30, max(1, Int($0.rounded()))) }
                                ),
                                in: 1...30,
                                step: 1
                            )
                        }
                        Text("Every \(draftIntervalMinutes) minutes")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        onSelect(draftFileName, draftIntervalMinutes)
                        preview.stop()
                        dismiss()
                    }
                }
            }
            .onAppear {
                draftFileName = initialFileName
                draftIntervalMinutes = max(1, min(30, initialIntervalMinutes))
            }
            .onDisappear {
                preview.stop()
            }
    }
}

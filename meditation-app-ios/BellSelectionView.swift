//
//  BellSelectionView.swift
//  meditation-app-ios
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
    @Binding var draftFileName: String
    @ObservedObject var preview: BellPreviewPlayer
    @ObservedObject private var soundStore = SoundStore.shared

    var body: some View {
        Group {
            if soundStore.needsInitialCatalogLoad {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(AppTheme.bodyMuted)
                    Text("Loading bells\u{2026}")
                        .font(.body)
                        .foregroundStyle(AppTheme.bodyMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                bellList
            }
        }
    }

    private var bellList: some View {
        List {
            ListScreenTitleRow(title: screenTitle)

            noBellRow()
                .listRowSeparator(.hidden, edges: .top)

            ForEach(soundStore.bellSummaries) { summary in
                let index = soundStore.bellSummaries.firstIndex(where: { $0.id == summary.id }) ?? 0
                bellRow(
                    summary: summary,
                    isFirstInSection: index == 0,
                    isLastInSection: index == soundStore.bellSummaries.count - 1
                )
            }
        }
#if os(iOS) || os(tvOS) || os(visionOS)
        .listStyle(.plain)
#else
        .listStyle(.inset)
#endif
        .environment(\.defaultMinListRowHeight, 48)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .listRowSeparatorTint(AppTheme.listSeparator)
        .appThemedListScreen()
    }

    @ViewBuilder
    private func noBellRow() -> some View {
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

    @ViewBuilder
    private func bellRow(summary: SoundSummary, isFirstInSection: Bool, isLastInSection: Bool) -> some View {
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

// MARK: - Starting / ending bell

struct BellSelectionView: View {
    let screenTitle: String
    /// Current menu draft when this screen is opened (re-read each presentation).
    let initialFileName: String
    /// Prefer this over `Binding` through `navigationDestination` — parent `@State` updates are unreliable there.
    let onSelect: (String) -> Void

    @State private var draftFileName: String
    @StateObject private var preview = BellPreviewPlayer()
    @Environment(\.dismiss) private var dismiss

    init(initialFileName: String, screenTitle: String, onSelect: @escaping (String) -> Void) {
        self.screenTitle = screenTitle
        self.initialFileName = initialFileName
        self.onSelect = onSelect
        _draftFileName = State(initialValue: initialFileName)
    }

    var body: some View {
        BellPickerList(screenTitle: screenTitle, draftFileName: $draftFileName, preview: preview)
            .navigationScreenChrome(trailingTitle: "Select") {
                onSelect(draftFileName)
                preview.stop()
                dismiss()
            }
            .onAppear {
                draftFileName = initialFileName
                SoundStore.shared.ensureSoundsAvailable()
            }
            .onDisappear {
                preview.stop()
            }
    }
}

// MARK: - Interval bell (catalog + minutes)

struct IntervalBellSelectionView: View {
    let initialFileName: String
    let initialIntervalMinutes: Int
    let onSelect: (String, Int) -> Void

    @State private var draftFileName: String
    @State private var draftIntervalMinutes: Int
    @StateObject private var preview = BellPreviewPlayer()
    @Environment(\.dismiss) private var dismiss

    init(
        initialFileName: String,
        initialIntervalMinutes: Int,
        onSelect: @escaping (String, Int) -> Void
    ) {
        self.initialFileName = initialFileName
        self.initialIntervalMinutes = initialIntervalMinutes
        self.onSelect = onSelect
        _draftFileName = State(initialValue: initialFileName)
        _draftIntervalMinutes = State(initialValue: max(1, min(30, initialIntervalMinutes)))
    }

    var body: some View {
        BellPickerList(screenTitle: "Interval bell", draftFileName: $draftFileName, preview: preview)
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
                            .tint(AppTheme.selectionAccent)
                        }
                        Text("Every \(draftIntervalMinutes) minutes")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.rowValue)
                    }
                    .padding(.horizontal, AppScreenChrome.navigationContentHorizontalPadding)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.insetBarBackground)
                }
            }
            .navigationScreenChrome(trailingTitle: "Select") {
                onSelect(draftFileName, draftIntervalMinutes)
                preview.stop()
                dismiss()
            }
            .onAppear {
                draftFileName = initialFileName
                draftIntervalMinutes = max(1, min(30, initialIntervalMinutes))
                SoundStore.shared.ensureSoundsAvailable()
            }
            .onDisappear {
                preview.stop()
            }
    }
}

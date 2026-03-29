//
//  BellMenuView.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import SwiftUI

struct BellMenuView: View {
    let bellFiles: [String]
    /// Increments each time the user opens this screen from home; used to reload drafts from persisted storage without clobbering drafts when popping back from a child picker.
    let presentationSeed: Int
    /// Tied to `navigationDestination(isPresented:)` on home; set `false` after Save so the stack returns reliably.
    @Binding var isPresented: Bool

    /// Written on Save only. Using `@AppStorage` here (not bindings from the parent) so values reliably persist—`Binding`s through `navigationDestination` can fail to update `UserDefaults`.
    @AppStorage("startingBellFile") private var startingBellFile = ""
    @AppStorage("endingBellFile") private var endingBellFile = ""
    @AppStorage("intervalBellFile") private var intervalBellFile = ""
    @AppStorage("intervalBellMinutes") private var intervalBellMinutes: Int = 5

    @State private var draftStartingBellFile = ""
    @State private var draftEndingBellFile = ""
    @State private var draftIntervalBellFile = ""
    @State private var draftIntervalBellMinutes = 5

    @State private var showStartingBellPicker = false
    @State private var showEndingBellPicker = false
    @State private var showIntervalBellPicker = false

    /// Avoids re-loading from `@AppStorage` when popping a child picker (would wipe drafts). See `syncDraftsFromStorageIfNeeded`.
    @State private var lastSyncedPresentationSeed: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Bells")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, AppScreenChrome.navigationContentHorizontalPadding)
                .padding(.bottom, 20)

            VStack(spacing: 12) {
                bellMenuRow(
                    title: "Starting bell",
                    valueLabel: displaySubtitle(for: draftStartingBellFile)
                ) {
                    showStartingBellPicker = true
                }
                bellMenuRow(
                    title: "Ending bell",
                    valueLabel: displaySubtitle(for: draftEndingBellFile)
                ) {
                    showEndingBellPicker = true
                }
                bellMenuRow(
                    title: "Interval bells",
                    valueLabel: intervalRowSubtitle
                ) {
                    showIntervalBellPicker = true
                }
            }
            .padding(.horizontal, AppScreenChrome.navigationContentHorizontalPadding)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    commitDraftsToPersistence()
                    isPresented = false
                }
            }
        }
        .navigationTextBackButton()
        .navigationDestination(isPresented: $showStartingBellPicker) {
            BellSelectionView(
                files: bellFiles,
                initialFileName: draftStartingBellFile,
                screenTitle: "Starting bell",
                onSelect: { draftStartingBellFile = $0 }
            )
        }
        .navigationDestination(isPresented: $showEndingBellPicker) {
            BellSelectionView(
                files: bellFiles,
                initialFileName: draftEndingBellFile,
                screenTitle: "Ending bell",
                onSelect: { draftEndingBellFile = $0 }
            )
        }
        .navigationDestination(isPresented: $showIntervalBellPicker) {
            IntervalBellSelectionView(
                files: bellFiles,
                initialFileName: draftIntervalBellFile,
                initialIntervalMinutes: draftIntervalBellMinutes,
                onSelect: { file, minutes in
                    draftIntervalBellFile = file
                    draftIntervalBellMinutes = minutes
                }
            )
        }
        .onAppear {
            syncDraftsFromStorageIfNeeded()
        }
        .onChange(of: presentationSeed) { _, newSeed in
            lastSyncedPresentationSeed = newSeed
            draftStartingBellFile = startingBellFile
            draftEndingBellFile = endingBellFile
            draftIntervalBellFile = intervalBellFile
            draftIntervalBellMinutes = intervalBellMinutes
        }
    }

    private func syncDraftsFromStorageIfNeeded() {
        guard lastSyncedPresentationSeed != presentationSeed else { return }
        lastSyncedPresentationSeed = presentationSeed
        draftStartingBellFile = startingBellFile
        draftEndingBellFile = endingBellFile
        draftIntervalBellFile = intervalBellFile
        draftIntervalBellMinutes = intervalBellMinutes
    }

    private func commitDraftsToPersistence() {
        startingBellFile = draftStartingBellFile
        endingBellFile = draftEndingBellFile
        intervalBellFile = draftIntervalBellFile
        intervalBellMinutes = draftIntervalBellMinutes
    }

    private var intervalRowSubtitle: String {
        if draftIntervalBellFile.isEmpty {
            return "No selection"
        }
        let name = displaySubtitle(for: draftIntervalBellFile)
        return "\(draftIntervalBellMinutes) min · \(name)"
    }

    private func displaySubtitle(for file: String) -> String {
        if file.isEmpty { return "No selection" }
        guard bellFiles.contains(file) else { return "No selection" }
        return BellsCatalog.displayTitle(fileName: file)
    }

    private func bellMenuRow(title: String, valueLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(valueLabel)
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
            .padding(.horizontal, AppScreenChrome.navigationContentHorizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(valueLabel)")
    }
}

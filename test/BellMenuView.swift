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
    @Binding var startingBellFile: String
    @Binding var endingBellFile: String
    @Binding var intervalBellFile: String
    @Binding var intervalBellMinutes: Int

    @State private var draftStartingBellFile = ""
    @State private var draftEndingBellFile = ""
    @State private var draftIntervalBellFile = ""
    @State private var draftIntervalBellMinutes = 5

    @State private var showStartingBellPicker = false
    @State private var showEndingBellPicker = false
    @State private var showIntervalBellPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Bells")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 12)

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
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    commitDraftsToPersistence()
                }
            }
        }
        .navigationDestination(isPresented: $showStartingBellPicker) {
            BellSelectionView(files: bellFiles, selectedFileName: $draftStartingBellFile, screenTitle: "Starting bell")
        }
        .navigationDestination(isPresented: $showEndingBellPicker) {
            BellSelectionView(files: bellFiles, selectedFileName: $draftEndingBellFile, screenTitle: "Ending bell")
        }
        .navigationDestination(isPresented: $showIntervalBellPicker) {
            IntervalBellSelectionView(
                files: bellFiles,
                selectedFileName: $draftIntervalBellFile,
                intervalMinutes: $draftIntervalBellMinutes
            )
        }
        .onChange(of: presentationSeed, initial: true) { _, _ in
            draftStartingBellFile = startingBellFile
            draftEndingBellFile = endingBellFile
            draftIntervalBellFile = intervalBellFile
            draftIntervalBellMinutes = intervalBellMinutes
        }
    }

    private func commitDraftsToPersistence() {
        startingBellFile = draftStartingBellFile
        endingBellFile = draftEndingBellFile
        intervalBellFile = draftIntervalBellFile
        intervalBellMinutes = draftIntervalBellMinutes
    }

    private var intervalRowSubtitle: String {
        if draftIntervalBellFile.isEmpty {
            return "No bell"
        }
        let name = displaySubtitle(for: draftIntervalBellFile)
        return "\(draftIntervalBellMinutes) min · \(name)"
    }

    private func displaySubtitle(for file: String) -> String {
        if file.isEmpty { return "No bell" }
        guard bellFiles.contains(file) else { return "No bell" }
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
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(valueLabel)")
    }
}

//
//  BellMenuView.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import SwiftUI

struct BellMenuView: View {
    let bellFiles: [String]
    @Binding var startingBellFile: String
    @Binding var endingBellFile: String
    @Binding var intervalBellFile: String
    @Binding var intervalBellMinutes: Int

    @State private var showStartingBellPicker = false
    @State private var showEndingBellPicker = false
    @State private var showIntervalBellPicker = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                bellMenuRow(
                    title: "Starting bell",
                    valueLabel: displaySubtitle(for: startingBellFile)
                ) {
                    showStartingBellPicker = true
                }
                bellMenuRow(
                    title: "Ending bell",
                    valueLabel: displaySubtitle(for: endingBellFile)
                ) {
                    showEndingBellPicker = true
                }
                bellMenuRow(
                    title: "Interval bell",
                    valueLabel: intervalRowSubtitle
                ) {
                    showIntervalBellPicker = true
                }
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationDestination(isPresented: $showStartingBellPicker) {
            BellSelectionView(files: bellFiles, selectedFileName: $startingBellFile)
        }
        .navigationDestination(isPresented: $showEndingBellPicker) {
            BellSelectionView(files: bellFiles, selectedFileName: $endingBellFile)
        }
        .navigationDestination(isPresented: $showIntervalBellPicker) {
            IntervalBellSelectionView(
                files: bellFiles,
                selectedFileName: $intervalBellFile,
                intervalMinutes: $intervalBellMinutes
            )
        }
    }

    private var intervalRowSubtitle: String {
        let name = displaySubtitle(for: intervalBellFile)
        return "\(intervalBellMinutes) min · \(name)"
    }

    private func displaySubtitle(for file: String) -> String {
        guard !file.isEmpty, bellFiles.contains(file) else { return "—" }
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

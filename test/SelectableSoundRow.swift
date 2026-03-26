//
//  SelectableSoundRow.swift
//  test
//
//  Created by Cursor on 3/26/26.
//

import SwiftUI

struct SelectableSoundRow: View {
    let title: String
    let isSelected: Bool
    let isPlaying: Bool
    let titleStyle: AnyShapeStyle
    let showTopSeparator: Bool
    let showBottomSeparator: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.body)
                    .fontWeight(isPlaying ? .semibold : (isSelected ? .medium : .regular))
                    .foregroundStyle(titleStyle)
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
        .listRowSeparator(showBottomSeparator ? .visible : .hidden, edges: .bottom)
        .listRowSeparator(showTopSeparator ? .visible : .hidden, edges: .top)
    }
}

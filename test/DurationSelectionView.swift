//
//  DurationSelectionView.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import SwiftUI
#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#endif

#if os(iOS) || os(tvOS) || os(visionOS)
/// Hour wheel, `h`, minute wheel, `m` in one row (two single-component pickers + suffix labels).
fileprivate struct DurationWheelPickerRepresentable: UIViewRepresentable {
    @Binding var totalSeconds: Int

    static let maxSeconds = 23 * 3600 + 59 * 60
    static var totalWidth: CGFloat {
        // Matches the constraints applied to the returned UIKit `UIStackView` ("green border").
        // hourColumn/minuteColumn = (wheel + label) * 2 + suffix; then two columns + outer spacing.
        let column = Layout.columnWidth
        let suffix = Layout.suffixColumnSpacing
        let outer = Layout.outerColumnSpacing
        return (column * 2 + suffix) * 2 + outer
    }

    private enum Layout {
#if os(tvOS)
        static let rowHeight: CGFloat = 40
        static let columnWidth: CGFloat = 72
        static let outerColumnSpacing: CGFloat = 12
#else
        static let rowHeight: CGFloat = 30
        static let columnWidth: CGFloat = 54
        static let outerColumnSpacing: CGFloat = 12
#endif
        static let suffixColumnSpacing: CGFloat = 6
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
        var parent: DurationWheelPickerRepresentable
        weak var hourPicker: UIPickerView?
        weak var minutePicker: UIPickerView?

        init(_ parent: DurationWheelPickerRepresentable) {
            self.parent = parent
        }

        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            pickerView === hourPicker ? 24 : 60
        }

        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            Layout.rowHeight
        }

        func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
            Layout.columnWidth
        }

        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            label.text = pickerView === hourPicker ? "\(row)" : String(format: "%02d", row)
            label.textAlignment = .center
            label.font = UIFont.preferredFont(forTextStyle: .callout)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = AppTheme.uiRowValue
            return label
        }

        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            guard let hP = hourPicker, let mP = minutePicker else { return }
            let hi = hP.selectedRow(inComponent: 0)
            let mi = mP.selectedRow(inComponent: 0)
            let s = hi * 3600 + mi * 60
            if s < 60 {
                parent.totalSeconds = 60
                hP.selectRow(0, inComponent: 0, animated: true)
                mP.selectRow(1, inComponent: 0, animated: true)
                return
            }
            parent.totalSeconds = min(DurationWheelPickerRepresentable.maxSeconds, s)
        }
    }

    func makeUIView(context: Context) -> UIStackView {
        let c = context.coordinator

        let hourPV = UIPickerView()
        hourPV.delegate = c
        hourPV.dataSource = c
        c.hourPicker = hourPV
        hourPV.widthAnchor.constraint(equalToConstant: Layout.columnWidth).isActive = true

        let minutePV = UIPickerView()
        minutePV.delegate = c
        minutePV.dataSource = c
        c.minutePicker = minutePV
        minutePV.widthAnchor.constraint(equalToConstant: Layout.columnWidth).isActive = true

        let hLabel = UILabel()
        hLabel.text = "h"
        hLabel.font = UIFont.preferredFont(forTextStyle: .callout)
        hLabel.textColor = AppTheme.uiSecondary
        hLabel.setContentHuggingPriority(.required, for: .horizontal)
        hLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        hLabel.widthAnchor.constraint(equalToConstant: Layout.columnWidth).isActive = true

        let mLabel = UILabel()
        mLabel.text = "m"
        mLabel.font = UIFont.preferredFont(forTextStyle: .callout)
        mLabel.textColor = AppTheme.uiSecondary
        mLabel.setContentHuggingPriority(.required, for: .horizontal)
        mLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        mLabel.widthAnchor.constraint(equalToConstant: Layout.columnWidth).isActive = true

        // Picker + suffix per column so unit labels aren’t squeezed between two wide wheels.
        let hourColumn = UIStackView(arrangedSubviews: [hourPV, hLabel])
        hourColumn.axis = .horizontal
        hourColumn.spacing = Layout.suffixColumnSpacing
        hourColumn.alignment = .center
        hourColumn.distribution = .fill
        hourColumn.widthAnchor.constraint(equalToConstant: Layout.columnWidth * 2 + Layout.suffixColumnSpacing).isActive = true

        let minuteColumn = UIStackView(arrangedSubviews: [minutePV, mLabel])
        minuteColumn.axis = .horizontal
        minuteColumn.spacing = Layout.suffixColumnSpacing
        minuteColumn.alignment = .center
        minuteColumn.distribution = .fill
        minuteColumn.widthAnchor.constraint(equalToConstant: Layout.columnWidth * 2 + Layout.suffixColumnSpacing).isActive = true

        hourPV.setContentHuggingPriority(.defaultLow, for: .horizontal)
        minutePV.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [hourColumn, minuteColumn])
        stack.axis = .horizontal
        stack.spacing = Layout.outerColumnSpacing
        stack.alignment = .center
        stack.distribution = .fillEqually
        stack.widthAnchor.constraint(equalToConstant: (Layout.columnWidth * 2 + Layout.suffixColumnSpacing) * 2 + Layout.outerColumnSpacing).isActive = true
        stack.setContentHuggingPriority(.required, for: .horizontal)
        stack.setContentCompressionResistancePriority(.required, for: .horizontal)

        hourColumn.widthAnchor.constraint(equalTo: minuteColumn.widthAnchor).isActive = true

        return stack
    }

    func updateUIView(_ uiView: UIStackView, context: Context) {
        guard let hourPV = context.coordinator.hourPicker,
              let minutePV = context.coordinator.minutePicker else { return }
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        if hourPV.selectedRow(inComponent: 0) != h {
            hourPV.selectRow(h, inComponent: 0, animated: false)
        }
        if minutePV.selectedRow(inComponent: 0) != m {
            minutePV.selectRow(m, inComponent: 0, animated: false)
        }
    }
}
#endif

struct DurationSelectionView: View {
    @Binding var durationSeconds: Int
    @State private var draftSeconds: Int
    @Environment(\.dismiss) private var dismiss

    init(durationSeconds: Binding<Int>) {
        self._durationSeconds = durationSeconds
        _draftSeconds = State(initialValue: max(60, durationSeconds.wrappedValue))
    }

    private static let maxSeconds = 23 * 3600 + 59 * 60

    private var hourBinding: Binding<Int> {
        Binding(
            get: { draftSeconds / 3600 },
            set: { h in
                let m = (draftSeconds % 3600) / 60
                draftSeconds = min(Self.maxSeconds, max(60, h * 3600 + m * 60))
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { (draftSeconds % 3600) / 60 },
            set: { m in
                let h = draftSeconds / 3600
                draftSeconds = min(Self.maxSeconds, max(60, h * 3600 + m * 60))
            }
        )
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Duration")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.heroTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppScreenChrome.navigationContentHorizontalPadding)
                .padding(.top, 4)

            VStack(spacing: 8) {
#if os(iOS) || os(tvOS) || os(visionOS)
                DurationWheelPickerRepresentable(totalSeconds: $draftSeconds)
                    .frame(width: DurationWheelPickerRepresentable.totalWidth)
                    .frame(minHeight: 160)
                    .frame(maxWidth: .infinity, alignment: .center)
#else
                HStack(spacing: 6) {
                    Picker("Hours", selection: hourBinding) {
                        ForEach(0..<24, id: \.self) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .frame(width: 72)
                    .clipped()
                    .tint(AppTheme.selectionAccent)

                    Text("h")
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize()

                    Picker("Minutes", selection: minuteBinding) {
                        ForEach(0..<60, id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .frame(width: 72)
                    .clipped()
                    .tint(AppTheme.selectionAccent)

                    Text("m")
                        .font(.body)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize()
                }
                .frame(minHeight: 180)
                .frame(maxWidth: .infinity, alignment: .center)
#endif
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical)
        .appThemedScreen()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    durationSeconds = max(60, min(Self.maxSeconds, draftSeconds))
                    dismiss()
                }
            }
        }
        .navigationTextBackButton()
        .onAppear {
            draftSeconds = max(60, min(Self.maxSeconds, durationSeconds))
        }
    }
}

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
            label.textColor = UIColor.label
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

        let minutePV = UIPickerView()
        minutePV.delegate = c
        minutePV.dataSource = c
        c.minutePicker = minutePV

        let hLabel = UILabel()
        hLabel.text = "h"
        hLabel.font = UIFont.preferredFont(forTextStyle: .callout)
        hLabel.textColor = UIColor.secondaryLabel
        hLabel.setContentHuggingPriority(.required, for: .horizontal)
        hLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let mLabel = UILabel()
        mLabel.text = "m"
        mLabel.font = UIFont.preferredFont(forTextStyle: .callout)
        mLabel.textColor = UIColor.secondaryLabel
        mLabel.setContentHuggingPriority(.required, for: .horizontal)
        mLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Picker + suffix per column so unit labels aren’t squeezed between two wide wheels.
        let hourColumn = UIStackView(arrangedSubviews: [hourPV, hLabel])
        hourColumn.axis = .horizontal
        hourColumn.spacing = Layout.suffixColumnSpacing
        hourColumn.alignment = .center
        hourColumn.distribution = .fill

        let minuteColumn = UIStackView(arrangedSubviews: [minutePV, mLabel])
        minuteColumn.axis = .horizontal
        minuteColumn.spacing = Layout.suffixColumnSpacing
        minuteColumn.alignment = .center
        minuteColumn.distribution = .fill

        hourPV.setContentHuggingPriority(.defaultLow, for: .horizontal)
        minutePV.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [hourColumn, minuteColumn])
        stack.axis = .horizontal
        stack.spacing = Layout.outerColumnSpacing
        stack.alignment = .center
        stack.distribution = .fillEqually

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

            VStack(spacing: 8) {
#if os(iOS) || os(tvOS) || os(visionOS)
                DurationWheelPickerRepresentable(totalSeconds: $draftSeconds)
                    .frame(minHeight: 160)
#else
                HStack(spacing: 6) {
                    Picker("Hours", selection: hourBinding) {
                        ForEach(0..<24, id: \.self) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Text("h")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize()

                    Picker("Minutes", selection: minuteBinding) {
                        ForEach(0..<60, id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Text("m")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                .frame(minHeight: 180)
#endif
            }

            Spacer(minLength: 0)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    durationSeconds = max(60, min(Self.maxSeconds, draftSeconds))
                    dismiss()
                }
            }
        }
        .onAppear {
            draftSeconds = max(60, min(Self.maxSeconds, durationSeconds))
        }
    }
}

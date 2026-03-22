//
//  ContentView.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import SwiftUI
import AVFoundation
#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#endif

// MARK: - Bundled soundscapes (add files under test/assets/soundscapes in Xcode)

private enum SoundscapeCatalog {
    /// Logical folder in the project; the built app may **flatten** these into `Resources/` (no subfolder).
    static let subdirectory = "assets/soundscapes"
    private static let extensions = ["mp3", "m4a", "wav", "aac", "caf"]
    private static let allowedExtensionSet = Set(extensions.map { $0.lowercased() })
    private static let fm = FileManager.default

    /// Filenames (e.g. `Alpha Waves.mp3`) found in the bundle for soundscapes.
    static func bundledSoundscapeFileNames() -> [String] {
        var names = Set<String>()

        for ext in extensions {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: subdirectory) {
                for u in urls { names.insert(u.lastPathComponent) }
            }
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for u in urls { names.insert(u.lastPathComponent) }
            }
        }

        if let dir = soundscapesDirectoryInBundle(),
           let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            while let url = enumerator.nextObject() as? URL {
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                let ext = url.pathExtension.lowercased()
                guard allowedExtensionSet.contains(ext) else { continue }
                names.insert(url.lastPathComponent)
            }
        }

        // Flattened Copy Resources: audio sits next to Assets.car in `Resources/` (no `assets/soundscapes` in bundle).
        if let res = Bundle.main.resourceURL,
           let contents = try? fm.contentsOfDirectory(at: res, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for u in contents {
                guard (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                let ext = u.pathExtension.lowercased()
                guard allowedExtensionSet.contains(ext) else { continue }
                names.insert(u.lastPathComponent)
            }
        }

        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// If the bundle preserves `assets/soundscapes/`, return it.
    private static func soundscapesDirectoryInBundle() -> URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let dir = resources.appendingPathComponent(subdirectory, isDirectory: true)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { return nil }
        return dir
    }

    static func urlInBundle(fileName: String) -> URL? {
        if let dir = soundscapesDirectoryInBundle() {
            let direct = dir.appendingPathComponent(fileName)
            if fm.fileExists(atPath: direct.path) { return direct }
        }
        if let res = Bundle.main.resourceURL {
            let flat = res.appendingPathComponent(fileName)
            if fm.fileExists(atPath: flat.path) { return flat }
        }
        let base = fileName as NSString
        let name = base.deletingPathExtension
        let ext = base.pathExtension
        guard !name.isEmpty, !ext.isEmpty else { return nil }
        if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory) { return u }
        return Bundle.main.url(forResource: name, withExtension: ext)
    }

    static func displayTitle(fileName: String) -> String {
        (fileName as NSString).deletingPathExtension
    }
}

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

private enum PlayerSlot {
    case a, b
}

private final class SoundscapePlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    /// True after Play starts until Finish or countdown reaches zero.
    @Published private(set) var sessionActive = false
    @Published private(set) var sessionRemainingSeconds: Int = 0

    private static let crossfadeLeadSeconds = 10.0
    private var sessionTotalSeconds: Int = 180

    private var soundscapeURL: URL?
    private var engine: AVAudioEngine?
    private var fileA: AVAudioFile?
    private var fileB: AVAudioFile?
    private var nodeA: AVAudioPlayerNode?
    private var nodeB: AVAudioPlayerNode?
    private var primary: PlayerSlot = .a
    private var slotStartDates: [PlayerSlot: Date] = [:]
    private var fileDuration: Double = 0
    private var pollTimer: Timer?
    private var elapsedTimer: Timer?
    private var resumeA = false
    private var resumeB = false

    init() {
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        configureAudioSessionForPlayback()
#endif
    }

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private func configureAudioSessionForPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch { }
    }
#endif

    deinit {
        pollTimer?.invalidate()
        elapsedTimer?.invalidate()
        engine?.stop()
    }

    /// Call when the user picks a file; does nothing while playing. Rebuilds engine on next play.
    func applySoundscape(fileName: String) {
        guard !isPlaying, !sessionActive else { return }
        guard let url = SoundscapeCatalog.urlInBundle(fileName: fileName) else { return }
        soundscapeURL = url
        tearDownEngine()
        if !sessionActive {
            sessionRemainingSeconds = 0
        }
    }

    func configureSessionDuration(_ totalSeconds: Int) {
        guard !isPlaying, !sessionActive else { return }
        sessionTotalSeconds = max(60, totalSeconds)
    }

    func toggle() {
        ensureEngine()
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    func finish() {
        tearDownEngine()
        sessionRemainingSeconds = 0
        sessionActive = false
        isPlaying = false
    }

    private func handleNodeFinished(slot: PlayerSlot) {
        node(for: slot)?.stop()
        slotStartDates[slot] = nil

        if slot == primary {
            primary = (slot == .a) ? .b : .a
        }
    }

    private func tearDownEngine() {
        pollTimer?.invalidate()
        pollTimer = nil
        stopSessionCountdownTimer()
        nodeA?.stop()
        nodeB?.stop()
        engine?.stop()
        engine = nil
        fileA = nil
        fileB = nil
        nodeA = nil
        nodeB = nil
        slotStartDates.removeAll()
        primary = .a
        resumeA = false
        resumeB = false
        fileDuration = 0
    }

    private func ensureEngine() {
        guard engine == nil else { return }
        guard let url = soundscapeURL else { return }

        do {
            let fa = try AVAudioFile(forReading: url)
            let fb = try AVAudioFile(forReading: url)

            fileDuration = Double(fa.length) / fa.fileFormat.sampleRate

            let na = AVAudioPlayerNode()
            let nb = AVAudioPlayerNode()
            let eng = AVAudioEngine()
            let format = fa.processingFormat

            eng.attach(na)
            eng.attach(nb)
            eng.connect(na, to: eng.mainMixerNode, format: format)
            eng.connect(nb, to: eng.mainMixerNode, format: format)

            fileA = fa
            fileB = fb
            nodeA = na
            nodeB = nb
            engine = eng
        } catch { }
    }

    private func node(for slot: PlayerSlot) -> AVAudioPlayerNode? {
        slot == .a ? nodeA : nodeB
    }

    private func file(for slot: PlayerSlot) -> AVAudioFile? {
        slot == .a ? fileA : fileB
    }

    private func remainingSeconds(for slot: PlayerSlot) -> Double? {
        guard let start = slotStartDates[slot] else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        return max(0, fileDuration - elapsed)
    }

    private func startPlayback() {
        guard soundscapeURL != nil else { return }
        ensureEngine()
        guard engine != nil else { return }
        if resumeA || resumeB {
            resumeFromPause()
        } else {
            startFromStopped()
        }
    }

    private func startFromStopped() {
        guard let na = nodeA, let nb = nodeB, let eng = engine else { return }

        slotStartDates.removeAll()
        resumeA = true
        resumeB = false
        primary = .a

        sessionRemainingSeconds = sessionTotalSeconds
        sessionActive = true

        na.stop()
        nb.stop()

        do {
            if !eng.isRunning {
                try eng.start()
            }
        } catch {
            return
        }

        scheduleFullFile(on: .a) { [weak self] in
            self?.handleNodeFinished(slot: .a)
        }

        isPlaying = true
        startPolling()
        startSessionCountdownTimer()
    }

    private func scheduleFullFile(on slot: PlayerSlot, completion: @escaping () -> Void) {
        guard let n = node(for: slot), let f = file(for: slot) else { return }

        f.framePosition = 0
        slotStartDates[slot] = Date()

        n.scheduleFile(f, at: nil) {
            DispatchQueue.main.async {
                completion()
            }
        }

        n.play()
    }

    private func pausePlayback() {
        resumeA = slotStartDates[.a] != nil
        resumeB = slotStartDates[.b] != nil

        nodeA?.pause()
        nodeB?.pause()

        pollTimer?.invalidate()
        pollTimer = nil
        stopSessionCountdownTimer()
        isPlaying = false
    }

    private func resumeFromPause() {
        if let eng = engine, !eng.isRunning {
            try? eng.start()
        }

        if resumeA { nodeA?.play() }
        if resumeB { nodeB?.play() }

        if resumeA || resumeB {
            isPlaying = true
            startPolling()
            startSessionCountdownTimer()
        }
    }

    private func startSessionCountdownTimer() {
        stopSessionCountdownTimer()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }
            if self.sessionRemainingSeconds > 0 {
                self.sessionRemainingSeconds -= 1
            }
            if self.sessionRemainingSeconds <= 0 {
                self.finish()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        elapsedTimer = t
    }

    private func stopSessionCountdownTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func startPolling() {
        pollTimer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.pollCrossfade()
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    private func pollCrossfade() {
        guard isPlaying else { return }

        let other: PlayerSlot = (primary == .a) ? .b : .a

        guard let remaining = remainingSeconds(for: primary),
              remaining <= Self.crossfadeLeadSeconds,
              slotStartDates[other] == nil else {
            return
        }

        node(for: other)?.stop()
        scheduleFullFile(on: other) { [weak self] in
            self?.handleNodeFinished(slot: other)
        }
    }
}

private enum ElapsedFormat {
    static func mmss(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    /// Session countdown / chosen duration: includes hours when needed (`H:MM:SS` or `M:SS`).
    static func sessionCountdown(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%d:%02d", m, sec)
    }
}

#if os(iOS) || os(tvOS) || os(visionOS)
/// Hour wheel, `h`, minute wheel, `m` in one row (two single-component pickers + suffix labels).
private struct DurationWheelPickerRepresentable: UIViewRepresentable {
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
        .navigationTitle("Duration")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
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

/// Full-screen session: live countdown and Finish; audio is driven by `SoundscapePlayer`.
private struct ActiveSessionView: View {
    @ObservedObject var player: SoundscapePlayer

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 0)

            Text(ElapsedFormat.sessionCountdown(player.sessionRemainingSeconds))
                .font(.system(size: 48, weight: .medium, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.primary)
                .accessibilityLabel("Time remaining")
                .accessibilityValue(ElapsedFormat.sessionCountdown(player.sessionRemainingSeconds))

            Spacer(minLength: 0)

            Button("Finish", role: .destructive) {
                player.finish()
            }
            .font(.body.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.85))
            .padding(.bottom, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Session")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onDisappear {
            if player.sessionActive || player.isPlaying {
                player.finish()
            }
        }
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
        .navigationTitle("Soundscapes")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
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

struct ContentView: View {
    @StateObject private var audio = SoundscapePlayer()
    @AppStorage("selectedSoundscapeFile") private var selectedSoundscapeFile = ""
    @AppStorage("sessionDurationSeconds") private var sessionDurationSeconds: Int = 180
    @State private var showSoundscapePicker = false
    @State private var showDurationPicker = false
    @State private var showActiveSession = false

    private var soundscapeFiles: [String] {
        SoundscapeCatalog.bundledSoundscapeFileNames()
    }

    private var selectedTitle: String {
        SoundscapeCatalog.displayTitle(fileName: selectedSoundscapeFile)
    }

    private var timerDisplayText: String {
        if audio.sessionActive {
            return ElapsedFormat.sessionCountdown(audio.sessionRemainingSeconds)
        }
        return ElapsedFormat.sessionCountdown(sessionDurationSeconds)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if soundscapeFiles.isEmpty {
                    Text("Add MP3s under test/assets/soundscapes, build the app (not Preview), then run.")
                        .multilineTextAlignment(.center)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 12) {
                        Button {
                            showSoundscapePicker = true
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Soundscape")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(selectedTitle)
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
                        .padding(.horizontal, 20)
                        .disabled(audio.isPlaying || audio.sessionActive)
                        .accessibilityLabel("Soundscape, \(selectedTitle)")
                        .accessibilityHint("Opens list to preview and choose a soundscape")

                        Button {
                            showDurationPicker = true
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Duration")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(ElapsedFormat.sessionCountdown(sessionDurationSeconds))
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
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
                        .padding(.horizontal, 20)
                        .disabled(audio.isPlaying || audio.sessionActive)
                        .accessibilityLabel("Duration, \(ElapsedFormat.sessionCountdown(sessionDurationSeconds))")
                        .accessibilityHint("Opens screen to set session length")
                    }

                    if !showActiveSession {
                        Text(timerDisplayText)
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Session timer")
                            .accessibilityValue(timerDisplayText)

                        Button {
                            guard SoundscapeCatalog.urlInBundle(fileName: selectedSoundscapeFile) != nil else { return }
                            audio.configureSessionDuration(sessionDurationSeconds)
                            audio.toggle()
                            if audio.sessionActive {
                                showActiveSession = true
                            }
                        } label: {
                            Label("Play", systemImage: "play.circle.fill")
                                .font(.system(size: 56))
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .disabled(audio.isPlaying || audio.sessionActive)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: audio.isPlaying)
            .navigationTitle("Home")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .navigationDestination(isPresented: $showSoundscapePicker) {
                SoundscapeSelectionView(files: soundscapeFiles, selectedFileName: $selectedSoundscapeFile)
            }
            .navigationDestination(isPresented: $showDurationPicker) {
                DurationSelectionView(durationSeconds: $sessionDurationSeconds)
            }
            .navigationDestination(isPresented: $showActiveSession) {
                ActiveSessionView(player: audio)
            }
            .onChange(of: audio.sessionActive) { _, active in
                if !active {
                    showActiveSession = false
                }
            }
            .onAppear {
                syncSelectionWithCatalog()
                audio.configureSessionDuration(sessionDurationSeconds)
                if SoundscapeCatalog.urlInBundle(fileName: selectedSoundscapeFile) != nil {
                    audio.applySoundscape(fileName: selectedSoundscapeFile)
                }
            }
            .onChange(of: selectedSoundscapeFile) { _, newValue in
                guard SoundscapeCatalog.urlInBundle(fileName: newValue) != nil else { return }
                audio.applySoundscape(fileName: newValue)
            }
            .onChange(of: sessionDurationSeconds) { _, newValue in
                audio.configureSessionDuration(newValue)
            }
        }
    }

    private func syncSelectionWithCatalog() {
        let files = soundscapeFiles
        guard !files.isEmpty else {
            selectedSoundscapeFile = ""
            return
        }
        if selectedSoundscapeFile.isEmpty || !files.contains(selectedSoundscapeFile) {
            selectedSoundscapeFile = files[0]
        }
    }
}

#Preview {
    ContentView()
}

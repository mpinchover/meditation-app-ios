//
//  ContentView.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import SwiftUI
import AVFoundation

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

private enum PlayerSlot {
    case a, b
}

private final class SoundscapePlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var elapsedSeconds: Int = 0

    private static let crossfadeLeadSeconds = 10.0

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
        guard !isPlaying else { return }
        guard let url = SoundscapeCatalog.urlInBundle(fileName: fileName) else { return }
        soundscapeURL = url
        tearDownEngine()
        elapsedSeconds = 0
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
        elapsedSeconds = 0
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
        stopElapsedTimer()
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

        elapsedSeconds = 0
        slotStartDates.removeAll()
        resumeA = true
        resumeB = false
        primary = .a

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
        startElapsedTimer()
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
        stopElapsedTimer()
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
            startElapsedTimer()
        }
    }

    private func startElapsedTimer() {
        stopElapsedTimer()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }
            self.elapsedSeconds += 1
        }
        RunLoop.main.add(t, forMode: .common)
        elapsedTimer = t
    }

    private func stopElapsedTimer() {
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
}

struct ContentView: View {
    @StateObject private var audio = SoundscapePlayer()
    @AppStorage("selectedSoundscapeFile") private var selectedSoundscapeFile = ""

    private var soundscapeFiles: [String] {
        SoundscapeCatalog.bundledSoundscapeFileNames()
    }

    var body: some View {
        VStack(spacing: 24) {
            if soundscapeFiles.isEmpty {
                Text("Add MP3s under test/assets/soundscapes, build the app (not Preview), then run.")
                    .multilineTextAlignment(.center)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Soundscape", selection: $selectedSoundscapeFile) {
                    ForEach(soundscapeFiles, id: \.self) { fileName in
                        Text(SoundscapeCatalog.displayTitle(fileName: fileName))
                            .tag(fileName)
                    }
                }
                .pickerStyle(.menu)
                .disabled(audio.isPlaying)
                .accessibilityLabel("Soundscape")

                Text(SoundscapeCatalog.displayTitle(fileName: selectedSoundscapeFile))
                    .font(.title2.weight(.medium))

                Text(ElapsedFormat.mmss(audio.elapsedSeconds))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button {
                    audio.toggle()
                } label: {
                    Label(
                        audio.isPlaying ? "Pause" : "Play",
                        systemImage: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill"
                    )
                    .font(.system(size: 56))
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)

                if audio.isPlaying || audio.elapsedSeconds > 0 {
                    Button("Finish", role: .destructive) {
                        audio.finish()
                    }
                    .font(.body.weight(.medium))
                    .buttonStyle(.borderedProminent)
                    .tint(.red.opacity(0.8))
                }
            }
        }
        .padding()
        .animation(.easeInOut(duration: 0.2), value: audio.isPlaying)
        .onAppear {
            syncSelectionWithCatalog()
            if SoundscapeCatalog.urlInBundle(fileName: selectedSoundscapeFile) != nil {
                audio.applySoundscape(fileName: selectedSoundscapeFile)
            }
        }
        .onChange(of: selectedSoundscapeFile) { _, newValue in
            guard SoundscapeCatalog.urlInBundle(fileName: newValue) != nil else { return }
            audio.applySoundscape(fileName: newValue)
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

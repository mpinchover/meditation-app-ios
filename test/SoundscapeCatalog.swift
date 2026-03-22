//
//  SoundscapeCatalog.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import Foundation

// MARK: - Bundled soundscapes (add files under test/assets/soundscapes in Xcode)

enum SoundscapeCatalog {
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

    // MARK: - Grouping (picker sections)

    private static let sectionOrder: [String] = [
        "Waves & Brainwaves",
        "Meditation & Healing",
        "Instruments & Bells",
        "Drones & Tones",
        "Ambient & Nature",
    ]

    /// Buckets each file into a section for the soundscape picker (keyword heuristics).
    static func sectionTitle(forFileName fileName: String) -> String {
        let t = displayTitle(fileName: fileName).lowercased()

        if t.contains("meditation") || t.contains("chakra") || t.contains("lucid") || t.contains("stillness")
            || t.contains("oneness") || t.contains("energy cleanse") || t.contains("anxiety")
            || t.contains("cleansing") || t.contains("heart chakra") || t == "pure"
            || t.contains("silver moon") || t.contains("negative energy") || t.contains("circle of") {
            return "Meditation & Healing"
        }
        if t.contains("wave") || t.contains("alpha") || t.contains("delta") || t.contains("theta") || t.contains("gamma") {
            return "Waves & Brainwaves"
        }
        if t.contains("bowl") || t.contains("didgeridoo") || t.contains("flute") || t.contains("bell")
            || t.contains("tibetan") || t.contains("singing") || t.contains("ohm") || t.contains("peruvian")
            || t.contains("temple") {
            return "Instruments & Bells"
        }
        if t.contains("drone") {
            return "Drones & Tones"
        }
        if t.contains("rain") || t.contains("fire") || t.contains("river") || t.contains("ocean") || t.contains("icy") {
            return "Ambient & Nature"
        }
        return "Meditation & Healing"
    }

    /// Groups sorted filenames into ordered sections; empty sections are omitted.
    static func groupedSoundscapeSections(files: [String]) -> [(title: String, files: [String])] {
        var buckets: [String: [String]] = [:]
        for s in sectionOrder { buckets[s] = [] }
        for f in files {
            let key = sectionTitle(forFileName: f)
            if buckets[key] == nil { buckets[key] = [] }
            buckets[key]?.append(f)
        }
        var result: [(title: String, files: [String])] = []
        for title in sectionOrder {
            guard let group = buckets[title]?.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }),
                  !group.isEmpty else { continue }
            result.append((title, group))
        }
        return result
    }
}

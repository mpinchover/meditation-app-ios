//
//  BellsCatalog.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import Foundation

// MARK: - Bundled bells (add files under test/assets/bells in Xcode)

enum BellsCatalog {
    static let subdirectory = "assets/bells"
    private static let extensions = ["mp3", "m4a", "wav", "aac", "caf"]
    private static let allowedExtensionSet = Set(extensions.map { $0.lowercased() })
    private static let fm = FileManager.default

    /// Filenames (e.g. `Zen bell 1.wav`) found in the bundle for bells.
    static func bundledBellFileNames() -> [String] {
        var names = Set<String>()

        for ext in extensions {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: subdirectory) {
                for u in urls { names.insert(u.lastPathComponent) }
            }
            // Some targets flatten resources (no `assets/bells` folder in the built bundle).
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for u in urls {
                    let name = u.lastPathComponent
                    if isLikelyBellFileName(name) { names.insert(name) }
                }
            }
        }

        if let dir = bellsDirectoryInBundle(),
           let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            while let url = enumerator.nextObject() as? URL {
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                let ext = url.pathExtension.lowercased()
                guard allowedExtensionSet.contains(ext) else { continue }
                names.insert(url.lastPathComponent)
            }
        }

        // Same as soundscapes: files may sit directly under `Resources/` with no subfolder.
        if let res = Bundle.main.resourceURL,
           let contents = try? fm.contentsOfDirectory(at: res, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for u in contents {
                guard (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                let ext = u.pathExtension.lowercased()
                guard allowedExtensionSet.contains(ext) else { continue }
                let base = u.lastPathComponent
                if isLikelyBellFileName(base) { names.insert(base) }
            }
        }

        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// When resources are flattened into the bundle root, only treat typical bell/gong assets as bells (not every soundscape).
    private static func isLikelyBellFileName(_ fileName: String) -> Bool {
        let stem = (fileName as NSString).deletingPathExtension.lowercased()
        return stem.contains("bell") || stem.contains("gong")
    }

    private static func bellsDirectoryInBundle() -> URL? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let dir = resources.appendingPathComponent(subdirectory, isDirectory: true)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { return nil }
        return dir
    }

    static func urlInBundle(fileName: String) -> URL? {
        if let dir = bellsDirectoryInBundle() {
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
        "Tibetan bells",
        "Gongs",
        "Zen bells",
    ]

    static func sectionTitle(forFileName fileName: String) -> String {
        let t = displayTitle(fileName: fileName).lowercased()
        if t.contains("tibetan") { return "Tibetan bells" }
        if t.contains("chinese") || t.contains("gong") { return "Gongs" }
        if t.contains("zen") { return "Zen bells" }
        return "Tibetan bells"
    }

    static func groupedBellSections(files: [String]) -> [(title: String, files: [String])] {
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

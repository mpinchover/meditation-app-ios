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
}

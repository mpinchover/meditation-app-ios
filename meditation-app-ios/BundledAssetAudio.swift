//
//  BundledAssetAudio.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 3/28/26.
//

import Foundation

/// Audio files under `Bundle.main` with paths like `assets/soundscapes/...` (see Run Script build phase).
enum BundledAssetAudio {
    static let extensions = ["mp3", "m4a", "wav", "aac", "caf"]
    private static let extSet = Set(extensions.map { $0.lowercased() })
    private static let fm = FileManager.default

    /// Paths relative to `rootSubdirectory` using `/` (e.g. `Drone/a.mp3`, `b.mp3`).
    static func relativeAudioPaths(rootSubdirectory: String) -> [String] {
        guard let base = bundleDirectoryURL(rootSubdirectory) else { return [] }
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: base.path, isDirectory: &isDir), isDir.boolValue else { return [] }

        let basePath = base.standardizedFileURL.path
        var results: [String] = []
        guard let enumerator = fm.enumerator(at: base, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return [] }
        while let item = enumerator.nextObject() as? URL {
            guard (try? item.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            if item.lastPathComponent == ".DS_Store" { continue }
            let ext = item.pathExtension.lowercased()
            guard extSet.contains(ext) else { continue }
            let full = item.standardizedFileURL.path
            guard full.hasPrefix(basePath) else { continue }
            var rel = String(full.dropFirst(basePath.count))
            if rel.hasPrefix("/") { rel.removeFirst() }
            if rel.isEmpty { continue }
            results.append(rel)
        }
        return results.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// `relativePath` is the path under `rootSubdirectory` (may include subfolders).
    static func url(relativePath: String, rootSubdirectory: String) -> URL? {
        let parts = relativePath.split(separator: "/").map(String.init)
        guard let fileName = parts.last else { return nil }
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard !name.isEmpty, !ext.isEmpty else { return nil }
        let parent = parts.dropLast()
        let subdirectory: String
        if parent.isEmpty {
            subdirectory = rootSubdirectory
        } else {
            subdirectory = rootSubdirectory + "/" + parent.joined(separator: "/")
        }
        return Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
    }

    static func displayTitle(relativePath: String) -> String {
        ((relativePath as NSString).lastPathComponent as NSString).deletingPathExtension
    }

    private static func bundleDirectoryURL(_ rootSubdirectory: String) -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent(rootSubdirectory, isDirectory: true)
    }
}

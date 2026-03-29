//
//  SoundscapeCatalog.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import Foundation

enum SoundscapeCatalog {
    static let rootSubdirectory = "assets/soundscapes"

    static func bundledSoundscapeFileNames() -> [String] {
        BundledAssetAudio.relativeAudioPaths(rootSubdirectory: rootSubdirectory)
    }

    static func urlInBundle(fileName: String) -> URL? {
        BundledAssetAudio.url(relativePath: fileName, rootSubdirectory: rootSubdirectory)
    }

    static func displayTitle(fileName: String) -> String {
        BundledAssetAudio.displayTitle(relativePath: fileName)
    }

    static func groupedSoundscapeSections(files: [String]) -> [(title: String, files: [String])] {
        BundledAssetAudio.groupedSections(relativePaths: files, otherTitle: "Other")
    }
}

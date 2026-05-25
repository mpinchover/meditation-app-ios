//
//  SoundscapeCatalog.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 3/21/26.
//

import Foundation

enum SoundscapeCatalog {
    static func bundledSoundscapeFileNames() -> [String] {
        SoundStore.shared.soundscapeFileNames()
    }

    static func urlInBundle(fileName: String) -> URL? {
        SoundStore.shared.soundscapeURL(id: fileName)
    }

    static func displayTitle(fileName: String) -> String {
        SoundStore.shared.soundscapeDisplayName(id: fileName)
    }
}

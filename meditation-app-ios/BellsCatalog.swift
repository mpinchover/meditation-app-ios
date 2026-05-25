//
//  BellsCatalog.swift
//  meditation-app-ios
//
//  Created by Matt Pinchover on 3/21/26.
//

import Foundation

enum BellsCatalog {
    static func bundledBellFileNames() -> [String] {
        SoundStore.shared.bellFileNames()
    }

    static func urlInBundle(fileName: String) -> URL? {
        SoundStore.shared.bellURL(id: fileName)
    }

    static func displayTitle(fileName: String) -> String {
        SoundStore.shared.bellDisplayName(id: fileName)
    }
}

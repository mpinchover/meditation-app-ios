//
//  SessionBellPlayback.swift
//  test
//
//  Created by Matt Pinchover on 3/21/26.
//

import AVFoundation

/// One-shot bell playback during meditation (separate from soundscape engine).
/// Retains each `AVAudioPlayer` until playback ends; a local player is released immediately and would not play.
enum SessionBellPlayback {
    private static var active: [HeldBell] = []

    private final class HeldBell: NSObject, AVAudioPlayerDelegate {
        let player: AVAudioPlayer

        init(player: AVAudioPlayer) {
            self.player = player
            super.init()
            self.player.delegate = self
        }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            SessionBellPlayback.release(self)
        }

        func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
            SessionBellPlayback.release(self)
        }
    }

    private static func release(_ held: HeldBell) {
        active.removeAll { $0 === held }
    }

    static func play(fileName: String) {
        guard !fileName.isEmpty, let url = BellsCatalog.urlInBundle(fileName: fileName) else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = 0
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
#endif
            let held = HeldBell(player: p)
            active.append(held)
            held.player.prepareToPlay()
            _ = held.player.play()
        } catch { }
    }
}

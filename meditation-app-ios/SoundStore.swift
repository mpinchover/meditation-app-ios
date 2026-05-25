//
//  SoundStore.swift
//  meditation-app-ios
//

import Foundation

struct SoundMetadata: Codable, Sendable {
    let id: String
    let name: String
    let mediaUrl: String
}

struct SoundCatalogData: Codable, Sendable {
    let bells: [SoundMetadata]
    let soundscapes: [SoundMetadata]
}

/// Downloads and caches bell / soundscape audio in the app's Documents directory.
/// On first launch the catalog is fetched from the server and every audio file is
/// downloaded; subsequent launches read from the local cache (offline-capable).
final class SoundStore: ObservableObject {
    @MainActor static let shared = SoundStore()

    @MainActor @Published private(set) var isLoading = false
    @MainActor @Published private(set) var isReady = false
    @MainActor @Published private(set) var error: String?

    private let fm = FileManager.default

    /// Once written (on main actor during bootstrap), only read thereafter -- safe for
    /// nonisolated reads from audio threads after the store is marked ready.
    nonisolated(unsafe) private var catalog: SoundCatalogData?

    private static let serverBaseURL =
        "https://meditate-now-server-535943965628.us-central1.run.app"

    // MARK: - Directory layout

    private var soundsDir: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sounds", isDirectory: true)
    }
    private var bellsDir: URL { soundsDir.appendingPathComponent("bells", isDirectory: true) }
    private var soundscapesDir: URL { soundsDir.appendingPathComponent("soundscapes", isDirectory: true) }
    private var catalogFile: URL { soundsDir.appendingPathComponent("catalog.json") }

    // MARK: - Public queries (nonisolated -- safe to call from any thread)

    nonisolated func bellFileNames() -> [String] { catalog?.bells.map(\.id) ?? [] }
    nonisolated func soundscapeFileNames() -> [String] { catalog?.soundscapes.map(\.id) ?? [] }

    nonisolated func bellURL(id: String) -> URL? {
        guard let bell = catalog?.bells.first(where: { $0.id == id }) else { return nil }
        let url = bellsDir.appendingPathComponent("\(id).\(Self.ext(from: bell.mediaUrl))")
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    nonisolated func soundscapeURL(id: String) -> URL? {
        guard let s = catalog?.soundscapes.first(where: { $0.id == id }) else { return nil }
        let url = soundscapesDir.appendingPathComponent("\(id).\(Self.ext(from: s.mediaUrl))")
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    nonisolated func bellDisplayName(id: String) -> String {
        catalog?.bells.first(where: { $0.id == id })?.name ?? id
    }

    nonisolated func soundscapeDisplayName(id: String) -> String {
        catalog?.soundscapes.first(where: { $0.id == id })?.name ?? id
    }

    // MARK: - Bootstrap

    /// Call once at launch: loads from disk or downloads from the server.
    @MainActor
    func ensureSoundsAvailable() async {
        if isReady { return }
        if loadCatalogFromDisk() { return }
        await downloadSounds()
    }

    @MainActor
    func retryDownload() async {
        error = nil
        await downloadSounds()
    }

    // MARK: - Internals

    @MainActor
    @discardableResult
    private func loadCatalogFromDisk() -> Bool {
        guard fm.fileExists(atPath: catalogFile.path),
              let data = try? Data(contentsOf: catalogFile),
              let decoded = try? JSONDecoder().decode(SoundCatalogData.self, from: data) else {
            return false
        }
        catalog = decoded
        isReady = true
        return true
    }

    @MainActor
    private func downloadSounds() async {
        isLoading = true
        error = nil

        do {
            let (bells, soundscapes) = try await fetchCatalogFromServer()

            try fm.createDirectory(at: bellsDir, withIntermediateDirectories: true)
            try fm.createDirectory(at: soundscapesDir, withIntermediateDirectories: true)

            var downloadedBells: [SoundMetadata] = []
            for item in bells {
                let localFile = bellsDir.appendingPathComponent("\(item.id).\(Self.ext(from: item.mediaUrl))")
                try await downloadFile(from: item.mediaUrl, to: localFile)
                downloadedBells.append(item)
            }

            var downloadedScapes: [SoundMetadata] = []
            for item in soundscapes {
                let localFile = soundscapesDir.appendingPathComponent("\(item.id).\(Self.ext(from: item.mediaUrl))")
                try await downloadFile(from: item.mediaUrl, to: localFile)
                downloadedScapes.append(item)
            }

            let stored = SoundCatalogData(bells: downloadedBells, soundscapes: downloadedScapes)
            try JSONEncoder().encode(stored).write(to: catalogFile)

            catalog = stored
            isReady = true
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private nonisolated func fetchCatalogFromServer() async throws -> (bells: [SoundMetadata], soundscapes: [SoundMetadata]) {
        guard let url = URL(string: "\(Self.serverBaseURL)/meditation-sounds") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        func parse(_ items: [[String: Any]]) -> [SoundMetadata] {
            items.compactMap { dict in
                guard let id = dict["id"] as? String,
                      let name = dict["name"] as? String,
                      let mediaUrl = dict["media_url"] as? String else { return nil }
                return SoundMetadata(id: id, name: name, mediaUrl: mediaUrl)
            }
        }

        let bells = parse(json["bells"] as? [[String: Any]] ?? [])
        let soundscapes = parse(json["soundscapes"] as? [[String: Any]] ?? [])
        return (bells, soundscapes)
    }

    private nonisolated func downloadFile(from urlString: String, to destination: URL) async throws {
        guard let remoteURL = URL(string: urlString) else { throw URLError(.badURL) }
        let (tmpURL, response) = try await URLSession.shared.download(from: remoteURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: tmpURL, to: destination)
    }

    private nonisolated static func ext(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "mp3" }
        let e = url.pathExtension.lowercased()
        return e.isEmpty ? "mp3" : e
    }
}

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

struct SoundSummary: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
}

enum SoundDownloadState: String, Codable, Sendable {
    case pending
    case downloading
    case downloaded
}

struct SoundCatalogData: Codable, Sendable {
    var bells: [SoundMetadata]
    var soundscapes: [SoundMetadata]
    var bellSummaries: [SoundSummary]
    var soundscapeSummaries: [SoundSummary]

    init(
        bells: [SoundMetadata] = [],
        soundscapes: [SoundMetadata] = [],
        bellSummaries: [SoundSummary] = [],
        soundscapeSummaries: [SoundSummary] = []
    ) {
        self.bells = bells
        self.soundscapes = soundscapes
        self.bellSummaries = bellSummaries
        self.soundscapeSummaries = soundscapeSummaries
    }
}

private enum SoundKind: String, Sendable {
    case bell
    case soundscape

    var collectionPath: String {
        switch self {
        case .bell: return "bells"
        case .soundscape: return "soundscapes"
        }
    }
}

private struct SoundSyncPlan: Sendable {
    let catalog: SoundCatalogData
    let pending: [(kind: SoundKind, id: String)]
}

/// Downloads and caches bell / soundscape audio in the app's Documents directory.
/// Cached sounds are shown immediately; missing sounds sync in the background on each launch.
final class SoundStore: ObservableObject {
    @MainActor static let shared = SoundStore()

    @MainActor @Published private(set) var isReady = false
    @MainActor @Published private(set) var isRemoteCatalogLoaded = false
    @MainActor @Published private(set) var catalogRevision = 0
    @MainActor @Published private(set) var bellSummaries: [SoundSummary] = []
    @MainActor @Published private(set) var soundscapeSummaries: [SoundSummary] = []
    @MainActor @Published private(set) var downloadStates: [String: SoundDownloadState] = [:]

    private let fm = FileManager.default

    nonisolated(unsafe) private var catalog: SoundCatalogData?
    nonisolated(unsafe) private var bellSummariesCache: [SoundSummary] = []
    nonisolated(unsafe) private var soundscapeSummariesCache: [SoundSummary] = []

    @MainActor private var hasBootstrapped = false
    @MainActor private var syncInFlight = false

    private static let serverBaseURL =
        "https://callysto-server-724373166676.us-central1.run.app"

    private static let parallelDownloadLimit = 3

    private var soundsDir: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sounds", isDirectory: true)
    }
    private var bellsDir: URL { soundsDir.appendingPathComponent("bells", isDirectory: true) }
    private var soundscapesDir: URL { soundsDir.appendingPathComponent("soundscapes", isDirectory: true) }
    private var catalogFile: URL { soundsDir.appendingPathComponent("catalog.json") }

    // MARK: - Public queries

    @MainActor
    var needsInitialCatalogLoad: Bool {
        !isRemoteCatalogLoaded && !hasCachedSounds
    }

    @MainActor
    var hasCachedSounds: Bool {
        !(catalog?.bells.isEmpty ?? true)
            || !(catalog?.soundscapes.isEmpty ?? true)
            || !bellSummaries.isEmpty
            || !soundscapeSummaries.isEmpty
    }

    nonisolated func bellFileNames() -> [String] { bellSummariesCache.map(\.id) }
    nonisolated func soundscapeFileNames() -> [String] { soundscapeSummariesCache.map(\.id) }

    @MainActor
    func downloadState(for id: String) -> SoundDownloadState? {
        downloadStates[id]
    }

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
        if let summary = bellSummariesCache.first(where: { $0.id == id }) { return summary.name }
        return catalog?.bells.first(where: { $0.id == id })?.name ?? id
    }

    nonisolated func soundscapeDisplayName(id: String) -> String {
        if let summary = soundscapeSummariesCache.first(where: { $0.id == id }) { return summary.name }
        return catalog?.soundscapes.first(where: { $0.id == id })?.name ?? id
    }

    // MARK: - Bootstrap

    @MainActor
    func ensureSoundsAvailable() {
        if !hasBootstrapped {
            hasBootstrapped = true
            _ = loadCatalogFromDisk()
            isReady = true
        }
        startBackgroundSyncIfNeeded()
    }

    // MARK: - Internals

    @MainActor
    @discardableResult
    private func loadCatalogFromDisk() -> Bool {
        guard fm.fileExists(atPath: catalogFile.path),
              let data = try? Data(contentsOf: catalogFile),
              let decoded = try? JSONDecoder().decode(SoundCatalogData.self, from: data) else {
            applyCatalog(SoundCatalogData())
            return false
        }
        applyCatalog(decoded)
        if !decoded.bellSummaries.isEmpty || !decoded.soundscapeSummaries.isEmpty {
            isRemoteCatalogLoaded = true
        }
        refreshDownloadStates()
        return true
    }

    @MainActor
    private func applyCatalog(_ data: SoundCatalogData) {
        catalog = data
        bellSummaries = data.bellSummaries.isEmpty
            ? data.bells.map { SoundSummary(id: $0.id, name: $0.name) }
            : data.bellSummaries
        soundscapeSummaries = data.soundscapeSummaries.isEmpty
            ? data.soundscapes.map { SoundSummary(id: $0.id, name: $0.name) }
            : data.soundscapeSummaries
        bellSummariesCache = bellSummaries
        soundscapeSummariesCache = soundscapeSummaries
    }

    @MainActor
    private func applyRemoteSummaries(bells: [SoundSummary], soundscapes: [SoundSummary]) {
        bellSummaries = bells
        soundscapeSummaries = soundscapes
        bellSummariesCache = bells
        soundscapeSummariesCache = soundscapes
        isRemoteCatalogLoaded = true

        var data = catalog ?? SoundCatalogData()
        data.bellSummaries = bells
        data.soundscapeSummaries = soundscapes
        catalog = data
    }

    @MainActor
    private func refreshDownloadStates() {
        var states: [String: SoundDownloadState] = [:]
        for summary in bellSummaries {
            states[summary.id] = bellURL(id: summary.id) != nil ? .downloaded : .pending
        }
        for summary in soundscapeSummaries {
            states[summary.id] = soundscapeURL(id: summary.id) != nil ? .downloaded : .pending
        }
        downloadStates = states
    }

    @MainActor
    private func setDownloadState(_ state: SoundDownloadState, for id: String) {
        var updated = downloadStates
        updated[id] = state
        downloadStates = updated
    }

    @MainActor
    private func startBackgroundSyncIfNeeded() {
        guard !syncInFlight else { return }
        syncInFlight = true
        Task {
            defer { syncInFlight = false }
            do {
                try await performSync()
            } catch {
                // Silent failure; retry on next app open.
            }
        }
    }

    @MainActor
    private func performSync() async throws {
        let remote = try await fetchSoundSummariesFromServer()
        applyRemoteSummaries(bells: remote.bells, soundscapes: remote.soundscapes)
        refreshDownloadStates()
        catalogRevision += 1

        try ensureSoundDirectoriesExist()

        let local = catalog ?? SoundCatalogData()
        let bellsPath = bellsDir
        let soundscapesPath = soundscapesDir

        let plan = await Task.detached(priority: .utility) {
            Self.buildSyncPlan(
                local: local,
                remoteBellIds: remote.bells.map(\.id),
                remoteSoundscapeIds: remote.soundscapes.map(\.id),
                bellsDir: bellsPath,
                soundscapesDir: soundscapesPath
            )
        }.value

        var merged = plan.catalog
        merged.bellSummaries = remote.bells
        merged.soundscapeSummaries = remote.soundscapes
        catalog = merged
        refreshDownloadStates()

        for item in plan.pending {
            setDownloadState(.pending, for: item.id)
        }

        guard !plan.pending.isEmpty else {
            try saveCatalog(merged)
            catalogRevision += 1
            return
        }

        var updated = merged
        try await downloadPendingSounds(plan.pending) { metadata, kind in
            switch kind {
            case .bell:
                updated.bells.removeAll { $0.id == metadata.id }
                updated.bells.append(metadata)
                updated.bells.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            case .soundscape:
                updated.soundscapes.removeAll { $0.id == metadata.id }
                updated.soundscapes.append(metadata)
                updated.soundscapes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }
            self.catalog = updated
            self.setDownloadState(.downloaded, for: metadata.id)
            try? self.saveCatalog(updated)
        }
        catalogRevision += 1
    }

    @MainActor
    private func ensureSoundDirectoriesExist() throws {
        try fm.createDirectory(at: bellsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: soundscapesDir, withIntermediateDirectories: true)
    }

    @MainActor
    private func saveCatalog(_ data: SoundCatalogData) throws {
        try JSONEncoder().encode(data).write(to: catalogFile)
        applyCatalog(data)
    }

    private nonisolated static func buildSyncPlan(
        local: SoundCatalogData,
        remoteBellIds: [String],
        remoteSoundscapeIds: [String],
        bellsDir: URL,
        soundscapesDir: URL
    ) -> SoundSyncPlan {
        var catalog = local
        let fm = FileManager.default

        let staleBellIds = Set(catalog.bells.map(\.id)).subtracting(remoteBellIds)
        for id in staleBellIds {
            deleteLocalAudioFiles(id: id, in: bellsDir, fm: fm)
            catalog.bells.removeAll { $0.id == id }
        }

        let staleSoundscapeIds = Set(catalog.soundscapes.map(\.id)).subtracting(remoteSoundscapeIds)
        for id in staleSoundscapeIds {
            deleteLocalAudioFiles(id: id, in: soundscapesDir, fm: fm)
            catalog.soundscapes.removeAll { $0.id == id }
        }

        var pending: [(SoundKind, String)] = []

        for id in remoteBellIds {
            if let meta = catalog.bells.first(where: { $0.id == id }),
               localAudioExists(for: meta, in: bellsDir, fm: fm) {
                continue
            }
            pending.append((.bell, id))
        }

        for id in remoteSoundscapeIds {
            if let meta = catalog.soundscapes.first(where: { $0.id == id }),
               localAudioExists(for: meta, in: soundscapesDir, fm: fm) {
                continue
            }
            pending.append((.soundscape, id))
        }

        return SoundSyncPlan(catalog: catalog, pending: pending)
    }

    private nonisolated static func deleteLocalAudioFiles(id: String, in directory: URL, fm: FileManager) {
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names where name.hasPrefix("\(id).") {
            try? fm.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    private nonisolated static func localAudioExists(for metadata: SoundMetadata, in directory: URL, fm: FileManager) -> Bool {
        let url = directory.appendingPathComponent("\(metadata.id).\(ext(from: metadata.mediaUrl))")
        return fm.fileExists(atPath: url.path)
    }

    @MainActor
    private func downloadPendingSounds(
        _ pending: [(kind: SoundKind, id: String)],
        onSuccess: @escaping (SoundMetadata, SoundKind) throws -> Void
    ) async throws {
        let bells = bellsDir
        let soundscapes = soundscapesDir
        var index = 0

        try await withThrowingTaskGroup(of: Void.self) { group in
            let initial = min(Self.parallelDownloadLimit, pending.count)
            for _ in 0..<initial {
                let item = pending[index]
                index += 1
                group.addTask {
                    try await self.downloadOneSound(
                        kind: item.kind,
                        id: item.id,
                        bellsDir: bells,
                        soundscapesDir: soundscapes,
                        onSuccess: onSuccess
                    )
                }
            }

            while try await group.next() != nil {
                guard index < pending.count else { continue }
                let item = pending[index]
                index += 1
                group.addTask {
                    try await self.downloadOneSound(
                        kind: item.kind,
                        id: item.id,
                        bellsDir: bells,
                        soundscapesDir: soundscapes,
                        onSuccess: onSuccess
                    )
                }
            }
        }
    }

    private nonisolated func downloadOneSound(
        kind: SoundKind,
        id: String,
        bellsDir: URL,
        soundscapesDir: URL,
        onSuccess: @MainActor @escaping (SoundMetadata, SoundKind) throws -> Void
    ) async throws {
        await MainActor.run {
            SoundStore.shared.setDownloadState(.downloading, for: id)
        }
        let metadata = try await fetchSoundMetadata(kind: kind, id: id)
        let directory = kind == .bell ? bellsDir : soundscapesDir
        let localFile = directory.appendingPathComponent("\(metadata.id).\(Self.ext(from: metadata.mediaUrl))")
        try await downloadFile(from: metadata.mediaUrl, to: localFile)
        try await MainActor.run {
            try onSuccess(metadata, kind)
        }
    }

    private nonisolated func fetchSoundSummariesFromServer() async throws -> (bells: [SoundSummary], soundscapes: [SoundSummary]) {
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

        func parseSummaries(_ value: Any?) -> [SoundSummary] {
            guard let items = value as? [[String: Any]] else { return [] }
            return items.compactMap { dict in
                guard let id = dict["id"] as? String,
                      let name = dict["name"] as? String else { return nil }
                return SoundSummary(id: id, name: name)
            }
        }

        return (parseSummaries(json["bells"]), parseSummaries(json["soundscapes"]))
    }

    private nonisolated func fetchSoundMetadata(kind: SoundKind, id: String) async throws -> SoundMetadata {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        guard let url = URL(string: "\(Self.serverBaseURL)/meditation-sounds/\(kind.collectionPath)/\(encoded)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let parsedId = json["id"] as? String,
              let name = json["name"] as? String,
              let mediaUrl = json["media_url"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        return SoundMetadata(id: parsedId, name: name, mediaUrl: mediaUrl)
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

import Foundation

struct CachedInsight: Codable, Sendable {
    let month: Int
    let date: Int
    let title: String
    let insight: String
}

@MainActor
final class InsightStore: ObservableObject {
    static let shared = InsightStore()

    @Published private(set) var isLoading = false
    @Published private(set) var current: CachedInsight?
    /// Set only when a fetch fails AND there is no cached insight to fall back on.
    @Published private(set) var fetchError: String?

    private let fm = FileManager.default

    private static let serverBaseURL =
        "https://callysto-server-724373166676.us-central1.run.app"

    private var cacheFile: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sounds", isDirectory: true)
            .appendingPathComponent("insight.json")
    }

    /// Loads cached insight, then fetches from the server if the cached one is stale or missing.
    /// Safe to call multiple times — concurrent calls are ignored while a fetch is in flight.
    func loadInsight() async {
        // Populate from disk on first call
        if current == nil {
            current = loadFromDisk()
        }

        // UTC date components
        let (todayMonth, todayDay) = utcMonthDay()

        // Already have today's insight — nothing to do
        if let current, current.month == todayMonth, current.date == todayDay {
            return
        }

        // Prevent duplicate in-flight fetches
        guard !isLoading else { return }

        isLoading = true

        do {
            let fetched = try await fetchFromServer(month: todayMonth, date: todayDay)
            current = fetched
            fetchError = nil
            saveToDisk(fetched)
        } catch {
            // If we already have a cached insight, silently keep it and don't surface the error.
            if current == nil {
                fetchError = "Could not load today's insight."
            }
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func utcMonthDay() -> (month: Int, day: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.month, .day], from: Date())
        return (c.month ?? 1, c.day ?? 1)
    }

    private func loadFromDisk() -> CachedInsight? {
        guard fm.fileExists(atPath: cacheFile.path),
              let data = try? Data(contentsOf: cacheFile),
              let decoded = try? JSONDecoder().decode(CachedInsight.self, from: data) else {
            return nil
        }
        return decoded
    }

    private func saveToDisk(_ insight: CachedInsight) {
        try? fm.createDirectory(
            at: cacheFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? JSONEncoder().encode(insight).write(to: cacheFile)
    }

    private nonisolated func fetchFromServer(month: Int, date: Int) async throws -> CachedInsight {
        guard let url = URL(string: "\(Self.serverBaseURL)/insight?month=\(month)&date=\(date)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String,
              let insight = json["insight"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        return CachedInsight(month: month, date: date, title: title, insight: insight)
    }
}

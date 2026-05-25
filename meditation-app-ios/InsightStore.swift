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
    @Published private(set) var error: String?

    private let fm = FileManager.default

    private static let serverBaseURL =
        "https://meditate-now-server-535943965628.us-central1.run.app"

    private var cacheFile: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sounds", isDirectory: true)
            .appendingPathComponent("insight.json")
    }

    func loadInsight() async {
        let cached = loadFromDisk()
        current = cached

        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        let todayMonth = today.month ?? 1
        let todayDate = today.day ?? 1

        if let cached, cached.month == todayMonth, cached.date == todayDate {
            return
        }

        isLoading = true
        error = nil

        do {
            let fetched = try await fetchFromServer(month: todayMonth, date: todayDate)
            current = fetched
            saveToDisk(fetched)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
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

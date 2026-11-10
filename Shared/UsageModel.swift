import Foundation

/// One usage bar, e.g. "Current session · 74%".
struct UsageLimit: Codable, Hashable, Identifiable {
    var id: String { title }
    let title: String
    let percent: Double
    let resetsAt: Date?
    let severity: String

    /// If the reset time has already passed, the stored percent is stale; treat it as 0.
    func effectivePercent(at now: Date) -> Double {
        if let resetsAt, resetsAt <= now { return 0 }
        return min(max(percent, 0), 100)
    }
}

/// What the helper app writes and the widget reads. Contains no credentials.
struct UsageSnapshot: Codable {
    let updatedAt: Date
    let limits: [UsageLimit]
    let error: String?

    static let sample = UsageSnapshot(
        updatedAt: Date(),
        limits: [
            UsageLimit(title: "Current session", percent: 70, resetsAt: Date().addingTimeInterval(3 * 3600), severity: "normal"),
            UsageLimit(title: "Weekly · All models", percent: 12, resetsAt: Date().addingTimeInterval(5 * 86400), severity: "normal"),
            UsageLimit(title: "Fable", percent: 20, resetsAt: Date().addingTimeInterval(5 * 86400), severity: "normal"),
        ],
        error: nil
    )
}

enum UsageStore {
    /// ~/Library/Application Support/ClaudeUsageWidget/usage.json (real home, also from inside the widget sandbox).
    static var fileURL: URL {
        realHome.appendingPathComponent("Library/Application Support/ClaudeUsageWidget/usage.json")
    }

    private static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static func load() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(UsageSnapshot.self, from: data)
    }

    static func save(_ snapshot: UsageSnapshot) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }
}

enum UsageFormat {
    static func resetText(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        if date <= now { return "Reset" }
        let f = DateFormatter()
        if Calendar.current.isDate(date, inSameDayAs: now) {
            f.setLocalizedDateFormatFromTemplate("jmm")
            return "Resets at \(f.string(from: date))"
        }
        f.setLocalizedDateFormatFromTemplate("EEE jmm")
        return "Resets \(f.string(from: date))"
    }

    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("jmm")
        return f.string(from: date)
    }
}

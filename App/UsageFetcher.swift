import Foundation

enum FetchError: LocalizedError {
    case notLoggedIn, expired, http(Int), badResponse

    var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "Log in to Claude Code"
        case .expired: return "Open Claude Code to refresh login"
        case .http(let code): return "Server error (\(code))"
        case .badResponse: return "Unexpected response"
        }
    }
}

/// Reads the Claude Code login from the Keychain and asks Anthropic for plan usage.
/// The token is only held in memory for the request: never logged, never written to disk.
enum UsageFetcher {
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetch() async throws -> [UsageLimit] {
        let token = try readToken()
        var req = URLRequest(url: endpoint, timeoutInterval: 20)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("ClaudeUsageWidget/1.0", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw FetchError.expired }
        guard status == 200 else { throw FetchError.http(status) }
        return try parse(data)
    }

    // MARK: - Keychain

    private static func readToken() throws -> String {
        // Use the system `security` tool, the same way Claude Code stores this item.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        try p.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty
        else { throw FetchError.notLoggedIn }

        if let expiresMs = oauth["expiresAt"] as? Double,
           Date(timeIntervalSince1970: expiresMs / 1000) < Date() {
            throw FetchError.expired
        }
        return token
    }

    // MARK: - Parsing

    private struct Response: Decodable {
        struct Window: Decodable { let utilization: Double?; let resets_at: String? }
        struct Limit: Decodable {
            struct Scope: Decodable {
                struct Model: Decodable { let display_name: String? }
                let model: Model?
            }
            let kind: String
            let percent: Double?
            let severity: String?
            let resets_at: String?
            let scope: Scope?
        }
        let limits: [Limit]?
        let five_hour: Window?
        let seven_day: Window?
    }

    private static func parse(_ data: Data) throws -> [UsageLimit] {
        guard let r = try? JSONDecoder().decode(Response.self, from: data) else { throw FetchError.badResponse }

        if let limits = r.limits, !limits.isEmpty {
            return limits.map { l in
                UsageLimit(title: title(for: l), percent: l.percent ?? 0,
                           resetsAt: date(l.resets_at), severity: l.severity ?? "normal")
            }
        }
        // Fallback to the older fields.
        var out: [UsageLimit] = []
        if let w = r.five_hour {
            out.append(UsageLimit(title: "Current session", percent: w.utilization ?? 0, resetsAt: date(w.resets_at), severity: "normal"))
        }
        if let w = r.seven_day {
            out.append(UsageLimit(title: "Weekly · All models", percent: w.utilization ?? 0, resetsAt: date(w.resets_at), severity: "normal"))
        }
        guard !out.isEmpty else { throw FetchError.badResponse }
        return out
    }

    private static func title(for l: Response.Limit) -> String {
        switch l.kind {
        case "session": return "Current session"
        case "weekly_all": return "Weekly · All models"
        default:
            if let name = l.scope?.model?.display_name { return name }
            return l.kind.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Parses e.g. "2026-11-10T17:40:00.495422+00:00" (fractional part dropped).
    private static func date(_ s: String?) -> Date? {
        guard var s else { return nil }
        if let dot = s.firstIndex(of: "."),
           let end = s[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            s.removeSubrange(dot..<end)
        }
        guard let d = ISO8601DateFormatter().date(from: s) else { return nil }
        // Round to the nearest minute so 17:39:59 shows as 17:40, like Claude's own UI.
        return Date(timeIntervalSince1970: (d.timeIntervalSince1970 / 60).rounded() * 60)
    }
}

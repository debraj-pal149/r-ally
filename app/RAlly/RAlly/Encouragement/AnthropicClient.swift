import Foundation

struct PepLines: Codable, Sendable {
    var pre_quit_fade: [String]
    var pace_slip: [String]?
    var keep_going: [String]?
    var stopped: [String]
    var still_stopped: [String]?
    var recovery: [String]?
    var grind_support: [String]
}

struct AnthropicClient: Sendable {
    var apiKey: String
    var session: URLSession = .shared

    static func keyFromBundle() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String) ?? ""
    }

    var isConfigured: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func generate(system: String, user: String) async throws -> PepLines {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 5
        req.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.addValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 300,
            "temperature": 1.0,
            "system": system,
            "messages": [["role": "user", "content": user]],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: req)
        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        let text = decoded.content.first?.text ?? ""
        return try Self.parseLines(text)
    }

    static func parseLines(_ text: String) throws -> PepLines {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let json: String = {
            if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
                return String(trimmed[start...end])
            }
            return trimmed
        }()
        guard let data = json.data(using: .utf8) else { throw URLError(.cannotDecodeContentData) }
        return Self.scrub(try JSONDecoder().decode(PepLines.self, from: data))
    }

    private static func scrub(_ pep: PepLines) -> PepLines {
        var p = pep
        p.pre_quit_fade = DashNormalizer.normalizeLines(p.pre_quit_fade)
        p.pace_slip = p.pace_slip.map(DashNormalizer.normalizeLines)
        p.keep_going = p.keep_going.map(DashNormalizer.normalizeLines)
        p.stopped = DashNormalizer.normalizeLines(p.stopped)
        p.still_stopped = p.still_stopped.map(DashNormalizer.normalizeLines)
        p.recovery = p.recovery.map(DashNormalizer.normalizeLines)
        p.grind_support = DashNormalizer.normalizeLines(p.grind_support)
        return p
    }

    private struct MessagesResponse: Codable {
        var content: [Block]
        struct Block: Codable { var text: String? }
    }
}

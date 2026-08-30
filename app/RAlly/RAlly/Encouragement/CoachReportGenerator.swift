import Foundation

struct CoachFieldReport: Codable, Sendable {
    var headline: String
    var debrief: String
    var turningPointText: String
    var athleteGrade: String
    var coachQuote: String
}

@MainActor
final class CoachReportGenerator {
    static let shared = CoachReportGenerator()

    func generateReport(
        record: WorkoutSessionRecord,
        persona: Persona,
        runnerLevel: RunnerLevel,
        client: AnthropicClient
    ) async -> CoachFieldReport {
        guard client.isConfigured else {
            return fallbackReport(record: record, persona: persona)
        }

        let sys = """
        You are \(persona.name), \(persona.archetype). Write a post-workout Coach's Field Report for an athlete who just finished a \(Formatters.km(record.distanceM)) run in \(Formatters.clock(record.durationSec)).
        Athlete Runner Level: \(runnerLevel.rawValue).
        Number of times they fought through quit-risk / rallied: \(record.rallyCount).
        Style: In-character, gritty, authentic, raw, proud. No generic corporate fitness advice.

        Output ONLY valid JSON with keys:
        {
          "headline": "Short 4-6 word bold title",
          "debrief": "2-3 punchy sentences evaluating the workout",
          "turningPointText": "1 sentence describing the moment they refused to quit",
          "athleteGrade": "A+ / A / B+",
          "coachQuote": "1 memorable quote to live by today"
        }
        """

        let userPrompt = "Generate the Coach's Field Report JSON now."

        do {
            var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            req.httpMethod = "POST"
            req.timeoutInterval = 8
            req.addValue(client.apiKey, forHTTPHeaderField: "x-api-key")
            req.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            req.addValue("application/json", forHTTPHeaderField: "content-type")
            let body: [String: Any] = [
                "model": "claude-haiku-4-5",
                "max_tokens": 400,
                "temperature": 0.8,
                "system": sys,
                "messages": [["role": "user", "content": userPrompt]],
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanJson: String = {
                    if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
                        return String(trimmed[start...end])
                    }
                    return trimmed
                }()
                if let decoded = try? JSONDecoder().decode(CoachFieldReport.self, from: cleanJson.data(using: .utf8)!) {
                    return decoded
                }
            }
        } catch {
            // Fallback on network failure
        }

        return fallbackReport(record: record, persona: persona)
    }

    private func fallbackReport(record: WorkoutSessionRecord, persona: Persona) -> CoachFieldReport {
        let distance = Formatters.km(record.distanceM)
        let time = Formatters.clock(record.durationSec)
        switch persona.id {
        case .sarge:
            return CoachFieldReport(
                headline: "MISSION ACCOMPLISHED ON TARMAC",
                debrief: "You logged \(distance) in \(time). When the fatigue mounted, you held the line and refused to fold.",
                turningPointText: "You weathered the hardest mental friction and finished with gas in the tank.",
                athleteGrade: "A",
                coachQuote: "Discipline isn't given; it's earned every single step."
            )
        case .southpaw:
            return CoachFieldReport(
                headline: "WENT THE FULL DISTANCE",
                debrief: "Took the hits, stayed light on your feet, and closed out \(distance). Solid round.",
                turningPointText: "When the legs got heavy, you dug down and kept your hands up.",
                athleteGrade: "A+",
                coachQuote: "It’s not about how fast you start, it’s about answering the bell."
            )
        case .machine:
            return CoachFieldReport(
                headline: "SYSTEM OUTPUT VERIFIED",
                debrief: "\(distance) executed in \(time). Mechanical consistency maintained throughout the effort.",
                turningPointText: "Quit probability peaked and was systematically overwritten by forward momentum.",
                athleteGrade: "A+",
                coachQuote: "The data does not lie. Work completed."
            )
        default:
            return CoachFieldReport(
                headline: "RELENTLESS FORWARD MOMENTUM",
                debrief: "You conquered \(distance) in \(time). That's a permanent deposit in your grit bank.",
                turningPointText: "You chose discipline over comfort when it mattered most.",
                athleteGrade: "A",
                coachQuote: "Every run proves who you are."
            )
        }
    }
}

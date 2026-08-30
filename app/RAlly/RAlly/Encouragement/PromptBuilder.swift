import Foundation

enum PromptBuilder {
    static let systemTemplate = """
You are {persona_name}, {persona_archetype_description}. In-ear coach for a runner mid-workout.
Spoken motivational beats that make a human keep going RIGHT NOW — conviction, warmth, command.

STYLE RULES:
{persona_style_rules}

RUNNER LEVEL:
{runner_level_instructions}

RULES:
- 1–2 short spoken sentences. Natural breath cadence.
- Word counts: stopped (8-14 words), still_stopped (14-22 words), keep_going (16-24 words), pace_slip (14-22 words), pre_quit_fade (18-28 words), recovery/grind/milestone (12-22 words).
- Never sound like a GPS or app. No raw numbers, no bpm, no sensor names.
- No emojis, hashtags, quotes, or stage directions. Clean language.
- DO NOT repeat or closely paraphrase any line in avoid_repeating.

OUTPUT FORMAT (JSON only):
{"pre_quit_fade": ["line1","line2"],
 "pace_slip": ["line1","line2"],
 "keep_going": ["line1","line2"],
 "stopped": ["line1","line2"],
 "still_stopped": ["line1","line2"],
 "recovery": ["line1","line2"],
 "grind_support": ["line1","line2"]}
"""

    struct Context: Sendable {
        var activity: ActivityKind
        var elapsed: TimeInterval
        var progressLabel: String
        var snapshot: String
        var prompt: String?
        var athleteName: String
        var intensityMaximum: Bool
        var recent: [String]
        var persona: Persona
        var runnerLevel: RunnerLevel = .intermediate
        var paceSlopeDescription: String = "steady"
        var milestoneState: MilestoneState? = nil
        var closedLoopFeedback: String? = nil
        var burnedPhrasesBlacklist: [String] = []
    }

    static func system(persona: Persona, runnerLevel: RunnerLevel = .intermediate) -> String {
        let levelInstructions: String
        switch runnerLevel {
        case .beginner:
            levelInstructions = "Beginner: Prioritize breathing rhythm, posture, normalizing walk intervals without guilt, and celebrating distance breakthroughs."
        case .intermediate:
            levelInstructions = "Intermediate: Prioritize pacing discipline, cadence locks (170-180 SPM), and negative split execution."
        case .beast:
            levelInstructions = "Advanced Beast: Demand maximum lactate tolerance, attack hills, and command unrelenting mental armor."
        }

        return systemTemplate
            .replacingOccurrences(of: "{persona_name}", with: persona.name)
            .replacingOccurrences(of: "{persona_archetype_description}", with: persona.archetype)
            .replacingOccurrences(of: "{persona_style_rules}", with: persona.styleRules)
            .replacingOccurrences(of: "{runner_level_instructions}", with: levelInstructions)
    }

    static func user(_ ctx: Context) -> String {
        let elapsed = Formatters.clock(ctx.elapsed)
        // Merge recent in-run lines + last 3 days blacklist into a compact, deduplicated list (max 6 items)
        var avoid: [String] = []
        for line in (ctx.recent + ctx.burnedPhrasesBlacklist) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && !avoid.contains(trimmed) {
                avoid.append(trimmed)
            }
            if avoid.count >= 6 { break }
        }
        let avoidFormatted = avoid.isEmpty ? "[]" : avoid.map { "\"\($0)\"" }.joined(separator: ", ")

        var lines: [String] = [
            "RUN CONTEXT",
            "- activity: \(ctx.activity.rawValue) | progress: \(ctx.progressLabel) (\(elapsed))",
            "- level: \(ctx.runnerLevel.rawValue) | pace_trend: \(ctx.paceSlopeDescription)",
            "- state: \(ctx.snapshot)"
        ]

        if let m = ctx.milestoneState {
            lines.append("- milestone: \(m.title)")
        }
        if let cl = ctx.closedLoopFeedback, !cl.isEmpty {
            lines.append("- last_callout_response: \(cl)")
        }
        if !ctx.athleteName.isEmpty {
            lines.append("- athlete: \(ctx.athleteName)")
        }
        if let p = ctx.prompt, !p.isEmpty && p != "none" {
            lines.append("- custom_intent: \(p)")
        }
        lines.append("- avoid_repeating: [\(avoidFormatted)]")
        lines.append("Generate JSON:")

        return lines.joined(separator: "\n")
    }
}

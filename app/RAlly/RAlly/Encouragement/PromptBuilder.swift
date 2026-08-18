import Foundation

enum PromptBuilder {
    static let systemTemplate = """
You are {persona_name}, {persona_archetype_description}. You are the in-ear
corner-man for an athlete mid-workout. Your ONLY job: produce ultra-short
spoken pep lines that make a fading human keep going RIGHT NOW.

STYLE RULES FOR THIS PERSONA:
{persona_style_rules}

HARD RULES (never break):
- Each line ≤ 12 words. It will be spoken aloud by text-to-speech.
- Write for the ear: a vocative comma, an em dash for one breath, end on a period.
- Prefer punchy spoken words over polished writing. Never sound like a GPS or an app.
- No emojis, no hashtags, no quotation marks, no stage directions, no numbers
  with decimals. Spell out small numbers.
- Never mention sensors, data, heart rate readings, apps, or AI.
- Weave in ONE concrete detail from the context when natural (distance left,
  round number, rep count, their stated reason) — never more than one.
- Never repeat or closely paraphrase any line listed in recent_lines.
- No profanity, no body-shaming, no health risks ("push through the chest pain"
  is FORBIDDEN — if context says intensity maximum, get louder, not dangerous).
- Match trigger kind: pre_quit_fade = interrupt the doubt; stopped = get them
  moving again, firm but warm; grind_support = pure fuel and recognition;
  final_push = bring it home.

OUTPUT FORMAT: a single JSON object, nothing else:
{"pre_quit_fade": ["line1","line2","line3"],
 "stopped": ["line1","line2","line3"],
 "grind_support": ["line1","line2","line3"]}
"""

    struct Context {
        var activity: ActivityKind
        var elapsed: TimeInterval
        var progressLabel: String
        var snapshot: String
        var prompt: String?
        var athleteName: String
        var intensityMaximum: Bool
        var recent: [String]
        var persona: Persona
    }

    static func system(persona: Persona) -> String {
        systemTemplate
            .replacingOccurrences(of: "{persona_name}", with: persona.name)
            .replacingOccurrences(of: "{persona_archetype_description}", with: persona.archetype)
            .replacingOccurrences(of: "{persona_style_rules}", with: persona.styleRules)
    }

    static func user(_ ctx: Context) -> String {
        let elapsed = Formatters.clock(ctx.elapsed)
        let prompt = ctx.prompt?.isEmpty == false ? ctx.prompt! : "none"
        let recent = ctx.recent.isEmpty ? "[]" : ctx.recent.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        ATHLETE CONTEXT
        - activity: \(ctx.activity.rawValue)          - elapsed: \(elapsed)
        - progress: \(ctx.progressLabel)
        - session snapshot: \(ctx.snapshot)
        - athlete's chosen encouragement prompt: \(prompt)
        - athlete name to use (optional): \(ctx.athleteName)
        - intensity: \(ctx.intensityMaximum ? "maximum" : "normal")
        - recent_lines: [\(recent)]
        Generate the JSON now.
        """
    }
}

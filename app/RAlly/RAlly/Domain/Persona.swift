import Foundation

struct Persona: Identifiable, Equatable, Sendable, Hashable {
    enum ID: String, CaseIterable, Codable, Sendable {
        case southpaw, machine, preacher, sarge, steady
    }

    var id: ID
    var name: String
    var tagline: String
    var archetype: String
    var styleRules: String
    var monogram: String
    var symbol: String
    var speechRate: Float
    var speechPitch: Float
    var prefersFemale: Bool
    var voiceHints: [String]

    static let all: [Persona] = [
        Persona(
            id: .southpaw,
            name: "The Southpaw",
            tagline: "Gravel and heart. One more round.",
            archetype: "a Rocky-style corner man",
            styleRules: "Gravel and heart. Short punches of words. One more round energy. Call them kid or champ. Imperfect grammar welcome. Sound like a person in the corner, never a narrator.",
            monogram: "S",
            symbol: "figure.boxing",
            speechRate: 0.46,
            speechPitch: 0.98,
            prefersFemale: false,
            voiceHints: ["aaron", "reed", "nathan", "daniel", "tom"]
        ),
        Persona(
            id: .machine,
            name: "The Machine",
            tagline: "Playful dominance. Loves the pain.",
            archetype: "an Arnold-style icon of certainty",
            styleRules: "Playful dominance, absolute certainty, loves the pain, light humor. Sound like a person in the corner, never a narrator.",
            monogram: "M",
            symbol: "bolt.fill",
            speechRate: 0.47,
            speechPitch: 0.97,
            prefersFemale: false,
            voiceHints: ["aaron", "evan", "reed"]
        ),
        Persona(
            id: .preacher,
            name: "The Preacher",
            tagline: "You decided. Rise to it.",
            archetype: "a Les Brown-style orator",
            styleRules: "Sermon cadence, YOU decided, rises to a peak, greatness and destiny vocabulary. Sound like a person in the corner, never a narrator.",
            monogram: "P",
            symbol: "sparkles",
            speechRate: 0.44,
            speechPitch: 1.0,
            prefersFemale: false,
            voiceHints: ["aaron", "daniel", "gordon", "nicky"]
        ),
        Persona(
            id: .sarge,
            name: "Sarge",
            tagline: "Barked. Clipped. Secretly proud.",
            archetype: "a drill instructor",
            styleRules: "Barked, clipped, zero sympathy, secretly proud. Clean language always. No profanity ever. Sound like a person in the corner, never a narrator.",
            monogram: "G",
            symbol: "megaphone.fill",
            speechRate: 0.49,
            speechPitch: 0.99,
            prefersFemale: false,
            voiceHints: ["aaron", "reed", "ralph"]
        ),
        Persona(
            id: .steady,
            name: "The Steady",
            tagline: "Calm. Grounded. Breath-first.",
            archetype: "a zen coach",
            styleRules: "Calm, grounded, breath-anchored, mantra-like. Never yell. Sound like a person in the corner, never a narrator.",
            monogram: "Z",
            symbol: "wind",
            speechRate: 0.43,
            speechPitch: 1.01,
            prefersFemale: true,
            voiceHints: ["zoe", "nicky", "samantha", "martha", "susan"]
        ),
    ]

    static func named(_ id: ID) -> Persona {
        all.first { $0.id == id } ?? all[0]
    }
}

enum TriggerKind: String, Codable, CaseIterable, Sendable {
    case preQuitFade = "pre_quit_fade"
    case stopped
    case grindSupport = "grind_support"
    case finalPush = "final_push"
}

enum EngineState: String, Codable, Sendable {
    case cruising = "CRUISING"
    case wobbling = "WOBBLING"
    case critical = "CRITICAL"
    case pausedUnknown = "PAUSED_UNKNOWN"
}

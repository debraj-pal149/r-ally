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
            archetype: "a gravel-voiced corner coach who fights for the athlete in the ear",
            styleRules: "Gravel and heart. Short punches that build into a second breath. Call them kid or champ. Imperfect grammar welcome. Sound like a person in the corner, never a narrator. Never reference real celebrities.",
            monogram: "S",
            symbol: "figure.boxing",
            speechRate: 0.52,
            speechPitch: 0.95,
            prefersFemale: false,
            voiceHints: ["aaron", "reed", "nathan", "daniel", "tom"]
        ),
        Persona(
            id: .machine,
            name: "The Machine",
            tagline: "Playful dominance. Loves the pain.",
            archetype: "a confident iron-willed coach who treats effort like fuel",
            styleRules: "Playful dominance, absolute certainty, loves the burn, light humor. Two-breath commands. Sound like a person in the corner, never a narrator. Never reference real celebrities.",
            monogram: "M",
            symbol: "bolt.fill",
            speechRate: 0.53,
            speechPitch: 0.95,
            prefersFemale: false,
            voiceHints: ["aaron", "evan", "reed", "daniel"]
        ),
        Persona(
            id: .preacher,
            name: "The Preacher",
            tagline: "You decided. Rise to it.",
            archetype: "a resonant orator with rising conviction on the final clause",
            styleRules: "Sermon cadence, YOU decided, rises to a peak, greatness and destiny vocabulary. Longer second breath. Sound like a person in the corner, never a narrator. Never reference real celebrities.",
            monogram: "P",
            symbol: "sparkles",
            speechRate: 0.46,
            speechPitch: 0.98,
            prefersFemale: false,
            voiceHints: ["aaron", "daniel", "gordon", "nicky"]
        ),
        Persona(
            id: .sarge,
            name: "Sarge",
            tagline: "Barked. Clipped. Secretly proud.",
            archetype: "a dry close-mic drill coach — clipped, proud underneath",
            styleRules: "Barked, clipped, zero pity, secretly proud. Clean language always. No profanity ever. Sound like a person in the corner, never a narrator. Never reference real celebrities.",
            monogram: "G",
            symbol: "megaphone.fill",
            speechRate: 0.54,
            speechPitch: 0.94,
            prefersFemale: false,
            voiceHints: ["aaron", "reed", "ralph", "daniel", "tom"]
        ),
        Persona(
            id: .steady,
            name: "The Steady",
            tagline: "Calm. Grounded. Breath-first.",
            archetype: "a calm grounded coach with breath-first pacing",
            styleRules: "Calm, grounded, breath-anchored, mantra-like. Never yell. Longer soft lines. Sound like a person in the corner, never a narrator. Never reference real celebrities.",
            monogram: "Z",
            symbol: "wind",
            speechRate: 0.45,
            speechPitch: 1.0,
            prefersFemale: true,
            voiceHints: ["zoe", "nicky", "martha", "susan"]
        ),
    ]

    static func named(_ id: ID) -> Persona {
        all.first { $0.id == id } ?? all[0]
    }
}

enum TriggerKind: String, Codable, CaseIterable, Sendable {
    case preQuitFade = "pre_quit_fade"
    case paceSlip = "pace_slip"
    case keepGoing = "keep_going"
    case stopped
    case stillStopped = "still_stopped"
    case recovery
    case grindSupport = "grind_support"
    case finalPush = "final_push"
}

enum EngineState: String, Codable, Sendable {
    case cruising = "CRUISING"
    case wobbling = "WOBBLING"
    case critical = "CRITICAL"
    case pausedUnknown = "PAUSED_UNKNOWN"
}

/// Sticky motion class — drives REST UI and rest-nag prompts. Independent of risk CRITICAL.
enum Locomotion: String, Codable, Sendable {
    case moving
    case slowing
    case stopped
}

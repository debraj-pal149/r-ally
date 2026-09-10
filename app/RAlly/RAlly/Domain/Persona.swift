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
    var voiceId: String
    var elevenLabsVoiceId: String?

    static let all: [Persona] = [
        Persona(
            id: .sarge,
            name: "Sarge",
            tagline: "Barked. Clipped. Zero pity.",
            archetype: "a dry close-mic drill coach. Clipped, commanding authority",
            styleRules: "Barked, clipped, zero pity, intense authority. Clean language always. Sound like a drill instructor in the ear.",
            monogram: "G",
            symbol: "megaphone.fill",
            speechRate: 0.54,
            speechPitch: 0.94,
            prefersFemale: false,
            voiceHints: ["aaron", "reed", "ralph", "daniel", "tom"],
            voiceId: "a0ef13957a8442dca8139d6a345bdf66",
            elevenLabsVoiceId: "onwK4e9ZLuTAKqWW03F9"
        ),
        Persona(
            id: .southpaw,
            name: "The Southpaw",
            tagline: "Gravel and corner grit. One more round.",
            archetype: "a gravel-voiced ringside corner coach who fights for the athlete in the ear",
            styleRules: "Gravel and heart. Short punches that build into a second breath. Call them kid or champ. Imperfect grammar welcome. Sound like a person in the corner.",
            monogram: "S",
            symbol: "figure.boxing",
            speechRate: 0.52,
            speechPitch: 0.95,
            prefersFemale: false,
            voiceHints: ["aaron", "reed", "nathan", "daniel", "tom"],
            voiceId: "6b2ef1931c30417981cb1f13742496b0",
            elevenLabsVoiceId: "ErXwobaYiN019PkySvjV"
        ),
        Persona(
            id: .machine,
            name: "The Beast",
            tagline: "Pain is fuel. Crush the wall.",
            archetype: "a hardcore mental-toughness motivator who treats fatigue like fuel",
            styleRules: "Hardcore mental toughness, absolute certainty, treats fatigue like fuel. Two-breath commands. Push through the wall.",
            monogram: "M",
            symbol: "bolt.fill",
            speechRate: 0.53,
            speechPitch: 0.95,
            prefersFemale: false,
            voiceHints: ["aaron", "evan", "reed", "daniel"],
            voiceId: "ff5468d06c2443dba9b8d2f9c6aa26b0",
            elevenLabsVoiceId: "pNInz6obpgDQGcFmaJgB"
        ),
        Persona(
            id: .preacher,
            name: "The Drill Master",
            tagline: "Booming iron command. Move it now.",
            archetype: "a booming military drill master demanding immediate discipline",
            styleRules: "Booming boot-camp cadence, high authority, demands immediate discipline and high knees. Zero excuses.",
            monogram: "D",
            symbol: "shield.fill",
            speechRate: 0.50,
            speechPitch: 0.95,
            prefersFemale: false,
            voiceHints: ["aaron", "daniel", "gordon", "nicky"],
            voiceId: "bc44dad8dbab41f28afbe4092094e07c",
            elevenLabsVoiceId: "VR6AewLTigWG4xSOukaG"
        ),
        Persona(
            id: .steady,
            name: "The Gunny",
            tagline: "Gravel & grit. Hold the line.",
            archetype: "a deep gravel battlefield motivator demanding standard and focus",
            styleRules: "Deep gravel, raspy intensity, demands standard and focus through heavy fatigue.",
            monogram: "Z",
            symbol: "star.fill",
            speechRate: 0.50,
            speechPitch: 0.94,
            prefersFemale: false,
            voiceHints: ["zoe", "nicky", "martha", "susan"],
            voiceId: "9865a69980674b94b58a39daa5455cee",
            elevenLabsVoiceId: "N2lVS1w4EtoT3dr4eOWO"
        )
    ]

    static func named(_ id: ID) -> Persona {
        all.first { $0.id == id } ?? all[0]
    }
}

enum RunnerLevel: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case beast = "Advanced Beast"

    var id: String { rawValue }

    var tagline: String {
        switch self {
        case .beginner: return "Form, breathing rhythm & walk intervals"
        case .intermediate: return "Pacing discipline & cadence control"
        case .beast: return "Threshold grit & maximum output"
        }
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
    case milestone = "milestone"
}

enum EngineState: String, Codable, Sendable {
    case cruising = "CRUISING"
    case wobbling = "WOBBLING"
    case critical = "CRITICAL"
    case pausedUnknown = "PAUSED_UNKNOWN"
}

/// Sticky motion class. Drives REST UI and rest-nag prompts. Independent of risk CRITICAL.
enum Locomotion: String, Codable, Sendable {
    case moving
    case slowing
    case stopped
}

import Foundation

struct Persona: Identifiable, Equatable, Sendable, Hashable {
    enum ID: String, CaseIterable, Codable, Sendable {
        case southpaw, machine, preacher, sarge, steady
        case major, whip, hardline
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
            styleRules: "Hardcore mental toughness, absolute certainty, treats fatigue like fuel. Two-breath commands. Push through the wall. Loud and relentless.",
            monogram: "M",
            symbol: "bolt.fill",
            speechRate: 0.53,
            speechPitch: 0.95,
            prefersFemale: false,
            voiceHints: ["aaron", "evan", "reed", "daniel"],
            // Louder authoritative DI model (replaces quiet Goggins clone).
            voiceId: "c00ebfd0ef74450889a749a2c07112f0",
            // Distinct from Drill Master EL fallback.
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
            voiceHints: ["aaron", "daniel", "fred", "ralph"],
            voiceId: "9865a69980674b94b58a39daa5455cee",
            elevenLabsVoiceId: "N2lVS1w4EtoT3dr4eOWO"
        ),
        Persona(
            id: .major,
            name: "Major",
            tagline: "Tactical command. No debate.",
            archetype: "a ruthless female tactical commander who runs the ear like a war room",
            styleRules: "Clipped female command voice. Military precision, zero softness, loud when it counts. Clean language. Bark orders like a major on the line.",
            monogram: "A",
            symbol: "scope",
            speechRate: 0.54,
            speechPitch: 1.02,
            prefersFemale: true,
            voiceHints: ["samantha", "karen", "moira", "tessa", "zoe"],
            voiceId: "ebd72850e23d4fd39b52bbae76268449",
            elevenLabsVoiceId: "21m00Tcm4TlvDq8ikWAM"
        ),
        Persona(
            id: .whip,
            name: "The Whip",
            tagline: "Shouted fire. Move or get left.",
            archetype: "a screaming female sideline coach who will not let the athlete fade",
            styleRules: "Loud, sharp, shouted female intensity. Short punches. Demand motion. Clean language. Sound like a whip cracking in the ear.",
            monogram: "W",
            symbol: "flame.fill",
            speechRate: 0.55,
            speechPitch: 1.04,
            prefersFemale: true,
            voiceHints: ["samantha", "karen", "moira", "tessa"],
            voiceId: "1836740041c74e65a71d0bbadd234e73",
            elevenLabsVoiceId: "AZnzlk1XvdvUeBnXmlld"
        ),
        Persona(
            id: .hardline,
            name: "Hardline",
            tagline: "Yell it. Own it. Finish it.",
            archetype: "an aggressive female drill coach who shouts through the quit moment",
            styleRules: "Aggressive shouted female drill energy. Relentless. Clean language. Make them move with volume and conviction.",
            monogram: "H",
            symbol: "bolt.horizontal.fill",
            speechRate: 0.55,
            speechPitch: 1.03,
            prefersFemale: true,
            voiceHints: ["samantha", "karen", "moira", "zoe"],
            voiceId: "d2fd7e38733e47e7a208a1d553de76d3",
            elevenLabsVoiceId: "MF3mGyEYCl7XYWbV9V6O"
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
    /// Rotating running tip / health tip / joke while cruising.
    case engagement = "engagement"
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

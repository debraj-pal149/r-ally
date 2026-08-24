import Foundation

/// Voice engine choice — kept free of FluidAudio so Settings/AppModel compile even if SPM fails.
enum VoiceEngine: String, CaseIterable, Sendable {
    /// Best Apple male neural + energetic delivery. Fast, no model download.
    case auto
    /// On-device PocketTTS baritone coach. Distinct from Auto.
    case power
    /// Manual Apple system voice picker.
    case apple

    var chipTitle: String {
        switch self {
        case .auto: "AUTO"
        case .power: "POWER"
        case .apple: "APPLE"
        }
    }

    var blurb: String {
        switch self {
        case .auto:
            "Apple male neural · punchy coach delivery · instant"
        case .power:
            "On-device baritone coach · downloads once · offline"
        case .apple:
            "Pick any system voice yourself"
        }
    }
}

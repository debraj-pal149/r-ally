import Foundation

/// Voice engine descriptor for the cloud TTS audio pipeline.
enum VoiceEngine: String, CaseIterable, Sendable {
    case cloud = "cloud"

    var chipTitle: String {
        switch CloudTTSService.activeProvider {
        case .fishAudio: return "FISH AUDIO"
        case .elevenLabs: return "ELEVENLABS"
        case .appleFallback: return "APPLE NEURAL"
        }
    }

    var blurb: String {
        switch CloudTTSService.activeProvider {
        case .fishAudio:
            return "Fish Audio S2 ultra-realistic neural speech · instant streaming"
        case .elevenLabs:
            return "ElevenLabs Turbo v2.5 low-latency speech"
        case .appleFallback:
            return "Apple neural male coach (offline fallback)"
        }
    }
}

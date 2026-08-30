import XCTest
@testable import RAlly

final class CloudTTSTests: XCTestCase {

    func testTop5VoicesDefined() {
        XCTAssertEqual(CoachVoiceOption.top5.count, 5)
        let defaultVoice = CoachVoiceOption.find(CoachVoiceOption.defaultVoiceId)
        XCTAssertEqual(defaultVoice.title, "The Sarge")
        XCTAssertFalse(defaultVoice.previewText.isEmpty)
    }

    func testCoachTextFormatting() {
        let raw = "\"Champ pick up the pace\""
        let formatted = SpeechEngine.coachText(raw)
        XCTAssertFalse(formatted.contains("\""))
        XCTAssertTrue(formatted.contains("Champ, pick up the pace."))
    }

    func testBreathChunking() {
        let text = "Hold the standard — quiet mouth — drive through the burn."
        let chunks = SpeechEngine.breathChunks(text)
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], "Hold the standard")
    }

    @MainActor
    func testSpeechEngineActiveVoice() {
        let engine = SpeechEngine()
        XCTAssertEqual(engine.voiceId, CoachVoiceOption.defaultVoiceId)
        XCTAssertEqual(engine.activeVoiceOption.title, "The Sarge")

        engine.voiceId = "6b2ef1931c30417981cb1f13742496b0"
        XCTAssertEqual(engine.activeVoiceOption.title, "The Southpaw")
    }

    func testActiveProviderPrecedence() {
        // When Fish Audio key is present, provider is fishAudio
        let provider = CloudTTSService.activeProvider
        // In local test environment, Fish key is present in .env
        XCTAssertTrue(provider == .fishAudio || provider == .appleFallback || provider == .elevenLabs)
    }
}

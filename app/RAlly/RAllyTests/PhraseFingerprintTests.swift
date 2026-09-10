import XCTest
@testable import RAlly

final class PhraseFingerprintTests: XCTestCase {

    func testNearParaphraseDetected() {
        let a = "Hold this line and do not fold under the burn"
        let b = "Hold the line. Don't fold when it burns"
        XCTAssertGreaterThan(PhraseFingerprint.similarity(a, b), 0.30)
        XCTAssertTrue(PhraseFingerprint.isTooSimilar(b, to: [a]))
    }

    func testDistinctLinesNotRejected() {
        let a = "You've been improving. Match last run and push past it"
        let b = "Pace is slipping. Reel it back and find your earlier stride"
        XCTAssertLessThan(PhraseFingerprint.similarity(a, b), 0.35)
        XCTAssertFalse(PhraseFingerprint.isTooSimilar(b, to: [a]))
    }

    func testLeanMotifsAreShort() {
        let motifs = PhraseFingerprint.leanMotifs(from: [
            "Hold this line and stay mean kid",
            "Beautiful ugly kilometres champ eat the road"
        ], limit: 8)
        XCTAssertFalse(motifs.isEmpty)
        XCTAssertTrue(motifs.allSatisfy { $0.split(separator: " ").count <= 3 })
    }

    @MainActor
    func testLifetimeMemoryHardGateUsesFingerprints() {
        let memory = LifetimePromptMemory.shared
        memory.beginRun()
        memory.recordSpokenLine("Stay mean and keep those legs honest out here")
        XCTAssertTrue(memory.isTooSimilarToBurned("Stay mean. Keep the legs honest"))
        XCTAssertFalse(memory.isTooSimilarToBurned("Breathe easy and settle into a soft climb"))
    }

    @MainActor
    func testFallbackSkipsNearDuplicate() {
        let prior = "That's it kid. You are doing the honest work, stay mean and keep rolling forward"
        LifetimePromptMemory.shared.beginRun()
        LifetimePromptMemory.shared.recordSpokenLine(prior)
        let ctx = LineContext(
            activity: .running,
            elapsed: 400,
            distanceM: 2000,
            goal: .distance(meters: 5000),
            snapshot: "ok",
            prompt: nil,
            name: "Deb",
            intensityMaximum: false,
            recent: [prior],
            persona: Persona.named(.southpaw),
            progressLabel: "2 km",
            distanceUnit: .kilometre
        )
        // Force index toward the same southpaw keepGoing core by using matching recent count;
        // the walker should still skip the near-dupe when possible.
        let line = FallbackLines.line(kind: .keepGoing, ctx: ctx)
        XCTAssertFalse(PhraseFingerprint.isTooSimilar(line, to: [prior]), "fallback returned near-dupe: \(line)")
    }

    func testPromptIncludesAvoidMotifs() {
        let p = Persona.named(.sarge)
        let user = PromptBuilder.user(.init(
            activity: .running,
            elapsed: 200,
            progressLabel: "1 km",
            snapshot: "cruising",
            prompt: nil,
            athleteName: "Deb",
            intensityMaximum: false,
            recent: ["Drive those legs now"],
            persona: p,
            burnedPhrasesBlacklist: ["Dig deep"],
            avoidMotifs: ["hold line", "stay mean"]
        ))
        XCTAssertTrue(user.contains("avoid_motifs:"))
        XCTAssertTrue(user.contains("hold line"))
        XCTAssertTrue(user.contains("avoid_repeating:"))
    }
}

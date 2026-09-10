import XCTest
@testable import RAlly

final class CoachHistoryAndUnitsTests: XCTestCase {

    func testDistanceUnitNormalizerForcesKilometres() {
        let raw = "Beautiful ugly miles champ. Write this mile with purpose"
        let out = DistanceUnitNormalizer.normalize(raw, to: .kilometre)
        XCTAssertFalse(out.lowercased().contains("mile"))
        XCTAssertTrue(out.lowercased().contains("kilometre"))
    }

    func testDistanceUnitNormalizerForcesMiles() {
        let raw = "Hold this kilometre and eat the kilometers"
        let out = DistanceUnitNormalizer.normalize(raw, to: .mile)
        XCTAssertFalse(out.lowercased().contains("kilomet"))
        XCTAssertTrue(out.lowercased().contains("mile"))
    }

    func testDistanceUnitDetectsIndiaAsKilometres() {
        let india = Locale(identifier: "en_IN")
        XCTAssertEqual(DistanceUnit.detect(locale: india), .kilometre)
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(DistanceUnit.detect(locale: us), .mile)
    }

    func testPromptBuilderIncludesUnitRuleAndHistoryCue() {
        let p = Persona.named(.sarge)
        let sys = PromptBuilder.system(persona: p, distanceUnit: .kilometre)
        XCTAssertTrue(sys.contains("kilometre"))
        XCTAssertFalse(sys.contains("{distance_unit_rule}"))

        let user = PromptBuilder.user(.init(
            activity: .running,
            elapsed: 200,
            progressLabel: "1.0 km of 5.0 km (20%)",
            snapshot: "cruising",
            prompt: nil,
            athleteName: "Deb",
            intensityMaximum: false,
            recent: [],
            persona: p,
            runnerLevel: .intermediate,
            distanceUnit: .kilometre,
            athleteHistoryLines: ["history: 4 runs | last 2d ago | 5.00 km"],
            historyCue: "past longest-ever distance (5.00 km). Lifetime breakthrough"
        ))
        XCTAssertTrue(user.contains("history: 4 runs"))
        XCTAssertTrue(user.contains("history_cue:"))
        XCTAssertTrue(user.contains("unit: kilometre"))
    }

    @MainActor
    func testOpeningPushForNewAthlete() {
        var card = AthleteHistoryCard()
        card.isNewAthlete = true
        card.totalRuns = 0
        let line = card.openingPushLine(persona: Persona.named(.sarge), unit: .kilometre)
        XCTAssertTrue(line.lowercased().contains("first") || line.lowercased().contains("standard") || line.lowercased().contains("kilometre"))
        XCTAssertFalse(line.lowercased().contains("mile"))
    }

    @MainActor
    func testOpeningPushAfterGap() {
        var card = AthleteHistoryCard()
        card.isNewAthlete = false
        card.totalRuns = 5
        card.daysSinceLastRun = 7
        card.lastDistanceM = 4000
        card.consistency = .spaced
        card.trend = .holding
        let line = card.openingPushLine(persona: Persona.named(.sarge), unit: .kilometre)
        XCTAssertTrue(line.contains("7 days") || line.lowercased().contains("gap") || line.lowercased().contains("inconsistent"))
    }

    @MainActor
    func testGatedCuePastLongest() {
        var card = AthleteHistoryCard()
        card.isNewAthlete = false
        card.totalRuns = 6
        card.longestDistanceM = 5000
        card.previousQuitDistanceM = 4200
        let cue = card.gatedCue(
            distanceM: 5050,
            currentPaceSecPerKm: 320,
            milestone: nil,
            engineState: .cruising,
            elapsed: 1400
        )
        XCTAssertNotNil(cue)
        XCTAssertTrue(cue!.contains("longest"))
        XCTAssertTrue(card.shouldSpeakDirectly(cue!))
        let beat = card.spokenBeat(for: cue!, persona: Persona.named(.sarge), unit: .kilometre)
        XCTAssertTrue(beat.lowercased().contains("longest"))
        XCTAssertFalse(beat.lowercased().contains("mile"))
    }

    @MainActor
    func testOpeningPushImproving() {
        var card = AthleteHistoryCard()
        card.isNewAthlete = false
        card.totalRuns = 8
        card.daysSinceLastRun = 1
        card.lastDistanceM = 5000
        card.consistency = .consistent
        card.trend = .improving
        let line = card.openingPushLine(persona: Persona.named(.sarge), unit: .kilometre)
        XCTAssertTrue(line.lowercased().contains("improving"))
    }

    @MainActor
    func testGatedCueNearQuitSpeaksDirectly() {
        var card = AthleteHistoryCard()
        card.isNewAthlete = false
        card.totalRuns = 4
        card.previousQuitDistanceM = 4000
        card.longestDistanceM = 4500
        let cue = card.gatedCue(
            distanceM: 3950,
            currentPaceSecPerKm: 330,
            milestone: nil,
            engineState: .cruising,
            elapsed: 900
        )
        XCTAssertNotNil(cue)
        XCTAssertTrue(card.shouldSpeakDirectly(cue!))
        let beat = card.spokenBeat(for: cue!, persona: Persona.named(.steady), unit: .kilometre)
        XCTAssertFalse(beat.isEmpty)
    }

    @MainActor
    func testHistoryCardPersistRoundTrip() {
        var card = AthleteHistoryCard()
        card.totalRuns = 3
        card.isNewAthlete = false
        card.lastDistanceM = 5200
        card.trend = .improving
        AthleteHistoryBuilder.persist(card)
        let loaded = AthleteHistoryBuilder.loadPersisted()
        XCTAssertEqual(loaded.totalRuns, 3)
        XCTAssertEqual(loaded.trend, .improving)
        XCTAssertEqual(loaded.lastDistanceM, 5200, accuracy: 0.1)
    }

    @MainActor
    func testFallbackLineNormalizesMilesForMetric() {
        let ctx = LineContext(
            activity: .running,
            elapsed: 400,
            distanceM: 2000,
            goal: .distance(meters: 5000),
            snapshot: "ok",
            prompt: nil,
            name: "Deb",
            intensityMaximum: false,
            recent: [],
            persona: Persona.named(.southpaw),
            progressLabel: "2 km",
            distanceUnit: .kilometre
        )
        // Force a line that historically contained miles through normalizer path
        let normalized = DistanceUnitNormalizer.normalize(
            FallbackLines.line(kind: .keepGoing, ctx: ctx),
            to: .kilometre
        )
        XCTAssertFalse(normalized.lowercased().contains("mile"))
    }

    func testDashNormalizerStripsEmAndEnDashes() {
        let built = "Stay mean " + String(Character(UnicodeScalar(0x2014)!)) + " keep honest"
        let ranged = "Take 1" + String(Character(UnicodeScalar(0x2013)!)) + "2 more"
        let out = DashNormalizer.normalize(built)
        let out2 = DashNormalizer.normalize(ranged)
        XCTAssertFalse(out.contains(String(Character(UnicodeScalar(0x2014)!))))
        XCTAssertFalse(out2.contains(String(Character(UnicodeScalar(0x2013)!))))
        XCTAssertTrue(out.contains("Stay mean"))
        XCTAssertTrue(out2.contains("1-2"))
    }
}

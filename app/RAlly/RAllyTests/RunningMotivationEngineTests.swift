import XCTest
@testable import RAlly

final class RunningMotivationEngineTests: XCTestCase {

    func testMilestoneCatalogCompleteness() {
        XCTAssertEqual(MilestoneState.allCases.count, 34)
    }

    func testTelemetryTrendTrackerCalculus() {
        let tracker = TelemetryTrendTracker()
        tracker.reset()

        // Feed accelerating pace points
        tracker.recordPoint(t: 0, speedMps: 2.8, hrBpm: 140, cadenceSpm: 165, powerWatts: 220, altitudeM: 10, gradePercent: 0)
        tracker.recordPoint(t: 20, speedMps: 3.0, hrBpm: 145, cadenceSpm: 170, powerWatts: 240, altitudeM: 10, gradePercent: 0)
        tracker.recordPoint(t: 40, speedMps: 3.2, hrBpm: 148, cadenceSpm: 172, powerWatts: 250, altitudeM: 10, gradePercent: 0)
        tracker.recordPoint(t: 60, speedMps: 3.4, hrBpm: 152, cadenceSpm: 174, powerWatts: 260, altitudeM: 10, gradePercent: 0)

        let slope = tracker.paceSlope(windowSec: 60)
        XCTAssertLessThan(slope, 0, "Negative slope indicates accelerating speed/decreasing pace time")
    }

    func testTargetMilestonesTrigger() {
        let tracker = TelemetryTrendTracker()
        tracker.reset()

        // 1. Target secured at 5000m
        let milestone1 = tracker.evaluateMilestone(
            t: 1200,
            distanceM: 5010,
            targetDistanceM: 5000,
            speedMps: 3.2,
            hrBpm: 160,
            maxHR: 190,
            cadenceSpm: 174,
            powerWatts: 250,
            gradePercent: 0,
            engineState: .cruising,
            locomotion: .moving,
            lastSpokenT: 1000
        )
        XCTAssertEqual(milestone1, .targetSecured)

        // 2. Over-distance bonus at 5300m
        let milestone2 = tracker.evaluateMilestone(
            t: 1300,
            distanceM: 5350,
            targetDistanceM: 5000,
            speedMps: 3.2,
            hrBpm: 162,
            maxHR: 190,
            cadenceSpm: 174,
            powerWatts: 250,
            gradePercent: 0,
            engineState: .cruising,
            locomotion: .moving,
            lastSpokenT: 1200
        )
        XCTAssertEqual(milestone2, .overDistanceBonus)
    }

    func testClosedLoopInterventionEvaluation() {
        let tracker = TelemetryTrendTracker()
        tracker.reset()

        // Record coach callout at t=100 with pace 360 s/km (6:00 /km)
        tracker.recordIntervention(
            t: 100,
            line: "Pick it up champ!",
            trigger: .paceSlip,
            milestone: nil,
            currentPace: 360,
            cadence: 168,
            hr: 155
        )

        // Runner responds at t=130 with pace 340 s/km (5:40 /km -> 20s faster)
        let evaluated = tracker.evaluatePendingInterventions(currentT: 130, currentPace: 340)
        XCTAssertNotNil(evaluated)
        XCTAssertEqual(evaluated?.result, .surged)
        XCTAssertNotNil(tracker.lastClosedLoopDescription)
        XCTAssertTrue(tracker.lastClosedLoopDescription!.contains("surged"))
    }

    @MainActor
    func testLifetimePromptMemoryAntiRepetition() {
        let memory = LifetimePromptMemory.shared
        let testPhrase = "Hold this line and do not fold!"
        memory.recordSpokenLine(testPhrase)

        XCTAssertTrue(memory.isTooSimilarToBurned(testPhrase))
        XCTAssertTrue(memory.isTooSimilarToBurned("Hold this line"))
        XCTAssertTrue(memory.dynamicBlacklist.contains(testPhrase))
    }

    func testPromptBuilderWithContextVector() {
        let persona = Persona.named(.sarge)
        let ctx = PromptBuilder.Context(
            activity: .running,
            elapsed: 600,
            progressLabel: "3.2 km of 5.0 km (64%)",
            snapshot: "holding steady",
            prompt: "none",
            athleteName: "Alex",
            intensityMaximum: false,
            recent: ["Keep your eyes up."],
            persona: persona,
            runnerLevel: .beast,
            paceSlopeDescription: "surging and accelerating faster",
            milestoneState: .thePainCaveEntry,
            closedLoopFeedback: "Surged 12s/km after last callout",
            burnedPhrasesBlacklist: ["Dig deep."]
        )

        let prompt = PromptBuilder.user(ctx)
        XCTAssertTrue(prompt.contains("Advanced Beast"))
        XCTAssertTrue(prompt.contains("Entering The Pain Cave"))
        XCTAssertTrue(prompt.contains("Surged 12s/km after last callout"))
        XCTAssertTrue(prompt.contains("Dig deep."))
    }

    @MainActor
    func testCoachReportGeneratorFallback() async {
        let record = WorkoutSessionRecord(
            startedAt: Date().addingTimeInterval(-1800),
            endedAt: Date(),
            activityRaw: "running",
            durationSec: 1800,
            distanceM: 5200,
            avgHR: 158,
            rallyCount: 2,
            outputSpark: [1.0, 1.2, 0.8, 1.1],
            rallies: [],
            personaRaw: Persona.ID.sarge.rawValue,
            finishedAfterCritical: true
        )

        let report = await CoachReportGenerator.shared.generateReport(
            record: record,
            persona: Persona.named(.sarge),
            runnerLevel: .beast,
            client: AnthropicClient(apiKey: "")
        )

        XCTAssertFalse(report.headline.isEmpty)
        XCTAssertFalse(report.debrief.isEmpty)
        XCTAssertFalse(report.coachQuote.isEmpty)
    }
}

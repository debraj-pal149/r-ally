import XCTest
@testable import RAlly

final class AnalyticsAndPBsTests: XCTestCase {

    // MARK: - GAP (Grade-Adjusted Pace) Tests

    func testGradeAdjustedPaceCalculations() {
        // Flat ground (0% grade) should have cost ratio == 1.0 and GAP == raw pace
        let flatCost = GradeAdjustedCalculator.costRatio(gradePercent: 0)
        XCTAssertEqual(flatCost, 1.0, accuracy: 0.05)
        let flatGAP = GradeAdjustedCalculator.gradeAdjustedPace(rawPaceSecPerKm: 300, gradePercent: 0)
        XCTAssertEqual(flatGAP, 300, accuracy: 1.0)

        // Uphill (+6% grade) makes equivalent flat pace faster (lower seconds)
        let uphillCost = GradeAdjustedCalculator.costRatio(gradePercent: 6.0)
        XCTAssertGreaterThan(uphillCost, 1.2)
        let uphillGAP = GradeAdjustedCalculator.gradeAdjustedPace(rawPaceSecPerKm: 360, gradePercent: 6.0) // 6:00 /km uphill
        XCTAssertLessThan(uphillGAP, 320) // Equivalent to < 5:20 /km on flat

        // Downhill (-5% grade) makes equivalent flat pace slower (higher seconds)
        let downhillCost = GradeAdjustedCalculator.costRatio(gradePercent: -5.0)
        XCTAssertLessThan(downhillCost, 1.0)
        let downhillGAP = GradeAdjustedCalculator.gradeAdjustedPace(rawPaceSecPerKm: 300, gradePercent: -5.0)
        XCTAssertGreaterThan(downhillGAP, 300)
    }

    // MARK: - Periodic 1-Kilometer Split Engine Tests

    func testPeriodicSplitEngineAnnouncements() {
        let engine = PeriodicSplitEngine()
        engine.reset()

        // Before 1KM, no split announcement
        let line0 = engine.checkKilometerSplit(
            currentDistanceM: 850,
            currentElapsedT: 250,
            persona: Persona.named(.sarge),
            currentPaceSecPerKm: 300
        )
        XCTAssertNil(line0)

        // Crossing 1KM mark
        let line1 = engine.checkKilometerSplit(
            currentDistanceM: 1050,
            currentElapsedT: 312,
            persona: Persona.named(.sarge),
            currentPaceSecPerKm: 300
        )
        XCTAssertNotNil(line1)
        XCTAssertTrue(line1!.contains("Kilometre 1") || line1!.contains("Kilometer 1"))
        XCTAssertTrue(line1!.contains("5:12"))

        // Still in KM 1, should not repeat
        let line1Repeat = engine.checkKilometerSplit(
            currentDistanceM: 1400,
            currentElapsedT: 420,
            persona: Persona.named(.sarge),
            currentPaceSecPerKm: 300
        )
        XCTAssertNil(line1Repeat)

        // Crossing KM 2
        let line2 = engine.checkKilometerSplit(
            currentDistanceM: 2050,
            currentElapsedT: 600,
            persona: Persona.named(.southpaw),
            currentPaceSecPerKm: 288
        )
        XCTAssertNotNil(line2)
        XCTAssertTrue(line2!.contains("Round 2"))
    }

    // MARK: - Lifetime Personal Bests Store Tests

    @MainActor
    func testPersonalBestStoreEvaluation() {
        let store = PersonalBestStore()
        store.reset()

        // Five ~1 km splits → real consecutive 5K (not average-pace scaled).
        let splits: [LapSplitRecord] = (1...5).map { n in
            LapSplitRecord(
                splitNumber: n,
                distanceM: 1000,
                durationSec: n == 2 ? 260 : 280,
                paceSecPerKm: n == 2 ? 260 : 280,
                gapPaceSecPerKm: n == 2 ? 260 : 280
            )
        }

        let newPBs = store.evaluateSession(
            distanceM: 5200,
            durationSec: 1400,
            elevationGainM: 45,
            splits: splits
        )

        XCTAssertFalse(newPBs.isEmpty)
        let kinds = newPBs.map(\.kind)
        XCTAssertTrue(kinds.contains(.longestRun))
        XCTAssertTrue(kinds.contains(.maxElevation))
        XCTAssertTrue(kinds.contains(.fastest1K))
        XCTAssertTrue(kinds.contains(.fastest5K))
        // Sum of the five split durations — not (1400/5200)*5000.
        XCTAssertEqual(store.records[.fastest5K]?.recordValue, 280 + 260 + 280 + 280 + 280)

        // Without 5 consecutive km splits, no 5K PB even if distance ≥ 5 km.
        store.reset()
        let shortSplits = [
            LapSplitRecord(splitNumber: 1, distanceM: 1000, durationSec: 280, paceSecPerKm: 280, gapPaceSecPerKm: 280),
            LapSplitRecord(splitNumber: 2, distanceM: 1000, durationSec: 260, paceSecPerKm: 260, gapPaceSecPerKm: 260),
        ]
        let noFive = store.evaluateSession(distanceM: 5200, durationSec: 1400, elevationGainM: 45, splits: shortSplits)
        XCTAssertFalse(noFive.map(\.kind).contains(.fastest5K))

        // 7 km: fastest 5K is the best of km 1–5 / 2–6 / 3–7, not a scaled average.
        store.reset()
        let seven: [LapSplitRecord] = (1...7).map { n in
            let dur: Double = n <= 5 ? 300 - Double(n) * 4 : 400
            return LapSplitRecord(splitNumber: n, distanceM: 1000, durationSec: dur, paceSecPerKm: dur, gapPaceSecPerKm: dur)
        }
        _ = store.evaluateSession(distanceM: 7000, durationSec: 2400, elevationGainM: 20, splits: seven)
        let expected = seven.prefix(5).reduce(0.0) { $0 + $1.durationSec }
        XCTAssertEqual(store.records[.fastest5K]?.recordValue, expected)

        // A glitch lap in the middle must not join km 2 and km 4 as "consecutive".
        store.reset()
        var glitchy = (1...5).map { n in
            LapSplitRecord(splitNumber: n, distanceM: 1000, durationSec: 280, paceSecPerKm: 280, gapPaceSecPerKm: 280)
        }
        glitchy.insert(
            LapSplitRecord(splitNumber: 3, distanceM: 1000, durationSec: 20, paceSecPerKm: 20, gapPaceSecPerKm: 20),
            at: 2
        )
        let glitchPBs = store.evaluateSession(distanceM: 6000, durationSec: 1500, elevationGainM: 20, splits: glitchy)
        XCTAssertFalse(glitchPBs.map(\.kind).contains(.fastest5K))
    }

    // MARK: - Telemetry HR Zones & Breadcrumb Tests

    func testTelemetryAnalyticsAggregation() {
        let tracker = TelemetryTrendTracker()
        tracker.reset()

        // Record 10 minutes of steady running
        for i in 0..<60 {
            let t = Double(i) * 10.0 // 0 to 600 seconds
            tracker.recordPoint(
                t: t,
                speedMps: 3.33, // ~5:00 /km
                hrBpm: 155,
                maxHR: 190,
                cadenceSpm: 175,
                powerWatts: 260,
                altitudeM: 50.0 + Double(i) * 0.5,
                gradePercent: 2.0,
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001,
                cumulativeDistanceM: Double(i) * 33.3
            )
        }

        XCTAssertGreaterThan(tracker.totalElevationGainM, 5.0)
        XCTAssertGreaterThan(tracker.breadcrumbs.count, 5)

        let zones = tracker.computeHRZones(maxHR: 190)
        XCTAssertEqual(zones.count, 5)
        // 155 BPM / 190 = 81.5% => Zone 4 (Threshold)
        let z4 = zones.first(where: { $0.zoneIndex == 4 })
        XCTAssertNotNil(z4)
        XCTAssertGreaterThan(z4!.percentage, 80)
    }
}

import XCTest
@testable import RAlly

final class SyncCodecTests: XCTestCase {
    func testOutboxDedupesByIdKeepingNewer() async {
        await MainActor.run {
            SyncOutbox.shared.removeAll()
            let older = SyncOutboxItem(
                entity: .workout,
                entityId: "A",
                op: .upsert,
                updatedAt: Date(timeIntervalSince1970: 100)
            )
            let newer = SyncOutboxItem(
                entity: .workout,
                entityId: "A",
                op: .upsert,
                updatedAt: Date(timeIntervalSince1970: 200)
            )
            SyncOutbox.shared.enqueue(older)
            SyncOutbox.shared.enqueue(newer)
            XCTAssertEqual(SyncOutbox.shared.items.count, 1)
            XCTAssertEqual(SyncOutbox.shared.items[0].updatedAt.timeIntervalSince1970, 200)
            SyncOutbox.shared.removeAll()
        }
    }

    func testHistoryExportRoundTripDatesAsStrings() throws {
        let doc = HistoryExportDocument(
            exportedAt: "2026-11-01T00:00:00Z",
            schemaVersion: 1,
            profile: HistoryExportProfile(
                name: "Deb",
                age: 32,
                bodyWeightKg: 70,
                personaRaw: "sarge",
                runnerLevel: "intermediate"
            ),
            workouts: [],
            personalBests: []
        )
        let data = try HistoryExport.encode(doc)
        let decoded = try JSONDecoder().decode(HistoryExportDocument.self, from: data)
        XCTAssertEqual(decoded.profile.name, "Deb")
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertTrue(String(data: data, encoding: .utf8)?.contains("2026-11-01") == true)
    }

    func testWorkoutEncodeContainsRouteAndMomentsKeys() {
        let moment = RallyMomentRecord(t: 12, kindRaw: "rally", text: "Go", aftermath: "held")
        let workout = WorkoutSessionRecord(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_001_800),
            activityRaw: "running",
            durationSec: 1800,
            distanceM: 5000,
            avgHR: 150,
            rallyCount: 1,
            outputSpark: [0.2, 0.4],
            rallies: [moment],
            personaRaw: "sarge",
            finishedAfterCritical: false,
            routeCoordinates: [
                GPSBreadcrumb(
                    latitude: 12.9,
                    longitude: 77.6,
                    altitudeM: 900,
                    speedMps: 3,
                    paceSecPerKm: 330,
                    timestamp: 0
                )
            ]
        )
        workout.updatedAt = Date(timeIntervalSince1970: 1_700_001_800)
        let data = CloudCodec.encodeWorkout(workout)
        XCTAssertEqual(data["id"] as? String, workout.id.uuidString)
        XCTAssertNotNil(data["moments"])
        // Precise GPS must not leave the phone via sync.
        let routes = data["routeCoordinates"] as? [Any] ?? ["missing"]
        XCTAssertTrue(routes.isEmpty)
        XCTAssertEqual(data["distanceM"] as? Double, 5000)

        // Empty cloud route must not wipe a local track.
        let local = WorkoutSessionRecord(
            id: workout.id,
            startedAt: workout.startedAt,
            endedAt: workout.endedAt,
            activityRaw: workout.activityRaw,
            durationSec: workout.durationSec,
            distanceM: workout.distanceM,
            avgHR: workout.avgHR,
            rallyCount: workout.rallyCount,
            outputSpark: workout.outputSpark,
            rallies: [],
            personaRaw: workout.personaRaw,
            finishedAfterCritical: false,
            routeCoordinates: workout.routeCoordinates
        )
        let applied = CloudCodec.applyWorkout(data: data, onto: local)
        XCTAssertEqual(applied?.routeCoordinates.count, 1)
    }
}

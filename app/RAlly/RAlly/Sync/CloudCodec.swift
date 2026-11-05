import Foundation
@preconcurrency import FirebaseFirestore

enum CloudCodec {
    static let schemaVersion = AccountKeys.schemaVersion

    // MARK: - Profile

    static func encodeProfile(
        name: String,
        age: Int,
        bodyWeightKg: Double?,
        hrMaxOverride: Double?,
        thresholdPace: Double,
        personaRaw: String,
        runnerLevel: String,
        voiceId: String,
        sessionCap: Int,
        appearance: String,
        distanceUnit: String,
        displayName: String?,
        email: String?,
        providers: [String],
        updatedAt: Date
    ) -> [String: Any] {
        var data: [String: Any] = [
            "schemaVersion": schemaVersion,
            "name": name,
            "age": age,
            "thresholdPace": thresholdPace,
            "personaRaw": personaRaw,
            "runnerLevel": runnerLevel,
            "voiceId": voiceId,
            "sessionCap": sessionCap,
            "appearance": appearance,
            "distanceUnit": distanceUnit,
            "providers": providers,
            "updatedAt": Timestamp(date: updatedAt),
        ]
        if let bodyWeightKg { data["bodyWeightKg"] = bodyWeightKg }
        if let hrMaxOverride { data["hrMaxOverride"] = hrMaxOverride }
        if let displayName { data["displayName"] = displayName }
        if let email { data["email"] = email }
        return data
    }

    static func decodeProfileUpdatedAt(_ data: [String: Any]) -> Date {
        (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
    }

    // MARK: - Workout

    static func encodeWorkout(_ record: WorkoutSessionRecord) -> [String: Any] {
        let moments: [[String: Any]] = record.rallies.map { m in
            [
                "id": m.id.uuidString,
                "t": m.t,
                "kindRaw": m.kindRaw,
                "text": m.text,
                "aftermath": m.aftermath,
            ]
        }
        var data: [String: Any] = [
            "schemaVersion": schemaVersion,
            "id": record.id.uuidString,
            "startedAt": Timestamp(date: record.startedAt),
            "endedAt": Timestamp(date: record.endedAt),
            "activityRaw": record.activityRaw,
            "durationSec": record.durationSec,
            "distanceM": record.distanceM,
            "rallyCount": record.rallyCount,
            "outputSpark": record.outputSpark,
            "personaRaw": record.personaRaw,
            "finishedAfterCritical": record.finishedAfterCritical,
            "elevationGainM": record.elevationGainM,
            "elevationLossM": record.elevationLossM,
            "movingDurationSec": record.movingDurationSec,
            "activeEnergyKcal": record.activeEnergyKcal,
            "moments": moments,
            "splits": encodeJSONArray(record.splits),
            "hrZones": encodeJSONArray(record.hrZones),
            // Precise GPS stays on-device. Cloud sync carries stats/moments only.
            "routeCoordinates": [] as [Any],
            "personalBests": encodeJSONArray(record.personalBests),
            "updatedAt": Timestamp(date: record.updatedAt),
        ]
        if let avgHR = record.avgHR { data["avgHR"] = avgHR }
        if let gap = record.gapAveragePaceSecPerKm { data["gapAveragePaceSecPerKm"] = gap }
        if let reportHeadline = record.reportHeadline { data["reportHeadline"] = reportHeadline }
        if let reportDebrief = record.reportDebrief { data["reportDebrief"] = reportDebrief }
        if let reportQuote = record.reportQuote { data["reportQuote"] = reportQuote }
        if let reportGrade = record.reportGrade { data["reportGrade"] = reportGrade }
        if let ownerUid = record.ownerUid { data["ownerUid"] = ownerUid }
        if let deletedAt = record.deletedAt {
            data["deletedAt"] = Timestamp(date: deletedAt)
        } else {
            data["deletedAt"] = NSNull()
        }
        return data
    }

    static func applyWorkout(data: [String: Any], onto existing: WorkoutSessionRecord?) -> WorkoutSessionRecord? {
        guard let idString = data["id"] as? String, let id = UUID(uuidString: idString) else { return nil }
        let startedAt = (data["startedAt"] as? Timestamp)?.dateValue() ?? Date()
        let endedAt = (data["endedAt"] as? Timestamp)?.dateValue() ?? startedAt
        let record = existing ?? WorkoutSessionRecord(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            activityRaw: data["activityRaw"] as? String ?? ActivityKind.running.rawValue,
            durationSec: data["durationSec"] as? Double ?? 0,
            distanceM: data["distanceM"] as? Double ?? 0,
            avgHR: data["avgHR"] as? Double,
            rallyCount: data["rallyCount"] as? Int ?? 0,
            outputSpark: data["outputSpark"] as? [Double] ?? [],
            personaRaw: data["personaRaw"] as? String ?? Persona.ID.sarge.rawValue,
            finishedAfterCritical: data["finishedAfterCritical"] as? Bool ?? false
        )
        record.id = id
        record.startedAt = startedAt
        record.endedAt = endedAt
        record.activityRaw = data["activityRaw"] as? String ?? record.activityRaw
        record.durationSec = data["durationSec"] as? Double ?? record.durationSec
        record.distanceM = data["distanceM"] as? Double ?? record.distanceM
        record.avgHR = data["avgHR"] as? Double
        record.rallyCount = data["rallyCount"] as? Int ?? record.rallyCount
        record.outputSpark = data["outputSpark"] as? [Double] ?? record.outputSpark
        record.personaRaw = data["personaRaw"] as? String ?? record.personaRaw
        record.finishedAfterCritical = data["finishedAfterCritical"] as? Bool ?? record.finishedAfterCritical
        record.elevationGainM = data["elevationGainM"] as? Double ?? 0
        record.elevationLossM = data["elevationLossM"] as? Double ?? 0
        record.movingDurationSec = data["movingDurationSec"] as? Double ?? 0
        record.gapAveragePaceSecPerKm = data["gapAveragePaceSecPerKm"] as? Double
        record.activeEnergyKcal = data["activeEnergyKcal"] as? Double ?? 0
        record.reportHeadline = data["reportHeadline"] as? String
        record.reportDebrief = data["reportDebrief"] as? String
        record.reportQuote = data["reportQuote"] as? String
        record.reportGrade = data["reportGrade"] as? String
        record.ownerUid = data["ownerUid"] as? String
        record.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        if data["deletedAt"] is NSNull {
            record.deletedAt = nil
        } else {
            record.deletedAt = (data["deletedAt"] as? Timestamp)?.dateValue()
        }

        if let splits: [LapSplitRecord] = decodeJSONArray(data["splits"]) {
            record.splitsData = try? JSONEncoder().encode(splits)
        }
        if let zones: [HRZoneBucket] = decodeJSONArray(data["hrZones"]) {
            record.hrZonesData = try? JSONEncoder().encode(zones)
        }
        // Never blank a local GPS track with an empty cloud payload.
        if let route: [GPSBreadcrumb] = decodeJSONArray(data["routeCoordinates"]), !route.isEmpty {
            record.routeCoordinatesData = try? JSONEncoder().encode(route)
        }
        if let pbs: [PersonalBestAchievement] = decodeJSONArray(data["personalBests"]) {
            record.personalBestsData = try? JSONEncoder().encode(pbs)
        }

        let momentsData = data["moments"] as? [[String: Any]] ?? []
        let rebuilt: [RallyMomentRecord] = momentsData.compactMap { m in
            guard let text = m["text"] as? String else { return nil }
            let moment = RallyMomentRecord(
                t: m["t"] as? Double ?? 0,
                kindRaw: m["kindRaw"] as? String ?? "",
                text: text,
                aftermath: m["aftermath"] as? String ?? ""
            )
            if let mid = m["id"] as? String, let uuid = UUID(uuidString: mid) {
                moment.id = uuid
            }
            return moment
        }
        record.rallies = rebuilt
        return record
    }

    // MARK: - Personal bests

    static func encodePersonalBests(_ badges: [PersonalBestAchievement], updatedAt: Date) -> [String: Any] {
        [
            "schemaVersion": schemaVersion,
            "updatedAt": Timestamp(date: updatedAt),
            "items": encodeJSONArray(badges),
        ]
    }

    static func decodePersonalBests(_ data: [String: Any]) -> (items: [PersonalBestAchievement], updatedAt: Date)? {
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
        let items: [PersonalBestAchievement] = decodeJSONArray(data["items"]) ?? []
        return (items, updatedAt)
    }

    // MARK: - Helpers

    private static func encodeJSONArray<T: Encodable>(_ value: [T]) -> Any {
        guard let data = try? JSONEncoder().encode(value),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }
        return obj
    }

    private static func decodeJSONArray<T: Decodable>(_ value: Any?) -> [T]? {
        guard let value, JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value) else {
            return nil
        }
        return try? JSONDecoder().decode([T].self, from: data)
    }
}

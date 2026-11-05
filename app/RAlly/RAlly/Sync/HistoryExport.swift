import Foundation

struct HistoryExportDocument: Codable, Sendable {
    var exportedAt: String
    var schemaVersion: Int
    var profile: HistoryExportProfile
    var workouts: [HistoryExportWorkout]
    var personalBests: [HistoryExportPB]
}

struct HistoryExportProfile: Codable, Sendable {
    var name: String
    var age: Int
    var bodyWeightKg: Double?
    var personaRaw: String
    var runnerLevel: String
}

struct HistoryExportWorkout: Codable, Sendable {
    var id: String
    var startedAt: String
    var endedAt: String
    var activityRaw: String
    var durationSec: Double
    var distanceM: Double
    var avgHR: Double?
    var rallyCount: Int
    var personaRaw: String
    var elevationGainM: Double
    var activeEnergyKcal: Double
    var reportHeadline: String?
    var reportGrade: String?
    var deletedAt: String?
    var moments: [HistoryExportMoment]
}

struct HistoryExportMoment: Codable, Sendable {
    var id: String
    var t: Double
    var kindRaw: String
    var text: String
    var aftermath: String
}

struct HistoryExportPB: Codable, Sendable {
    var kind: String
    var title: String
    var recordValue: Double
    var formattedValue: String
    var achievedDate: String
}

enum HistoryExport {
    private static func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    @MainActor
    static func makeDocument(
        workouts: [WorkoutSessionRecord],
        personalBests: [PersonalBestAchievement],
        name: String = UserDefaults.standard.string(forKey: "athlete.name") ?? "",
        age: Int = UserDefaults.standard.object(forKey: "athlete.age") as? Int ?? 0,
        bodyWeightKg: Double? = UserDefaults.standard.object(forKey: "athlete.weightKg") as? Double,
        personaRaw: String = UserDefaults.standard.string(forKey: "athlete.persona") ?? "",
        runnerLevel: String = UserDefaults.standard.string(forKey: "athlete.runnerLevel") ?? ""
    ) -> HistoryExportDocument {
        HistoryExportDocument(
            exportedAt: isoString(Date()),
            schemaVersion: AccountKeys.schemaVersion,
            profile: HistoryExportProfile(
                name: name,
                age: age,
                bodyWeightKg: bodyWeightKg,
                personaRaw: personaRaw,
                runnerLevel: runnerLevel
            ),
            workouts: workouts.map { w in
                HistoryExportWorkout(
                    id: w.id.uuidString,
                    startedAt: isoString(w.startedAt),
                    endedAt: isoString(w.endedAt),
                    activityRaw: w.activityRaw,
                    durationSec: w.durationSec,
                    distanceM: w.distanceM,
                    avgHR: w.avgHR,
                    rallyCount: w.rallyCount,
                    personaRaw: w.personaRaw,
                    elevationGainM: w.elevationGainM,
                    activeEnergyKcal: w.activeEnergyKcal,
                    reportHeadline: w.reportHeadline,
                    reportGrade: w.reportGrade,
                    deletedAt: w.deletedAt.map(isoString),
                    moments: w.rallies.map {
                        HistoryExportMoment(
                            id: $0.id.uuidString,
                            t: $0.t,
                            kindRaw: $0.kindRaw,
                            text: $0.text,
                            aftermath: $0.aftermath
                        )
                    }
                )
            },
            personalBests: personalBests.map {
                HistoryExportPB(
                    kind: $0.kind.rawValue,
                    title: $0.title,
                    recordValue: $0.recordValue,
                    formattedValue: $0.formattedValue,
                    achievedDate: isoString($0.achievedDate)
                )
            }
        )
    }

    static func encode(_ doc: HistoryExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(doc)
    }
}

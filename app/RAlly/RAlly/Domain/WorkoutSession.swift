import Foundation
import SwiftData

@Model
final class WorkoutSessionRecord {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var activityRaw: String
    var durationSec: Double
    var distanceM: Double
    var avgHR: Double?
    var rallyCount: Int
    var outputSpark: [Double]
    var rallies: [RallyMomentRecord]
    var personaRaw: String
    var finishedAfterCritical: Bool

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        activityRaw: String,
        durationSec: Double,
        distanceM: Double,
        avgHR: Double?,
        rallyCount: Int,
        outputSpark: [Double],
        rallies: [RallyMomentRecord],
        personaRaw: String,
        finishedAfterCritical: Bool
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.activityRaw = activityRaw
        self.durationSec = durationSec
        self.distanceM = distanceM
        self.avgHR = avgHR
        self.rallyCount = rallyCount
        self.outputSpark = outputSpark
        self.rallies = rallies
        self.personaRaw = personaRaw
        self.finishedAfterCritical = finishedAfterCritical
    }

    var activity: ActivityKind { ActivityKind(rawValue: activityRaw) ?? .running }
}

@Model
final class RallyMomentRecord {
    var id: UUID
    var t: Double
    var kindRaw: String
    var text: String
    var aftermath: String

    init(t: Double, kindRaw: String, text: String, aftermath: String) {
        self.id = UUID()
        self.t = t
        self.kindRaw = kindRaw
        self.text = text
        self.aftermath = aftermath
    }
}

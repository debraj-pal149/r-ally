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
    var personaRaw: String
    var finishedAfterCritical: Bool

    // Enhanced Analytics Properties
    var elevationGainM: Double = 0
    var elevationLossM: Double = 0
    var movingDurationSec: Double = 0
    var gapAveragePaceSecPerKm: Double?
    var splitsData: Data?
    var hrZonesData: Data?
    var routeCoordinatesData: Data?
    var personalBestsData: Data?

    // Coach's Field Report data
    var reportHeadline: String?
    var reportDebrief: String?
    var reportQuote: String?
    var reportGrade: String?

    @Relationship(deleteRule: .cascade)
    var rallies: [RallyMomentRecord] = []

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
        rallies: [RallyMomentRecord] = [],
        personaRaw: String,
        finishedAfterCritical: Bool,
        elevationGainM: Double = 0,
        elevationLossM: Double = 0,
        movingDurationSec: Double = 0,
        gapAveragePaceSecPerKm: Double? = nil,
        splits: [LapSplitRecord] = [],
        hrZones: [HRZoneBucket] = [],
        routeCoordinates: [GPSBreadcrumb] = [],
        personalBests: [PersonalBestAchievement] = [],
        reportHeadline: String? = nil,
        reportDebrief: String? = nil,
        reportQuote: String? = nil,
        reportGrade: String? = nil
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
        self.elevationGainM = elevationGainM
        self.elevationLossM = elevationLossM
        self.movingDurationSec = movingDurationSec
        self.gapAveragePaceSecPerKm = gapAveragePaceSecPerKm
        self.reportHeadline = reportHeadline
        self.reportDebrief = reportDebrief
        self.reportQuote = reportQuote
        self.reportGrade = reportGrade

        self.splitsData = try? JSONEncoder().encode(splits)
        self.hrZonesData = try? JSONEncoder().encode(hrZones)
        self.routeCoordinatesData = try? JSONEncoder().encode(routeCoordinates)
        self.personalBestsData = try? JSONEncoder().encode(personalBests)
    }

    var activity: ActivityKind { ActivityKind(rawValue: activityRaw) ?? .running }

    var splits: [LapSplitRecord] {
        guard let data = splitsData else { return [] }
        return (try? JSONDecoder().decode([LapSplitRecord].self, from: data)) ?? []
    }

    var hrZones: [HRZoneBucket] {
        guard let data = hrZonesData else { return [] }
        return (try? JSONDecoder().decode([HRZoneBucket].self, from: data)) ?? []
    }

    var routeCoordinates: [GPSBreadcrumb] {
        guard let data = routeCoordinatesData else { return [] }
        return (try? JSONDecoder().decode([GPSBreadcrumb].self, from: data)) ?? []
    }

    var personalBests: [PersonalBestAchievement] {
        guard let data = personalBestsData else { return [] }
        return (try? JSONDecoder().decode([PersonalBestAchievement].self, from: data)) ?? []
    }
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

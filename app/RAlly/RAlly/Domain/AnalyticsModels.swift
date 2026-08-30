import Foundation

// MARK: - GPS Breadcrumb for Route Map
public struct GPSBreadcrumb: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var latitude: Double
    public var longitude: Double
    public var altitudeM: Double
    public var speedMps: Double
    public var paceSecPerKm: Double
    public var timestamp: Double

    public init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitudeM: Double,
        speedMps: Double,
        paceSecPerKm: Double,
        timestamp: Double
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeM = altitudeM
        self.speedMps = speedMps
        self.paceSecPerKm = paceSecPerKm
        self.timestamp = timestamp
    }
}

// MARK: - 1-Kilometer Lap Split Record
public struct LapSplitRecord: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var splitNumber: Int
    public var distanceM: Double
    public var durationSec: Double
    public var paceSecPerKm: Double
    public var gapPaceSecPerKm: Double
    public var avgHR: Double?
    public var avgCadence: Double?
    public var elevationDeltaM: Double

    public init(
        id: UUID = UUID(),
        splitNumber: Int,
        distanceM: Double,
        durationSec: Double,
        paceSecPerKm: Double,
        gapPaceSecPerKm: Double,
        avgHR: Double? = nil,
        avgCadence: Double? = nil,
        elevationDeltaM: Double = 0
    ) {
        self.id = id
        self.splitNumber = splitNumber
        self.distanceM = distanceM
        self.durationSec = durationSec
        self.paceSecPerKm = paceSecPerKm
        self.gapPaceSecPerKm = gapPaceSecPerKm
        self.avgHR = avgHR
        self.avgCadence = avgCadence
        self.elevationDeltaM = elevationDeltaM
    }
}

// MARK: - Heart Rate Zone Distribution Bucket
public struct HRZoneBucket: Codable, Sendable, Identifiable, Equatable {
    public var id: Int { zoneIndex }
    public var zoneIndex: Int           // 1 to 5
    public var name: String             // "Recovery", "Aerobic", "Tempo", "Threshold", "Anaerobic"
    public var rangeBpm: String         // e.g. "115 - 134 bpm"
    public var durationSec: Double      // seconds spent in this zone
    public var percentage: Double       // 0.0 to 100.0

    public init(zoneIndex: Int, name: String, rangeBpm: String, durationSec: Double, percentage: Double) {
        self.zoneIndex = zoneIndex
        self.name = name
        self.rangeBpm = rangeBpm
        self.durationSec = durationSec
        self.percentage = percentage
    }
}

// MARK: - Personal Best Achievement Badge
public struct PersonalBestAchievement: Codable, Sendable, Identifiable, Equatable {
    public var id: String { kind.rawValue }
    public var kind: PBKind
    public var title: String
    public var recordValue: Double      // seconds for time, meters for distance
    public var formattedValue: String
    public var achievedDate: Date

    public enum PBKind: String, Codable, CaseIterable, Sendable {
        case fastest1K = "fastest_1k"
        case fastest1Mile = "fastest_1mile"
        case fastest5K = "fastest_5k"
        case fastest10K = "fastest_10k"
        case longestRun = "longest_run"
        case maxElevation = "max_elevation"
    }

    public init(kind: PBKind, title: String, recordValue: Double, formattedValue: String, achievedDate: Date = Date()) {
        self.kind = kind
        self.title = title
        self.recordValue = recordValue
        self.formattedValue = formattedValue
        self.achievedDate = achievedDate
    }
}

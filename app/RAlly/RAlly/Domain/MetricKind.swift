import Foundation

enum MetricKind: String, Codable, CaseIterable, Sendable, Hashable {
    case heartRateBpm
    case paceSecPerKm
    case speedMps
    case cadenceSpm
    case powerWatts
    case strokeRateSpm
    case punchRatePpm
    case repVelocityMps
    case repCount
    case motionIntensityG
    case distanceM
    case activeEnergyKcal
    case altitudeM
    case gradePercent
    /// 1 = CMMotionActivity.stationary, 0 = not. Optional corroboration for locomotion.
    case motionStationary
    case latitude
    case longitude

    var unitLabel: String {
        switch self {
        case .heartRateBpm: "bpm"
        case .paceSecPerKm: "/km"
        case .speedMps: "m/s"
        case .cadenceSpm: "spm"
        case .powerWatts: "W"
        case .strokeRateSpm: "spm"
        case .punchRatePpm: "ppm"
        case .repVelocityMps: "m/s"
        case .repCount: "reps"
        case .motionIntensityG: "g"
        case .distanceM: "m"
        case .activeEnergyKcal: "kcal"
        case .altitudeM: "m"
        case .gradePercent: "%"
        case .motionStationary: ""
        case .latitude: "°"
        case .longitude: "°"
        }
    }
}

enum SampleSource: String, Codable, Sendable {
    case simulator
    case device
    case ble
    case healthKit
    case watch
    case derived
}

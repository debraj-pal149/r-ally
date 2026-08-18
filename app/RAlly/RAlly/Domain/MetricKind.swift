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

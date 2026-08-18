import Foundation

struct HIITAdapter: ActivityAdapter {
    var usesStructuredRest: Bool { true }
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        let m = latest[.motionIntensityG] ?? 0
        return EngineChannels(output: m, hr: latest[.heartRateBpm], rhythm: latest[.cadenceSpm] ?? 120, plannedRest: m < 0.25, snapshot: "intervals")
    }
}

import Foundation

struct StrengthAdapter: ActivityAdapter {
    var usesStructuredRest: Bool { true }
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        let vel = latest[.repVelocityMps] ?? 0
        return EngineChannels(output: vel, hr: latest[.heartRateBpm], rhythm: vel, plannedRest: vel < 0.05, snapshot: "lifting")
    }
}

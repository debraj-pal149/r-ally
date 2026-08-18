import Foundation

struct RunningAdapter: ActivityAdapter {
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        let speed: Double = {
            if let s = latest[.speedMps] { return s }
            if let p = latest[.paceSecPerKm], p > 1 { return 1000 / p }
            return 0
        }()
        return EngineChannels(output: speed, hr: latest[.heartRateBpm], rhythm: latest[.cadenceSpm] ?? 160, plannedRest: false, snapshot: "running")
    }
}

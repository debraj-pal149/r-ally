import Foundation

struct CyclingAdapter: ActivityAdapter {
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        let power = latest[.powerWatts] ?? (latest[.speedMps] ?? 0) * 30
        return EngineChannels(output: power, hr: latest[.heartRateBpm], rhythm: latest[.cadenceSpm] ?? 80, plannedRest: false, snapshot: "cycling")
    }
}

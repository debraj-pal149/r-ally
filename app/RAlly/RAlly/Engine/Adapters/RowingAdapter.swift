import Foundation

struct RowingAdapter: ActivityAdapter {
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        if let p = latest[.powerWatts], p > 15 {
            return EngineChannels(
                output: p,
                hr: latest[.heartRateBpm],
                rhythm: latest[.strokeRateSpm] ?? 22,
                plannedRest: false,
                snapshot: "rowing · watts"
            )
        }
        return EngineChannels(
            output: latest[.speedMps] ?? 0,
            hr: latest[.heartRateBpm],
            rhythm: latest[.strokeRateSpm] ?? 22,
            plannedRest: false,
            snapshot: "rowing · split proxy",
            outputIsProxy: true
        )
    }
}

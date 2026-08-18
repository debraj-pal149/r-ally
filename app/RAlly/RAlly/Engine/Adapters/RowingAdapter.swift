import Foundation

struct RowingAdapter: ActivityAdapter {
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        EngineChannels(output: latest[.powerWatts] ?? 0, hr: latest[.heartRateBpm], rhythm: latest[.strokeRateSpm] ?? 22, plannedRest: false, snapshot: "rowing")
    }
}

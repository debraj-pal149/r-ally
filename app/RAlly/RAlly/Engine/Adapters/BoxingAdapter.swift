import Foundation

struct BoxingAdapter: ActivityAdapter {
    var usesStructuredRest: Bool { true }
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        let p = latest[.punchRatePpm] ?? 0
        return EngineChannels(output: p, hr: latest[.heartRateBpm], rhythm: p, plannedRest: p < 12, snapshot: "boxing")
    }
}

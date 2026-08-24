import Foundation

// Original v1 adapter — punch rate from a phone in a pocket is not a signal.
// Rebuild on a round clock. See future/v2/README.md

struct BoxingAdapter: ActivityAdapter {
    var usesStructuredRest: Bool { true }
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        let p = latest[.punchRatePpm] ?? 0
        return EngineChannels(output: p, hr: latest[.heartRateBpm], rhythm: p, plannedRest: p < 12, snapshot: "boxing")
    }
}

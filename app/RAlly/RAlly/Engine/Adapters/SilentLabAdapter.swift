import Foundation

/// Lab sports (strength / boxing / HIIT / swim) must never shout in v1.
/// Rest is the protocol. A fade detector pointed at a lifter fires constantly or never.
/// Real implementations live in future/v2. Schedule adherence, not physiology.
struct SilentLabAdapter: ActivityAdapter {
    var usesStructuredRest: Bool { true }
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        EngineChannels(
            output: 0,
            hr: latest[.heartRateBpm],
            rhythm: 0,
            plannedRest: true,
            snapshot: "lab scenario. V1 will not shout",
            outputIsProxy: true
        )
    }
}

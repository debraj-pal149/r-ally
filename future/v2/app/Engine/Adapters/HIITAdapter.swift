import Foundation

// Original v1 adapter — rest intervals look like quitting to a fade detector.
// Rebuild on a declared interval clock + within-session motion baseline.
// See future/v2/README.md

struct HIITAdapter: ActivityAdapter {
    var usesStructuredRest: Bool { true }
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        let m = latest[.motionIntensityG] ?? 0
        return EngineChannels(output: m, hr: latest[.heartRateBpm], rhythm: latest[.cadenceSpm] ?? 120, plannedRest: m < 0.25, snapshot: "intervals")
    }
}

import Foundation

// Original v1 adapter — WRONG instrument for lifting.
// Rest is the protocol. Do not compile into the shipped app.
// Rebuild as a rest-creep coach: declared sets, rest timer, shout only after rest + grace.
// See future/v2/README.md

struct StrengthAdapter: ActivityAdapter {
    var usesStructuredRest: Bool { true }
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        let vel = latest[.repVelocityMps] ?? 0
        return EngineChannels(output: vel, hr: latest[.heartRateBpm], rhythm: vel, plannedRest: vel < 0.05, snapshot: "lifting")
    }
}

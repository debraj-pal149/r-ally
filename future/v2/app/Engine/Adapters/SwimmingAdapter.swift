import Foundation

// Original v1 adapter. Swimming is cut: no phone on body, no TTS underwater.
// Keep the simulator scenario as engine-test coverage only.

struct SwimmingAdapter: ActivityAdapter {
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        let speed = latest[.speedMps] ?? {
            if let p = latest[.paceSecPerKm], p > 1 { return 1000 / p }
            return 0
        }()
        return EngineChannels(output: speed, hr: latest[.heartRateBpm], rhythm: latest[.strokeRateSpm] ?? 30, plannedRest: false, snapshot: "swimming")
    }
}

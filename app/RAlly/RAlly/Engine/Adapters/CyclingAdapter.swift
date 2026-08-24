import Foundation

struct CyclingAdapter: ActivityAdapter {
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        if let p = latest[.powerWatts], p > 15 {
            return EngineChannels(
                output: p,
                hr: latest[.heartRateBpm],
                rhythm: latest[.cadenceSpm] ?? 80,
                plannedRest: false,
                snapshot: "cycling · power"
            )
        }
        // GPS speed is a proxy. Hills, wind, and drafting all look like a bonk.
        // The engine refuses fade triggers on a proxy unless HR + cadence also break.
        return EngineChannels(
            output: latest[.speedMps] ?? 0,
            hr: latest[.heartRateBpm],
            rhythm: latest[.cadenceSpm] ?? 80,
            plannedRest: false,
            snapshot: "cycling · speed proxy",
            outputIsProxy: true
        )
    }
}

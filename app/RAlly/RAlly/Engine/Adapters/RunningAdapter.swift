import Foundation

struct RunningAdapter: ActivityAdapter {
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels {
        var speed: Double = {
            if let s = latest[.speedMps] { return s }
            if let p = latest[.paceSecPerKm], p > 1 { return 1000 / p }
            return 0
        }()
        // Grade-adjusted pace: a hill drops raw speed and looks like a bonk.
        if let g = latest[.gradePercent], speed >= EngineConstants.vStop {
            speed *= max(0.5, 1 + 0.033 * g)
        }
        // Kill GPS wander at rest. Engine must see a hard zero when standing.
        if speed < EngineConstants.vStop {
            speed = 0
        }
        let rhythm: Double = {
            if speed < EngineConstants.vStop { return 0 }
            if let c = latest[.cadenceSpm] { return c }
            return speed < EngineConstants.vJog ? 100 : 150
        }()
        return EngineChannels(
            output: speed,
            hr: latest[.heartRateBpm],
            rhythm: rhythm,
            plannedRest: false,
            snapshot: "running"
        )
    }
}

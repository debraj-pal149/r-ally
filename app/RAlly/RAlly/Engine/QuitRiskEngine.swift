import Foundation

struct EngineTickResult: Sendable {
    var risk: Double
    var state: EngineState
    var trigger: TriggerKind?
    var snapshot: String
    var channels: EngineChannels
    var store: StoreSnapshot
}

final class QuitRiskEngine {
    let store = MetricStore()
    let policy = TriggerPolicy()
    private(set) var state: EngineState = .cruising
    private var risk = 0.0
    private var highTicks = 0
    private var lowTicks = 0
    private var pauseStarted: TimeInterval?
    private var pauseFrom: EngineState = .cruising
    private var lastOutput: Double = 0
    private var goalDone = false
    var adapter: any ActivityAdapter = RunningAdapter()
    var activity: ActivityKind = .running

    func reset(activity: ActivityKind, maxHR: Double, sessionCap: Int) {
        self.activity = activity
        adapter = activity.makeAdapter()
        store.reset(maxHR: maxHR)
        policy.reset(sessionCap: sessionCap)
        state = .cruising
        risk = 0
        highTicks = 0
        lowTicks = 0
        pauseStarted = nil
        lastOutput = 0
        goalDone = false
    }

    func setGoalDone(_ done: Bool) { goalDone = done }

    func ingest(_ sample: MetricSample) {
        store.ingest(sample)
    }

    func tick(t: TimeInterval) -> EngineTickResult {
        let latest = storeLatest()
        var ch = adapter.channels(from: latest, t: t)
        let snap = store.tick(t: t, channelsIn: ch)
        let features = computeFeatures(ch: ch, snap: snap)
        ch.snapshot = adapter.dropPhrase(outputDrop: features.outputDrop, stutter: features.stutter, grind: features.grind)

        let raw = 100 * logistic(
            EngineConstants.wOutputDrop * features.outputDrop
                + EngineConstants.wDecaySlope * features.decaySlope
                + EngineConstants.wDecoupling * features.decoupling
                + EngineConstants.wStutter * features.stutter
                + EngineConstants.wGrind * features.grind
                - EngineConstants.wCooldown * features.cooldownCue
                - EngineConstants.bias
        )
        risk = EngineConstants.riskSmooth * risk + (1 - EngineConstants.riskSmooth) * raw

        var trigger: TriggerKind?

        // Sudden-stop path
        if let stop = suddenStop(t: t, ch: ch, snap: snap) {
            trigger = stop
        } else {
            advanceStateMachine()
            if state == .critical {
                if policy.allow(kind: .preQuitFade, t: t, warmupOver: t >= EngineConstants.warmupSec, goalDone: goalDone) {
                    trigger = .preQuitFade
                }
            }
            if trigger == nil, features.grind > 0.55, features.outputDrop < 0.08 {
                if policy.allow(kind: .grindSupport, t: t, warmupOver: t >= EngineConstants.warmupSec, goalDone: goalDone) {
                    trigger = .grindSupport
                }
            }
            if trigger == nil, goalDone {
                if policy.allow(kind: .finalPush, t: t, warmupOver: true, goalDone: true) {
                    trigger = .finalPush
                }
            }
        }

        if ch.plannedRest, trigger == .preQuitFade || trigger == .stopped {
            trigger = nil
        }

        if let kind = trigger {
            policy.record(kind: kind, t: t)
            if kind == .preQuitFade { state = .critical }
        }

        lastOutput = ch.output
        return EngineTickResult(risk: risk, state: state, trigger: trigger, snapshot: ch.snapshot, channels: ch, store: snap)
    }

    private func storeLatest() -> [MetricKind: Double] {
        var d: [MetricKind: Double] = [:]
        for k in MetricKind.allCases {
            if let v = store.latest(k) { d[k] = v }
        }
        return d
    }

    private struct Features {
        var outputDrop: Double
        var decaySlope: Double
        var decoupling: Double
        var cooldownCue: Double
        var stutter: Double
        var grind: Double
    }

    private func computeFeatures(ch: EngineChannels, snap: StoreSnapshot) -> Features {
        let base = max(snap.baseOut, EngineConstants.epsilon)
        let outputDrop = clamp((base - snap.shortOut) / base, 0, 1)
        let decaySlope = clamp(-snap.slope30Out / (EngineConstants.decaySlopeFull * base), 0, 1)
        let decoupling: Double = {
            guard let hrTrend = snap.slope30HR else { return 0 }
            let z = clamp(hrTrend / EngineConstants.hrTrendFull, 0, 1)
            return outputDrop > 0.05 ? z : 0
        }()
        let cooldownCue: Double = {
            if let hrTrend = snap.slope30HR {
                return clamp(-hrTrend / EngineConstants.cooldownHrFall, 0, 1)
            }
            return goalDone ? 1 : 0
        }()
        let stutter = clamp((snap.cv20Rhythm - snap.baseCv) / EngineConstants.stutterCv, 0, 1)
        let grind = clamp(snap.secondsHard / EngineConstants.grindSeconds, 0, 1)
        return Features(outputDrop: outputDrop, decaySlope: decaySlope, decoupling: decoupling, cooldownCue: cooldownCue, stutter: stutter, grind: grind)
    }

    private func advanceStateMachine() {
        switch state {
        case .cruising:
            if risk >= EngineConstants.wobbleEnter {
                highTicks += 1
                if highTicks >= EngineConstants.wobbleTicks { state = .wobbling; highTicks = 0; lowTicks = 0 }
            } else { highTicks = 0 }
        case .wobbling:
            if risk >= EngineConstants.criticalEnter {
                highTicks += 1
                lowTicks = 0
                if highTicks >= EngineConstants.criticalTicks { state = .critical; highTicks = 0 }
            } else if risk <= EngineConstants.cruiseReturn {
                lowTicks += 1
                highTicks = 0
                if lowTicks >= EngineConstants.cruiseTicks { state = .cruising; lowTicks = 0 }
            } else {
                highTicks = 0
                lowTicks = 0
            }
        case .critical:
            if risk <= EngineConstants.criticalExit {
                lowTicks += 1
                if lowTicks >= EngineConstants.criticalExitTicks { state = .wobbling; lowTicks = 0 }
            } else { lowTicks = 0 }
        case .pausedUnknown:
            break
        }
    }

    private func suddenStop(t: TimeInterval, ch: EngineChannels, snap: StoreSnapshot) -> TriggerKind? {
        let collapsed = ch.output < EngineConstants.stopFraction * max(snap.baseOut, EngineConstants.epsilon)
        if collapsed, pauseStarted == nil, lastOutput > 0 {
            let dropFast = lastOutput > 0 && ch.output < 0.5 * lastOutput
            if dropFast || ch.output < EngineConstants.stopFraction * max(snap.baseOut, EngineConstants.epsilon) {
                pauseStarted = t
                pauseFrom = state == .pausedUnknown ? .cruising : state
                state = .pausedUnknown
            }
        }
        if let start = pauseStarted {
            let grace = adapter.usesStructuredRest ? EngineConstants.graceSec * EngineConstants.structuredRestMul : EngineConstants.graceSec
            if ch.output >= EngineConstants.resumeFraction * max(snap.baseOut, EngineConstants.epsilon) {
                pauseStarted = nil
                state = pauseFrom
                policy.noteStopRecovery(t: t)
                return nil
            }
            if t - start >= grace {
                pauseStarted = nil
                let hrOk: Bool = {
                    guard let hr = ch.hr, snap.peakHR > 0 else { return true }
                    return hr > EngineConstants.stopHRPeakFraction * snap.peakHR
                }()
                if hrOk, !goalDone, !ch.plannedRest {
                    if policy.allow(kind: .stopped, t: t, warmupOver: t >= EngineConstants.warmupSec, goalDone: goalDone) {
                        state = .wobbling
                        return .stopped
                    }
                }
                state = pauseFrom
            }
        }
        return nil
    }

    private func logistic(_ x: Double) -> Double {
        1 / (1 + exp(-x))
    }

    private func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, x))
    }
}

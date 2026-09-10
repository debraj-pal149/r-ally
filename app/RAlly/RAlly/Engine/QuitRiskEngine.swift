import Foundation

struct EngineTickResult: Sendable {
    var risk: Double
    /// Risk state machine (always advances. Bug A3). UI must prefer `locomotion` when stopped.
    var state: EngineState
    var locomotion: Locomotion
    var trigger: TriggerKind?
    var milestone: MilestoneState?
    var snapshot: String
    var channels: EngineChannels
    var store: StoreSnapshot
}

final class QuitRiskEngine {
    let store = MetricStore()
    let policy = TriggerPolicy()
    let locomotionClassifier = LocomotionClassifier()
    private(set) var state: EngineState = .cruising
    private(set) var locomotion: Locomotion = .moving
    private var risk = 0.0
    private var highTicks = 0
    private var lowTicks = 0
    private var lastOutput: Double = 0
    private var goalDone = false

    private var paceSlipSince: TimeInterval?
    private var lastKeepGoingT: TimeInterval = -10_000
    private var lastRestNagT: TimeInterval = -10_000
    private var announcedStop = false
    private var restNagCount = 0

    private var followUpArmed = false
    private var followUpAt: TimeInterval = -1
    private var followUpBase: Double = 0
    private var stillStoppedFired = false
    private var recoveryFired = false

    var adapter: any ActivityAdapter = RunningAdapter()
    var activity: ActivityKind = .running

    func reset(activity: ActivityKind, maxHR: Double, sessionCap: Int) {
        self.activity = activity
        adapter = activity.makeAdapter()
        store.reset(maxHR: maxHR)
        policy.reset(fadeShoutCap: sessionCap)
        locomotionClassifier.reset()
        state = .cruising
        locomotion = .moving
        risk = 0
        highTicks = 0
        lowTicks = 0
        lastOutput = 0
        goalDone = false
        paceSlipSince = nil
        lastKeepGoingT = -10_000
        lastRestNagT = -10_000
        announcedStop = false
        restNagCount = 0
        clearFollowUp()
    }

    func setGoalDone(_ done: Bool) { goalDone = done }

    func ingest(_ sample: MetricSample) {
        store.ingest(sample)
    }

    func tick(t: TimeInterval) -> EngineTickResult {
        let latest = storeLatest()
        var ch = adapter.channels(from: latest, t: t)

        let hint = motionHint(from: latest)
        let transition = locomotionClassifier.update(speed: ch.output, cadence: ch.rhythm, hint: hint)
        locomotion = locomotionClassifier.state

        if transition.enteredStopped {
            announcedStop = false
            recoveryFired = false
            stillStoppedFired = false
            restNagCount = 0
        }

        let freezeBase = locomotion == .stopped
        let reseed = transition.leftStopped
        let snap = store.tick(t: t, channelsIn: ch, freezeBaseline: freezeBase, reseedFromFrozen: reseed)
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

        // Bug A3: risk machine ALWAYS advances. Locomotion gates display + which trigger loop runs.
        if state == .pausedUnknown { state = .cruising }
        advanceStateMachine()

        var trigger: TriggerKind?

        if locomotion == .stopped {
            trigger = stoppedPromptTick(t: t, ch: ch, snap: snap)
        } else {
            if let follow = followUpTick(t: t, ch: ch, snap: snap) {
                trigger = follow
            } else if let slip = paceSlipTick(t: t, features: features, ch: ch) {
                trigger = slip
            } else if state == .critical,
                      fadeIsHonest(features: features, ch: ch),
                      policy.allow(kind: .preQuitFade, t: t, warmupOver: t >= EngineConstants.warmupSec, goalDone: goalDone) {
                trigger = .preQuitFade
            } else if features.grind > 0.55, features.outputDrop < 0.08,
                      policy.allow(kind: .grindSupport, t: t, warmupOver: t >= EngineConstants.warmupSec, goalDone: goalDone) {
                trigger = .grindSupport
            } else if goalDone,
                      policy.allow(kind: .finalPush, t: t, warmupOver: true, goalDone: true) {
                trigger = .finalPush
            } else if let keep = keepGoingTick(t: t, features: features) {
                trigger = keep
            }

            if announcedStop, locomotion == .moving, !recoveryFired {
                if policy.allow(kind: .recovery, t: t, warmupOver: true, goalDone: goalDone) {
                    trigger = .recovery
                    recoveryFired = true
                    announcedStop = false
                    clearFollowUp()
                }
            }
        }

        if ch.plannedRest, trigger == .preQuitFade || trigger == .stopped || trigger == .stillStopped || trigger == .paceSlip {
            trigger = nil
        }

        if let kind = trigger {
            policy.record(kind: kind, t: t)
            if kind == .preQuitFade { state = .critical }
            if kind == .stopped {
                announcedStop = true
                restNagCount = 1
                armFollowUp(after: kind, t: t, base: max(snap.baseOut, EngineConstants.epsilon))
                lastRestNagT = t
            }
            if kind == .stillStopped {
                stillStoppedFired = true
                restNagCount += 1
                lastRestNagT = t
            }
            if kind == .recovery {
                recoveryFired = true
                clearFollowUp()
            }
            if kind == .keepGoing { lastKeepGoingT = t }
            if kind == .paceSlip { paceSlipSince = nil }
        }

        lastOutput = ch.output
        return EngineTickResult(
            risk: risk,
            state: state,
            locomotion: locomotion,
            trigger: trigger,
            milestone: nil,
            snapshot: ch.snapshot,
            channels: ch,
            store: snap
        )
    }

    private func motionHint(from latest: [MetricKind: Double]) -> LocomotionClassifier.MotionHint? {
        guard let v = latest[.motionStationary] else { return nil }
        return .init(stationary: v >= 0.5, walking: nil, running: nil)
    }

    private func stoppedPromptTick(t: TimeInterval, ch: EngineChannels, snap: StoreSnapshot) -> TriggerKind? {
        guard t >= EngineConstants.warmupSec, !goalDone, !ch.plannedRest else { return nil }

        if !announcedStop {
            if policy.allow(kind: .stopped, t: t, warmupOver: true, goalDone: goalDone) {
                return .stopped
            }
            return nil
        }

        if t - lastRestNagT >= CoachRhythm.restInterval(afterNagCount: restNagCount) {
            if policy.allow(kind: .stillStopped, t: t, warmupOver: true, goalDone: goalDone) {
                return .stillStopped
            }
        }

        if followUpArmed, !stillStoppedFired,
           t - followUpAt >= EngineConstants.stillStoppedAfterSec,
           ch.output < EngineConstants.stopFraction * max(followUpBase, snap.baseOut, EngineConstants.epsilon) {
            if policy.allow(kind: .stillStopped, t: t, warmupOver: true, goalDone: goalDone) {
                return .stillStopped
            }
        }
        return nil
    }

    private func paceSlipTick(t: TimeInterval, features: Features, ch: EngineChannels) -> TriggerKind? {
        guard locomotion == .moving || locomotion == .slowing else { return nil }
        guard t >= EngineConstants.warmupSec, !goalDone else { return nil }
        let slipping = features.outputDrop >= EngineConstants.paceSlipDrop
            && features.outputDrop < EngineConstants.phoneOnlyHardDrop
            && ch.output >= EngineConstants.vStop
        if slipping {
            if paceSlipSince == nil { paceSlipSince = t }
            if let start = paceSlipSince, t - start >= EngineConstants.paceSlipHoldSec {
                if policy.allow(kind: .paceSlip, t: t, warmupOver: true, goalDone: goalDone) {
                    return .paceSlip
                }
            }
        } else {
            paceSlipSince = nil
        }
        return nil
    }

    private func keepGoingTick(t: TimeInterval, features: Features) -> TriggerKind? {
        guard locomotion == .moving else { return nil }
        guard t >= EngineConstants.warmupSec, !goalDone else { return nil }
        guard features.outputDrop < EngineConstants.paceSlipDrop * 0.85 else { return nil }
        guard t - lastKeepGoingT >= EngineConstants.keepGoingSec else { return nil }
        if policy.allow(kind: .keepGoing, t: t, warmupOver: true, goalDone: goalDone) {
            return .keepGoing
        }
        return nil
    }

    private func armFollowUp(after kind: TriggerKind, t: TimeInterval, base: Double) {
        followUpArmed = true
        followUpAt = t
        followUpBase = base
        stillStoppedFired = false
        recoveryFired = false
        _ = kind
    }

    private func clearFollowUp() {
        followUpArmed = false
        followUpAt = -1
        stillStoppedFired = false
    }

    private func followUpTick(t: TimeInterval, ch: EngineChannels, snap: StoreSnapshot) -> TriggerKind? {
        guard followUpArmed, !recoveryFired else { return nil }
        let base = max(followUpBase, snap.baseOut, EngineConstants.epsilon)
        let recovered = ch.output >= EngineConstants.recoveryFraction * base
        if recovered {
            if policy.allow(kind: .recovery, t: t, warmupOver: true, goalDone: goalDone) {
                return .recovery
            }
            return nil
        }
        if t - followUpAt > EngineConstants.recoveryWindowSec + 40 {
            clearFollowUp()
        }
        return nil
    }

    private func fadeIsHonest(features: Features, ch: EngineChannels) -> Bool {
        if ch.plannedRest { return false }
        if features.cooldownCue > 0.5 { return false }
        let drop = features.outputDrop
        let decoupling = features.decoupling
        let stutter = features.stutter

        if ch.outputIsProxy, ch.hr == nil {
            return false
        }
        if ch.hr != nil {
            let decoupled = decoupling >= 0.28 && drop >= 0.06
            let cadenceBreak = stutter >= 0.40 && drop >= 0.10
            return decoupled || cadenceBreak
        }
        let cadenceFade = stutter >= EngineConstants.phoneOnlyStutter && drop >= EngineConstants.phoneOnlyDrop
        let hardCollapse = drop >= EngineConstants.phoneOnlyHardDrop && features.decaySlope >= 0.30
        return cadenceFade || hardCollapse
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
            guard outputDrop > 0.05 else { return 0 }
            guard let hrTrend = snap.slope30HR else { return 0 }
            let rising = clamp(hrTrend / EngineConstants.hrTrendFull, 0, 1)
            let pinned = hrTrend > -EngineConstants.hrPinnedFloor ? 0.75 : 0
            return max(rising, pinned * clamp(outputDrop / 0.12, 0, 1))
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
            state = .cruising
            highTicks = 0
            lowTicks = 0
        }
    }

    private func logistic(_ x: Double) -> Double {
        1 / (1 + exp(-x))
    }

    private func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, x))
    }
}

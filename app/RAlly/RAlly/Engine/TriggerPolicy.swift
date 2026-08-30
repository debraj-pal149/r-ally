import Foundation

struct TriggerDecision: Sendable {
    var kind: TriggerKind
    var intensityMaximum: Bool
}

final class TriggerPolicy {
    var fadeShoutCap: Int = EngineConstants.defaultFadeShoutCap
    private var lastSpokenT: TimeInterval = -10_000
    /// Session time when speech actually finished (real callback — never WPM estimate).
    private var lastSpeechEndedT: TimeInterval = -10_000
    /// True after `record` until `noteSpeechEnded` — blocks stacking while TTS plays.
    private var awaitingSpeechEnd = false
    private var lastKind: TriggerKind?
    private var fadeTotal = 0
    private var grindCount = 0
    private var finalCount = 0
    private var lastFadeT: TimeInterval = -10_000
    private var lastStopRecoverT: TimeInterval = -10_000
    private(set) var intensityMaximum = false

    var sessionCap: Int {
        get { fadeShoutCap }
        set { fadeShoutCap = newValue }
    }

    func reset(fadeShoutCap: Int) {
        self.fadeShoutCap = fadeShoutCap
        lastSpokenT = -10_000
        lastSpeechEndedT = -10_000
        awaitingSpeechEnd = false
        lastKind = nil
        fadeTotal = 0
        grindCount = 0
        finalCount = 0
        lastFadeT = -10_000
        lastStopRecoverT = -10_000
        intensityMaximum = false
    }

    func reset(sessionCap: Int) {
        reset(fadeShoutCap: sessionCap)
    }

    func noteStopRecovery(t: TimeInterval) {
        lastStopRecoverT = t
    }

    /// Call from SpeechEngine finish / booth drain — session `t` at real completion.
    func noteSpeechEnded(t: TimeInterval) {
        lastSpeechEndedT = t
        awaitingSpeechEnd = false
    }

    /// Unit tests / silent sims: mark the line "spoken" instantly so rhythm can continue.
    func noteSpeechEndedImmediate(t: TimeInterval) {
        noteSpeechEnded(t: t)
    }

    func allow(kind: TriggerKind, t: TimeInterval, warmupOver: Bool, goalDone: Bool) -> Bool {
        if t < EngineConstants.warmupSec { return false }
        if !warmupOver { return false }
        if awaitingSpeechEnd { return false }
        if lastSpeechEndedT > -9_000, t - lastSpeechEndedT < EngineConstants.breathGapSec {
            return false
        }

        let refractory: Double = {
            switch kind {
            case .stillStopped: CoachRhythm.restNagSec * 0.9
            case .stopped: CoachRhythm.followUpRefractorySec
            case .recovery: CoachRhythm.followUpRefractorySec
            case .keepGoing: CoachRhythm.keepGoingSec * 0.85
            case .paceSlip: CoachRhythm.paceSlipRefractorySec
            default: EngineConstants.refractorySec
            }
        }()
        if t - lastSpokenT < refractory { return false }
        if t - lastStopRecoverT < EngineConstants.resumeGraceSec,
           kind != .stopped, kind != .stillStopped, kind != .recovery, kind != .keepGoing {
            return false
        }
        if usesFadeBudget(kind), fadeTotal >= fadeShoutCap { return false }
        if goalDone, kind == .preQuitFade || kind == .stillStopped || kind == .paceSlip { return false }
        if kind == .grindSupport, grindCount >= EngineConstants.grindCap { return false }
        if kind == .finalPush, finalCount >= EngineConstants.finalPushCap { return false }
        if kind == .finalPush, !goalDone { return false }
        return true
    }

    func record(kind: TriggerKind, t: TimeInterval) {
        lastSpokenT = t
        lastKind = kind
        awaitingSpeechEnd = true
        if usesFadeBudget(kind) {
            fadeTotal += 1
        }
        if kind == .grindSupport { grindCount += 1 }
        if kind == .finalPush { finalCount += 1 }
        if kind == .preQuitFade {
            if t - lastFadeT < EngineConstants.escalationWindow, lastFadeT > 0 {
                intensityMaximum = true
            }
            lastFadeT = t
        }
    }

    private func usesFadeBudget(_ kind: TriggerKind) -> Bool {
        switch kind {
        case .preQuitFade, .paceSlip, .grindSupport, .finalPush: true
        case .stopped, .stillStopped, .keepGoing, .recovery, .milestone: false
        }
    }
}

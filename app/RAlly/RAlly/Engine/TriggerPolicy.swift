import Foundation

struct TriggerDecision: Sendable {
    var kind: TriggerKind
    var intensityMaximum: Bool
}

final class TriggerPolicy {
    var sessionCap: Int = EngineConstants.defaultSessionCap
    private var lastSpokenT: TimeInterval = -10_000
    private var total = 0
    private var grindCount = 0
    private var finalCount = 0
    private var lastFadeT: TimeInterval = -10_000
    private var lastStopRecoverT: TimeInterval = -10_000
    private(set) var intensityMaximum = false

    func reset(sessionCap: Int) {
        self.sessionCap = sessionCap
        lastSpokenT = -10_000
        total = 0
        grindCount = 0
        finalCount = 0
        lastFadeT = -10_000
        lastStopRecoverT = -10_000
        intensityMaximum = false
    }

    func noteStopRecovery(t: TimeInterval) {
        lastStopRecoverT = t
    }

    func allow(kind: TriggerKind, t: TimeInterval, warmupOver: Bool, goalDone: Bool) -> Bool {
        if t < EngineConstants.warmupSec { return false }
        if !warmupOver { return false }
        if t - lastSpokenT < EngineConstants.refractorySec { return false }
        if t - lastStopRecoverT < EngineConstants.resumeGraceSec, kind != .stopped { return false }
        if total >= sessionCap { return false }
        if goalDone, kind == .preQuitFade { return false }
        if kind == .grindSupport, grindCount >= EngineConstants.grindCap { return false }
        if kind == .finalPush, finalCount >= EngineConstants.finalPushCap { return false }
        if kind == .finalPush, !goalDone { return false }
        return true
    }

    func record(kind: TriggerKind, t: TimeInterval) {
        lastSpokenT = t
        total += 1
        if kind == .grindSupport { grindCount += 1 }
        if kind == .finalPush { finalCount += 1 }
        if kind == .preQuitFade {
            if t - lastFadeT < EngineConstants.escalationWindow, lastFadeT > 0 {
                intensityMaximum = true
            }
            lastFadeT = t
        }
    }
}

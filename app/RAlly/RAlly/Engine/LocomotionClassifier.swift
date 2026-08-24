import Foundation

/// Sticky locomotion — independent of QuitRisk risk state.
/// Entry AND exit are debounced (multi-tick), so GPS noise cannot flicker REST ↔ RUNNING.
final class LocomotionClassifier {
    private(set) var state: Locomotion = .moving
    private var belowStopCount = 0
    private var aboveResumeCount = 0

    struct MotionHint: Sendable {
        var stationary: Bool?
        var walking: Bool?
        var running: Bool?
    }

    struct Transition: Sendable {
        var enteredStopped: Bool
        var leftStopped: Bool
    }

    func reset() {
        state = .moving
        belowStopCount = 0
        aboveResumeCount = 0
    }

    @discardableResult
    func update(speed: Double, cadence: Double?, hint: MotionHint? = nil) -> Transition {
        let clamped = speed < EngineConstants.vStop ? 0 : speed
        let motionStationary = hint?.stationary == true
        let motionRunning = hint?.running == true
        let walkLikeCadence = (cadence ?? 0) > 0 && (cadence ?? 0) < 105

        var entered = false
        var left = false

        switch state {
        case .stopped:
            let resumeCandidate = (clamped >= EngineConstants.vResume && !motionStationary) || motionRunning
            if resumeCandidate {
                aboveResumeCount += 1
                if aboveResumeCount >= EngineConstants.resumeSustainTicks {
                    state = clamped < EngineConstants.vJog ? .slowing : .moving
                    aboveResumeCount = 0
                    belowStopCount = 0
                    left = true
                }
            } else {
                aboveResumeCount = 0
            }

        case .moving, .slowing:
            let hardStop = clamped < EngineConstants.vStop || motionStationary
            if hardStop {
                belowStopCount += 1
                aboveResumeCount = 0
                if belowStopCount >= EngineConstants.stopEntrySustainTicks {
                    state = .stopped
                    belowStopCount = 0
                    entered = true
                } else if clamped < EngineConstants.vJog {
                    state = .slowing
                }
            } else {
                belowStopCount = 0
                if clamped < EngineConstants.vJog || (walkLikeCadence && clamped < EngineConstants.vJog) {
                    state = .slowing
                } else {
                    state = .moving
                }
            }
        }

        return Transition(enteredStopped: entered, leftStopped: left)
    }
}

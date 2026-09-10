import Foundation

enum EngineConstants {
    static let ewmaHalfLife: Double = 90
    static var ewmaAlpha: Double { 1 - pow(2.0, -1.0 / ewmaHalfLife) }
    static let shortWindow: Int = 15
    static let slopeWindow: Int = 30
    static let cvWindow: Int = 20
    static let epsilon: Double = 1e-6

    static let decaySlopeFull: Double = 0.005
    static let hrTrendFull: Double = 0.05
    static let hrPinnedFloor: Double = 0.02
    static let cooldownHrFall: Double = 0.15
    static let stutterCv: Double = 0.10
    static let grindSeconds: Double = 300
    static let hardHRFraction: Double = 0.88
    static let hardOutputFraction: Double = 0.92

    static let wOutputDrop: Double = 3.2
    static let wDecaySlope: Double = 2.0
    static let wDecoupling: Double = 2.4
    static let wStutter: Double = 1.2
    static let wGrind: Double = 0.6
    static let wCooldown: Double = 2.8
    static let bias: Double = 2.2
    static let riskSmooth: Double = 0.7

    static let wobbleEnter: Double = 42
    static let criticalEnter: Double = 60
    static let wobbleTicks: Int = 3
    static let criticalTicks: Int = 3
    static let cruiseReturn: Double = 35
    static let cruiseTicks: Int = 10
    static let criticalExit: Double = 50
    static let criticalExitTicks: Int = 15

    // --- Locomotion (m/s). Sticky stop/resume hysteresis kills RALLY↔STILL flicker. ---
    /// Below this ⇒ candidate for STOPPED (GPS noise floor / standing).
    static let vStop: Double = 0.70
    /// Must exceed this for resumeHoldSec to leave STOPPED.
    static let vResume: Double = 1.45
    /// Below this while not fully stopped ⇒ walk-break / slowing band.
    static let vJog: Double = 1.55
    /// Debounced entry/exit (1 Hz ticks). Bug A1/A2.
    static let stopEntrySustainTicks: Int = 3
    static let resumeSustainTicks: Int = 3
    static let stopEnterSec: Double = 2.5
    static let resumeHoldSec: Double = 3.0

    static let stopFraction: Double = 0.22
    static let collapseWindow: Double = 4
    static let graceSec: Double = 4
    static let resumeFraction: Double = 0.45
    static let stopHRPeakFraction: Double = 0.75
    static let structuredRestMul: Double = 1.5

    static let warmupSec: Double = 45
    static let refractorySec: Double = CoachRhythm.fadeRefractorySec
    static let followUpRefractorySec: Double = CoachRhythm.followUpRefractorySec
    /// Incessant sideline nag while stopped (until Pause or they move).
    static let restNagSec: Double = CoachRhythm.restNagSec
    /// Periodic encouragement while holding pace.
    static let keepGoingSec: Double = CoachRhythm.keepGoingSec
    static let paceSlipRefractorySec: Double = CoachRhythm.paceSlipRefractorySec
    static let stillStoppedAfterSec: Double = 12
    static let recoveryWindowSec: Double = 50
    static let breathGapSec: Double = CoachRhythm.breathGapSec
    /// Fade / pace-slip / grind budget (Settings stepper). Rest nags are a separate uncapped budget.
    static let defaultSessionCap: Int = 24
    static let defaultFadeShoutCap: Int = 24
    static let grindCap: Int = 4
    static let finalPushCap: Int = 1
    static let resumeGraceSec: Double = 8
    static let escalationWindow: Double = 300
    static let finalPushProgress: Double = 0.90

    static let phoneOnlyDrop: Double = 0.12
    static let phoneOnlyStutter: Double = 0.30
    static let phoneOnlyHardDrop: Double = 0.18
    /// Mild slowdown vs baseline while still moving.
    static let paceSlipDrop: Double = 0.07
    static let paceSlipHoldSec: Double = 8
    static let recoveryFraction: Double = 0.70
}

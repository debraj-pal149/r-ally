import Foundation

/// Defines all 34 contextual milestone and telemetry states for R·ALLY.
enum MilestoneState: String, CaseIterable, Codable, Sendable {
    // MARK: - Macro / Proximity (11)
    case theFirstStride = "the_first_stride"
    case theLiarMile = "the_liar_mile"
    case rhythmLock = "rhythm_lock"
    case theHalfwayCross = "the_halfway_cross"
    case theMidRunVoid = "the_mid_run_void"
    case thePainCaveEntry = "the_pain_cave_entry"
    case thePenultimateKm = "the_penultimate_km"
    case theFinalKickLaunch = "the_final_kick_launch"
    case targetSecured = "target_secured"
    case overDistanceBonus = "over_distance_bonus"
    case doubleTargetBeast = "double_target_beast"

    // MARK: - Biometrics (6)
    case strideCollapse = "stride_collapse"
    case cardiacDecoupling = "cardiac_decoupling"
    case thresholdRedline = "threshold_redline"
    case cadenceResync = "cadence_resync"
    case powerSpikeSurge = "power_spike_surge"
    case asymmetryWobble = "asymmetry_wobble"

    // MARK: - Psychological (5)
    case imposterDoubt = "imposter_doubt"
    case flowState = "flow_state"
    case theLactateWall = "the_lactate_wall"
    case rebornInTheFire = "reborn_in_the_fire"
    case mentalCheckIn = "mental_check_in"

    // MARK: - Micro-Tactical (7)
    case hillAscentAttack = "hill_ascent_attack"
    case hillCrestConquest = "hill_crest_conquest"
    case unplannedStop = "unplanned_stop"
    case restartAfterStop = "restart_after_stop"
    case walkBreakRescue = "walk_break_rescue"
    case walkBreakLimit = "walk_break_limit"
    case negativeSplit = "negative_split"

    // MARK: - Closed-Loop & History (5)
    case calloutRespondedSurge = "callout_responded_surge"
    case calloutIgnoredFading = "callout_ignored_fading"
    case prevQuitVanquished = "prev_quit_vanquished"
    case pacePBLatest = "pace_pb_latest"
    case recoveryPaceCheck = "recovery_pace_check"

    var title: String {
        switch self {
        case .theFirstStride: return "The First Stride"
        case .theLiarMile: return "The Liar Mile (Pacing Trap)"
        case .rhythmLock: return "Rhythm Locked"
        case .theHalfwayCross: return "Halfway Point"
        case .theMidRunVoid: return "The Mid-Run Void"
        case .thePainCaveEntry: return "Entering The Pain Cave"
        case .thePenultimateKm: return "Penultimate Kilometer"
        case .theFinalKickLaunch: return "Final 400m Kick"
        case .targetSecured: return "Target Secured"
        case .overDistanceBonus: return "Over-Distance Bonus Grit"
        case .doubleTargetBeast: return "Double Target Accomplished"
        case .strideCollapse: return "Stride Sag / Overstriding"
        case .cardiacDecoupling: return "Cardiac Decoupling"
        case .thresholdRedline: return "Threshold Redline"
        case .cadenceResync: return "Cadence Resynced"
        case .powerSpikeSurge: return "Power Surge Attack"
        case .asymmetryWobble: return "Gait Asymmetry Alert"
        case .imposterDoubt: return "Warmup Resistance"
        case .flowState: return "Deep Flow State"
        case .theLactateWall: return "The Lactate Wall"
        case .rebornInTheFire: return "Averted Quit / Rallied"
        case .mentalCheckIn: return "Form & Breath Scan"
        case .hillAscentAttack: return "Hill Incline Attack"
        case .hillCrestConquest: return "Hill Crest Acceleration"
        case .unplannedStop: return "Traffic / Red Light Stop"
        case .restartAfterStop: return "Locomotion Resumed"
        case .walkBreakRescue: return "Active Recovery Walk"
        case .walkBreakLimit: return "Walk Break Expired"
        case .negativeSplit: return "Negative Split Execution"
        case .calloutRespondedSurge: return "Surge After Callout"
        case .calloutIgnoredFading: return "Fading After Callout"
        case .prevQuitVanquished: return "Passed Historical Stop"
        case .pacePBLatest: return "Fastest Split (PB)"
        case .recoveryPaceCheck: return "Recovery Pace Warning"
        }
    }
}

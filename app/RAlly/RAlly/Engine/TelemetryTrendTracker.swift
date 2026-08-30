import Foundation

struct TelemetryPoint: Sendable {
    var t: TimeInterval
    var speedMps: Double
    var paceSecPerKm: Double
    var hrBpm: Double?
    var cadenceSpm: Double?
    var powerWatts: Double?
    var altitudeM: Double?
    var gradePercent: Double?
}

struct InterventionRecord: Sendable {
    var spokenAtT: TimeInterval
    var line: String
    var triggerKind: TriggerKind
    var milestone: MilestoneState?
    var initialPace: Double
    var initialCadence: Double?
    var initialHR: Double?
    var evaluated: Bool = false
    var result: ClosedLoopResult?

    enum ClosedLoopResult: String, Sendable {
        case surged = "SURGED"
        case held = "HELD"
        case faded = "FADED"
    }
}

/// Tracks rolling telemetry slopes (dP/dt), cadence decay, cardiac drift, and closed-loop coaching responses.
final class TelemetryTrendTracker: @unchecked Sendable {
    private var history: [TelemetryPoint] = []
    private var interventions: [InterventionRecord] = []
    private var firedMilestones: Set<MilestoneState> = []

    // Historical reference markers
    var previousWorkoutMaxDistanceM: Double = 0
    var thirtyDayFastestPace: Double = 300 // 5:00 /km default benchmark

    func reset() {
        history.removeAll()
        interventions.removeAll()
        firedMilestones.removeAll()
    }

    func recordPoint(
        t: TimeInterval,
        speedMps: Double,
        hrBpm: Double?,
        cadenceSpm: Double?,
        powerWatts: Double?,
        altitudeM: Double?,
        gradePercent: Double?
    ) {
        let pace = speedMps > 0.3 ? (1000.0 / speedMps) : 0
        let pt = TelemetryPoint(
            t: t,
            speedMps: speedMps,
            paceSecPerKm: pace,
            hrBpm: hrBpm,
            cadenceSpm: cadenceSpm,
            powerWatts: powerWatts,
            altitudeM: altitudeM,
            gradePercent: gradePercent
        )
        history.append(pt)

        // Keep last 15 minutes of granular telemetry
        if let first = history.first, t - first.t > 900 {
            history.removeFirst()
        }
    }

    func recordIntervention(
        t: TimeInterval,
        line: String,
        trigger: TriggerKind,
        milestone: MilestoneState?,
        currentPace: Double,
        cadence: Double?,
        hr: Double?
    ) {
        let rec = InterventionRecord(
            spokenAtT: t,
            line: line,
            triggerKind: trigger,
            milestone: milestone,
            initialPace: currentPace,
            initialCadence: cadence,
            initialHR: hr
        )
        interventions.append(rec)
    }

    // MARK: - Calculus & Trend Calculations

    /// Computes pace slope (dP/dt in seconds per kilometer per minute) over window seconds.
    /// Negative means accelerating (pace number getting smaller); positive means slowing down.
    func paceSlope(windowSec: TimeInterval = 60) -> Double {
        guard history.count >= 4, let latest = history.last else { return 0 }
        let cutoff = latest.t - windowSec
        let sample = history.filter { $0.t >= cutoff && $0.paceSecPerKm > 0 }
        guard sample.count >= 3 else { return 0 }

        let n = Double(sample.count)
        let t0 = sample.first!.t
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0
        for p in sample {
            let x = (p.t - t0) / 60.0 // minutes
            let y = p.paceSecPerKm
            sumX += x
            sumY += y
            sumXY += x * y
            sumXX += x * x
        }
        let denom = (n * sumXX - sumX * sumX)
        guard denom.magnitude > 0.0001 else { return 0 }
        return (n * sumXY - sumX * sumY) / denom
    }

    /// Checks if cadence is sagging (>10 SPM decay) while pace remains relatively flat.
    func isCadenceSagging(windowSec: TimeInterval = 90) -> Bool {
        guard history.count >= 5, let latest = history.last else { return false }
        let cutoff = latest.t - windowSec
        let sample = history.filter { $0.t >= cutoff && ($0.cadenceSpm ?? 0) > 0 }
        guard let first = sample.first, let last = sample.last,
              let cFirst = first.cadenceSpm, let cLast = last.cadenceSpm else { return false }

        let paceChange = abs(last.paceSecPerKm - first.paceSecPerKm)
        let cadenceDrop = cFirst - cLast
        return cadenceDrop >= 10 && paceChange < 20 // cadence collapsed while forcing pace
    }

    /// Checks if heart rate climbed >12 BPM while pace is flat or declining (cardiac drift).
    func isCardiacDecoupling(windowSec: TimeInterval = 180) -> Bool {
        guard history.count >= 6, let latest = history.last else { return false }
        let cutoff = latest.t - windowSec
        let sample = history.filter { $0.t >= cutoff && ($0.hrBpm ?? 0) > 0 }
        guard let first = sample.first, let last = sample.last,
              let hrFirst = first.hrBpm, let hrLast = last.hrBpm else { return false }

        let hrRise = hrLast - hrFirst
        let paceSlope = self.paceSlope(windowSec: windowSec)
        return hrRise >= 12 && paceSlope >= -2 // HR spiked without pace improving
    }

    private(set) var lastClosedLoopDescription: String?

    // MARK: - Closed-Loop Intervention Evaluation

    /// Evaluates if athlete responded to recent callouts (checked at 15s to 45s post-callout).
    func evaluatePendingInterventions(currentT: TimeInterval, currentPace: Double) -> InterventionRecord? {
        for i in 0..<interventions.count {
            if !interventions[i].evaluated && currentT - interventions[i].spokenAtT >= 25 {
                interventions[i].evaluated = true
                let deltaPace = interventions[i].initialPace - currentPace // Positive = faster pace
                if deltaPace >= 8 {
                    interventions[i].result = .surged
                    lastClosedLoopDescription = "Athlete surged \(Int(deltaPace))s/km faster following last cue"
                } else if deltaPace <= -12 {
                    interventions[i].result = .faded
                    lastClosedLoopDescription = "Athlete pace slowed down \(Int(abs(deltaPace)))s/km following last cue"
                } else {
                    interventions[i].result = .held
                    lastClosedLoopDescription = "Athlete held steady pace following last cue"
                }
                return interventions[i]
            }
        }
        return nil
    }

    // MARK: - 34-State Milestone Evaluator

    func evaluateMilestone(
        t: TimeInterval,
        distanceM: Double,
        targetDistanceM: Double?,
        speedMps: Double,
        hrBpm: Double?,
        maxHR: Double,
        cadenceSpm: Double?,
        powerWatts: Double?,
        gradePercent: Double?,
        engineState: EngineState,
        locomotion: Locomotion,
        lastSpokenT: TimeInterval
    ) -> MilestoneState? {
        // Cooldown between arbitrary milestone events (at least 75 seconds unless target reached)
        let cooldownOk = (t - lastSpokenT >= 75)
        let targetM = targetDistanceM ?? 5000.0
        let progressRatio = distanceM / targetM

        // 1. targetSecured (100% distance met)
        if progressRatio >= 1.0 && !firedMilestones.contains(.targetSecured) {
            firedMilestones.insert(.targetSecured)
            return .targetSecured
        }

        // 2. doubleTargetBeast (150% to 200%)
        if progressRatio >= 1.5 && !firedMilestones.contains(.doubleTargetBeast) {
            firedMilestones.insert(.doubleTargetBeast)
            return .doubleTargetBeast
        }

        // 3. overDistanceBonus (105% to 120%)
        if progressRatio >= 1.05 && progressRatio < 1.4 && !firedMilestones.contains(.overDistanceBonus) {
            firedMilestones.insert(.overDistanceBonus)
            return .overDistanceBonus
        }

        guard cooldownOk else { return nil }

        // 4. theFirstStride (0-300m)
        if distanceM >= 80 && distanceM <= 300 && !firedMilestones.contains(.theFirstStride) {
            firedMilestones.insert(.theFirstStride)
            return .theFirstStride
        }

        // 5. theLiarMile (800m - 1500m, pacing way too hot)
        if distanceM >= 800 && distanceM <= 1500 && !firedMilestones.contains(.theLiarMile) {
            let slope = paceSlope(windowSec: 60)
            if slope < -15 { // surging violently early
                firedMilestones.insert(.theLiarMile)
                return .theLiarMile
            }
        }

        // 6. rhythmLock (25% distance)
        if progressRatio >= 0.23 && progressRatio <= 0.28 && !firedMilestones.contains(.rhythmLock) {
            if let cadence = cadenceSpm, cadence >= 168 {
                firedMilestones.insert(.rhythmLock)
                return .rhythmLock
            }
        }

        // 7. theHalfwayCross (50% distance)
        if progressRatio >= 0.48 && progressRatio <= 0.54 && !firedMilestones.contains(.theHalfwayCross) {
            firedMilestones.insert(.theHalfwayCross)
            return .theHalfwayCross
        }

        // 8. theMidRunVoid (60% - 75% distance)
        if progressRatio >= 0.62 && progressRatio <= 0.74 && !firedMilestones.contains(.theMidRunVoid) {
            firedMilestones.insert(.theMidRunVoid)
            return .theMidRunVoid
        }

        // 9. thePainCaveEntry (80% - 90% distance)
        if progressRatio >= 0.80 && progressRatio <= 0.90 && !firedMilestones.contains(.thePainCaveEntry) {
            firedMilestones.insert(.thePainCaveEntry)
            return .thePainCaveEntry
        }

        // 10. thePenultimateKm (1.0 - 1.5km left)
        let distLeft = targetM - distanceM
        if distLeft > 800 && distLeft <= 1500 && progressRatio > 0.65 && !firedMilestones.contains(.thePenultimateKm) {
            firedMilestones.insert(.thePenultimateKm)
            return .thePenultimateKm
        }

        // 11. theFinalKickLaunch (last 400m)
        if distLeft > 50 && distLeft <= 400 && !firedMilestones.contains(.theFinalKickLaunch) {
            firedMilestones.insert(.theFinalKickLaunch)
            return .theFinalKickLaunch
        }

        // Biometrics
        // 12. thresholdRedline
        if let hr = hrBpm, hr >= 0.95 * maxHR && !firedMilestones.contains(.thresholdRedline) {
            firedMilestones.insert(.thresholdRedline)
            return .thresholdRedline
        }

        // 13. strideCollapse
        if isCadenceSagging() && !firedMilestones.contains(.strideCollapse) {
            firedMilestones.insert(.strideCollapse)
            return .strideCollapse
        }

        // 14. cardiacDecoupling
        if isCardiacDecoupling() && !firedMilestones.contains(.cardiacDecoupling) {
            firedMilestones.insert(.cardiacDecoupling)
            return .cardiacDecoupling
        }

        // Micro-Tactical
        // 15. hillAscentAttack
        if let grade = gradePercent, grade >= 3.0 && !firedMilestones.contains(.hillAscentAttack) {
            firedMilestones.insert(.hillAscentAttack)
            return .hillAscentAttack
        }

        // 16. prevQuitVanquished
        if previousWorkoutMaxDistanceM > 1000 && distanceM > previousWorkoutMaxDistanceM && !firedMilestones.contains(.prevQuitVanquished) {
            firedMilestones.insert(.prevQuitVanquished)
            return .prevQuitVanquished
        }

        return nil
    }
}

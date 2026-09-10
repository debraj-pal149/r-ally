import Foundation

struct TelemetryPoint: Sendable {
    var t: TimeInterval
    var speedMps: Double
    var paceSecPerKm: Double
    var gapPaceSecPerKm: Double
    var hrBpm: Double?
    var cadenceSpm: Double?
    var powerWatts: Double?
    var altitudeM: Double?
    var gradePercent: Double?
    var latitude: Double?
    var longitude: Double?
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

/// Tracks rolling telemetry slopes (dP/dt), cadence decay, cardiac drift, GAP, breadcrumbs, and closed-loop coaching responses.
final class TelemetryTrendTracker: @unchecked Sendable {
    private var history: [TelemetryPoint] = []
    private var interventions: [InterventionRecord] = []
    private var firedMilestones: Set<MilestoneState> = []

    // Analytics Collections
    private(set) var breadcrumbs: [GPSBreadcrumb] = []
    private(set) var lapSplits: [LapSplitRecord] = []
    private(set) var totalElevationGainM: Double = 0
    private(set) var totalElevationLossM: Double = 0
    private(set) var movingDurationSec: Double = 0
    private var lastPointT: TimeInterval = 0
    private var lastSplitDistanceM: Double = 0
    private var lastSplitT: TimeInterval = 0
    private var lastSplitAltitudeM: Double = 0

    // Heart Rate Zone Buckets (seconds per zone)
    private var hrZoneSeconds: [Int: Double] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]

    // Historical reference markers
    var previousWorkoutMaxDistanceM: Double = 0
    var thirtyDayFastestPace: Double = 300 // 5:00 /km default benchmark
    private(set) var lastClosedLoopDescription: String?

    func reset() {
        history.removeAll()
        interventions.removeAll()
        firedMilestones.removeAll()
        breadcrumbs.removeAll()
        lapSplits.removeAll()
        totalElevationGainM = 0
        totalElevationLossM = 0
        movingDurationSec = 0
        lastPointT = 0
        lastSplitDistanceM = 0
        lastSplitT = 0
        lastSplitAltitudeM = 0
        hrZoneSeconds = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        lastClosedLoopDescription = nil
    }

    func recordPoint(
        t: TimeInterval,
        speedMps: Double,
        hrBpm: Double?,
        maxHR: Double = 190,
        cadenceSpm: Double?,
        powerWatts: Double?,
        altitudeM: Double?,
        gradePercent: Double?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        cumulativeDistanceM: Double = 0
    ) {
        let rawPace = speedMps > 0.3 ? (1000.0 / speedMps) : 0
        let grade = gradePercent ?? 0
        let gapPace = GradeAdjustedCalculator.gradeAdjustedPace(rawPaceSecPerKm: rawPace, gradePercent: grade)

        let pt = TelemetryPoint(
            t: t,
            speedMps: speedMps,
            paceSecPerKm: rawPace,
            gapPaceSecPerKm: gapPace,
            hrBpm: hrBpm,
            cadenceSpm: cadenceSpm,
            powerWatts: powerWatts,
            altitudeM: altitudeM,
            gradePercent: gradePercent,
            latitude: latitude,
            longitude: longitude
        )
        history.append(pt)

        // Time delta & moving time accumulation
        let dt = lastPointT > 0 ? max(0, t - lastPointT) : 1.0
        lastPointT = t
        if speedMps >= 0.4 {
            movingDurationSec += dt
        }

        // Elevation Gain / Loss
        if let alt = altitudeM, let lastAlt = history.dropLast().last?.altitudeM {
            let dAlt = alt - lastAlt
            if dAlt > 0.3 && dAlt < 15 {
                totalElevationGainM += dAlt
            } else if dAlt < -0.3 && dAlt > -15 {
                totalElevationLossM += abs(dAlt)
            }
        }

        // Heart Rate Zone Bucketing
        if let hr = hrBpm, hr > 40 {
            let hrPct = hr / maxHR
            let zone: Int
            if hrPct < 0.60 { zone = 1 }
            else if hrPct < 0.70 { zone = 2 }
            else if hrPct < 0.80 { zone = 3 }
            else if hrPct < 0.90 { zone = 4 }
            else { zone = 5 }
            hrZoneSeconds[zone, default: 0] += dt
        }

        // Record GPS Breadcrumb (sample every 3 seconds or on significant movement)
        if let lat = latitude, let lon = longitude {
            if breadcrumbs.isEmpty || (t - (breadcrumbs.last?.timestamp ?? 0) >= 3.0) {
                let crumb = GPSBreadcrumb(
                    latitude: lat,
                    longitude: lon,
                    altitudeM: altitudeM ?? 0,
                    speedMps: speedMps,
                    paceSecPerKm: rawPace,
                    timestamp: t
                )
                breadcrumbs.append(crumb)
            }
        }

        // 1-Kilometer Lap Split Accumulator
        let completedKms = Int(cumulativeDistanceM / 1000.0)
        if completedKms > lapSplits.count && completedKms >= 1 {
            let splitDist = cumulativeDistanceM - lastSplitDistanceM
            let splitDur = max(1, t - lastSplitT)
            let splitPace = splitDist > 0 ? (splitDur / splitDist) * 1000.0 : rawPace
            let splitGap = GradeAdjustedCalculator.gradeAdjustedPace(rawPaceSecPerKm: splitPace, gradePercent: grade)
            let splitElevDelta = (altitudeM ?? 0) - lastSplitAltitudeM

            let lap = LapSplitRecord(
                splitNumber: completedKms,
                distanceM: splitDist,
                durationSec: splitDur,
                paceSecPerKm: splitPace,
                gapPaceSecPerKm: splitGap,
                avgHR: hrBpm,
                avgCadence: cadenceSpm,
                elevationDeltaM: splitElevDelta
            )
            lapSplits.append(lap)

            lastSplitDistanceM = cumulativeDistanceM
            lastSplitT = t
            lastSplitAltitudeM = altitudeM ?? 0
        }

        // Keep last 15 minutes of granular telemetry in memory
        if let first = history.first, t - first.t > 900 {
            history.removeFirst()
        }
    }

    /// Computes HR Zone distribution buckets for post-run analytics.
    func computeHRZones(maxHR: Double) -> [HRZoneBucket] {
        let total = hrZoneSeconds.values.reduce(0, +)
        let safeTotal = max(1, total)

        let names = [
            1: ("Recovery", "<\(Int(0.60 * maxHR)) bpm"),
            2: ("Aerobic", "\(Int(0.60 * maxHR))-\(Int(0.70 * maxHR)) bpm"),
            3: ("Tempo", "\(Int(0.70 * maxHR))-\(Int(0.80 * maxHR)) bpm"),
            4: ("Threshold", "\(Int(0.80 * maxHR))-\(Int(0.90 * maxHR)) bpm"),
            5: ("Anaerobic", ">\(Int(0.90 * maxHR)) bpm")
        ]

        var buckets: [HRZoneBucket] = []
        for z in 1...5 {
            let secs = hrZoneSeconds[z] ?? 0
            let pct = (secs / safeTotal) * 100.0
            let (name, range) = names[z] ?? ("Zone \(z)", "")
            buckets.append(HRZoneBucket(zoneIndex: z, name: name, rangeBpm: range, durationSec: secs, percentage: pct))
        }
        return buckets
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
        return cadenceDrop >= 10 && paceChange < 20
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
        return hrRise >= 12 && paceSlope >= -2
    }

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
        let cooldownOk = (t - lastSpokenT >= 75)
        let targetM = targetDistanceM ?? 5000.0
        let progressRatio = distanceM / targetM

        // 1. TargetSecured
        if progressRatio >= 1.0 && !firedMilestones.contains(.targetSecured) {
            firedMilestones.insert(.targetSecured)
            return .targetSecured
        }

        // 2. DoubleTargetBeast
        if progressRatio >= 1.5 && !firedMilestones.contains(.doubleTargetBeast) {
            firedMilestones.insert(.doubleTargetBeast)
            return .doubleTargetBeast
        }

        // 3. OverDistanceBonus
        if progressRatio >= 1.05 && progressRatio < 1.4 && !firedMilestones.contains(.overDistanceBonus) {
            firedMilestones.insert(.overDistanceBonus)
            return .overDistanceBonus
        }

        guard cooldownOk else { return nil }

        // 4. TheFirstStride
        if distanceM >= 80 && distanceM <= 300 && !firedMilestones.contains(.theFirstStride) {
            firedMilestones.insert(.theFirstStride)
            return .theFirstStride
        }

        // 5. TheLiarMile
        if distanceM >= 800 && distanceM <= 1500 && !firedMilestones.contains(.theLiarMile) {
            let slope = paceSlope(windowSec: 60)
            if slope < -15 {
                firedMilestones.insert(.theLiarMile)
                return .theLiarMile
            }
        }

        // 6. RhythmLock
        if progressRatio >= 0.23 && progressRatio <= 0.28 && !firedMilestones.contains(.rhythmLock) {
            if let cadence = cadenceSpm, cadence >= 168 {
                firedMilestones.insert(.rhythmLock)
                return .rhythmLock
            }
        }

        // 7. TheHalfwayCross
        if progressRatio >= 0.48 && progressRatio <= 0.54 && !firedMilestones.contains(.theHalfwayCross) {
            firedMilestones.insert(.theHalfwayCross)
            return .theHalfwayCross
        }

        // 8. TheMidRunVoid
        if progressRatio >= 0.62 && progressRatio <= 0.74 && !firedMilestones.contains(.theMidRunVoid) {
            firedMilestones.insert(.theMidRunVoid)
            return .theMidRunVoid
        }

        // 9. ThePainCaveEntry
        if progressRatio >= 0.80 && progressRatio <= 0.90 && !firedMilestones.contains(.thePainCaveEntry) {
            firedMilestones.insert(.thePainCaveEntry)
            return .thePainCaveEntry
        }

        // 10. ThePenultimateKm
        let distLeft = targetM - distanceM
        if distLeft > 800 && distLeft <= 1500 && progressRatio > 0.65 && !firedMilestones.contains(.thePenultimateKm) {
            firedMilestones.insert(.thePenultimateKm)
            return .thePenultimateKm
        }

        // 11. TheFinalKickLaunch
        if distLeft > 50 && distLeft <= 400 && !firedMilestones.contains(.theFinalKickLaunch) {
            firedMilestones.insert(.theFinalKickLaunch)
            return .theFinalKickLaunch
        }

        // 12. ThresholdRedline
        if let hr = hrBpm, hr >= 0.95 * maxHR && !firedMilestones.contains(.thresholdRedline) {
            firedMilestones.insert(.thresholdRedline)
            return .thresholdRedline
        }

        // 13. StrideCollapse
        if isCadenceSagging() && !firedMilestones.contains(.strideCollapse) {
            firedMilestones.insert(.strideCollapse)
            return .strideCollapse
        }

        // 14. CardiacDecoupling
        if isCardiacDecoupling() && !firedMilestones.contains(.cardiacDecoupling) {
            firedMilestones.insert(.cardiacDecoupling)
            return .cardiacDecoupling
        }

        // 15. HillAscentAttack
        if let grade = gradePercent, grade >= 3.0 && !firedMilestones.contains(.hillAscentAttack) {
            firedMilestones.insert(.hillAscentAttack)
            return .hillAscentAttack
        }

        // 16. PrevQuitVanquished
        if previousWorkoutMaxDistanceM > 1000 && distanceM > previousWorkoutMaxDistanceM && !firedMilestones.contains(.prevQuitVanquished) {
            firedMilestones.insert(.prevQuitVanquished)
            return .prevQuitVanquished
        }

        return nil
    }
}

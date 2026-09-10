import Foundation
import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
import CoreLocation
import CoreMotion
#endif

enum AppRoute: Equatable {
    case onboarding
    case home
    case live
    case summary(WorkoutSessionRecord)
    case history
    case settings
}

@Observable
@MainActor
final class AppModel {
    var name: String = UserDefaults.standard.string(forKey: "athlete.name") ?? ""
    var age: Int = UserDefaults.standard.object(forKey: "athlete.age") as? Int ?? 32
    var hrMaxOverride: Double? = UserDefaults.standard.object(forKey: "athlete.hrMax") as? Double
    var thresholdPace: Double = UserDefaults.standard.object(forKey: "athlete.pace") as? Double ?? 330
    var persona: Persona = {
        if let raw = UserDefaults.standard.string(forKey: "athlete.persona"),
           let id = Persona.ID(rawValue: raw) {
            return Persona.named(id)
        }
        return Persona.named(.sarge)
    }() {
        didSet {
            if let savedLevel = UserDefaults.standard.string(forKey: "athlete.runnerLevel"),
           let level = RunnerLevel(rawValue: savedLevel) {
            runnerLevel = level
        }
            speech.voiceId = persona.voiceId
            UserDefaults.standard.set(persona.id.rawValue, forKey: "athlete.persona")
            UserDefaults.standard.set(persona.voiceId, forKey: "coach.voiceId")
        }
    }
    var activity: ActivityKind = .running
    var goal: WorkoutGoal = ActivityKind.running.defaultGoal
    var selectedPrompt: String?
    var customPrompt: String = ""
    var sourceKind: DataSourceKind = {
        // Physical iPhone from Xcode is almost always DEBUG. Never default that to Simulator.
        #if targetEnvironment(simulator)
        .simulator
        #else
        if let raw = UserDefaults.standard.string(forKey: "source.kind"),
           let kind = DataSourceKind(rawValue: raw) {
            return kind
        }
        return .device
        #endif
    }()
    var simulatorURLString: String = UserDefaults.standard.string(forKey: "sim.url") ?? "ws://127.0.0.1:7777/stream"
    var sessionCap: Int = UserDefaults.standard.object(forKey: "rally.cap") as? Int ?? 10
    var didOnboard: Bool = UserDefaults.standard.bool(forKey: "didOnboard")
    var route: AppRoute
    var selectedTab: MainTab = .run
    var muted = false
    var spokenLine: String?
    var connectedToSim = false
    var llmOffline = false
    var bleEnabled = false
    var bleDevices: [(id: UUID, name: String)] = []
    var healthAuthorized = false
    var nrcWorkoutCount = 0
    var voiceId: String = UserDefaults.standard.string(forKey: "coach.voiceId") ?? CoachVoiceOption.defaultVoiceId {
        didSet {
            speech.voiceId = voiceId
            UserDefaults.standard.set(voiceId, forKey: "coach.voiceId")
        }
    }
    var voiceEngine: VoiceEngine = .cloud

    var liveT: TimeInterval = 0
    var liveRisk: Double = 0
    var liveState: EngineState = .cruising
    var liveLocomotion: Locomotion = .moving
    var liveLatest: [MetricKind: Double] = [:]
    var liveRallies: [RallyMoment] = []
    var livePaused = false
    var liveDisconnected = false
    var liveStartedAt: Date?
    var finishedAfterCritical = false
    var lastRecord: WorkoutSessionRecord?

    var runnerLevel: RunnerLevel = .intermediate {
        didSet {
            UserDefaults.standard.set(runnerLevel.rawValue, forKey: "athlete.runnerLevel")
        }
    }

    let engine = QuitRiskEngine()
    let trendTracker = TelemetryTrendTracker()
    let splitEngine = PeriodicSplitEngine()
    var latestReport: CoachFieldReport?
    var athleteHistory: AthleteHistoryCard = AthleteHistoryBuilder.loadPersisted()
    var distanceUnit: DistanceUnit = DistanceUnit.detect()
    var appearanceMode: AppearanceMode = AppearanceMode.load() {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "ui.appearance")
            AppearanceMode.applyToWindows(appearanceMode)
        }
    }
    private var didFireOpeningPush = false
    private var lastHistoryCueKey: String? = nil
    let sources = DataSourceManager()
    let speech = SpeechEngine()
    let ble = BLEHeartRateDataSource()
    let universalBle = UniversalBLEDataSource()
    let health = HealthKitDataSource()
    let strava = StravaClient()
    let hkWriter = HealthKitWriter()
    let cache: LineCache

    private var lastTick: TimeInterval = -1
    private var lastSpokenTimestamp: TimeInterval = -10_000
    private var lastRiskReport: TimeInterval = -100
    private var lastRiskState: EngineState = .cruising
    private var recentLines: [String] = []
    private var simSource: SimulatorDataSource?
    private var deviceSource: DeviceSensorDataSource?

    var hrMax: Double {
        hrMaxOverride ?? (211 - 0.64 * Double(age))
    }

    var greeting: String {
        let n = name.isEmpty ? "" : ", \(name)."
        return "\(Formatters.greeting())\(n)"
    }

    /// Cycling/rowing need effort sensors we do not ship in the phone-only product.
    var startBlockedReason: String? {
        if sourceKind == .simulator { return nil }
        if !activity.isShipped {
            return "v1 is running on phone sensors. Ride and row need a strap. Not this build."
        }
        return nil
    }

    /// Phone-only is the product. No scare banner.
    var phoneOnlyWarning: String? { nil }

    init() {
        let key = AnthropicClient.keyFromBundle()
        cache = LineCache(client: AnthropicClient(apiKey: key))
        llmOffline = key.trimmingCharacters(in: .whitespaces).isEmpty
        route = UserDefaults.standard.bool(forKey: "didOnboard") ? .home : .onboarding
        speech.voiceId = persona.voiceId
        voiceId = persona.voiceId
        if let savedLevel = UserDefaults.standard.string(forKey: "athlete.runnerLevel"),
           let level = RunnerLevel(rawValue: savedLevel) {
            runnerLevel = level
        }
        athleteHistory = AthleteHistoryBuilder.loadPersisted()
        distanceUnit = DistanceUnit.detect()
        ble.onDevices = { [weak self] list in
            Task { @MainActor in
                self?.bleDevices = list.map { (id: $0.0, name: $0.1) }
            }
        }
    }

    func persistProfile() {
        UserDefaults.standard.set(name, forKey: "athlete.name")
        UserDefaults.standard.set(age, forKey: "athlete.age")
        UserDefaults.standard.set(thresholdPace, forKey: "athlete.pace")
        UserDefaults.standard.set(sessionCap, forKey: "rally.cap")
        UserDefaults.standard.set(simulatorURLString, forKey: "sim.url")
        UserDefaults.standard.set(sourceKind.rawValue, forKey: "source.kind")
        if let hrMaxOverride { UserDefaults.standard.set(hrMaxOverride, forKey: "athlete.hrMax") }
        UserDefaults.standard.set(voiceId, forKey: "coach.voiceId")
        UserDefaults.standard.set(appearanceMode.rawValue, forKey: "ui.appearance")
    }

    func completeOnboarding() {
        didOnboard = true
        #if !targetEnvironment(simulator)
        sourceKind = .device
        #endif
        persistProfile()
        Task { @MainActor in
            _ = await health.requestAuthorization()
            healthAuthorized = true
        }
        route = .home
    }

    /// Kick location/motion prompts before the first outdoor run.
    func prepareDevicePermissions() {
        #if os(iOS)
        let loc = CLLocationManager()
        loc.requestWhenInUseAuthorization()
        if CMPedometer.isCadenceAvailable() || CMPedometer.isDistanceAvailable() {
            let pedo = CMPedometer()
            pedo.startUpdates(from: Date()) { _, _ in }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { pedo.stopUpdates() }
        }
        #endif
    }

    func refreshHistory(from sessions: [WorkoutSessionRecord]) {
        athleteHistory = AthleteHistoryBuilder.build(from: sessions)
        distanceUnit = DistanceUnit.detect()
    }

    func startWorkout() {
        guard startBlockedReason == nil else { return }
        // Physical phone product is Run. Never leave a leftover sim activity.
        #if !targetEnvironment(simulator)
        if sourceKind == .device { activity = .running }
        #endif
        if !activity.isShipped, sourceKind == .device { activity = .running }
        engine.reset(activity: activity, maxHR: hrMax, sessionCap: sessionCap)
        liveT = 0
        liveRisk = 0
        liveState = .cruising
        liveLocomotion = .moving
        liveLatest = [:]
        liveRallies = []
        livePaused = false
        liveDisconnected = false
        liveStartedAt = Date()
        lastTick = -1
        recentLines = []
        finishedAfterCritical = false
        spokenLine = nil
        speech.muted = muted
        trendTracker.reset()
        splitEngine.reset()
        latestReport = nil
        didFireOpeningPush = false
        lastHistoryCueKey = nil
        distanceUnit = DistanceUnit.detect()
        athleteHistory = AthleteHistoryBuilder.loadPersisted()
        LifetimePromptMemory.shared.beginRun()
        trendTracker.previousWorkoutMaxDistanceM = max(athleteHistory.previousQuitDistanceM, athleteHistory.longestDistanceM)
        trendTracker.thirtyDayFastestPace = athleteHistory.thirtyDayBestPaceSecPerKm > 0
            ? athleteHistory.thirtyDayBestPaceSecPerKm
            : 300
        speech.warmSession()

        // Phone sensors are the primary path. Universal BLE (Polar, Wahoo, Stryd, WHOOP, Garmin)
        // automatically layers live HR, cadence, and power onto the run telemetry.
        let supplements: [SupplementalHRSource] = [universalBle]
        if sourceKind == .simulator {
            let url = URL(string: simulatorURLString) ?? URL(string: "ws://127.0.0.1:7777/stream")!
            let sim = SimulatorDataSource(url: url)
            sim.persona = persona.id.rawValue
            sim.onConnectionChange = { [weak self] ok in
                Task { @MainActor in
                    self?.connectedToSim = ok
                    self?.liveDisconnected = !ok
                    if !ok { self?.livePaused = true }
                }
            }
            sim.onHello = { [weak self] _, act in
                Task { @MainActor in
                    guard let self else { return }
            // Lab / ride / row scenarios stay on Run. Phone product does not follow them.
                    if act.isShipped {
                        self.activity = act
                        self.engine.reset(activity: act, maxHR: self.hrMax, sessionCap: self.sessionCap)
                    }
                }
            }
            sim.onScenarioEnded = { [weak self] in
                Task { @MainActor in self?.endWorkout() }
            }
            simSource = sim
            deviceSource = nil
            sources.configure(primary: sim, supplements: [])
        } else {
            let dev = DeviceSensorDataSource()
            deviceSource = dev
            simSource = nil
            sources.configure(primary: dev, supplements: supplements)
            // Ask Health once so the finished run can save. Not used for live tracking.
            Task { @MainActor in
                if !self.healthAuthorized {
                    self.healthAuthorized = await self.health.requestAuthorization()
                }
            }
        }
        sources.onSample = { [weak self] sample in
            self?.ingest(sample)
        }
        sources.start()
        route = .live
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }

    func togglePause() {
        livePaused.toggle()
    }

    func endWorkout() {
        sources.stop()
        speech.stop()
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
        let ended = Date()
        let started = liveStartedAt ?? ended
        let distance = liveLatest[.distanceM] ?? 0
        let duration = liveT
        let elevationGain = trendTracker.totalElevationGainM
        let elevationLoss = trendTracker.totalElevationLossM
        let movingSec = trendTracker.movingDurationSec
        let rawAvgPace = distance > 0 ? (duration / distance) * 1000 : 0
        let avgGrade = distance > 0 ? ((elevationGain - elevationLoss) / distance) * 100 : 0
        let gapAvgPace = GradeAdjustedCalculator.gradeAdjustedPace(rawPaceSecPerKm: rawAvgPace, gradePercent: avgGrade)
        let splits = trendTracker.lapSplits
        let hrZones = trendTracker.computeHRZones(maxHR: hrMax)
        let breadcrumbs = trendTracker.breadcrumbs

        let unlockedPBs = PersonalBestStore.shared.evaluateSession(
            distanceM: distance,
            durationSec: duration,
            elevationGainM: elevationGain,
            splits: splits
        )

        let rec = WorkoutSessionRecord(
            startedAt: started,
            endedAt: ended,
            activityRaw: activity.rawValue,
            durationSec: duration,
            distanceM: distance,
            avgHR: liveLatest[.heartRateBpm],
            rallyCount: liveRallies.count,
            outputSpark: engine.store.sparkline(),
            rallies: liveRallies.map { RallyMomentRecord(t: $0.t, kindRaw: $0.kind.rawValue, text: $0.text, aftermath: $0.aftermath) },
            personaRaw: persona.id.rawValue,
            finishedAfterCritical: finishedAfterCritical,
            elevationGainM: elevationGain,
            elevationLossM: elevationLoss,
            movingDurationSec: movingSec,
            gapAveragePaceSecPerKm: gapAvgPace,
            splits: splits,
            hrZones: hrZones,
            routeCoordinates: breadcrumbs,
            personalBests: unlockedPBs
        )
        lastRecord = rec
        athleteHistory = AthleteHistoryBuilder.incorporateFinished(
            distanceM: distance,
            durationSec: duration,
            endedAt: ended,
            into: athleteHistory
        )
        Task { @MainActor in
            await hkWriter.save(session: rec)
            let report = await CoachReportGenerator.shared.generateReport(
                record: rec,
                persona: persona,
                runnerLevel: runnerLevel,
                client: AnthropicClient(apiKey: AnthropicClient.keyFromBundle())
            )
            self.latestReport = report
        }
        route = .summary(rec)
    }

    private func ingest(_ sample: MetricSample) {
        if livePaused { return }
        engine.ingest(sample)
        liveLatest[sample.kind] = sample.value
        let sec = floor(sample.timestamp)
        liveT = sample.timestamp
        if sec > lastTick {
            lastTick = sec
            tick(sec)
        }
    }

    private func tick(_ t: TimeInterval) {
        updateGoalDone()
        let result = engine.tick(t: t)
        liveRisk = result.risk
        liveState = result.state
        liveLocomotion = result.locomotion
        if result.state == .critical { finishedAfterCritical = true }

        let speed = liveLatest[.speedMps] ?? 0
        let hr = liveLatest[.heartRateBpm]
        let cadence = liveLatest[.cadenceSpm]
        let power = liveLatest[.powerWatts]
        let alt = liveLatest[.altitudeM]
        let grade = liveLatest[.gradePercent]
        let dist = liveLatest[.distanceM] ?? 0
        let lat = liveLatest[.latitude]
        let lon = liveLatest[.longitude]

        trendTracker.recordPoint(
            t: t,
            speedMps: speed,
            hrBpm: hr,
            maxHR: hrMax,
            cadenceSpm: cadence,
            powerWatts: power,
            altitudeM: alt,
            gradePercent: grade,
            latitude: lat,
            longitude: lon,
            cumulativeDistanceM: dist
        )

        // Evaluate closed-loop feedback from last intervention
        let currentPace = speed > 0.3 ? (1000.0 / speed) : 0
        if let evaluated = trendTracker.evaluatePendingInterventions(currentT: t, currentPace: currentPace) {
            if evaluated.result == .surged {
                // Positively reinforced
            }
        }

        // Periodic distance split callouts (km or mile by locale)
        if activity == .running,
           let splitLine = splitEngine.checkKilometerSplit(
               currentDistanceM: dist,
               currentElapsedT: t,
               persona: persona,
               currentPaceSecPerKm: currentPace,
               unit: distanceUnit
           ),
           !speech.speaking,
           result.trigger == nil {
            fireDirectSplitLine(DistanceUnitNormalizer.normalize(splitLine, to: distanceUnit), t: t)
            return
        }

        // First-minute history opening push (once). Window extends to 2 min so a slow
        // start / early stop doesn't permanently skip the initiation beat.
        if !didFireOpeningPush,
           activity == .running,
           t >= 8, t <= 120,
           !speech.speaking,
           result.trigger == nil,
           liveLocomotion != .stopped {
            didFireOpeningPush = true
            let opening = athleteHistory.openingPushLine(persona: persona, unit: distanceUnit)
            fireDirectSplitLine(opening, t: t)
            return
        }

        // Check for 34 milestone & telemetry states
        var targetDist: Double? = nil
        if case .distance(let m) = goal { targetDist = Double(m) }
        let milestone = trendTracker.evaluateMilestone(
            t: t,
            distanceM: dist,
            targetDistanceM: targetDist,
            speedMps: speed,
            hrBpm: hr,
            maxHR: hrMax,
            cadenceSpm: cadence,
            powerWatts: power,
            gradePercent: grade,
            engineState: result.state,
            locomotion: result.locomotion,
            lastSpokenT: lastSpokenTimestamp
        )

        let rawHistoryCue = athleteHistory.gatedCue(
            distanceM: dist,
            currentPaceSecPerKm: currentPace,
            milestone: milestone,
            engineState: result.state,
            elapsed: t
        )
        // Sticky until spoken: keep injecting a new cue until a line actually fires with it.
        let historyCue: String? = {
            guard let cue = rawHistoryCue, cue != lastHistoryCueKey else { return nil }
            return cue
        }()

        // Breakthrough history moments: shout immediately at the right time.
        if let cue = historyCue,
           athleteHistory.shouldSpeakDirectly(cue),
           !speech.speaking,
           result.trigger == nil,
           t - lastSpokenTimestamp >= 20 {
            lastHistoryCueKey = cue
            let beat = athleteHistory.spokenBeat(for: cue, persona: persona, unit: distanceUnit)
            fireDirectSplitLine(beat, t: t)
            return
        }

        let ctx = lineContext(snapshot: result.snapshot, t: t, milestone: milestone, historyCue: historyCue)
        cache.maybePrefetch(ctx: ctx, risk: result.risk)
        llmOffline = cache.llmOffline

        if let sim = simSource {
            if t - lastRiskReport >= 5 || result.state != lastRiskState {
                sim.sendRisk(t: t, score: result.risk, state: result.state)
                lastRiskReport = t
                lastRiskState = result.state
            }
        }

        if let kind = result.trigger {
            guard !speech.speaking else { return }
            fire(kind: kind, t: t, ctx: ctx, output: result.channels.output)
        } else if milestone != nil, !speech.speaking, (t - lastSpokenTimestamp >= 45) {
            fire(kind: .milestone, t: t, ctx: ctx, output: result.channels.output)
        }
    }

    private func fire(kind: TriggerKind, t: TimeInterval, ctx: LineContext, output: Double) {
        lastSpokenTimestamp = t
        if let cue = ctx.historyCue {
            lastHistoryCueKey = cue
        }
        let start = Date()
        let popped = cache.pop(kind: kind, ctx: ctx)
        let spokenText = DistanceUnitNormalizer.normalize(popped.text, to: distanceUnit)
        let latency = Int(Date().timeIntervalSince(start) * 1000)
        noteSpoken(spokenText)
        withAnimation(.easeInOut(duration: 0.2)) {
            spokenLine = spokenText
        }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif

        speech.prefetch(spokenText)

        let lineID = spokenText
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(8.0))
            if self.spokenLine == lineID {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.spokenLine = nil
                }
            }
        }

        let curSpeed = liveLatest[.speedMps] ?? 0
        let curPace = curSpeed > 0.3 ? (1000.0 / curSpeed) : 0
        trendTracker.recordIntervention(
            t: t,
            line: spokenText,
            trigger: kind,
            milestone: ctx.milestoneState,
            currentPace: curPace,
            cadence: liveLatest[.cadenceSpm],
            hr: liveLatest[.heartRateBpm]
        )

        speech.speak(spokenText, persona: persona) { [weak self] in
            guard let self else { return }
            self.engine.policy.noteSpeechEnded(t: self.liveT)
            self.simSource?.sendSpeechDone(t: self.liveT)
            let nextKind: TriggerKind = self.liveLocomotion == .stopped ? .stillStopped : .keepGoing
            let peek = FallbackLines.line(kind: nextKind, ctx: ctx)
            self.speech.prefetch(peek)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.0))
                if self.spokenLine == spokenText {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.spokenLine = nil
                    }
                }
            }
        }
        simSource?.sendTrigger(t: t, kind: kind, persona: persona.id.rawValue, text: spokenText, sourceLLM: popped.sourceLLM, latencyMs: latency)
        var moment = RallyMoment(t: t, kind: kind, text: spokenText, sourceLLM: popped.sourceLLM, latencyMs: latency, aftermath: "")
        moment.outputAtTrigger = output
        liveRallies.append(moment)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(40))
            await MainActor.run {
                guard let self else { return }
                if let later = self.engine.store.value(kind: MetricKind.speedMps, around: t, plus: 40) ?? self.engine.store.latest(MetricKind.speedMps),
                   let before = moment.outputAtTrigger, before > 0 {
                    let pct = Int(((later - before) / before) * 100)
                    let after = pct >= 0 ? "Pace recovered \(pct) % within 40 s" : "Still grinding."
                    if let idx = self.liveRallies.firstIndex(where: { $0.id == moment.id }) {
                        self.liveRallies[idx].aftermath = after
                    }
                }
            }
        }
    }

    private func fireDirectSplitLine(_ text: String, t: TimeInterval) {
        let spokenText = DistanceUnitNormalizer.normalize(text, to: distanceUnit)
        lastSpokenTimestamp = t
        noteSpoken(spokenText)
        withAnimation(.easeInOut(duration: 0.2)) {
            spokenLine = spokenText
        }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        speech.prefetch(spokenText)
        speech.speak(spokenText, persona: persona) { [weak self] in
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.0))
                if self?.spokenLine == spokenText {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self?.spokenLine = nil
                    }
                }
            }
        }
    }

    /// Track spoken text for in-run avoid + lifetime fingerprint memory.
    private func noteSpoken(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentLines.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentLines.append(trimmed)
        if recentLines.count > 12 {
            recentLines.removeFirst(recentLines.count - 12)
        }
        LifetimePromptMemory.shared.recordSpokenLine(trimmed)
    }

    private func updateGoalDone() {
        let done: Bool = {
            switch goal {
            case .distance(let m): return (liveLatest[.distanceM] ?? 0) >= m * EngineConstants.finalPushProgress
            case .duration(let s): return liveT >= s * EngineConstants.finalPushProgress
            case .rounds, .sets: return false
            }
        }()
        engine.setGoalDone(done)
    }

    private func lineContext(snapshot: String, t: TimeInterval, milestone: MilestoneState? = nil, historyCue: String? = nil) -> LineContext {
        let slope = trendTracker.paceSlope(windowSec: 60)
        let slopeDesc: String = {
            if slope < -8 { return "surging and accelerating faster" }
            if slope > 10 { return "fading and slowing down" }
            return "holding steady pace"
        }()

        return LineContext(
            activity: activity,
            elapsed: t,
            distanceM: liveLatest[.distanceM] ?? 0,
            goal: goal,
            snapshot: snapshot,
            prompt: selectedPrompt,
            name: name,
            intensityMaximum: engine.policy.intensityMaximum,
            recent: recentLines,
            persona: persona,
            progressLabel: progressLabel(),
            runnerLevel: runnerLevel,
            paceSlopeDescription: slopeDesc,
            milestoneState: milestone,
            closedLoopFeedback: trendTracker.lastClosedLoopDescription,
            distanceUnit: distanceUnit,
            athleteHistoryLines: athleteHistory.leanPromptLines,
            historyCue: historyCue
        )
    }

    func progressLabel() -> String {
        switch goal {
        case .distance(let m):
            let d = liveLatest[.distanceM] ?? 0
            let pct = m > 0 ? Int((d / m) * 100) : 0
            return "\(Formatters.km(d)) km of \(Formatters.km(m)) km goal (\(pct)%)"
        case .duration(let s):
            return "\(Formatters.clock(liveT)) of \(Formatters.clock(s))"
        case .rounds(let n):
            return "boxing · \(n) rounds"
        case .sets(let n):
            return "\(Int(liveLatest[.repCount] ?? 0)) reps · \(n) sets"
        }
    }

    func metricDisplay(_ kind: MetricKind) -> String {
        guard let v = liveLatest[kind] else { return "-" }
        switch kind {
        case .paceSecPerKm:
            if liveLocomotion == .stopped || (liveLatest[.speedMps] ?? 0) < EngineConstants.vStop {
                return "-"
            }
            return Formatters.pace(v)
        case .distanceM: return Formatters.km(v)
        case .heartRateBpm, .cadenceSpm, .strokeRateSpm, .punchRatePpm, .powerWatts, .repCount:
            return String(Int(v.rounded()))
        case .repVelocityMps, .speedMps, .motionIntensityG, .gradePercent:
            return String(format: "%.2f", v)
        case .activeEnergyKcal, .altitudeM:
            return String(Int(v.rounded()))
        case .motionStationary:
            return v >= 0.5 ? "still" : "move"
        case .latitude, .longitude:
            return String(format: "%.5f", v)
        }
    }
}

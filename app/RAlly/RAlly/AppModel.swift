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
    var persona: Persona = Persona.named(.southpaw)
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
    var muted = false
    var spokenLine: String?
    var connectedToSim = false
    var llmOffline = false
    var bleEnabled = false
    var bleDevices: [(id: UUID, name: String)] = []
    var healthAuthorized = false
    var nrcWorkoutCount = 0
    var voiceIdentifier: String? {
        didSet {
            speech.voiceIdentifier = voiceIdentifier
            if let voiceIdentifier {
                UserDefaults.standard.set(voiceIdentifier, forKey: "voice.id")
            } else {
                UserDefaults.standard.removeObject(forKey: "voice.id")
            }
        }
    }
    var voiceEngine: VoiceEngine = {
        if let raw = UserDefaults.standard.string(forKey: "voice.engine"),
           let e = VoiceEngine(rawValue: raw) {
            return e
        }
        return .auto
    }() {
        didSet {
            speech.voiceEngine = voiceEngine
            UserDefaults.standard.set(voiceEngine.rawValue, forKey: "voice.engine")
            speech.warmOnDeviceVoice(persona: persona)
        }
    }

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

    let engine = QuitRiskEngine()
    let sources = DataSourceManager()
    let speech = SpeechEngine()
    let ble = BLEHeartRateDataSource()
    let health = HealthKitDataSource()
    let strava = StravaClient()
    let hkWriter = HealthKitWriter()
    let cache: LineCache

    private var lastTick: TimeInterval = -1
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
            return "v1 is running on phone sensors. Ride and row need a strap — not this build."
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
        if let vid = UserDefaults.standard.string(forKey: "voice.id") {
            voiceIdentifier = vid
        }
        speech.voiceIdentifier = voiceIdentifier
        speech.voiceEngine = voiceEngine
        speech.warmOnDeviceVoice(persona: persona)
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
        UserDefaults.standard.set(didOnboard, forKey: "didOnboard")
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

        // Phone sensors are the primary path. BLE HR is optional. HealthKit HR is not
        // attached live unless a strap is on — otherwise Watch/Health lag would fake "live" HR.
        let supplements: [SupplementalHRSource] = bleEnabled ? [ble] : []
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
                    // Simulator may play ride/row for engine demos. Phone UI only ships Run.
                    if act.isContinuousEffort {
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
        speech.warmOnDeviceVoice(persona: persona)
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
        let rec = WorkoutSessionRecord(
            startedAt: started,
            endedAt: ended,
            activityRaw: activity.rawValue,
            durationSec: liveT,
            distanceM: liveLatest[.distanceM] ?? 0,
            avgHR: liveLatest[.heartRateBpm],
            rallyCount: liveRallies.count,
            outputSpark: engine.store.sparkline(),
            rallies: liveRallies.map { RallyMomentRecord(t: $0.t, kindRaw: $0.kind.rawValue, text: $0.text, aftermath: $0.aftermath) },
            personaRaw: persona.id.rawValue,
            finishedAfterCritical: finishedAfterCritical
        )
        lastRecord = rec
        Task { @MainActor in await hkWriter.save(session: rec) }
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

        let ctx = lineContext(snapshot: result.snapshot, t: t)
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
            // Never queue a new line while the previous one is still speaking.
            guard !speech.speaking else { return }
            fire(kind: kind, t: t, ctx: ctx, output: result.channels.output)
        }
    }

    private func fire(kind: TriggerKind, t: TimeInterval, ctx: LineContext, output: Double) {
        let start = Date()
        let popped = cache.pop(kind: kind, ctx: ctx)
        let latency = Int(Date().timeIntervalSince(start) * 1000)
        recentLines.append(popped.text)
        if recentLines.count > 5 { recentLines.removeFirst(recentLines.count - 5) }
        spokenLine = popped.text
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
        speech.speak(popped.text, persona: persona) { [weak self] in
            guard let self else { return }
            self.engine.policy.noteSpeechEnded(t: self.liveT)
            self.simSource?.sendSpeechDone(t: self.liveT)
            // Prefetch a likely next line during the breath window (on-device only).
            let nextKind: TriggerKind = self.liveLocomotion == .stopped ? .stillStopped : .keepGoing
            let peek = FallbackLines.line(kind: nextKind, ctx: ctx)
            self.speech.prefetch(peek, persona: self.persona)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                if self.spokenLine == popped.text { self.spokenLine = nil }
            }
        }
        simSource?.sendTrigger(t: t, kind: kind, persona: persona.id.rawValue, text: popped.text, sourceLLM: popped.sourceLLM, latencyMs: latency)
        var moment = RallyMoment(t: t, kind: kind, text: popped.text, sourceLLM: popped.sourceLLM, latencyMs: latency, aftermath: "")
        moment.outputAtTrigger = output
        liveRallies.append(moment)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(40))
            await MainActor.run {
                guard let self else { return }
                if let later = self.engine.store.value(kind: .speedMps, around: t, plus: 40) ?? self.engine.store.latest(.speedMps),
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

    private func lineContext(snapshot: String, t: TimeInterval) -> LineContext {
        LineContext(
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
            progressLabel: progressLabel()
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
        guard let v = liveLatest[kind] else { return "–" }
        switch kind {
        case .paceSecPerKm: return Formatters.pace(v)
        case .distanceM: return Formatters.km(v)
        case .heartRateBpm, .cadenceSpm, .strokeRateSpm, .punchRatePpm, .powerWatts, .repCount:
            return String(Int(v.rounded()))
        case .repVelocityMps, .speedMps, .motionIntensityG, .gradePercent:
            return String(format: "%.2f", v)
        case .activeEnergyKcal, .altitudeM:
            return String(Int(v.rounded()))
        case .motionStationary:
            return v >= 0.5 ? "still" : "move"
        }
    }
}

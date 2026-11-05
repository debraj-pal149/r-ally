import Foundation
import Mixpanel

/// One Mixpanel client. Debug and Release each carry a single project token from the build.
///
/// Guest installs identify with a local anonymous UUID. On Firebase sign-in we identify
/// with the account uid; on sign-out / delete we reset back to anonymous.
/// `device_paired` is intentionally not sent until wearable pairing works.
@MainActor
enum RallyAnalytics {
    private static var started = false
    private static var configured = false
    private static var memory = AnalyticsMemory.new(now: Date())

    static var isOptedOut: Bool {
        UserDefaults.standard.bool(forKey: AccountKeys.analyticsOptOut)
    }

    static func start() {
        guard !started else { return }
        started = true
        memory = AnalyticsStore.load()
        AnalyticsStore.save(memory)
        guard !isOptedOut else { return }
        bootstrapMixpanel()
    }

    /// Corner toggle. Opting out clears the Mixpanel identity; opting back in restarts it.
    static func setOptOut(_ optedOut: Bool) {
        let previous = isOptedOut
        UserDefaults.standard.set(optedOut, forKey: AccountKeys.analyticsOptOut)
        guard previous != optedOut else { return }
        if optedOut {
            if configured {
                Mixpanel.mainInstance().optOutTracking()
                Mixpanel.mainInstance().reset()
            }
            configured = false
            started = true
        } else {
            configured = false
            started = false
            start()
            if let uid = UserDefaults.standard.string(forKey: AccountKeys.ownerUid), !uid.isEmpty {
                identifyAccount(uid: uid)
            }
        }
    }

    private static func bootstrapMixpanel() {
        let token = bundleToken()
        guard !token.isEmpty else { return }
        let instance = Mixpanel.initialize(token: token, trackAutomaticEvents: false)
        instance.loggingEnabled = false
        instance.optInTracking()
        let accountId = UserDefaults.standard.string(forKey: AccountKeys.ownerUid)
        instance.identify(distinctId: accountId ?? memory.anonymousId)
        instance.registerSuperProperties([
            "app_version": appVersion,
            "build_type": buildType,
            "auth_state": accountId == nil ? "local" : "account",
        ])
        configured = true
    }

    static func identifyAccount(uid: String?) {
        guard !isOptedOut else { return }
        guard configured, let uid, !uid.isEmpty else { return }
        let instance = Mixpanel.mainInstance()
        instance.identify(distinctId: uid)
        instance.registerSuperProperties(["auth_state": "account"])
        setPeople(["auth_uid": uid])
        flush()
    }

    static func resetIdentity() {
        guard !isOptedOut else { return }
        guard configured else { return }
        let instance = Mixpanel.mainInstance()
        instance.reset()
        instance.identify(distinctId: memory.anonymousId)
        instance.registerSuperProperties([
            "app_version": appVersion,
            "build_type": buildType,
            "auth_state": "local",
        ])
        flush()
    }

    static func sync(persona: String, runnerLevel: String, hasWeight: Bool, stravaConnected: Bool) {
        var props: [String: MixpanelType] = [
            "onboarding_completed": memory.onboardingCompleted,
            "activated": memory.activated,
            "finished_workout_count": memory.finishedWorkoutCount,
            "persona": persona,
            "runner_level": runnerLevel,
            "has_weight": hasWeight,
            "strava_connected": stravaConnected,
        ]
        if let healthGranted = memory.healthGranted {
            props["health_authorized"] = healthGranted
        }
        if let lastWorkoutAt = memory.lastWorkoutAt {
            props["last_workout_at"] = lastWorkoutAt
        }
        if let lastQualifyingWorkoutAt = memory.lastQualifyingWorkoutAt {
            props["last_qualifying_workout_at"] = lastQualifyingWorkoutAt
        }
        setPeople(props)
    }

    static func onboardingCompleted(persona: String, hasName: Bool, hasWeight: Bool) {
        memory.onboardingCompleted = true
        let fire = memory.noteReadyForActivation()
        AnalyticsStore.save(memory)
        track("onboarding_completed", [
            "persona": persona,
            "has_name": hasName,
            "has_weight": hasWeight,
        ])
        setPeople([
            "onboarding_completed": true,
            "persona": persona,
            "has_weight": hasWeight,
        ])
        if fire { emitActivated() }
    }

    static func workoutStarted(persona: String, goalMeters: Double, runnerLevel: String, unit: String) {
        memory.workoutStarted = true
        let fire = memory.noteReadyForActivation()
        AnalyticsStore.save(memory)
        track("workout_started", [
            "persona": persona,
            "goal_m": goalMeters,
            "runner_level": runnerLevel,
            "unit": unit,
        ])
        setPeople([
            "persona": persona,
            "runner_level": runnerLevel,
        ])
        if fire { emitActivated() }
    }

    static func workoutFinished(
        activeSec: TimeInterval,
        distanceM: Double,
        paceSecPerKm: Double,
        kcal: Double,
        rallyCount: Int,
        persona: String,
        pbCount: Int,
        hadGPS: Bool,
        finishedAfterCritical: Bool
    ) {
        let now = Date()
        memory.workoutFinished = true
        memory.finishedWorkoutCount += 1
        memory.lastWorkoutAt = now
        if AnalyticsMemory.isQualifyingWorkout(activeSeconds: activeSec) {
            memory.lastQualifyingWorkoutAt = now
        }
        let fire = memory.noteReadyForActivation()
        AnalyticsStore.save(memory)
        track("workout_finished", [
            "active_sec": activeSec,
            "distance_m": distanceM,
            "pace_sec_per_km": paceSecPerKm,
            "kcal": kcal,
            "rally_count": rallyCount,
            "persona": persona,
            "pb_count": pbCount,
            "had_gps": hadGPS,
            "finished_after_critical": finishedAfterCritical,
        ])
        var people: [String: MixpanelType] = [
            "finished_workout_count": memory.finishedWorkoutCount,
            "last_workout_at": now,
            "persona": persona,
        ]
        if memory.lastQualifyingWorkoutAt == now {
            people["last_qualifying_workout_at"] = now
        }
        setPeople(people)
        flush()
        if fire { emitActivated() }
    }

    static func pauseChanged(paused: Bool) {
        track("workout_pause_changed", ["paused": paused])
    }

    static func muteChanged(muted: Bool) {
        track("coach_mute_changed", ["muted": muted])
    }

    static func personaChanged(persona: String, previous: String, source: String) {
        track("persona_changed", [
            "persona": persona,
            "previous": previous,
            "source": source,
        ])
        setPeople(["persona": persona])
    }

    static func shareCardReady(theme: String, format: String) {
        track("share_card_ready", [
            "theme": theme,
            "format": format,
        ])
    }

    static func coachReportReady(grade: String, source: String) {
        track("coach_report_ready", [
            "grade": grade,
            "source": source,
        ])
    }

    static func healthSaved(source: String) {
        track("health_saved", ["source": source])
    }

    static func healthPermission(granted: Bool) {
        let changed = memory.noteHealthPermission(granted: granted)
        AnalyticsStore.save(memory)
        guard changed else { return }
        track("health_permission_result", ["granted": granted])
        setPeople(["health_authorized": granted])
    }

    static func stravaConnect(ok: Bool) {
        track("strava_connect_result", ["ok": ok])
        if ok { setPeople(["strava_connected": true]) }
    }

    static func stravaDisconnected() {
        track("strava_disconnected")
        setPeople(["strava_connected": false])
    }

    static func stravaUpload(ok: Bool) {
        track("strava_upload_result", ["ok": ok])
    }

    static func noteWeight(hasWeight: Bool) {
        setPeople(["has_weight": hasWeight])
    }

    static func noteRunnerLevel(_ level: String) {
        setPeople(["runner_level": level])
    }

    private static func emitActivated() {
        let days = AnalyticsMemory.daysSinceInstall(
            installAt: memory.installAt,
            now: Date(),
            calendar: .current
        )
        track("activated", ["days_since_install": days])
        setPeople(["activated": true])
        flush()
    }

    private static func track(_ name: String, _ properties: [String: MixpanelType] = [:]) {
        guard !isOptedOut, configured else { return }
        Mixpanel.mainInstance().track(event: name, properties: properties)
    }

    private static func setPeople(_ properties: [String: MixpanelType]) {
        guard !isOptedOut, configured else { return }
        Mixpanel.mainInstance().people.set(properties: properties)
    }

    private static func flush() {
        guard !isOptedOut, configured else { return }
        Mixpanel.mainInstance().flush()
    }

    private static func bundleToken() -> String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "MIXPANEL_TOKEN") as? String) ?? ""
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !token.contains("$"), token.count >= 16 else { return "" }
        return token
    }

    private static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(short) (\(build))"
    }

    private static var buildType: String {
        #if DEBUG
        "debug"
        #else
        "release"
        #endif
    }
}

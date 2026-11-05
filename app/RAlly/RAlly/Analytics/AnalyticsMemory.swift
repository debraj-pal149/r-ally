import Foundation

/// Local facts Rally needs before it can decide whether to send `activated`.
struct AnalyticsMemory: Codable, Equatable, Sendable {
    var anonymousId: String
    var installAt: Date
    var onboardingCompleted: Bool
    var workoutStarted: Bool
    var workoutFinished: Bool
    var activated: Bool
    var finishedWorkoutCount: Int
    var healthGranted: Bool?
    var lastWorkoutAt: Date?
    var lastQualifyingWorkoutAt: Date?

    static let qualifyingActiveSeconds: TimeInterval = 60

    static func new(now: Date) -> AnalyticsMemory {
        AnalyticsMemory(
            anonymousId: UUID().uuidString,
            installAt: now,
            onboardingCompleted: false,
            workoutStarted: false,
            workoutFinished: false,
            activated: false,
            finishedWorkoutCount: 0,
            healthGranted: nil,
            lastWorkoutAt: nil,
            lastQualifyingWorkoutAt: nil
        )
    }

    static func daysSinceInstall(installAt: Date, now: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: installAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        return max(0, days)
    }

    static func isQualifyingWorkout(activeSeconds: TimeInterval) -> Bool {
        activeSeconds >= qualifyingActiveSeconds
    }

    /// True when this permission result is new. Repeat reads of the same answer stay quiet.
    mutating func noteHealthPermission(granted: Bool) -> Bool {
        let changed = healthGranted != granted
        healthGranted = granted
        return changed
    }

    /// True only the first time onboarding, a start, and a finish are all recorded.
    mutating func noteReadyForActivation() -> Bool {
        let ready = onboardingCompleted && workoutStarted && workoutFinished && !activated
        if ready { activated = true }
        return ready
    }
}

enum AnalyticsStore {
    private static let key = "rally.analytics.v1"

    static func load(now: Date = Date(), defaults: UserDefaults = .standard) -> AnalyticsMemory {
        var memory: AnalyticsMemory
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AnalyticsMemory.self, from: data) {
            memory = decoded
        } else {
            memory = .new(now: now)
        }
        if defaults.bool(forKey: "didOnboard") {
            memory.onboardingCompleted = true
        }
        return memory
    }

    static func save(_ memory: AnalyticsMemory, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        defaults.set(data, forKey: key)
    }
}

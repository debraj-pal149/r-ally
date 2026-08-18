import Foundation

enum ActivityKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case running, cycling, strength, boxing, swimming, rowing, hiit
    var id: String { rawValue }

    var title: String {
        switch self {
        case .running: "Running"
        case .cycling: "Cycling"
        case .strength: "Strength"
        case .boxing: "Boxing"
        case .swimming: "Swimming"
        case .rowing: "Rowing"
        case .hiit: "HIIT"
        }
    }

    var symbol: String {
        switch self {
        case .running: "figure.run"
        case .cycling: "figure.outdoor.cycle"
        case .strength: "dumbbell.fill"
        case .boxing: "figure.boxing"
        case .swimming: "figure.pool.swim"
        case .rowing: "figure.rower"
        case .hiit: "figure.highintensity.intervaltraining"
        }
    }

    var defaultGoal: WorkoutGoal {
        switch self {
        case .running: .distance(meters: 5000)
        case .cycling: .distance(meters: 20000)
        case .strength: .sets(5)
        case .boxing: .rounds(6)
        case .swimming: .distance(meters: 1500)
        case .rowing: .distance(meters: 2000)
        case .hiit: .duration(seconds: 1200)
        }
    }

    var promptChips: [String] {
        switch self {
        case .running:
            [
                "Remind me why I started",
                "I'm training for my first 10K",
                "Talk to me like it's the last round",
                "Tell me my legs are strong",
                "I run to be a good example for my kids",
                "Don't let me negotiate with myself",
            ]
        case .cycling:
            [
                "Remind me why I clipped in",
                "Hold this wattage",
                "This climb is mine",
                "Don't let the wind win",
                "I ride to get stronger",
            ]
        case .strength:
            [
                "One more clean rep",
                "Don't rack it early",
                "Trust the bar",
                "This is the working set",
                "Stay tight, stay mean",
            ]
        case .boxing:
            [
                "Last round energy",
                "Hands up, chin down",
                "Don't drop those hands",
                "This round is yours",
                "Keep throwing",
            ]
        case .swimming:
            [
                "Long and strong",
                "Find the water",
                "One more length",
                "Breathe and commit",
                "Don't fade in the last 200",
            ]
        case .rowing:
            [
                "Legs then body then arms",
                "Hold the split",
                "Don't dump the finish",
                "This 500 is yours",
                "Stay on the paddle",
            ]
        case .hiit:
            [
                "Survive this interval",
                "Don't quit on the rest",
                "Empty the tank",
                "Next work bout is yours",
                "Stay in the burn",
            ]
        }
    }

    var tileKinds: [MetricKind] {
        switch self {
        case .running: [.paceSecPerKm, .distanceM, .cadenceSpm]
        case .cycling: [.powerWatts, .distanceM, .cadenceSpm]
        case .strength: [.repCount, .repVelocityMps, .heartRateBpm]
        case .boxing: [.punchRatePpm, .heartRateBpm, .activeEnergyKcal]
        case .swimming: [.distanceM, .paceSecPerKm, .strokeRateSpm]
        case .rowing: [.powerWatts, .distanceM, .strokeRateSpm]
        case .hiit: [.motionIntensityG, .heartRateBpm, .activeEnergyKcal]
        }
    }

    func makeAdapter() -> any ActivityAdapter {
        switch self {
        case .running: RunningAdapter()
        case .cycling: CyclingAdapter()
        case .strength: StrengthAdapter()
        case .boxing: BoxingAdapter()
        case .swimming: SwimmingAdapter()
        case .rowing: RowingAdapter()
        case .hiit: HIITAdapter()
        }
    }
}

enum WorkoutGoal: Equatable, Sendable {
    case distance(meters: Double)
    case duration(seconds: Double)
    case rounds(Int)
    case sets(Int)

    var progressUnit: String {
        switch self {
        case .distance: "km"
        case .duration: "min"
        case .rounds: "rounds"
        case .sets: "sets"
        }
    }
}

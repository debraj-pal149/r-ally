import Foundation

enum ActivityKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case running, cycling, rowing
    /// Parked. Selectable nowhere in v1. Decoder keeps old history from exploding.
    case strength, boxing, swimming, hiit

    var id: String { rawValue }

    /// Sports where fade has a real physical signature *and* we can shout into an earbud.
    /// Phone-sensor product: running only. Ride/row stay decodeable for sim/history but need HR/power.
    static let shipped: [ActivityKind] = [.running]

    /// Engine still knows these; simulator and old sessions may reference them.
    static let continuousEffort: [ActivityKind] = [.running, .cycling, .rowing]

    var isShipped: Bool { Self.shipped.contains(self) }

    var isContinuousEffort: Bool { Self.continuousEffort.contains(self) }

    /// Cycling GPS speed cannot tell a climb from a bonk. Rowing split without watts is a guess.
    var needsEffortSensor: Bool {
        self == .cycling || self == .rowing
    }

    var title: String {
        switch self {
        case .running: "Run"
        case .cycling: "Ride"
        case .rowing: "Row"
        case .strength: "Strength"
        case .boxing: "Boxing"
        case .swimming: "Swim"
        case .hiit: "HIIT"
        }
    }

    var symbol: String {
        switch self {
        case .running: "figure.run"
        case .cycling: "figure.outdoor.cycle"
        case .rowing: "figure.rower"
        case .strength: "dumbbell.fill"
        case .boxing: "figure.boxing"
        case .swimming: "figure.pool.swim"
        case .hiit: "figure.highintensity.intervaltraining"
        }
    }

    var defaultGoal: WorkoutGoal {
        switch self {
        case .running: .distance(meters: 5000)
        case .cycling: .distance(meters: 20000)
        case .rowing: .distance(meters: 2000)
        case .strength: .sets(5)
        case .boxing: .rounds(6)
        case .swimming: .distance(meters: 1500)
        case .hiit: .duration(seconds: 1200)
        }
    }

    var promptChips: [String] {
        switch self {
        case .running:
            [
                "Don't let me negotiate with myself",
                "Remind me why I started",
                "I'm training for my first 10K",
                "Talk to me like it's the last mile",
                "Tell me my legs are strong",
                "I run to be a good example for my kids",
            ]
        case .cycling:
            [
                "Hold this wattage",
                "This climb is mine",
                "Don't let the wind win",
                "Remind me why I clipped in",
            ]
        case .rowing:
            [
                "Hold the split",
                "Legs then body then arms",
                "This 500 is yours",
                "Don't dump the finish",
            ]
        default:
            []
        }
    }

    var tileKinds: [MetricKind] {
        switch self {
        case .running: [.paceSecPerKm, .distanceM, .cadenceSpm]
        case .cycling: [.powerWatts, .distanceM, .heartRateBpm]
        case .rowing: [.powerWatts, .distanceM, .strokeRateSpm]
        default: [.heartRateBpm, .distanceM]
        }
    }

    func makeAdapter() -> any ActivityAdapter {
        switch self {
        case .running: RunningAdapter()
        case .cycling: CyclingAdapter()
        case .rowing: RowingAdapter()
        case .strength, .boxing, .swimming, .hiit:
            SilentLabAdapter()
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

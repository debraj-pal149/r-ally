import Foundation

// Parked v2 sports. Not compiled into the v1 target.
// See future/v2/README.md — these need a schedule-adherence engine, not fade detection.

enum ActivityKindV2: String, CaseIterable {
    case strength, boxing, swimming, hiit

    var title: String {
        switch self {
        case .strength: "Strength"
        case .boxing: "Boxing"
        case .swimming: "Swimming"
        case .hiit: "HIIT"
        }
    }

    var symbol: String {
        switch self {
        case .strength: "dumbbell.fill"
        case .boxing: "figure.boxing"
        case .swimming: "figure.pool.swim"
        case .hiit: "figure.highintensity.intervaltraining"
        }
    }

    var v2Mechanic: String {
        switch self {
        case .strength: "Rest-creep coach. Declared sets + rest timer. Never shout during programmed rest."
        case .boxing: "Round clock. Shout when round N+1 doesn't start, or motion halves vs early rounds."
        case .swimming: "Cut. Phone isn't on the body and TTS cannot reach the athlete underwater."
        case .hiit: "Interval clock. Shout when the next work bout is late, or intensity is half the session baseline."
        }
    }
}

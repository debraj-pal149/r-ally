import SwiftUI

struct GoalRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Goal")
                switch model.activity {
                case .running, .cycling, .swimming, .rowing:
                    GoalStepper(label: String(format: "%.1f km", km), onMinus: {
                        model.goal = .distance(meters: max(0.5, km - 0.5) * 1000)
                    }, onPlus: {
                        model.goal = .distance(meters: (km + 0.5) * 1000)
                    })
                case .boxing:
                    GoalStepper(label: "\(rounds) rounds", onMinus: {
                        model.goal = .rounds(max(1, rounds - 1))
                    }, onPlus: {
                        model.goal = .rounds(min(12, rounds + 1))
                    })
                case .strength:
                    GoalStepper(label: "\(sets) sets", onMinus: {
                        model.goal = .sets(max(1, sets - 1))
                    }, onPlus: {
                        model.goal = .sets(min(10, sets + 1))
                    })
                case .hiit:
                    GoalStepper(label: "\(mins) min", onMinus: {
                        model.goal = .duration(seconds: Double(max(5, mins - 5) * 60))
                    }, onPlus: {
                        model.goal = .duration(seconds: Double(min(90, mins + 5) * 60))
                    })
                }
            }
        }
    }

    private var km: Double {
        if case .distance(let m) = model.goal { return m / 1000 }
        return 5
    }
    private var rounds: Int {
        if case .rounds(let n) = model.goal { return n }
        return 6
    }
    private var sets: Int {
        if case .sets(let n) = model.goal { return n }
        return 5
    }
    private var mins: Int {
        if case .duration(let s) = model.goal { return Int(s / 60) }
        return 20
    }
}

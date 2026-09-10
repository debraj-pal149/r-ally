import SwiftUI

struct GoalRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Distance")
                GoalStepper(label: distanceLabel, onMinus: {
                    bump(-0.5)
                }, onPlus: {
                    bump(0.5)
                })
            }
        }
    }

    private func bump(_ delta: Double) {
        let unitMeters: Double = model.distanceUnit == .mile ? 1609.344 : 1000
        let next = max(0.5 * unitMeters, currentMeters + delta * unitMeters)
        model.goal = .distance(meters: next)
    }

    private var currentMeters: Double {
        if case .distance(let m) = model.goal { return m }
        switch model.activity {
        case .cycling: return 20_000
        case .rowing: return 2_000
        default: return 5_000
        }
    }

    private var distanceLabel: String {
        switch model.distanceUnit {
        case .kilometre:
            return String(format: "%.1f km", currentMeters / 1000)
        case .mile:
            return String(format: "%.1f mi", currentMeters / 1609.344)
        }
    }
}

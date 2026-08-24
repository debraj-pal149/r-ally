import SwiftUI

struct GoalRow: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Distance")
                GoalStepper(label: String(format: "%.1f km", km), onMinus: {
                    model.goal = .distance(meters: max(0.5, km - 0.5) * 1000)
                }, onPlus: {
                    model.goal = .distance(meters: (km + 0.5) * 1000)
                })
            }
        }
    }

    private var km: Double {
        if case .distance(let m) = model.goal { return m / 1000 }
        switch model.activity {
        case .cycling: return 20
        case .rowing: return 2
        default: return 5
        }
    }
}

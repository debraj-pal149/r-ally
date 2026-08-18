import SwiftUI

struct MetricTiles: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(model.activity.tileKinds.enumerated()), id: \.element) { i, kind in
                if i > 0 {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(width: 1, height: 36)
                }
                VStack(spacing: 6) {
                    Text(model.metricDisplay(kind))
                        .font(Theme.numeric(26, .bold))
                        .monospacedDigit()
                    Text(label(kind))
                        .font(Theme.label(10, .semibold))
                        .tracking(1.6)
                        .foregroundStyle(Theme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(label(kind)) \(model.metricDisplay(kind))")
            }
        }
        .foregroundStyle(Theme.textPrimary)
    }

    func label(_ k: MetricKind) -> String {
        switch k {
        case .paceSecPerKm: "PACE"
        case .distanceM: "KM"
        case .cadenceSpm: "CADENCE"
        case .powerWatts: "WATTS"
        case .heartRateBpm: "HR"
        case .repCount: "REPS"
        case .repVelocityMps: "VEL"
        case .punchRatePpm: "PUNCH"
        case .strokeRateSpm: "STROKE"
        case .motionIntensityG: "MOTION"
        case .activeEnergyKcal: "KCAL"
        default: k.rawValue.uppercased()
        }
    }
}

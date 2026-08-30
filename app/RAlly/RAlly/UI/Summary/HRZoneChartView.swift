import SwiftUI

struct HRZoneChartView: View {
    let zones: [HRZoneBucket]

    private func colorForZone(_ index: Int) -> Color {
        switch index {
        case 1: return Color.blue
        case 2: return Color.teal
        case 3: return Color.yellow
        case 4: return Color.orange
        case 5: return Theme.accentRed
        default: return Theme.accent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HEART RATE ZONES")
                    .font(Theme.font(size: 11, weight: .black))
                    .tracking(1.5)
                    .foregroundColor(Theme.secondaryText)
                Spacer()
                Text("Z1 – Z5 DISTRIBUTION")
                    .font(Theme.font(size: 10, weight: .bold))
                    .foregroundColor(Theme.secondaryText.opacity(0.8))
            }

            if zones.isEmpty || zones.allSatisfy({ $0.durationSec == 0 }) {
                Text("No continuous heart rate data captured for this workout.")
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(zones) { zone in
                        VStack(spacing: 4) {
                            HStack {
                                Text("Z\(zone.zoneIndex)  \(zone.name.uppercased())")
                                    .font(Theme.font(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(zone.rangeBpm)
                                    .font(Theme.font(size: 10, weight: .regular))
                                    .foregroundColor(Theme.secondaryText)
                                Text(Formatters.clock(zone.durationSec))
                                    .font(Theme.font(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 50, alignment: .trailing)
                                Text(String(format: "%.0f%%", zone.percentage))
                                    .font(Theme.font(size: 11, weight: .bold))
                                    .foregroundColor(colorForZone(zone.zoneIndex))
                                    .frame(width: 38, alignment: .trailing)
                            }

                            // Horizontal Bar
                            GeometryReader { geo in
                                let fillWidth = max(2, geo.size.width * CGFloat(zone.percentage / 100.0))
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                    Capsule()
                                        .fill(colorForZone(zone.zoneIndex))
                                        .frame(width: fillWidth)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }
}

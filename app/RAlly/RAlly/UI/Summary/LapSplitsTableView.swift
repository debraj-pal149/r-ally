import SwiftUI

struct LapSplitsTableView: View {
    let splits: [LapSplitRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SPLITS")
                    .font(Theme.font(size: 11, weight: .black))
                    .tracking(1.5)
                    .foregroundColor(Theme.secondaryText)
                Spacer()
                Text("1 KM INTERVALS")
                    .font(Theme.font(size: 10, weight: .bold))
                    .foregroundColor(Theme.secondaryText.opacity(0.8))
            }

            if splits.isEmpty {
                Text("No full kilometer splits completed.")
                    .font(Theme.font(size: 12, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                let fastestPace = splits.map(\.paceSecPerKm).min() ?? 300
                let slowestPace = splits.map(\.paceSecPerKm).max() ?? 400

                VStack(spacing: 8) {
                    // Header Row
                    HStack {
                        Text("KM")
                            .frame(width: 32, alignment: .leading)
                        Text("PACE")
                            .frame(width: 60, alignment: .leading)
                        Text("GAP")
                            .frame(width: 55, alignment: .leading)
                        Spacer()
                        Text("ELEV")
                            .frame(width: 45, alignment: .trailing)
                        Text("HR")
                            .frame(width: 45, alignment: .trailing)
                    }
                    .font(Theme.font(size: 10, weight: .bold))
                    .foregroundColor(Theme.secondaryText)

                    Divider().background(Theme.cardBorder)

                    ForEach(splits) { split in
                        HStack {
                            Text("\(split.splitNumber)")
                                .font(Theme.font(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, alignment: .leading)

                            HStack(spacing: 4) {
                                Text(Formatters.pace(split.paceSecPerKm))
                                    .font(Theme.font(size: 13, weight: .bold))
                                    .foregroundColor(split.paceSecPerKm == fastestPace ? Theme.accent : .white)
                            }
                            .frame(width: 60, alignment: .leading)

                            Text(Formatters.pace(split.gapPaceSecPerKm))
                                .font(Theme.font(size: 12, weight: .regular))
                                .foregroundColor(Theme.secondaryText)
                                .frame(width: 55, alignment: .leading)

                            // Relative Pace Bar
                            GeometryReader { geo in
                                let range = max(1.0, slowestPace - fastestPace)
                                let fillRatio = 1.0 - ((split.paceSecPerKm - fastestPace) / range)
                                let barWidth = max(8, geo.size.width * CGFloat(fillRatio))

                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                    Capsule()
                                        .fill(split.paceSecPerKm == fastestPace ? Theme.accent : Color.white.opacity(0.4))
                                        .frame(width: barWidth)
                                }
                            }
                            .frame(height: 6)
                            .padding(.horizontal, 4)

                            // Elevation Delta
                            Text(String(format: "%+.0fm", split.elevationDeltaM))
                                .font(Theme.font(size: 11, weight: .medium))
                                .foregroundColor(split.elevationDeltaM >= 0 ? Color.green : Color.red.opacity(0.8))
                                .frame(width: 45, alignment: .trailing)

                            // Average Heart Rate
                            Text(split.avgHR.map { "\(Int($0))" } ?? "--")
                                .font(Theme.font(size: 12, weight: .bold))
                                .foregroundColor(split.avgHR != nil ? Theme.accentRed : Theme.secondaryText)
                                .frame(width: 45, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
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

import SwiftUI

struct CoachReportShareCard: View {
    var record: WorkoutSessionRecord
    var report: CoachFieldReport
    var persona: Persona

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Persona Brand
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("R·ALLY COACH DEBRIEF")
                        .font(Theme.label(10, .bold))
                        .tracking(2.0)
                        .foregroundStyle(Theme.emberSoft)
                    Text(persona.name.uppercased())
                        .font(Theme.headline(16, .bold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.surfaceRaised)
                        .frame(width: 44, height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.hairline, lineWidth: 1))
                    Text(report.athleteGrade)
                        .font(Theme.headline(18, .bold))
                        .foregroundStyle(Theme.pulse)
                }
            }

            Divider().overlay(Theme.hairline)

            // Primary Metrics Grid
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("DISTANCE")
                        .font(Theme.label(9))
                        .foregroundStyle(Theme.textMuted)
                    Text(Formatters.km(record.distanceM))
                        .font(Theme.display(24))
                        .foregroundStyle(Theme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("TIME")
                        .font(Theme.label(9))
                        .foregroundStyle(Theme.textMuted)
                    Text(Formatters.clock(record.durationSec))
                        .font(Theme.display(24))
                        .foregroundStyle(Theme.textPrimary)
                }
                if let hr = record.avgHR {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("AVG HR")
                            .font(Theme.label(9))
                            .foregroundStyle(Theme.textMuted)
                        Text("\(Int(hr)) bpm")
                            .font(Theme.display(24))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }
            }

            // Headline & Debrief
            VStack(alignment: .leading, spacing: 6) {
                Text(report.headline)
                    .font(Theme.headline(14, .bold))
                    .foregroundStyle(Theme.emberSoft)
                Text(report.debrief)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(2)
            }

            // Coach Quote Callout
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Theme.ember)
                    .frame(width: 3)
                Text("\"\(report.coachQuote)\"")
                    .font(Theme.body(12, .medium))
                    .italic()
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.vertical, 4)

            // Footer
            HStack {
                Text("RUN WITH R·ALLY")
                    .font(Theme.label(9, .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textMuted)
                Spacer()
                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(Theme.label(9))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(20)
        .background(
            ZStack {
                Theme.surface
                Atmosphere(intensity: 0.4)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
    }
}

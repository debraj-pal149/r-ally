import SwiftUI

struct WorkoutDetailView: View {
    let session: WorkoutSessionRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerCard
                    
                    // Pace-Gradient Route Map
                    PaceGradientMapView(coordinates: session.routeCoordinates)
                        .frame(height: 240)

                    // Personal Bests Achieved in this session
                    if !session.personalBests.isEmpty {
                        sessionPBSection
                    }

                    // Coach's Field Report Card (if generated)
                    if let headline = session.reportHeadline,
                       let debrief = session.reportDebrief,
                       let quote = session.reportQuote,
                       let grade = session.reportGrade {
                        let persona = Persona.all.first(where: { $0.id.rawValue == session.personaRaw }) ?? Persona.named(.sarge)
                        let report = CoachFieldReport(
                            headline: headline,
                            debrief: debrief,
                            turningPointText: debrief,
                            athleteGrade: grade,
                            coachQuote: quote
                        )
                        CoachReportShareCard(
                            record: session,
                            report: report,
                            persona: persona
                        )
                    }

                    // Split-by-Split 1K Lap Breakdown Table
                    LapSplitsTableView(splits: session.splits)

                    // Heart Rate Zone (Z1-Z5) Distribution Chart
                    HRZoneChartView(zones: session.hrZones)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.secondaryText)
                    }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(session.activity.title.uppercased())
                    .font(Theme.font(size: 11, weight: .black))
                    .tracking(1.5)
                    .foregroundColor(Theme.secondaryText)
                Spacer()
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(Theme.font(size: 11, weight: .bold))
                    .foregroundColor(Theme.secondaryText)
            }

            HStack(spacing: 12) {
                metricCell(label: "DISTANCE", value: Formatters.km(session.distanceM))
                metricCell(label: "TIME", value: Formatters.clock(session.durationSec))
                metricCell(label: "AVG PACE", value: Formatters.pace(session.distanceM > 0 ? (session.durationSec / session.distanceM) * 1000 : 0))
            }

            if let gap = session.gapAveragePaceSecPerKm, gap > 0 {
                HStack {
                    Text("GRADE-ADJUSTED PACE (GAP)")
                        .font(Theme.font(size: 10, weight: .black))
                        .foregroundColor(Theme.secondaryText)
                    Spacer()
                    Text(Formatters.pace(gap))
                        .font(Theme.font(size: 12, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
    }

    private func metricCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.font(size: 9, weight: .bold))
                .foregroundColor(Theme.secondaryText)
            Text(value)
                .font(Theme.font(size: 18, weight: .black))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sessionPBSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(Theme.accent)
                Text("RECORDS BROKEN IN THIS SESSION")
                    .font(Theme.font(size: 10, weight: .black))
                    .tracking(1.2)
                    .foregroundColor(Theme.accent)
            }
            ForEach(session.personalBests) { pb in
                HStack {
                    Text(pb.title)
                        .font(Theme.font(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(pb.formattedValue)
                        .font(Theme.font(size: 13, weight: .black))
                        .foregroundColor(Theme.accent)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(Theme.accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

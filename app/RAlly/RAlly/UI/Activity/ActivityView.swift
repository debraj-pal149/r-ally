import SwiftUI
import SwiftData

struct ActivityView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSessionRecord.startedAt, order: .reverse) private var sessions: [WorkoutSessionRecord]
    @ObservedObject var pbStore = PersonalBestStore.shared

    @State private var selectedSession: WorkoutSessionRecord?

    var body: some View {
        NavigationStack {
            ZStack {
                Atmosphere(intensity: 0.85)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        header
                        lifetimeStatsCard
                        personalBestsSection
                        recentActivitiesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(item: $selectedSession) { session in
                WorkoutDetailView(session: session)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ACTIVITY")
                    .font(Theme.font(size: 26, weight: .black))
                    .tracking(2.0)
                    .foregroundStyle(Theme.textPrimary)
                Text("LIFETIME METRICS & RECORDS")
                    .font(Theme.font(size: 11, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
        }
    }

    private var lifetimeStatsCard: some View {
        let totalDistanceM = sessions.reduce(0) { $0 + $1.distanceM }
        let totalDurationSec = sessions.reduce(0) { $0 + $1.durationSec }
        let totalElevationM = sessions.reduce(0) { $0 + $1.elevationGainM }

        return VStack(spacing: 16) {
            HStack {
                Text("LIFETIME TOTALS")
                    .font(Theme.font(size: 11, weight: .black))
                    .tracking(1.5)
                    .foregroundColor(Theme.secondaryText)
                Spacer()
                Text("\(sessions.count) WORKOUTS")
                    .font(Theme.font(size: 11, weight: .bold))
                    .foregroundColor(Theme.accent)
            }

            HStack(spacing: 12) {
                statTile(label: "DISTANCE", value: String(format: "%.1f", totalDistanceM / 1000.0), unit: "KM")
                statTile(label: "TIME", value: formatHoursMinutes(totalDurationSec), unit: "")
                statTile(label: "ELEVATION", value: "\(Int(totalElevationM))", unit: "M")
            }
        }
        .padding(18)
        .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statTile(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(Theme.font(size: 10, weight: .bold))
                .foregroundColor(Theme.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(Theme.font(size: 20, weight: .black))
                    .foregroundStyle(Theme.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(Theme.font(size: 11, weight: .bold))
                        .foregroundColor(Theme.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var personalBestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.accent)
                Text("PERSONAL BESTS")
                    .font(Theme.font(size: 11, weight: .black))
                    .tracking(1.5)
                    .foregroundColor(Theme.secondaryText)
                Spacer()
            }

            let badges = pbStore.allBadges
            if badges.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "medal.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.secondaryText.opacity(0.5))
                        Text("Log runs to unlock lifetime PB badges")
                            .font(Theme.font(size: 12, weight: .medium))
                            .foregroundColor(Theme.secondaryText)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
                .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(badges) { badge in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: iconForPB(badge.kind))
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.accent)
                                Text(badge.title.uppercased())
                                    .font(Theme.font(size: 10, weight: .black))
                                    .foregroundColor(Theme.secondaryText)
                                Spacer()
                            }
                            Text(badge.formattedValue)
                                .font(Theme.font(size: 20, weight: .black))
                                .foregroundStyle(Theme.textPrimary)
                            Text(badge.achievedDate.formatted(date: .abbreviated, time: .omitted))
                                .font(Theme.font(size: 10, weight: .regular))
                                .foregroundColor(Theme.secondaryText.opacity(0.8))
                        }
                        .padding(14)
                        .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private var recentActivitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("WORKOUT HISTORY")
                    .font(Theme.font(size: 11, weight: .black))
                    .tracking(1.5)
                    .foregroundColor(Theme.secondaryText)
                Spacer()
            }

            if sessions.isEmpty {
                Text("No completed workouts yet. Hit start on the Run tab.")
                    .font(Theme.font(size: 13, weight: .regular))
                    .foregroundColor(Theme.secondaryText)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(sessions) { s in
                        Button {
                            selectedSession = s
                        } label: {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(s.activity.title.uppercased())
                                            .font(Theme.font(size: 13, weight: .black))
                                            .foregroundStyle(Theme.textPrimary)
                                        Text("•")
                                            .foregroundColor(Theme.secondaryText)
                                        Text(s.startedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(Theme.font(size: 11, weight: .medium))
                                            .foregroundColor(Theme.secondaryText)
                                    }

                                    HStack(spacing: 16) {
                                        Label(Formatters.km(s.distanceM), systemImage: "figure.run")
                                        Label(Formatters.clock(s.durationSec), systemImage: "clock")
                                        Label(Formatters.pace(s.distanceM > 0 ? (s.durationSec / s.distanceM) * 1000 : 0), systemImage: "speedometer")
                                    }
                                    .font(Theme.font(size: 12, weight: .medium))
                                    .foregroundColor(Theme.secondaryText)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.secondaryText.opacity(0.6))
                            }
                            .padding(16)
                            .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func iconForPB(_ kind: PersonalBestAchievement.PBKind) -> String {
        switch kind {
        case .fastest1K, .fastest1Mile: return "bolt.fill"
        case .fastest5K, .fastest10K: return "flame.fill"
        case .longestRun: return "map.fill"
        case .maxElevation: return "mountain.2.fill"
        }
    }

    private func formatHoursMinutes(_ totalSec: Double) -> String {
        let hrs = Int(totalSec) / 3600
        let mins = (Int(totalSec) % 3600) / 60
        if hrs > 0 {
            return "\(hrs)h \(mins)m"
        }
        return "\(mins)m"
    }
}

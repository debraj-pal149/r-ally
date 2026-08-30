import SwiftUI
import SwiftData

struct SummaryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var ctx
    var record: WorkoutSessionRecord
    var liveRallies: [RallyMoment]
    @State private var selected: RallyMomentRecord?
    @State private var stravaMsg: String?

    var body: some View {
        ZStack {
            Atmosphere(intensity: 0.7)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    PosterText(text: "The story\nof the run", size: 42)
                    HStack(spacing: 0) {
                        stat(record.activity.title, "ACTIVITY")
                        stat(Formatters.clock(record.durationSec), "TIME")
                        stat(Formatters.km(record.distanceM), "KM")
                        if let hr = record.avgHR { stat("\(Int(hr))", "HR") }
                    }
                    .padding(.vertical, 8)
                    if record.finishedAfterCritical {
                        Text("You rallied \(record.rallyCount) times and finished.")
                            .font(Theme.headline(19, .bold))
                            .foregroundStyle(Theme.emberSoft)
                    }
                    RallyTimeline(spark: record.outputSpark, rallies: record.rallies, selected: $selected)
                    if let s = selected {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(Formatters.clock(s.t)) — YOU WERE FADING")
                                .font(Theme.label(12, .bold))
                                .tracking(1.5)
                                .foregroundStyle(Theme.textMuted)
                            Text(s.text.uppercased())
                                .font(Theme.display(26))
                            if !s.aftermath.isEmpty {
                                Text(s.aftermath).foregroundStyle(Theme.pulse)
                                    .font(Theme.body(14, .medium))
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Theme.hairline, lineWidth: 1)
                        )
                        .transition(.opacity)
                    }
                    if let report = model.latestReport {
                        VStack(alignment: .leading, spacing: 12) {
                            CoachReportShareCard(record: record, report: report, persona: model.persona)
                            ShareLink(
                                item: "🏃 R·ALLY COACH DEBRIEF — \(model.persona.name.uppercased())\n\n\(report.headline)\n\n\(report.debrief)\n\n\"\(report.coachQuote)\"\n\nDistance: \(Formatters.km(record.distanceM)) | Time: \(Formatters.clock(record.durationSec)) | Grade: \(report.athleteGrade)"
                            ) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("SHARE COACH REPORT")
                                        .font(Theme.label(11, .bold))
                                        .tracking(0.8)
                                }
                                .foregroundStyle(Theme.emberSoft)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Theme.surfaceRaised)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Save to Health") {
                            Haptics.tap()
                            Task { @MainActor in
                                await model.hkWriter.save(session: record)
                            }
                        }
                        .buttonStyle(GhostButtonStyle())
                        if StravaClient.isConfigured {
                            Button("Upload to Strava") {
                                Haptics.tap()
                                Task {
                                    do {
                                        try await model.strava.upload(session: record)
                                        stravaMsg = "Uploaded"
                                    } catch {
                                        stravaMsg = error.localizedDescription
                                    }
                                }
                            }
                            .buttonStyle(GhostButtonStyle())
                        }
                    }
                    if let stravaMsg {
                        Text(stravaMsg).font(Theme.body(12)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(22)
                .padding(.bottom, 8)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Done") {
                Haptics.success()
                ctx.insert(record)
                try? ctx.save()
                model.route = .home
            }
            .buttonStyle(RallyButtonStyle())
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .background(
                LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg.opacity(0.92), Theme.bg], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .foregroundStyle(Theme.textPrimary)
        .navigationBarHidden(true)
    }

    func stat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l)
                .font(Theme.label(10, .semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.textMuted)
            Text(v.uppercased())
                .font(Theme.numeric(18, .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(l) \(v)")
    }
}

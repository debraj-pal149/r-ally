import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \WorkoutSessionRecord.startedAt, order: .reverse) private var sessions: [WorkoutSessionRecord]

    var body: some View {
        ZStack {
            Atmosphere()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    if model.llmOffline { llmBanner }
                    ActivityCarousel()
                    GoalRow()
                    PersonaPicker(preview: true)
                    PromptChips()
                    if let last = sessions.first {
                        lastCard(last)
                    }
                    Button {
                        Haptics.tap()
                        model.route = .history
                    } label: {
                        Text("HISTORY")
                            .font(Theme.label(14))
                            .tracking(1.5)
                            .foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Let's Rally") {
                Haptics.heavy()
                model.startWorkout()
            }
            .buttonStyle(RallyButtonStyle())
            .accessibilityHint("Starts the workout")
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

    var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("R-ALLY")
                    .font(Theme.label(12, .bold))
                    .tracking(4)
                    .foregroundStyle(Theme.ember)
                PosterText(text: model.greeting, size: 40)
                Text("Tonight's corner.")
                    .font(Theme.headline(16, .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button {
                Haptics.tap()
                model.route = .settings
            } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(model.sourceKind == .simulator ? Theme.pulse : Theme.emberSoft)
                        .frame(width: 7, height: 7)
                        .shadow(color: Theme.pulse.opacity(0.8), radius: 4)
                    Text(model.sourceKind == .simulator ? "SIM" : "PHONE")
                        .font(Theme.label(12))
                        .tracking(1)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(.ultraThinMaterial.opacity(0.35))
                .background(Theme.surfaceRaised.opacity(0.7))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textPrimary)
            .accessibilityLabel("Settings. Data source \(model.sourceKind == .simulator ? "simulator" : "phone sensors")")
        }
    }

    var llmBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .foregroundStyle(Theme.warn)
            Text("Built-in lines tonight — LLM is offline.")
                .font(Theme.body(13, .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warn.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.warn.opacity(0.25), lineWidth: 1)
        )
    }

    func lastCard(_ last: WorkoutSessionRecord) -> some View {
        Button {
            Haptics.tap()
            model.route = .summary(last)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Last fight")
                    Text(last.activity.title.uppercased())
                        .font(Theme.headline(18))
                    Text("\(last.rallyCount) rallies · \(Formatters.clock(last.durationSec))")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(18)
            .background(Theme.surface.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
        .accessibilityLabel("Last fight, \(last.activity.title), \(last.rallyCount) rallies")
    }
}

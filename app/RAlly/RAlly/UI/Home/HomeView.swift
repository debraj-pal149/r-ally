import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \WorkoutSessionRecord.startedAt, order: .reverse) private var sessions: [WorkoutSessionRecord]
    @State private var scrollTarget: String?

    /// Custom tab bar + home indicator clearance.
    private let chromeReserve: CGFloat = 112
    /// Intentional glimpse of the next section — kept *above* the floating tab.
    private let foldPeek: CGFloat = 36

    var body: some View {
        ZStack {
            Atmosphere(intensity: 1.35)
            RadialGradient(
                colors: [Theme.blueHour.opacity(0.32), Color.clear],
                center: UnitPoint(x: 0.0, y: 0.45),
                startRadius: 4,
                endRadius: 360
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GeometryReader { geo in
                let firstViewportH = max(520, geo.size.height - chromeReserve - foldPeek)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // —— First viewport: brand · air · hero · card · CTA ——
                            firstViewport(height: firstViewportH)

                            // —— Below the fold (peek sits above tab chrome) ——
                            VStack(alignment: .leading, spacing: 16) {
                                RallyCallSection(showCustomRow: true)
                                    .id("rallyCall")

                                PersonaPicker(preview: true, style: .list)
                                    .id("coaches")

                                if let last = sessions.first {
                                    lastCard(last)
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 14)
                            .padding(.bottom, chromeReserve + 24)
                        }
                    }
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        withAnimation(Theme.spring) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                        scrollTarget = nil
                    }
                }
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .navigationBarHidden(true)
        .onAppear {
            model.distanceUnit = DistanceUnit.detect()
            model.refreshHistory(from: Array(sessions))
        }
    }

    // MARK: - First viewport

    private func firstViewport(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            brandMark
                .padding(.top, 8)

            // Big intentional air between R · A L L Y and the street line
            Spacer(minLength: 72)

            VStack(alignment: .leading, spacing: 0) {
                hero
                metaLine
                    .padding(.top, 12)

                if model.llmOffline {
                    llmBanner.padding(.top, 12)
                }
                if let block = model.startBlockedReason {
                    sensorBanner(block, color: Theme.ember).padding(.top, 12)
                }

                setupViewport
                    .padding(.top, 18)

                startCTA
                    .padding(.top, 16)
            }

            // Leave a thin strip so Rally call peeks under the fold
            Spacer(minLength: 8)
                .frame(maxHeight: 14)
        }
        .padding(.horizontal, 22)
        .frame(height: height, alignment: .top)
        .clipped()
    }

    private var brandMark: some View {
        Text("R · A L L Y")
            .font(Theme.label(14, .bold))
            .tracking(4.5)
            .foregroundStyle(Theme.textPrimary.opacity(0.78))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("R Ally")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THE STREET")
            Text("DOESN'T CARE.")
            Text("WE DO.")
                .foregroundStyle(Theme.ember)
        }
        .font(Theme.display(44))
        .tracking(0.6)
        .lineSpacing(-6)
        .shadow(color: Theme.blueHour.opacity(0.45), radius: 22, y: 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The street doesn't care. We do.")
    }

    private var metaLine: some View {
        Text(metaCopy)
            .font(Theme.body(13))
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var metaCopy: String {
        let time = Date.now.formatted(date: .omitted, time: .shortened)
        return "\(time) · Dawn loop · phone GPS, cadence, earbuds in."
    }

    /// Bigger glass card: distance + vertical +/−, then In your ear row.
    private var setupViewport: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DISTANCE")
                        .font(Theme.label(10))
                        .tracking(1.6)
                        .foregroundStyle(Theme.textSecondary)
                    Text(distanceLabel)
                        .font(Theme.display(36))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VerticalGoalStepper(onMinus: bumpDistance(-0.5), onPlus: bumpDistance(0.5))
            }

            Button {
                Haptics.tap()
                scrollTarget = "coaches"
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IN YOUR EAR")
                            .font(Theme.label(10))
                            .tracking(1.6)
                            .foregroundStyle(Theme.textSecondary)
                        Text(model.persona.name)
                            .font(Theme.body(16, .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Spacer()
                        Text("CHANGE ▾")
                        .font(Theme.label(11, .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 14)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 1)
                }
                .padding(.top, 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("In your ear, \(model.persona.name). Change coach.")
            .accessibilityHint("Scrolls to coach list")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var startCTA: some View {
        Button("Let's Rally") {
            Haptics.heavy()
            model.startWorkout()
        }
        .buttonStyle(RallyButtonStyle())
        .accessibilityHint("Starts the run with phone sensors")
    }

    // MARK: - Distance

    private func bumpDistance(_ delta: Double) -> () -> Void {
        {
            let unitMeters: Double = model.distanceUnit == .mile ? 1609.344 : 1000
            let next = max(0.5 * unitMeters, currentGoalMeters + delta * unitMeters)
            model.goal = .distance(meters: next)
        }
    }

    private var currentGoalMeters: Double {
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
            return String(format: "%.1f KM", currentGoalMeters / 1000)
        case .mile:
            return String(format: "%.1f MI", currentGoalMeters / 1609.344)
        }
    }

    // MARK: - Banners / last

    func sensorBanner(_ text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .foregroundStyle(color)
            Text(text)
                .font(Theme.body(13, .medium))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }

    var llmBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .foregroundStyle(Theme.warn)
            Text("Built-in lines tonight. LLM is offline.")
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
                    SectionLabel(text: "Last session")
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
            .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
        .accessibilityLabel("Last fight, \(last.activity.title), \(last.rallyCount) rallies")
    }
}

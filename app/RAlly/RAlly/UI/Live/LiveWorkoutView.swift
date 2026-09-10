import SwiftUI

struct LiveWorkoutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Atmosphere(intensity: 0.55)
            RadialGradient(
                colors: [Theme.ringColor(state: model.liveState, locomotion: model.liveLocomotion).opacity(0.22), Color.clear],
                center: .center,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2), value: model.liveState)
            .animation(.easeInOut(duration: 2), value: model.liveLocomotion)

            VStack(spacing: 0) {
                HStack {
                    Text(model.activity.title.uppercased())
                        .font(Theme.label(12, .bold))
                        .tracking(2.4)
                        .foregroundStyle(Theme.textMuted)
                    Spacer()
                    if model.liveDisconnected {
                        Text("RECONNECTING")
                            .font(Theme.label(11, .bold))
                            .tracking(1.5)
                            .foregroundStyle(Theme.warn)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                Spacer()

                PulseRing(state: model.liveState, locomotion: model.liveLocomotion, bpm: model.liveLatest[.heartRateBpm], cadence: model.liveLatest[.cadenceSpm])
                    .overlay {
                        VStack(spacing: 6) {
                            Text(Formatters.clock(model.liveT))
                                .font(Theme.numeric(68, .bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.textPrimary)
                            Text(stateLabel)
                                .font(Theme.label(13, .bold))
                                .tracking(2.4)
                                .foregroundStyle(Theme.ringColor(state: model.liveState, locomotion: model.liveLocomotion))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Elapsed \(Formatters.clock(model.liveT)). Status \(stateLabel)")
                    }

                MetricTiles()
                    .padding(.vertical, 18)
                    .padding(.horizontal, 8)
                    .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.top, 32)
                    .padding(.horizontal, 20)

                Spacer()

                HStack(spacing: 26) {
                    liveControl(model.livePaused ? "play.fill" : "pause.fill", model.livePaused ? "Resume" : "Pause") {
                        Haptics.tap()
                        model.togglePause()
                    }
                    EndHoldButton {
                        Haptics.success()
                        model.endWorkout()
                    }
                    liveControl(model.muted ? "speaker.slash.fill" : "speaker.wave.2.fill", model.muted ? "Muted" : "Sound") {
                        Haptics.tap()
                        model.muted.toggle()
                        model.speech.muted = model.muted
                    }
                }
                .padding(.bottom, 32)
            }

            if let line = model.spokenLine {
                SpokenLineOverlay(text: line) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        model.spokenLine = nil
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
    }

    var stateLabel: String {
        // Locomotion wins over risk CRITICAL so REST never flickers with RALLY.
        if model.liveLocomotion == .stopped { return "REST" }
        if model.liveLocomotion == .slowing { return "SLOWING" }
        switch model.liveState {
        case .cruising: return "HOLDING"
        case .wobbling: return "FADING"
        case .critical: return "PUSH"
        case .pausedUnknown: return "REST"
        }
    }

    func liveControl(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 56, height: 56)
                    .rallyGlassCircle(.interactive, tint: nil)
                Text(label.uppercased())
                    .font(Theme.label(11, .semibold))
                    .tracking(1)
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct EndHoldButton: View {
    var action: () -> Void
    @State private var progress = 0.0
    @State private var holding = false
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Theme.hairline, lineWidth: 3)
                    .frame(width: 68, height: 68)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.ember, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 68, height: 68)
                    .rotationEffect(.degrees(-90))
                Text("END")
                    .font(Theme.label(12, .heavy))
                    .tracking(1.5)
            }
            Text("HOLD")
                .font(Theme.label(11, .semibold))
                .tracking(1)
                .foregroundStyle(Theme.textMuted)
        }
        .foregroundStyle(Theme.textPrimary)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !holding {
                        holding = true
                        Haptics.tap()
                        withAnimation(.linear(duration: 1)) { progress = 1 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            if holding { action() }
                        }
                    }
                }
                .onEnded { _ in
                    holding = false
                    withAnimation { progress = 0 }
                }
        )
        .accessibilityLabel("End workout")
        .accessibilityHint("Hold for one second, or double-tap with VoiceOver")
        .accessibilityAction { action() }
    }
}

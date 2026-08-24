import SwiftUI

struct PulseRing: View {
    var state: EngineState
    var locomotion: Locomotion = .moving
    var bpm: Double?
    var cadence: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        let period: Double = {
            if let bpm, bpm > 30 { return 60 / bpm }
            if let cadence, cadence > 30 { return 120 / cadence }
            return 1.0
        }()
        let color = Theme.ringColor(state: state, locomotion: locomotion)
        ZStack {
            Circle()
                .fill(color.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 28)
            Circle()
                .stroke(color.opacity(0.12), lineWidth: 22)
                .frame(width: 268, height: 268)
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.12), color, color.opacity(0.4), color.opacity(0.12)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .frame(width: 248, height: 248)
                .shadow(color: color.opacity(0.55), radius: 22)
        }
        .scaleEffect(reduceMotion ? 1 : (pulse ? 1.025 : 1.0))
        .animation(reduceMotion ? nil : .easeInOut(duration: max(period / 2, 0.35)).repeatForever(autoreverses: true), value: pulse)
        .animation(.easeInOut(duration: 2), value: state)
        .onAppear { pulse = true }
    }
}

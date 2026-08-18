import SwiftUI

struct SpokenLineOverlay: View {
    var text: String
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.15), Color.black.opacity(0.74)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 18) {
                Text("IN YOUR EAR")
                    .font(Theme.label(12, .bold))
                    .tracking(3.4)
                    .foregroundStyle(Theme.emberSoft)
                Text(text.uppercased())
                    .font(Theme.display(38))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 26)
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coach says: \(text)")
    }
}

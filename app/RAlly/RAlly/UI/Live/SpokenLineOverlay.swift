import SwiftUI

struct SpokenLineOverlay: View {
    var text: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Frosted blur backdrop over the live workout numbers
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // Dark gradient overlay for high contrast
            LinearGradient(
                colors: [Color.black.opacity(0.75), Color.black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.ember)
                        .frame(width: 8, height: 8)
                        .shadow(color: Theme.ember.opacity(0.8), radius: 4)
                    Text("IN YOUR EAR")
                        .font(Theme.label(12, .bold))
                        .tracking(3.4)
                        .foregroundStyle(Theme.emberSoft)
                }

                Text(text.uppercased())
                    .font(Theme.display(34))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 28)
                    .shadow(color: .black.opacity(0.6), radius: 16, y: 6)
            }
            .padding(.vertical, 40)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onDismiss?()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coach says: \(text)")
    }
}

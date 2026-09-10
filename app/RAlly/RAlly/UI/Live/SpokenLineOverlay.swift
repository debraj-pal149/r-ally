import SwiftUI

struct SpokenLineOverlay: View {
    var text: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 18) {
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
                    .font(Theme.display(32))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 28)
            .frame(maxWidth: 340)
            .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
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

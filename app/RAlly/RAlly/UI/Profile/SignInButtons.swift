import SwiftUI
import AuthenticationServices

struct SignInButtons: View {
    var busy: Bool
    var onGoogle: () -> Void
    var onApple: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onApple) {
                HStack(spacing: 10) {
                    Image(systemName: "apple.logo")
                    Text("Continue with Apple")
                        .font(Theme.font(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                // Apple HIG black style — fixed contrast in light and dark.
                .foregroundStyle(.white)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(busy)

            Button(action: onGoogle) {
                HStack(spacing: 10) {
                    Image(systemName: "g.circle.fill")
                    Text("Continue with Google")
                        .font(Theme.font(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(Theme.textPrimary)
                .background(Theme.surfaceRaised.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(busy)

            Text("Data stays on this phone until you sign in. Then it can sync to your profile.")
                .font(Theme.body(12))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

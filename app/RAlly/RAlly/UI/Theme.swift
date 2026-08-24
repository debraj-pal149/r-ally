import SwiftUI
#if os(iOS)
import UIKit
#endif

enum Theme {
    static let bg = Color(hex: 0x07080A)
    static let surface = Color(hex: 0x12151A)
    static let surfaceRaised = Color(hex: 0x1A1F26)
    static let hairline = Color.white.opacity(0.07)
    static let ember = Color(hex: 0xFF5A1F)
    static let emberSoft = Color(hex: 0xFF8A50)
    static let emberDeep = Color(hex: 0xC43A12)
    static let pulse = Color(hex: 0x3EE08A)
    static let warn = Color(hex: 0xF5B942)
    static let textPrimary = Color(hex: 0xF4F1EC)
    static let textSecondary = Color(hex: 0x8B938C)
    static let textMuted = Color(hex: 0x5C6370)

    static let cardRadius: CGFloat = 24
    static let chipRadius: CGFloat = 999
    static let buttonRadius: CGFloat = 18
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.84)

    // Fight-poster type: heavy compressed display, condensed labels, plain SF body.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.compressed)
    }
    static func headline(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
    static func label(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func numeric(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }

    static func ringColor(_ state: EngineState) -> Color {
        switch state {
        case .cruising: pulse
        case .wobbling: warn
        case .critical: ember
        case .pausedUnknown: textSecondary
        }
    }

    static func ringColor(state: EngineState, locomotion: Locomotion) -> Color {
        if locomotion == .stopped { return textSecondary }
        if locomotion == .slowing { return warn }
        return ringColor(state)
    }
}

enum Haptics {
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func heavy() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }
    static func success() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

struct Atmosphere: View {
    var intensity: Double = 1
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [Theme.ember.opacity(0.26 * intensity), Color.clear],
                center: UnitPoint(x: 0.92, y: -0.05),
                startRadius: 8,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color(hex: 0x1C140C).opacity(0.9 * intensity), Color.clear],
                center: UnitPoint(x: 0.1, y: 1.05),
                startRadius: 10,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }
}

/// Big compressed uppercase headline — the poster voice of the app.
struct PosterText: View {
    var text: String
    var size: CGFloat = 40
    var color: Color = Theme.textPrimary
    var body: some View {
        Text(text.uppercased())
            .font(Theme.display(size))
            .tracking(0.5)
            .lineSpacing(-2)
            .foregroundStyle(color)
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(12))
            .tracking(2.2)
            .foregroundStyle(Theme.textMuted)
            .accessibilityAddTraits(.isHeader)
    }
}

struct HairlineCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
    }
}

struct RallyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(22))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Theme.emberSoft, Theme.ember, Theme.emberDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.buttonRadius, style: .continuous))
            .shadow(color: Theme.ember.opacity(configuration.isPressed ? 0.15 : 0.38), radius: configuration.isPressed ? 6 : 22, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.spring, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(15))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(Theme.surfaceRaised.opacity(0.8))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Standard back chevron for pushed screens — one tap, top-left, always the same.
struct BackButton: View {
    var title: String = "Back"
    var action: () -> Void
    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                Text(title.uppercased())
                    .font(Theme.label(14))
                    .tracking(1)
            }
            .foregroundStyle(Theme.emberSoft)
            .frame(minHeight: 44)
        }
        .accessibilityLabel(title)
    }
}

struct ChipWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (i, origin) in result.origins.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        var maxX: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > width, x > 0 {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowH = max(rowH, s.height)
            x += s.width + spacing
            maxX = max(maxX, x)
        }
        return (CGSize(width: maxX, height: y + rowH), origins)
    }
}

struct GoalStepper: View {
    var label: String
    var onMinus: () -> Void
    var onPlus: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .font(Theme.numeric(30, .bold))
                .monospacedDigit()
            Spacer()
            HStack(spacing: 10) {
                step("minus", "Decrease", onMinus)
                step("plus", "Increase", onPlus)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(label)
    }

    func step(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 44, height: 44)
                .background(Theme.surfaceRaised)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
        .accessibilityLabel(label)
    }
}

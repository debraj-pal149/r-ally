import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Appearance

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// `nil` follows the device appearance.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static func load() -> AppearanceMode {
        if let raw = UserDefaults.standard.string(forKey: "ui.appearance"),
           let mode = AppearanceMode(rawValue: raw) {
            return mode
        }
        return .system
    }

    /// Force window trait refresh so Light/Dark switches immediately (not only after relaunch).
    @MainActor
    static func applyToWindows(_ mode: AppearanceMode) {
        #if os(iOS)
        let style: UIUserInterfaceStyle
        switch mode {
        case .system: style = .unspecified
        case .light: style = .light
        case .dark: style = .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
        #endif
    }
}

// MARK: - Theme

enum Theme {
    // Blood brand: crimson #C8102E + arterial #8B1A1A (adaptive surfaces)

    static let bg = Color.rallyAdaptive(light: 0xF6F2F0, dark: 0x0A0708)
    static let surface = Color.rallyAdaptive(light: 0xFFFFFF, dark: 0x1A1214, lightAlpha: 0.92, darkAlpha: 0.78)
    static let surfaceRaised = Color.rallyAdaptive(light: 0xFFFFFF, dark: 0x221618)
    static let hairline = Color.rallyAdaptive(light: 0x1A1214, dark: 0xEEF1F2, lightAlpha: 0.10, darkAlpha: 0.12)

    /// Soft atmospheric wash (replaces former blue-hour glow).
    static let blueHour = Color.rallyAdaptive(light: 0xC8102E, dark: 0x8B1A1A)

    /// Primary crimson — CTAs, selection, brand marks.
    static let ember = Color.rallyAdaptive(light: 0xC8102E, dark: 0xC8102E)
    /// Brighter crimson for icons / selected labels on dark chrome.
    static let emberSoft = Color.rallyAdaptive(light: 0xC8102E, dark: 0xE23A4C)
    /// Deep arterial — gradients, strokes, critical weight.
    static let emberDeep = Color.rallyAdaptive(light: 0x8B1A1A, dark: 0x8B1A1A)

    /// Light ink on filled red / dark CTAs.
    static let onAccent = Color.rallyAdaptive(light: 0xFFF8F7, dark: 0xFFF8F7)

    static let pulse = Color.rallyAdaptive(light: 0x1FA866, dark: 0x3EE08A)
    static let warn = Color.rallyAdaptive(light: 0xC49214, dark: 0xF5D76A)

    static let textPrimary = Color.rallyAdaptive(light: 0x141214, dark: 0xEEF1F2)
    static let textSecondary = Color.rallyAdaptive(light: 0x454042, dark: 0xA8B0BA)
    static let textMuted = Color.rallyAdaptive(light: 0x6A6466, dark: 0x7E8792)

    // Aliases
    static let background = bg
    static let card = Color.rallyAdaptive(light: 0xFFFFFF, dark: 0x1A1214, lightAlpha: 0.96, darkAlpha: 0.62)
    static let cardBorder = hairline
    static let accent = ember
    static let accentRed = ember
    static let secondaryText = textSecondary

    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }

    static let cardRadius: CGFloat = 22
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
    @MainActor
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    @MainActor
    static func heavy() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }
    @MainActor
    static func selection() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
    @MainActor
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
            blue: Double((hex >> 0) & 0xFF) / 255,
            opacity: alpha
        )
    }

    /// Resolves light/dark from the current trait collection (follows System / preferredColorScheme).
    static func rallyAdaptive(
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> Color {
        #if os(iOS)
        Color(
            uiColor: UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                let alpha = traits.userInterfaceStyle == .dark ? darkAlpha : lightAlpha
                return UIColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: alpha
                )
            }
        )
        #else
        Color(hex: light, alpha: Double(lightAlpha))
        #endif
    }
}

struct Atmosphere: View {
    var intensity: Double = 1
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [
                    Theme.ember.opacity((dark ? 0.28 : 0.10) * intensity),
                    Color.clear
                ],
                center: UnitPoint(x: 0.12, y: 0.0),
                startRadius: 8,
                endRadius: 420
            )
            RadialGradient(
                colors: [
                    Theme.emberDeep.opacity((dark ? 0.55 : 0.12) * intensity),
                    Color.clear
                ],
                center: UnitPoint(x: 0.92, y: 1.05),
                startRadius: 10,
                endRadius: 480
            )
            LinearGradient(
                colors: dark
                    ? [Color(hex: 0x0A0708), Color(hex: 0x120A0C), Color(hex: 0x0A0708)]
                    : [Color(hex: 0xF6F2F0), Color(hex: 0xFBF8F6), Color(hex: 0xF6F2F0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.55 * intensity)
        }
        .ignoresSafeArea()
    }
}

/// Big compressed uppercase headline. The poster voice of the app.
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

// MARK: - Liquid Glass (iOS 26+) with readable Material fallbacks

enum RallyGlassStyle {
    /// Frosted panel for cards / sheets. Prefer this for text-heavy surfaces.
    case regular
    /// Lighter frost for nested chips inside a card.
    case clear
    /// Soft accent wash (use sparingly).
    case tinted
    /// Pressable control chrome without a heavy tint wash.
    case interactive
}

extension View {
    /// Liquid Glass when available; denser materials on older OS so type stays readable.
    @ViewBuilder
    func rallyGlass(
        _ style: RallyGlassStyle = .regular,
        in shape: some Shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous),
        tint: Color? = nil
    ) -> some View {
        if #available(iOS 26.0, *) {
            switch style {
            case .regular:
                self.glassEffect(.regular, in: shape)
            case .clear:
                self.glassEffect(.clear, in: shape)
            case .tinted:
                self.glassEffect(.regular.tint((tint ?? Theme.ember).opacity(0.45)), in: shape)
            case .interactive:
                if let tint {
                    self.glassEffect(.regular.interactive().tint(tint.opacity(0.40)), in: shape)
                } else {
                    self.glassEffect(.regular.interactive(), in: shape)
                }
            }
        } else {
            self
                .background {
                    ZStack {
                        shape.fill(Theme.surfaceRaised.opacity(style == .clear ? 0.55 : 0.92))
                        shape.fill(.thinMaterial)
                        if style == .tinted || (style == .interactive && tint != nil) {
                            shape.fill((tint ?? Theme.ember).opacity(0.16))
                        }
                    }
                }
                .overlay(shape.stroke(Theme.hairline, lineWidth: 1))
        }
    }

    @ViewBuilder
    func rallyGlassCapsule(_ style: RallyGlassStyle = .regular, tint: Color? = nil) -> some View {
        rallyGlass(style, in: Capsule(), tint: tint)
    }

    @ViewBuilder
    func rallyGlassCircle(_ style: RallyGlassStyle = .interactive, tint: Color? = nil) -> some View {
        rallyGlass(style, in: Circle(), tint: tint)
    }
}

struct HairlineCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

/// Primary filled CTA. Crimson → arterial gradient + light on-accent text.
struct RallyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(20))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 8)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.ember.opacity(configuration.isPressed ? 0.90 : 1),
                                Theme.emberDeep.opacity(configuration.isPressed ? 0.88 : 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(Theme.emberDeep.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: Theme.emberDeep.opacity(configuration.isPressed ? 0.18 : 0.40), radius: configuration.isPressed ? 6 : 16, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.spring, value: configuration.isPressed)
    }
}

/// Outline CTA. Frosted surface + primary text + arterial stroke.
struct OutlineRallyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(22))
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .rallyGlassCapsule(.regular)
            .overlay(
                Capsule()
                    .stroke(Theme.ember.opacity(0.75), lineWidth: 1.5)
            )
            .shadow(color: Theme.emberDeep.opacity(configuration.isPressed ? 0.08 : 0.20), radius: configuration.isPressed ? 6 : 14, y: 0)
            .opacity(configuration.isPressed ? 0.88 : 1)
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
            .rallyGlassCapsule(.regular)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Standard back chevron for pushed screens. One tap, top-left, always the same.
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
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .rallyGlassCapsule(.regular)
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
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .rallyGlassCircle(.interactive, tint: nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Vertical +/− stack used on Home glass card.
struct VerticalGoalStepper: View {
    var onMinus: () -> Void
    var onPlus: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            step("plus", "Increase distance", onPlus)
            step("minus", "Decrease distance", onMinus)
        }
    }

    func step(_ icon: String, _ a11y: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 40, height: 40)
                .rallyGlassCircle(.interactive, tint: nil)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y)
    }
}

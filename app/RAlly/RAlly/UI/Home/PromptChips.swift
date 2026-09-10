import SwiftUI

/// Blue Hour Home. Richer 2-col “Rally call” intents (replaces thin prompt chips).
struct RallyCallSection: View {
    @Environment(AppModel.self) private var model
    @State private var custom = false
    /// When false, custom entry lives in the Home viewport instead.
    var showCustomRow: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("RALLY CALL")
                    .font(Theme.label(10))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("What he hammers today")
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.textMuted)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(RallyCallIntent.forActivity(model.activity)) { intent in
                    let on = model.selectedPrompt == intent.prompt
                    Button {
                        Haptics.tap()
                        withAnimation(Theme.spring) { model.selectedPrompt = intent.prompt }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(intent.title)
                                .font(Theme.body(13, .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(intent.subtitle)
                                .font(Theme.body(11))
                                .foregroundStyle(on ? Theme.textSecondary : Theme.textMuted)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                        .rallyGlass(
                            on ? .tinted : .regular,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                            tint: Theme.emberDeep
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(on ? Theme.ember.opacity(0.55) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(intent.title)
                    .accessibilityHint(intent.subtitle)
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                }
            }

            if showCustomRow {
                Button {
                    Haptics.tap()
                    custom = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Write your own call")
                                .font(Theme.body(13, .bold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Custom line for this bout only.")
                                .font(Theme.body(11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .rallyGlass(
                        isCustomOn ? .tinted : .regular,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                        tint: Theme.emberDeep
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isCustomOn ? Theme.ember.opacity(0.55) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Write your own call")
            }
        }
        .sheet(isPresented: $custom) {
            ZStack {
                Atmosphere(intensity: 0.6)
                VStack(alignment: .leading, spacing: 16) {
                    PosterText(text: "Your call", size: 32)
                    TextField("Remind me that…", text: Bindable(model).customPrompt, axis: .vertical)
                        .font(Theme.body(17))
                        .lineLimit(3...6)
                        .padding(16)
                        .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .submitLabel(.done)
                    Button("Use this") {
                        Haptics.tap()
                        model.selectedPrompt = model.customPrompt
                        custom = false
                    }
                    .buttonStyle(RallyButtonStyle())
                }
                .padding(24)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var isCustomOn: Bool {
        guard let selected = model.selectedPrompt, !selected.isEmpty else { return false }
        return !RallyCallIntent.forActivity(model.activity).contains { $0.prompt == selected }
    }
}

struct RallyCallIntent: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let prompt: String

    static func forActivity(_ activity: ActivityKind) -> [RallyCallIntent] {
        switch activity {
        case .running:
            [
                .init(id: "dont-quit", title: "Don’t quit on me", subtitle: "When the fade hits. Stay in it.", prompt: "Don't let me negotiate with myself. When the fade hits, stay in it"),
                .init(id: "hold-line", title: "Hold the line", subtitle: "Lock pace. No negotiation.", prompt: "Hold the line. Lock pace, no negotiation"),
                .init(id: "neg-split", title: "Negative split", subtitle: "Second half harder than first.", prompt: "Negative split. Second half harder than first"),
                .init(id: "breath", title: "Breath & form", subtitle: "Settle the stride, then push.", prompt: "Settle my breath and form, then push"),
                .init(id: "outlast", title: "Outlast last run", subtitle: "Past where you usually stop.", prompt: "Push me past where I usually stop. Outlast last run"),
                .init(id: "quiet", title: "Quiet grind", subtitle: "Less bark. More work.", prompt: "Quiet grind. Less bark, more work"),
            ]
        case .cycling:
            ActivityKind.cycling.promptChips.enumerated().map { i, chip in
                .init(id: "cycle-\(i)", title: chip, subtitle: "Hammer this today.", prompt: chip)
            }
        case .rowing:
            ActivityKind.rowing.promptChips.enumerated().map { i, chip in
                .init(id: "row-\(i)", title: chip, subtitle: "Hammer this today.", prompt: chip)
            }
        default:
            []
        }
    }
}

/// Kept for any remaining call sites; Home uses `RallyCallSection`.
struct PromptChips: View {
    var body: some View {
        RallyCallSection()
    }
}

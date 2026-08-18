import SwiftUI

struct PromptChips: View {
    @Environment(AppModel.self) private var model
    @State private var custom = false

    var items: [String] { model.activity.promptChips + ["Custom…", "No prompt"] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "What to say")
            ChipWrap(spacing: 8) {
                ForEach(items, id: \.self) { chip in
                    let on = isOn(chip)
                    Button {
                        Haptics.tap()
                        if chip == "Custom…" { custom = true }
                        else if chip == "No prompt" { model.selectedPrompt = nil }
                        else { model.selectedPrompt = chip }
                    } label: {
                        Text(chip)
                            .font(Theme.body(13, .medium))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 38)
                            .background(on ? Theme.ember : Theme.surfaceRaised.opacity(0.9))
                            .foregroundStyle(on ? Color.white : Theme.textPrimary)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(on ? Color.clear : Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                }
            }
        }
        .sheet(isPresented: $custom) {
            ZStack {
                Atmosphere(intensity: 0.6)
                VStack(alignment: .leading, spacing: 16) {
                    PosterText(text: "Your words", size: 32)
                    TextField("Remind me that…", text: Bindable(model).customPrompt, axis: .vertical)
                        .font(Theme.body(17))
                        .lineLimit(3...6)
                        .padding(16)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Theme.hairline, lineWidth: 1)
                        )
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
            .preferredColorScheme(.dark)
        }
    }

    func isOn(_ chip: String) -> Bool {
        if chip == "No prompt" { return model.selectedPrompt == nil }
        if chip == "Custom…" { return false }
        return model.selectedPrompt == chip
    }
}

import SwiftUI

struct ActivityCarousel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Today")
            HStack(spacing: 10) {
                ForEach(ActivityKind.shipped) { act in
                    let on = model.activity == act
                    Button {
                        Haptics.tap()
                        withAnimation(Theme.spring) {
                            model.activity = act
                            model.goal = act.defaultGoal
                            model.selectedPrompt = nil
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: act.symbol)
                                .font(.system(size: 28, weight: .semibold))
                                .frame(width: 48, height: 48)
                                .background(on ? Theme.onAccent.opacity(0.16) : Theme.surfaceRaised)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(act.title.uppercased())
                                    .font(Theme.label(20, .bold))
                                    .tracking(0.8)
                                Text("PHONE · GPS · CADENCE")
                                    .font(Theme.label(10, .bold))
                                    .tracking(1.2)
                                    .foregroundStyle(on ? Theme.onAccent.opacity(0.85) : Theme.emberSoft)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                        .background(
                            on
                                ? LinearGradient(colors: [Theme.ember, Theme.emberDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Theme.surface, Theme.surface], startPoint: .top, endPoint: .bottom)
                        )
                        .foregroundStyle(on ? Theme.onAccent : Theme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(on ? Theme.onAccent.opacity(0.22) : Theme.hairline, lineWidth: 1)
                        )
                        .shadow(color: on ? Theme.ember.opacity(0.35) : .clear, radius: 14, y: 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(act.title). Uses phone GPS and cadence.")
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                }
            }
        }
    }
}

import SwiftUI

struct ActivityCarousel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Discipline")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ActivityKind.allCases) { act in
                        let on = model.activity == act
                        Button {
                            Haptics.tap()
                            withAnimation(Theme.spring) {
                                model.activity = act
                                model.goal = act.defaultGoal
                                model.selectedPrompt = nil
                            }
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: act.symbol)
                                    .font(.system(size: 22, weight: .semibold))
                                    .frame(height: 26)
                                Text(act.title.uppercased())
                                    .font(Theme.label(14, .bold))
                                    .tracking(0.8)
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 92)
                            .background(
                                on
                                    ? LinearGradient(colors: [Theme.ember, Theme.emberDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Theme.surface, Theme.surface], startPoint: .top, endPoint: .bottom)
                            )
                            .foregroundStyle(on ? Color.white : Theme.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(on ? Color.white.opacity(0.18) : Theme.hairline, lineWidth: 1)
                            )
                            .shadow(color: on ? Theme.ember.opacity(0.35) : .clear, radius: 14, y: 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(act.title)
                        .accessibilityAddTraits(on ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 4)
                .padding(.trailing, 8)
            }
            .scrollClipDisabled()
        }
    }
}

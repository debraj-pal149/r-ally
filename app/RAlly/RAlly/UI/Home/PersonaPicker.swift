import SwiftUI

struct PersonaPicker: View {
    @Environment(AppModel.self) private var model
    var preview: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "In your ear")
                Spacer()
                if preview {
                    Button {
                        Haptics.tap()
                        model.speech.speak(FallbackLines.preview(persona: model.persona), persona: model.persona) {}
                    } label: {
                        Label("HEAR IT", systemImage: "speaker.wave.2.fill")
                            .font(Theme.label(12, .bold))
                            .tracking(1)
                            .foregroundStyle(Theme.emberSoft)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Preview this coach's voice")
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Persona.all) { p in
                        let on = model.persona.id == p.id
                        Button {
                            Haptics.tap()
                            withAnimation(Theme.spring) { model.persona = p }
                            if preview {
                                model.speech.speak(FallbackLines.preview(persona: p), persona: p) {}
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: p.symbol)
                                    .font(.system(size: 17, weight: .semibold))
                                    .frame(width: 34, height: 34)
                                    .background(on ? Color.white.opacity(0.16) : Theme.surfaceRaised)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.name.uppercased())
                                        .font(Theme.headline(16, .heavy))
                                        .tracking(0.4)
                                        .foregroundStyle(on ? .white : Theme.textPrimary)
                                        .lineLimit(1)
                                    Text(p.tagline)
                                        .font(Theme.body(12))
                                        .foregroundStyle(on ? Color.white.opacity(0.82) : Theme.textMuted)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(14)
                            .frame(width: 180, height: 136, alignment: .topLeading)
                            .background(
                                on
                                    ? LinearGradient(colors: [Theme.emberSoft, Theme.ember, Theme.emberDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Theme.surface, Theme.surface], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(on ? Color.white.opacity(0.22) : Theme.hairline, lineWidth: 1)
                            )
                            .shadow(color: on ? Theme.ember.opacity(0.38) : .clear, radius: 16, y: 7)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(p.name). \(p.tagline)")
                        .accessibilityAddTraits(on ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 6)
                .padding(.trailing, 8)
            }
            .scrollClipDisabled()
        }
    }
}

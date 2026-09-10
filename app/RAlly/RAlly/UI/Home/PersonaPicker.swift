import SwiftUI

struct PersonaPicker: View {
    @Environment(AppModel.self) private var model
    var preview: Bool = false
    var style: Style = .carousel

    enum Style {
        case carousel
        case list
    }

    var body: some View {
        switch style {
        case .carousel:
            carouselBody
        case .list:
            listBody
        }
    }

    private var carouselBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "In your ear")
                Spacer()
                if preview {
                    hearItButton
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Persona.all) { p in
                        carouselCard(p)
                    }
                }
                .padding(.vertical, 6)
                .padding(.trailing, 8)
            }
            .scrollClipDisabled()
        }
    }

    private var listBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Choose your corner")
                Spacer()
                if preview {
                    hearItButton
                }
            }
            ForEach(Persona.all) { p in
                listRow(p)
            }
        }
        .padding(.top, 8)
    }

    private var hearItButton: some View {
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

    private func select(_ p: Persona) {
        Haptics.tap()
        withAnimation(Theme.spring) { model.persona = p }
        if preview {
            model.speech.speak(FallbackLines.preview(persona: p), persona: p) {}
        }
    }

    private func carouselCard(_ p: Persona) -> some View {
        let on = model.persona.id == p.id
        return Button {
            select(p)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: p.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(on ? Theme.onAccent.opacity(0.16) : Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.name.uppercased())
                        .font(Theme.headline(16, .heavy))
                        .tracking(0.4)
                        .foregroundStyle(on ? Theme.onAccent : Theme.textPrimary)
                        .lineLimit(1)
                    Text(p.tagline)
                        .font(Theme.body(12))
                        .foregroundStyle(on ? Theme.onAccent.opacity(0.85) : Theme.textMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(width: 180, height: 136, alignment: .topLeading)
            .background(
                on
                    ? LinearGradient(colors: [Theme.ember, Theme.emberDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Theme.surfaceRaised, Theme.surfaceRaised], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(on ? Theme.onAccent.opacity(0.22) : Theme.hairline, lineWidth: 1)
            )
            .shadow(color: on ? Theme.emberDeep.opacity(0.4) : .clear, radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(p.name). \(p.tagline)")
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private func listRow(_ p: Persona) -> some View {
        let on = model.persona.id == p.id
        return Button {
            select(p)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: p.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(on ? Theme.emberSoft : Theme.textPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name)
                        .font(Theme.body(14, .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(p.tagline)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(on ? "ACTIVE" : "USE")
                    .font(Theme.label(11, .bold))
                    .tracking(1)
                    .foregroundStyle(on ? Theme.onAccent : Theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        if on {
                            Capsule().fill(Theme.ember)
                        } else {
                            Capsule().fill(Theme.surfaceRaised.opacity(0.9))
                        }
                    }
                    .overlay(
                        Capsule().stroke(on ? Color.clear : Theme.hairline, lineWidth: 1)
                    )
            }
            .padding(12)
            .rallyGlass(
                .regular,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(on ? Theme.ember.opacity(0.55) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(p.name). \(p.tagline)")
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}

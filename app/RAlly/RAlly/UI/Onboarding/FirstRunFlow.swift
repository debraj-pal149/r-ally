import SwiftUI

struct FirstRunFlow: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0

    var body: some View {
        ZStack {
            Atmosphere()
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? Theme.ember : Theme.hairline)
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .accessibilityLabel("Step \(step + 1) of 4")

                Spacer()
                Group {
                    switch step {
                    case 0:
                        VStack(alignment: .leading, spacing: 16) {
                            PosterText(text: "What should\nwe call you?", size: 44)
                            TextField("Your name", text: Bindable(model).name)
                                .font(Theme.body(20))
                                .padding(18)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Theme.hairline, lineWidth: 1)
                                )
                                .submitLabel(.continue)
                                .onSubmit { advance() }
                        }
                    case 1:
                        VStack(alignment: .leading, spacing: 16) {
                            PosterText(text: "How old?", size: 44)
                            Text("Only used to estimate heart-rate max. Override anytime.")
                                .font(Theme.body(15))
                                .foregroundStyle(Theme.textSecondary)
                            GoalStepper(label: "\(model.age)", onMinus: {
                                model.age = max(14, model.age - 1)
                            }, onPlus: {
                                model.age = min(80, model.age + 1)
                            })
                        }
                    case 2:
                        VStack(alignment: .leading, spacing: 16) {
                            PosterText(text: "Who's in\nyour ear?", size: 40)
                            Text("Put the buds in. The product is the voice at the moment you fade — not a screen.")
                                .font(Theme.body(15))
                                .foregroundStyle(Theme.textSecondary)
                            PersonaPicker(preview: true)
                        }
                    default:
                        VStack(alignment: .leading, spacing: 16) {
                            PosterText(text: "A few\npermissions", size: 40)
                            permission("figure.run", "Motion", "So we feel cadence fade without a watch.")
                            permission("location", "Location", "So outdoor runs have live pace.")
                            permission("heart.fill", "Apple Health", "To save workouts and read Nike Run Club history.")
                        }
                    }
                }
                .padding(.horizontal, 24)
                Spacer()
                Button(step < 3 ? "Continue" : "Let's go") {
                    if step == 3 {
                        model.prepareDevicePermissions()
                    }
                    advance()
                }
                    .buttonStyle(RallyButtonStyle())
                    .padding(24)
            }
        }
        .foregroundStyle(Theme.textPrimary)
    }

    private func advance() {
        Haptics.tap()
        withAnimation(Theme.spring) {
            if step < 3 { step += 1 } else { model.completeOnboarding() }
        }
    }

    func permission(_ icon: String, _ title: String, _ why: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ember)
                .frame(width: 36, height: 36)
                .background(Theme.ember.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(Theme.headline(16, .bold))
                Text(why)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(why)")
    }
}

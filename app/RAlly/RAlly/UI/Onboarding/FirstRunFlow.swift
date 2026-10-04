import SwiftUI

struct FirstRunFlow: View {
    @Environment(AppModel.self) private var model
    @State private var step = 0
    @State private var weightText = ""
    @State private var weightInPounds = false
    private let stepCount = 5

    var body: some View {
        ZStack {
            Atmosphere()
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<stepCount, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? Theme.ember : Theme.hairline)
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .accessibilityLabel("Step \(step + 1) of \(stepCount)")

                Spacer()
                Group {
                    switch step {
                    case 0:
                        VStack(alignment: .leading, spacing: 16) {
                            PosterText(text: "What should\nwe call you?", size: 44)
                            TextField("Your name", text: Bindable(model).name)
                                .font(Theme.body(20))
                                .padding(18)
                                .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                        weightStep
                    case 3:
                        VStack(alignment: .leading, spacing: 16) {
                            PosterText(text: "Who's in\nyour ear?", size: 40)
                            Text("Put the buds in. The product is the voice at the moment you fade. Not a screen.")
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
                            permission("waveform", "Coach Voice", "Ultra-realistic rugged audio motivators powered by low-latency cloud neural speech.")
                        }
                    }
                }
                .padding(.horizontal, 24)
                Spacer()
                Button(continueTitle) {
                    if step == 2 {
                        // Valid weight commits; empty skips and calories use the default mass.
                        if !weightText.trimmingCharacters(in: .whitespaces).isEmpty {
                            guard commitWeight() else { return }
                        } else {
                            model.bodyWeightKg = nil
                        }
                    }
                    if step == stepCount - 1 {
                        model.prepareDevicePermissions()
                    }
                    advance()
                }
                    .buttonStyle(RallyButtonStyle())
                    .disabled(!canAdvance)
                    .opacity(canAdvance ? 1 : 0.45)
                    .padding(24)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .onAppear(perform: prefillWeight)
    }

    private var continueTitle: String {
        if step == 2 {
            let blank = weightText.trimmingCharacters(in: .whitespaces).isEmpty
            if blank { return "Skip for now" }
            return "This weight is right"
        }
        if step < stepCount - 1 { return "Continue" }
        return "Let's go"
    }

    private var canAdvance: Bool {
        if step == 2 {
            let blank = weightText.trimmingCharacters(in: .whitespaces).isEmpty
            return blank || parsedWeightKg != nil
        }
        return true
    }

    private var weightStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            PosterText(text: "Your weight", size: 44)
            Text("Used to estimate calories on a run. Optional — if you skip, we use a standard adult weight (70 kg / 154 lb), same idea as Nike when height/weight are not shared. A device calorie total still wins when one is sent.")
                .font(Theme.body(15))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                unitChip("KG", on: !weightInPounds) { setWeightUnit(pounds: false) }
                unitChip("LB", on: weightInPounds) { setWeightUnit(pounds: true) }
            }

            TextField(weightInPounds ? "150" : "70", text: $weightText)
                .keyboardType(.decimalPad)
                .font(Theme.numeric(36, .bold))
                .padding(18)
                .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel("Body weight in \(weightInPounds ? "pounds" : "kilograms")")

            if let kg = parsedWeightKg {
                Text(confirmationLine(kg: kg))
                    .font(Theme.body(14, .medium))
                    .foregroundStyle(Theme.ember)
                    .fixedSize(horizontal: false, vertical: true)
            } else if weightText.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Skip and we estimate with 70 kg (154 lb). You can set your real weight later in Corner.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Enter a realistic weight, or clear the field to skip.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.warn)
            }
        }
    }

    private func unitChip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.label(12, .bold))
                .tracking(0.8)
                .foregroundStyle(on ? Theme.onAccent : Theme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background {
                    if on {
                        Capsule().fill(
                            LinearGradient(
                                colors: [Theme.ember, Theme.emberDeep],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    } else {
                        Capsule()
                            .fill(Theme.surfaceRaised.opacity(0.55))
                            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var parsedWeightKg: Double? {
        let raw = weightText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let value = Double(raw), value > 0 else { return nil }
        let kg = weightInPounds ? value / 2.2046226218 : value
        guard (35...250).contains(kg) else { return nil }
        return kg
    }

    private func confirmationLine(kg: Double) -> String {
        if weightInPounds {
            let lb = kg * 2.2046226218
            return String(format: "Confirm %.0f lb (%.1f kg). This is what calorie estimates will use.", lb, kg)
        }
        return String(format: "Confirm %.1f kg. This is what calorie estimates will use.", kg)
    }

    private func setWeightUnit(pounds: Bool) {
        guard pounds != weightInPounds else { return }
        if let kg = parsedWeightKg {
            weightInPounds = pounds
            if pounds {
                weightText = String(format: "%.0f", kg * 2.2046226218)
            } else {
                weightText = String(format: "%.1f", kg)
            }
        } else {
            weightInPounds = pounds
        }
        Haptics.selection()
    }

    private func prefillWeight() {
        weightInPounds = model.distanceUnit == .mile
        guard weightText.isEmpty, let kg = model.bodyWeightKg else { return }
        if weightInPounds {
            weightText = String(format: "%.0f", kg * 2.2046226218)
        } else {
            weightText = String(format: "%.1f", kg)
        }
    }

    @discardableResult
    private func commitWeight() -> Bool {
        guard let kg = parsedWeightKg else { return false }
        model.bodyWeightKg = kg
        return true
    }

    private func advance() {
        Haptics.tap()
        withAnimation(Theme.spring) {
            if step < stepCount - 1 { step += 1 } else { model.completeOnboarding() }
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
        .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(why)")
    }
}

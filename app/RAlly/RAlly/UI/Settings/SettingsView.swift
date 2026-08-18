import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var pairing = false
    @State private var showAllVoices = false

    var body: some View {
        ZStack {
            Atmosphere(intensity: 0.45)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    PosterText(text: "Corner\nsettings", size: 42)
                    sourceCard
                    voiceCard
                    athleteCard
                    healthCard
                    if StravaClient.isConfigured { stravaCard }
                    intensityCard
                    Text("r-ally · the corner man in your ear")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.bottom, 36)
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton(title: "Home") {
                    model.persistProfile()
                    model.route = .home
                }
            }
        }
        .sheet(isPresented: $pairing) {
            BLEPairingSheet()
        }
        .onDisappear { model.persistProfile() }
    }

    var sourceCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionLabel(text: "Signal")
                HStack(spacing: 8) {
                    sourceChip("Simulator", .simulator)
                    sourceChip("iPhone", .device)
                }
                if model.sourceKind == .simulator {
                    TextField("ws://127.0.0.1:7777/stream", text: Bindable(model).simulatorURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(Theme.body(14))
                        .padding(14)
                        .background(Theme.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Toggle(isOn: Bindable(model).bleEnabled) {
                    Text("Bluetooth heart-rate strap")
                        .font(Theme.body(15, .medium))
                }
                .tint(Theme.ember)
                if model.bleEnabled {
                    Button("Scan & pair") {
                        Haptics.tap()
                        pairing = true
                    }
                    .font(Theme.label(15, .bold))
                    .foregroundStyle(Theme.emberSoft)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    var voiceCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Voice")
                Text("Using \(model.speech.resolvedVoiceName)")
                    .font(Theme.headline(16, .bold))
                Text("Siri and Premium English voices sound human. Download them in iOS Settings → Accessibility → Spoken Content → Voices.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                VoiceList(expanded: $showAllVoices)
                Button {
                    Haptics.tap()
                    model.speech.speak(FallbackLines.preview(persona: model.persona), persona: model.persona) {}
                } label: {
                    Label("HEAR THIS COACH", systemImage: "speaker.wave.2.fill")
                        .font(Theme.label(14, .bold))
                        .tracking(1)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Theme.ember.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.emberSoft)
                .accessibilityLabel("Preview coach voice")
            }
        }
    }

    var athleteCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Athlete")
                TextField("Name", text: Bindable(model).name)
                    .font(Theme.body(18))
                    .padding(14)
                    .background(Theme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                GoalStepper(label: "\(model.age) yrs", onMinus: {
                    model.age = max(14, model.age - 1)
                }, onPlus: {
                    model.age = min(80, model.age + 1)
                })
                HStack {
                    Text("HR max")
                        .font(Theme.body(15, .medium))
                    Spacer()
                    TextField("auto \(Int(model.hrMax))", value: Bindable(model).hrMaxOverride, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(Theme.numeric(18, .bold))
                        .frame(width: 88, height: 44)
                }
            }
        }
    }

    var healthCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Apple Health")
                Button("Authorize Health") {
                    Haptics.tap()
                    Task {
                        model.healthAuthorized = await model.health.requestAuthorization()
                        let n = await model.health.recentWorkouts().count
                        model.nrcWorkoutCount = n
                    }
                }
                .font(Theme.label(15, .bold))
                .foregroundStyle(Theme.emberSoft)
                .frame(minHeight: 44)
                if model.nrcWorkoutCount > 0 {
                    Text("\(model.nrcWorkoutCount) running workouts in Health, including Nike Run Club if it synced.")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Text("Nike Run Club has no public API. Runs that synced to Apple Health show up in history.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textMuted)
            }
        }
    }

    var stravaCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Strava")
                if model.strava.isConnected {
                    Button("Disconnect Strava") { model.strava.disconnect() }
                        .font(Theme.label(15, .bold))
                        .foregroundStyle(Theme.emberSoft)
                        .frame(minHeight: 44)
                } else {
                    Button("Connect Strava") {
                        Task { try? await model.strava.connect() }
                    }
                    .font(Theme.label(15, .bold))
                    .foregroundStyle(Theme.emberSoft)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    var intensityCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Rally intensity")
                GoalStepper(label: "\(model.sessionCap) shouts", onMinus: {
                    model.sessionCap = max(3, model.sessionCap - 1)
                }, onPlus: {
                    model.sessionCap = min(10, model.sessionCap + 1)
                })
            }
        }
    }

    func sourceChip(_ title: String, _ kind: DataSourceKind) -> some View {
        let on = model.sourceKind == kind
        return Button {
            Haptics.tap()
            model.sourceKind = kind
        } label: {
            Text(title.uppercased())
                .font(Theme.label(14, .bold))
                .tracking(0.6)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(on ? Theme.ember : Theme.surfaceRaised)
                .foregroundStyle(on ? Color.white : Theme.textPrimary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(on ? Color.clear : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}

struct VoiceList: View {
    @Environment(AppModel.self) private var model
    @Binding var expanded: Bool

    var body: some View {
        let voices = SpeechEngine.rankedVoices()
        let shown = expanded ? voices : Array(voices.prefix(8))
        VStack(spacing: 6) {
            voiceRow(nil, "Auto · best neural for this coach")
            ForEach(shown, id: \.identifier) { v in
                voiceRow(v.identifier, label(v))
            }
            if voices.count > 8 {
                Button(expanded ? "Show fewer" : "All English voices") {
                    Haptics.tap()
                    withAnimation(Theme.spring) { expanded.toggle() }
                }
                .font(Theme.label(13, .bold))
                .foregroundStyle(Theme.textSecondary)
                .frame(minHeight: 44)
            }
        }
    }

    func voiceRow(_ id: String?, _ title: String) -> some View {
        let on = model.voiceIdentifier == id
        return Button {
            Haptics.tap()
            model.voiceIdentifier = id
        } label: {
            HStack {
                Text(title)
                    .font(Theme.body(14, on ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
                if on {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.ember)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 42)
            .background(on ? Theme.ember.opacity(0.12) : Theme.surfaceRaised.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.textPrimary)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    func label(_ v: AVSpeechSynthesisVoice) -> String {
        let neural = v.identifier.lowercased().contains("siri") || v.quality == .premium || v.quality == .enhanced
        return "\(neural ? "●  " : "")\(v.name)  \(v.language)"
    }
}

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var showAddDevice = false

    var body: some View {
        ZStack {
            Atmosphere(intensity: 0.45)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    PosterText(text: "Corner", size: 38)
                    appearanceCard
                    sourceCard
                    runnerLevelCard
                    voiceAuditionDashboard
                    athleteCard
                    healthCard
                    if StravaClient.isConfigured { stravaCard }
                    intensityCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
        }
        .foregroundStyle(Theme.textPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddDevice) {
            AddDeviceSheet()
        }
        .onDisappear { model.persistProfile() }
    }

    var appearanceCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Appearance")
                Text("Follows your iPhone setting by default.")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textMuted)

                HStack(spacing: 8) {
                    ForEach(AppearanceMode.allCases) { mode in
                        let on = model.appearanceMode == mode
                        Button {
                            Haptics.selection()
                            withAnimation(Theme.spring) {
                                model.appearanceMode = mode
                            }
                        } label: {
                            Text(mode.title.uppercased())
                                .font(Theme.label(11, .bold))
                                .tracking(0.8)
                                .foregroundStyle(on ? Theme.onAccent : Theme.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .background {
                                    if on {
                                        Capsule()
                                            .fill(
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
                        .accessibilityLabel("Appearance \(mode.title)")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
        }
    }

    var sourceCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel(text: "Source")
                    Spacer()
                    Button {
                        Haptics.tap()
                        showAddDevice = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("ADD")
                                .font(Theme.label(10, .bold))
                                .tracking(0.8)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .foregroundStyle(Theme.textPrimary)
                        .rallyGlassCapsule(.interactive)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add device or source")
                }

                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.ember)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("iPhone & Apple Health")
                                .font(Theme.headline(13, .bold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("GPS pace, cadence & Apple Health active")
                                .font(Theme.body(11))
                                .foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                        Circle()
                            .fill(Theme.pulse)
                            .frame(width: 6, height: 6)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .rallyGlass(.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // Connected BLE sensors
                    ForEach(model.universalBle.connectedDeviceNames, id: \.self) { bleName in
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.horizontal.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.pulse)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(bleName)
                                    .font(Theme.headline(13, .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("Live telemetry active")
                                    .font(Theme.body(11))
                                    .foregroundStyle(Theme.textMuted)
                            }
                            Spacer()
                            Circle()
                                .fill(Theme.pulse)
                                .frame(width: 6, height: 6)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .rallyGlass(.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    // Connected Cloud Wearables
                    ForEach(Array(WearableCloudService.shared.connectedProviders), id: \.self) { provider in
                        HStack(spacing: 10) {
                            Image(systemName: "icloud.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.emberSoft)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(provider)
                                    .font(Theme.headline(13, .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("Readiness & recovery synced")
                                    .font(Theme.body(11))
                                    .foregroundStyle(Theme.textMuted)
                            }
                            Spacer()
                            Circle()
                                .fill(Theme.pulse)
                                .frame(width: 6, height: 6)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .rallyGlass(.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    var runnerLevelCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Runner Level")
                VStack(spacing: 6) {
                    ForEach(RunnerLevel.allCases, id: \.self) { level in
                        let selected = (model.runnerLevel == level)
                        Button {
                            Haptics.selection()
                            model.runnerLevel = level
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(level.rawValue)
                                        .font(Theme.headline(13, .bold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(level.tagline)
                                        .font(Theme.body(11))
                                        .foregroundStyle(Theme.textMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 8)
                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Theme.ember)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .rallyGlass(
                                selected ? .tinted : .clear,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous),
                                tint: Theme.emberDeep
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(selected ? Theme.ember.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    var voiceAuditionDashboard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: "Coach Voice")
                    Spacer()
                    providerPill
                }

                VStack(spacing: 8) {
                    ForEach(Persona.all) { p in
                        voiceOptionRow(p)
                    }
                }
            }
        }
    }

    private var providerPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(CloudTTSService.hasCloudAPI ? Theme.pulse : Theme.emberSoft)
                .frame(width: 5, height: 5)
            Text(CloudTTSService.activeProvider.rawValue.uppercased())
                .font(Theme.label(10, .bold))
                .tracking(0.8)
                .foregroundStyle(CloudTTSService.hasCloudAPI ? Theme.pulse : Theme.emberSoft)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .rallyGlassCapsule(.clear)
    }

    private func voiceOptionRow(_ p: Persona) -> some View {
        let isSelected = model.persona.id == p.id
        let isPlaying = model.speech.isPreviewing && model.speech.previewingVoiceId == p.voiceId

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(p.name)
                        .font(Theme.headline(15, .bold))
                        .foregroundStyle(isSelected ? Theme.ember : Theme.textPrimary)

                    if isSelected {
                        Text("ACTIVE")
                            .font(Theme.label(8, .bold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.pulse)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Theme.pulse.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(p.tagline)
                    .font(Theme.label(11, .semibold))
                    .foregroundStyle(Theme.textMuted)
            }

            Spacer()

            // Audition preview button
            Button {
                Haptics.tap()
                if isPlaying {
                    model.speech.stop()
                } else {
                    let previewOpt = CoachVoiceOption(
                        id: p.voiceId,
                        title: p.name,
                        subtitle: p.tagline,
                        vibe: p.archetype,
                        previewText: FallbackLines.preview(persona: p),
                        elevenLabsVoiceId: p.elevenLabsVoiceId
                    )
                    model.speech.preview(voice: previewOpt)
                }
            } label: {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(isPlaying ? Theme.ember.opacity(0.35) : Theme.surfaceRaised)
                    .foregroundStyle(isPlaying ? Theme.ember : Theme.textPrimary)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(isPlaying ? Theme.ember : Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Select button
            if !isSelected {
                Button {
                    Haptics.heavy()
                    withAnimation(Theme.spring) {
                        model.persona = p
                    }
                } label: {
                    Text("USE")
                        .font(Theme.label(11, .bold))
                        .tracking(0.8)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(Theme.textPrimary)
                        .rallyGlassCapsule(.interactive)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Theme.ember.opacity(0.55) : Color.clear, lineWidth: 1)
        )
    }

    var athleteCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Athlete")
                TextField("Name", text: Bindable(model).name)
                    .font(Theme.body(16))
                    .padding(12)
                    .rallyGlass(.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                GoalStepper(label: "\(model.age) yrs", onMinus: {
                    model.age = max(14, model.age - 1)
                }, onPlus: {
                    model.age = min(80, model.age + 1)
                })
                HStack {
                    Text("HR Max")
                        .font(Theme.body(14, .medium))
                    Spacer()
                    TextField("auto \(Int(model.hrMax))", value: Bindable(model).hrMaxOverride, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(Theme.numeric(16, .bold))
                        .frame(width: 80, height: 38)
                }
            }
        }
    }

    var healthCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Apple Health")
                Button(model.healthAuthorized ? "Health Authorized" : "Authorize Health") {
                    Haptics.tap()
                    Task {
                        model.healthAuthorized = await model.health.requestAuthorization()
                        let n = await model.health.recentWorkouts().count
                        model.nrcWorkoutCount = n
                    }
                }
                .font(Theme.label(14, .bold))
                .foregroundStyle(model.healthAuthorized ? Theme.pulse : Theme.emberSoft)
                .frame(minHeight: 38)
            }
        }
    }

    var stravaCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Strava")
                Button(model.strava.isConnected ? "Disconnect Strava" : "Connect Strava") {
                    if model.strava.isConnected {
                        model.strava.disconnect()
                    } else {
                        Task { try? await model.strava.connect() }
                    }
                }
                .font(Theme.label(14, .bold))
                .foregroundStyle(Theme.emberSoft)
                .frame(minHeight: 38)
            }
        }
    }

    var intensityCard: some View {
        HairlineCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Fade Shout Budget")
                GoalStepper(label: "\(model.sessionCap) shouts", onMinus: {
                    model.sessionCap = max(3, model.sessionCap - 1)
                }, onPlus: {
                    model.sessionCap = min(30, model.sessionCap + 1)
                })
            }
        }
    }
}

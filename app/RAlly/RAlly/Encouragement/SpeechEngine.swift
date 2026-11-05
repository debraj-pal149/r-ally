import Foundation
import AVFoundation
#if os(iOS)
import UIKit
#endif

@Observable
@MainActor
final class SpeechEngine: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private let synth = AVSpeechSynthesizer()
    private let booth = VoiceBooth()
    private var audioPlayer: AVAudioPlayer?
    private var onFinish: (() -> Void)?
    private var pendingChunks: [String] = []
    private var activePersona: Persona = .named(.sarge)
    private var useBooth = true
    private var awaitingBuffers = false
    private var energeticDelivery = true
    /// Bumps on every stop/speak so late TTS tasks cannot play after cancellation.
    private var speakGeneration: UInt64 = 0
    /// Cancels a pending soft-deactivate so a short call cannot leave the session dead.
    private var deactivateGeneration: UInt64 = 0

    var voiceId: String = CoachVoiceOption.defaultVoiceId
    var muted = false
    /// Hard block while a phone call / Siri / other audio session interruption is active.
    var callInterrupted = false
    var speaking = false
    var isPreviewing = false
    var previewingVoiceId: String?

    /// True when the coach must not speak (mute or active call/Siri interruption).
    /// Do NOT gate on `secondaryAudioShouldBeSilencedHint` — that is often true
    /// while Spotify/podcasts play via mixWithOthers and would mute coaching entirely.
    var mustStaySilent: Bool {
        muted || callInterrupted
    }

    var activeVoiceOption: CoachVoiceOption {
        CoachVoiceOption.find(voiceId)
    }

    var resolvedVoiceName: String {
        let provider = CloudTTSService.activeProvider
        switch provider {
        case .fishAudio:
            return "Fish Audio · \(activeVoiceOption.title)"
        case .elevenLabs:
            return "ElevenLabs · \(activeVoiceOption.title)"
        case .appleFallback:
            let gender = activePersona.prefersFemale ? "Female" : "Male"
            return "Apple Neural · Coach \(gender)"
        }
    }

    var providerStatus: String {
        let provider = CloudTTSService.activeProvider
        switch provider {
        case .fishAudio:
            return "Fish Audio S2 ultra-realistic streaming active"
        case .elevenLabs:
            return "ElevenLabs Turbo v2.5 low-latency active"
        case .appleFallback:
            let gender = activePersona.prefersFemale ? "female" : "male"
            return "No cloud API key in .env. Using Apple \(gender) fallback"
        }
    }

    override init() {
        super.init()
        synth.delegate = self
        #if os(iOS)
        synth.usesApplicationAudioSession = true
        setupAudioSessionObservers()
        #endif
    }

    private func setupAudioSessionObservers() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let info = note.userInfo,
                  let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }

            switch type {
            case .began:
                // Mirror mute: hard silence + block new lines until the call ends.
                self.callInterrupted = true
                self.silenceNow()
            case .ended:
                self.callInterrupted = false
                // Restore route without ducking music; do not resume the cut mid-line.
                self.activateSession(duckOthers: false)
            @unknown default:
                break
            }
        }
        #endif
    }

    func prefetch(_ text: String) {
        CloudTTSService.shared.prefetch(text: Self.coachText(text), voiceId: voiceId)
    }

    func preview(voice: CoachVoiceOption, onFinish: (() -> Void)? = nil) {
        guard !mustStaySilent else { onFinish?(); return }
        stop()
        isPreviewing = true
        previewingVoiceId = voice.id
        self.onFinish = { [weak self] in
            self?.isPreviewing = false
            self?.previewingVoiceId = nil
            onFinish?()
        }
        let spoken = DistanceUnitNormalizer.normalize(Self.coachText(voice.previewText), to: DistanceUnit.detect())
        let previewPersona = Persona.all.first(where: { $0.voiceId == voice.id }) ?? Persona.named(.sarge)
        activePersona = previewPersona
        speaking = true
        let generation = speakGeneration

        Task { @MainActor in
            guard !self.mustStaySilent else {
                self.finishSpeaking()
                return
            }
            do {
                let data = try await CloudTTSService.shared.synthesize(text: spoken, voiceId: voice.id)
                guard self.speakGeneration == generation, self.speaking else { return }
                guard !self.mustStaySilent else {
                    self.finishSpeaking()
                    return
                }
                self.activateSession(duckOthers: true)
                if await self.playAudioData(data, fadeIn: true) {
                    return
                }
            } catch {
                // Fallback to Apple voice preview if cloud request fails
            }
            guard self.speakGeneration == generation, self.speaking || self.isPreviewing else { return }
            guard !self.mustStaySilent else {
                self.finishSpeaking()
                return
            }
            self.activateSession(duckOthers: true)
            self.speakApple(spoken, persona: previewPersona, energetic: true, labelPrefix: "Preview · ")
        }
    }

    func speak(_ text: String, persona: Persona, onFinish: @escaping () -> Void) {
        guard !mustStaySilent else { onFinish(); return }
        stop()
        self.onFinish = onFinish
        let spoken = DistanceUnitNormalizer.normalize(Self.coachText(text), to: DistanceUnit.detect())
        activePersona = persona
        self.voiceId = persona.voiceId
        // Claim the speaking lock immediately so tick() cannot double-fire while TTS synthesizes.
        speaking = true
        let generation = speakGeneration

        Task { @MainActor in
            guard !self.mustStaySilent else {
                self.finishSpeaking()
                return
            }
            // Synthesize FIRST. Only duck music when audio is ready to play.
            if CloudTTSService.hasCloudAPI {
                do {
                    let data = try await CloudTTSService.shared.synthesize(text: spoken, voiceId: persona.voiceId)
                    guard self.speakGeneration == generation, self.speaking else { return }
                    guard !self.mustStaySilent else {
                        self.finishSpeaking()
                        return
                    }
                    self.activateSession(duckOthers: true)
                    if await self.playAudioData(data, fadeIn: true) {
                        return
                    }
                } catch {
                    // Failover seamlessly to Apple neural (gender matches persona)
                }
            }
            guard self.speakGeneration == generation, self.speaking else { return }
            guard !self.mustStaySilent else {
                self.finishSpeaking()
                return
            }
            self.activateSession(duckOthers: true)
            self.speakApple(spoken, persona: persona, energetic: true, labelPrefix: "Fallback · ")
        }
    }

    /// Warm the playback route at workout start without ducking Spotify yet.
    func warmSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            // mixWithOthers only. DuckOthers would pull music down before any coach audio is ready.
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {}
        #endif
    }

    private func playAudioData(_ data: Data, fadeIn: Bool = false) async -> Bool {
        do {
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.enableRate = true
            player.rate = 1.05
            // Peak playback; Fish prosody already adds ~+7 dB upstream.
            let target: Float = 1.0
            if fadeIn {
                player.volume = 0.0
            } else {
                player.volume = target
            }
            player.prepareToPlay()
            audioPlayer = player
            speaking = true
            if !player.play() { return false }
            if fadeIn {
                player.setVolume(target, fadeDuration: 0.05)
            }
            return true
        } catch {
            return false
        }
    }

    private func speakApple(_ spoken: String, persona: Persona, energetic: Bool, labelPrefix: String) {
        energeticDelivery = energetic
        _ = labelPrefix
        booth.apply(BoothPreset.preset(for: persona.id))
        pendingChunks = Self.breathChunks(spoken)
        speaking = true
        useBooth = true
        speakNextChunk()
    }

    func stop() {
        speakGeneration &+= 1
        pendingChunks.removeAll()
        awaitingBuffers = false
        synth.stopSpeaking(at: .immediate)
        booth.stop()
        audioPlayer?.stop()
        audioPlayer = nil
        speaking = false
        isPreviewing = false
        previewingVoiceId = nil
    }

    /// Hard silence: cut current audio and fire the finish callback so coach policy unlocks.
    func silenceNow() {
        let finish = onFinish
        onFinish = nil
        stop()
        deactivateSession()
        finish?()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if self.useBooth { return }
            self.advanceOrFinish()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.finishSpeaking()
        }
    }

    private func speakNextChunk() {
        guard let chunk = pendingChunks.first else {
            finishSpeaking()
            return
        }
        pendingChunks.removeFirst()
        let spokenChunk = chunk
        let utterance = makeUtterance(spokenChunk)
        if useBooth {
            awaitingBuffers = true
            var received = false
            synth.write(utterance) { [weak self] buffer in
                let copy = Self.copyBuffer(buffer)
                let empty = (buffer as? AVAudioPCMBuffer)?.frameLength == 0
                Task { @MainActor in
                    guard let self else { return }
                    if let copy {
                        received = true
                        self.booth.schedule(copy)
                    } else if empty {
                        self.awaitingBuffers = false
                        if !received {
                            self.useBooth = false
                            self.synth.speak(self.makeUtterance(spokenChunk))
                            return
                        }
                        self.booth.markUtteranceDone { [weak self] in
                            self?.speakNextChunk()
                        }
                    }
                }
            }
        } else {
            synth.speak(utterance)
        }
    }

    private func advanceOrFinish() {
        if pendingChunks.isEmpty {
            finishSpeaking()
        } else {
            speakNextChunk()
        }
    }

    private func finishSpeaking() {
        speaking = false
        isPreviewing = false
        previewingVoiceId = nil
        deactivateSession()
        onFinish?()
        onFinish = nil
    }

    private func makeUtterance(_ chunk: String) -> AVSpeechUtterance {
        let forceMale = !activePersona.prefersFemale
        let voice = Self.voice(for: activePersona, preferredID: nil, forceMale: forceMale)
        let attr = Self.attributedCoach(chunk)
        let u = AVSpeechUtterance(attributedString: attr)
        u.voice = voice
        let jitterR = Float.random(in: -0.015...0.015)
        let jitterP = Float.random(in: -0.012...0.012)
        let baseRate = energeticDelivery ? max(activePersona.speechRate, 0.52) + 0.04 : activePersona.speechRate
        let basePitch = energeticDelivery
            ? (activePersona.prefersFemale
                ? min(activePersona.speechPitch, 1.08) - 0.02
                : min(activePersona.speechPitch, 0.96) - 0.04)
            : activePersona.speechPitch
        u.rate = max(0.44, min(0.58, baseRate + jitterR))
        u.pitchMultiplier = max(0.88, min(1.12, basePitch + jitterP))
        u.volume = 1.0
        u.preUtteranceDelay = 0.04
        u.postUtteranceDelay = 0.12
        u.prefersAssistiveTechnologySettings = false
        return u
    }

    nonisolated static func voice(for persona: Persona, preferredID: String?, forceMale: Bool = true) -> AVSpeechSynthesisVoice? {
        if let preferredID, let v = AVSpeechSynthesisVoice(identifier: preferredID) { return v }
        let all = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        return all.max { score($0, persona: persona, forceMale: forceMale) < score($1, persona: persona, forceMale: forceMale) }
    }

    nonisolated private static func score(_ v: AVSpeechSynthesisVoice, persona: Persona, forceMale: Bool = false) -> Int {
        var s = 0
        let id = v.identifier.lowercased()
        let name = v.name.lowercased()
        if id.contains("siri") || name.contains("siri") { s += 140 }
        if id.contains("premium") { s += 100 }
        if v.quality == .premium { s += 90 }
        if v.quality == .enhanced { s += 50 }
        if v.language.hasPrefix("en-US") { s += 10 }
        if v.language.hasPrefix("en-GB") { s += 6 }
        if v.voiceTraits.contains(.isNoveltyVoice) { s -= 260 }
        if v.voiceTraits.contains(.isPersonalVoice) { s -= 20 }
        if id.contains("compact") && !id.contains("siri") && v.quality == .default { s -= 50 }
        if ["albert", "bad news", "bahh", "bells", "boing", "bubbles", "cellos", "deranged", "good news", "hysterical", "pipe organ", "trinoids", "whisper", "zarvox", "kathy", "princess", "junior", "superstar", "wobble"].contains(where: { name.contains($0) }) {
            s -= 220
        }
        let wantMale = forceMale && !persona.prefersFemale
        if wantMale {
            for needle in ["aaron", "reed", "daniel", "nathan", "tom", "evan", "ralph", "fred", "gordon", "oliver", "arthur", "rishi"] {
                if name.contains(needle) { s += 40 }
            }
            if name.contains("samantha") { s -= 120 }
            if name.contains("karen") || name.contains("moira") || name.contains("tessa") { s -= 30 }
            if v.gender == .male { s += 50 }
            if v.gender == .female { s -= 80 }
        } else {
            for needle in ["samantha", "karen", "moira", "tessa", "zoe", "nicky", "susan", "allison", "ava", "serena"] {
                if name.contains(needle) { s += 40 }
            }
            if v.gender == .female { s += 55 }
            if v.gender == .male { s -= 80 }
        }
        for needle in persona.voiceHints {
            if name.contains(needle) || id.contains(needle) { s += 24 }
        }
        return s
    }

    nonisolated static func coachText(_ raw: String) -> String {
        var t = raw
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        for vocative in ["Kid", "Champ", "Coach", "Soldier", "Chief"] {
            t = t.replacingOccurrences(of: "\(vocative) ", with: "\(vocative), ")
        }
        t = DashNormalizer.normalize(t)
        t = t.replacingOccurrences(of: "  ", with: " ")
        if let last = t.last, !".!?".contains(last) {
            t += "."
        }
        return t
    }

    nonisolated static func breathChunks(_ text: String) -> [String] {
        let marked = text
            .replacingOccurrences(of: ". ", with: "|")
            .replacingOccurrences(of: ", ", with: "|")
            .replacingOccurrences(of: "; ", with: "|")
        let parts = marked
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let normalized = parts.isEmpty ? [text] : parts
        return Array(normalized.prefix(3))
    }

    nonisolated static func attributedCoach(_ text: String) -> NSAttributedString {
        let t = coachText(text)
        let m = NSMutableAttributedString(string: t)
        let ns = t as NSString
        let pause: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(rawValue: "UIAccessibilitySpeechAttributePause"): 0.16
        ]
        for token in [",", ", ", ". "] {
            var search = 0
            while search < ns.length {
                let found = ns.range(of: token, range: NSRange(location: search, length: ns.length - search))
                if found.location == NSNotFound { break }
                m.addAttributes(pause, range: NSRange(location: found.location, length: found.length))
                search = found.location + found.length
            }
        }
        return m
    }

    nonisolated private static func copyBuffer(_ buffer: AVAudioBuffer) -> AVAudioPCMBuffer? {
        guard let src = buffer as? AVAudioPCMBuffer, src.frameLength > 0 else { return nil }
        guard let out = AVAudioPCMBuffer(pcmFormat: src.format, frameCapacity: src.frameLength) else { return nil }
        out.frameLength = src.frameLength
        let channels = Int(src.format.channelCount)
        let frames = Int(src.frameLength)
        if src.format.commonFormat == .pcmFormatFloat32, let s = src.floatChannelData, let d = out.floatChannelData {
            for c in 0..<channels { d[c].update(from: s[c], count: frames) }
        } else if src.format.commonFormat == .pcmFormatInt16, let s = src.int16ChannelData, let d = out.int16ChannelData {
            for c in 0..<channels { d[c].update(from: s[c], count: frames) }
        } else {
            return nil
        }
        return out
    }

    private func activateSession(duckOthers: Bool = true) {
        #if os(iOS)
        if callInterrupted { return }
        // Cancel any pending soft-deactivate from a prior silenceNow / finish.
        deactivateGeneration &+= 1
        let session = AVAudioSession.sharedInstance()
        do {
            // Duck music hard so the coach cuts through Spotify / podcasts.
            let opts: AVAudioSession.CategoryOptions = duckOthers
                ? [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
                : [.mixWithOthers]
            try session.setCategory(.playback, mode: .spokenAudio, options: opts)
            try session.setActive(true, options: [])
        } catch {}
        #endif
    }

    private func deactivateSession() {
        #if os(iOS)
        // Soft restore: brief delay so music doesn't slam back mid-word echo.
        // Bump token so a later activateSession (e.g. call ended) wins the race.
        deactivateGeneration &+= 1
        let token = deactivateGeneration
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard self.deactivateGeneration == token, !self.callInterrupted, !self.speaking else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        #endif
    }
}

struct BoothPreset {
    var reverbPreset: AVAudioUnitReverbPreset
    var wet: Float
    var lowShelfGain: Float
    var presenceCut: Float
    var highShelfGain: Float

    static func preset(for id: Persona.ID) -> BoothPreset {
        switch id {
        case .southpaw, .whip:
            BoothPreset(reverbPreset: .smallRoom, wet: 3, lowShelfGain: 1.6, presenceCut: 1.4, highShelfGain: 1.2)
        case .machine, .hardline:
            BoothPreset(reverbPreset: .smallRoom, wet: 2, lowShelfGain: 1.8, presenceCut: 1.6, highShelfGain: 1.4)
        case .preacher:
            BoothPreset(reverbPreset: .mediumRoom, wet: 5, lowShelfGain: 1.4, presenceCut: 1.0, highShelfGain: 1.0)
        case .sarge, .major:
            BoothPreset(reverbPreset: .smallRoom, wet: 1, lowShelfGain: 1.4, presenceCut: 1.8, highShelfGain: 1.6)
        case .steady:
            BoothPreset(reverbPreset: .mediumChamber, wet: 4, lowShelfGain: 0.8, presenceCut: 0.8, highShelfGain: 0.7)
        }
    }
}

@MainActor
final class VoiceBooth {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let reverb = AVAudioUnitReverb()
    private let eq = AVAudioUnitEQ(numberOfBands: 3)
    private let compressor: AVAudioUnitEffect = {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return AVAudioUnitEffect(audioComponentDescription: desc)
    }()
    private var wiredFormat: AVAudioFormat?
    private var queued = 0
    private var utteranceComplete = false
    private var onDrained: (() -> Void)?

    init() {
        engine.attach(player)
        engine.attach(eq)
        engine.attach(compressor)
        engine.attach(reverb)
        let unit = compressor.audioUnit
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, -18, 0)
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_HeadRoom, kAudioUnitScope_Global, 0, 4, 0)
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, 0.004, 0)
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, 0.11, 0)
        // Louder Apple-fallback coach over music.
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, 9, 0)
        apply(BoothPreset.preset(for: .southpaw))
    }

    func apply(_ p: BoothPreset) {
        reverb.loadFactoryPreset(p.reverbPreset)
        reverb.wetDryMix = p.wet
        configure(eq.bands[0], type: .lowShelf, hz: 160, gain: p.lowShelfGain, bw: 0.8)
        configure(eq.bands[1], type: .parametric, hz: 2800, gain: p.presenceCut, bw: 1.0)
        configure(eq.bands[2], type: .highShelf, hz: 7500, gain: p.highShelfGain, bw: 0.7)
    }

    func schedule(_ buffer: AVAudioPCMBuffer) {
        wire(buffer.format)
        queued += 1
        player.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.queued -= 1
                self.fireIfDrained()
            }
        }
        if !engine.isRunning {
            try? engine.start()
        }
        if !player.isPlaying {
            player.play()
        }
    }

    func markUtteranceDone(then continueWith: @escaping () -> Void) {
        onDrained = continueWith
        utteranceComplete = true
        fireIfDrained()
    }

    func stop() {
        onDrained = nil
        utteranceComplete = false
        queued = 0
        player.stop()
        if engine.isRunning { engine.pause() }
    }

    private func fireIfDrained() {
        guard utteranceComplete, queued <= 0 else { return }
        utteranceComplete = false
        let next = onDrained
        onDrained = nil
        next?()
    }

    private func wire(_ format: AVAudioFormat) {
        if wiredFormat?.sampleRate == format.sampleRate, wiredFormat?.channelCount == format.channelCount {
            return
        }
        if engine.isRunning { engine.stop() }
        engine.disconnectNodeOutput(player)
        engine.disconnectNodeOutput(eq)
        engine.disconnectNodeOutput(compressor)
        engine.disconnectNodeOutput(reverb)
        engine.connect(player, to: eq, format: format)
        engine.connect(eq, to: compressor, format: format)
        engine.connect(compressor, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        wiredFormat = format
        engine.prepare()
    }

    private func configure(_ band: AVAudioUnitEQFilterParameters, type: AVAudioUnitEQFilterType, hz: Float, gain: Float, bw: Float) {
        band.filterType = type
        band.frequency = hz
        band.gain = gain
        band.bandwidth = bw
        band.bypass = false
    }
}

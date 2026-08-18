import Foundation
import AVFoundation
#if os(iOS)
import UIKit
#endif

@MainActor
final class SpeechEngine: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private let booth = VoiceBooth()
    private var onFinish: (() -> Void)?
    private var pendingChunks: [String] = []
    private var activePersona: Persona = .named(.southpaw)
    private var useBooth = true
    private var awaitingBuffers = false

    var voiceIdentifier: String?
    var muted = false
    var speaking = false
    private(set) var resolvedVoiceName: String = "Neural"

    override init() {
        super.init()
        synth.delegate = self
        #if os(iOS)
        synth.usesApplicationAudioSession = true
        #endif
    }

    /// Prefer Siri/neural and Premium voices. Classic compact Samantha is what sounds "AI".
    nonisolated static func voice(for persona: Persona, preferredID: String?) -> AVSpeechSynthesisVoice? {
        if let preferredID, let v = AVSpeechSynthesisVoice(identifier: preferredID) { return v }
        let all = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        return all.max { score($0, persona: persona) < score($1, persona: persona) }
    }

    nonisolated static func rankedVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { score($0, persona: Persona.named(.southpaw)) > score($1, persona: Persona.named(.southpaw)) }
    }

    nonisolated private static func score(_ v: AVSpeechSynthesisVoice, persona: Persona) -> Int {
        var s = 0
        let id = v.identifier.lowercased()
        let name = v.name.lowercased()
        if id.contains("siri") || name.contains("siri") { s += 140 }
        if id.contains("premium") { s += 100 }
        if v.quality == .premium { s += 90 }
        if v.quality == .enhanced { s += 50 }
        if id.contains("eloquence") && (name.contains("reed") || name.contains("flo") || name.contains("sandy")) { s += 18 }
        if v.language.hasPrefix("en-US") { s += 10 }
        if v.language.hasPrefix("en-GB") { s += 4 }
        if v.voiceTraits.contains(.isNoveltyVoice) { s -= 260 }
        if v.voiceTraits.contains(.isPersonalVoice) { s -= 20 }
        // Compact Samantha is the GPS / "AI assistant" voice.
        if name.contains("samantha") && v.quality == .default { s -= 90 }
        if id.contains("compact") && !id.contains("siri") && v.quality == .default { s -= 50 }
        if ["albert", "bad news", "bahh", "bells", "boing", "bubbles", "cellos", "deranged", "good news", "hysterical", "pipe organ", "trinoids", "whisper", "zarvox", "kathy", "princess", "junior", "superstar", "wobble"].contains(where: { name.contains($0) }) {
            s -= 220
        }
        if persona.prefersFemale {
            if v.gender == .female { s += 18 }
            if v.gender == .male { s -= 6 }
        } else {
            if v.gender == .male { s += 18 }
            if v.gender == .female { s -= 4 }
        }
        for needle in persona.voiceHints {
            if name.contains(needle) || id.contains(needle) { s += 32 }
        }
        return s
    }

    func speak(_ text: String, persona: Persona, onFinish: @escaping () -> Void) {
        guard !muted else { onFinish(); return }
        stop()
        self.onFinish = onFinish
        activateSession()
        let spoken = Self.coachText(text)
        let voice = Self.voice(for: persona, preferredID: voiceIdentifier)
        resolvedVoiceName = displayName(voice)
        activePersona = persona
        booth.apply(BoothPreset.preset(for: persona.id))
        pendingChunks = Self.breathChunks(spoken)
        speaking = true
        useBooth = true
        speakNextChunk()
    }

    func stop() {
        pendingChunks.removeAll()
        awaitingBuffers = false
        synth.stopSpeaking(at: .immediate)
        booth.stop()
        speaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if self.useBooth { return }
            self.advanceOrFinish()
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
        deactivateSession()
        onFinish?()
        onFinish = nil
    }

    private func makeUtterance(_ chunk: String) -> AVSpeechUtterance {
        let voice = Self.voice(for: activePersona, preferredID: voiceIdentifier)
        let attr = Self.attributedCoach(chunk)
        let u = AVSpeechUtterance(attributedString: attr)
        u.voice = voice
        // Micro-variation per chunk: humans never repeat rate and pitch exactly.
        let jitterR = Float.random(in: -0.015...0.015)
        let jitterP = Float.random(in: -0.012...0.012)
        u.rate = max(0.42, min(0.54, activePersona.speechRate + jitterR))
        u.pitchMultiplier = max(0.93, min(1.07, activePersona.speechPitch + jitterP))
        u.volume = 1.0
        u.preUtteranceDelay = 0.05
        u.postUtteranceDelay = 0.12
        u.prefersAssistiveTechnologySettings = false
        return u
    }

    private func displayName(_ v: AVSpeechSynthesisVoice?) -> String {
        guard let v else { return "System" }
        let q: String = {
            switch v.quality {
            case .premium: "Premium"
            case .enhanced: "Enhanced"
            default:
                v.identifier.lowercased().contains("siri") ? "Siri" : "Standard"
            }
        }()
        return "\(v.name) · \(q)"
    }

    /// Punctuation and vocative commas give neural voices a falling, human contour.
    nonisolated static func coachText(_ raw: String) -> String {
        var t = raw
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        for vocative in ["Kid", "Champ", "Coach", "Soldier", "Chief"] {
            t = t.replacingOccurrences(of: "\(vocative) ", with: "\(vocative), ")
        }
        t = t.replacingOccurrences(of: "  ", with: " ")
        if let last = t.last, !".!?".contains(last) {
            t += "."
        }
        return t
    }

    /// Split on em-dash / semicolon so the coach takes a breath — not a robotic run-on.
    nonisolated static func breathChunks(_ text: String) -> [String] {
        let marked = text
            .replacingOccurrences(of: " — ", with: "|")
            .replacingOccurrences(of: "—", with: "|")
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
        for token in [",", "—", " – "] {
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

    private func activateSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true)
        } catch {}
        #endif
    }

    private func deactivateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}

/// Per-persona room character: Sarge is dry and close, Steady has air, Preacher gets a hall.
struct BoothPreset {
    var reverbPreset: AVAudioUnitReverbPreset
    var wet: Float
    var lowShelfGain: Float
    var presenceCut: Float
    var highShelfGain: Float

    static func preset(for id: Persona.ID) -> BoothPreset {
        switch id {
        case .southpaw:
            BoothPreset(reverbPreset: .mediumRoom, wet: 10, lowShelfGain: 2.6, presenceCut: -5.5, highShelfGain: -2.2)
        case .machine:
            BoothPreset(reverbPreset: .mediumRoom, wet: 12, lowShelfGain: 3.0, presenceCut: -4.5, highShelfGain: -1.5)
        case .preacher:
            BoothPreset(reverbPreset: .largeRoom, wet: 18, lowShelfGain: 2.0, presenceCut: -3.5, highShelfGain: -1.0)
        case .sarge:
            BoothPreset(reverbPreset: .smallRoom, wet: 5, lowShelfGain: 1.6, presenceCut: -2.5, highShelfGain: -0.8)
        case .steady:
            BoothPreset(reverbPreset: .mediumHall, wet: 16, lowShelfGain: 1.2, presenceCut: -5.0, highShelfGain: 0.5)
        }
    }
}

/// Plays synthesizer buffers through a short room so the voice sits in the gym, not in a GPS unit.
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
        // Broadcast-style squeeze: pull peaks down, lift the body of the voice.
        let unit = compressor.audioUnit
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, -18, 0)
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_HeadRoom, kAudioUnitScope_Global, 0, 4, 0)
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, 0.004, 0)
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, 0.11, 0)
        AudioUnitSetParameter(unit, kDynamicsProcessorParam_OverallGain, kAudioUnitScope_Global, 0, 5, 0)
        apply(BoothPreset.preset(for: .southpaw))
    }

    func apply(_ p: BoothPreset) {
        reverb.loadFactoryPreset(p.reverbPreset)
        reverb.wetDryMix = p.wet
        configure(eq.bands[0], type: .lowShelf, hz: 160, gain: p.lowShelfGain, bw: 0.8)
        configure(eq.bands[1], type: .parametric, hz: 3100, gain: p.presenceCut, bw: 1.1)
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

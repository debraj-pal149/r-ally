import Foundation
#if canImport(FluidAudio)
import FluidAudio
#endif

/// On-device PocketTTS for **Power** (male baritone). Auto does not use this — Auto is Apple punchy male.
@MainActor
final class OnDeviceTTS {
    /// Opaque model voice id — deeper male pack (baritone lean). Not a celebrity label.
    private static let powerVoiceID = "bill_boerst"
    /// Hotter sampling = more bite / less flat lecture tone.
    private static let powerTemperature: Float = 1.05

    #if canImport(FluidAudio)
    private var pocket: PocketTtsManager?
    #endif
    private var pocketReady = false
    private var warming = false

    private(set) var statusLine: String = {
        #if canImport(FluidAudio)
        "Power voice idle — tap Hear this coach to load"
        #else
        "FluidAudio not linked — Power falls back to Apple"
        #endif
    }()

    var isReady: Bool { pocketReady }
    var activeVoiceLabel: String {
        pocketReady ? "Power · baritone (on-device)" : "Power · loading…"
    }

    /// Only Power needs on-device models. Auto/Apple skip this.
    func warmForPower() {
        #if canImport(FluidAudio)
        guard !warming, !pocketReady else {
            if pocketReady { statusLine = "Power baritone ready" }
            return
        }
        warming = true
        Task { @MainActor in
            defer { warming = false }
            statusLine = "Downloading power baritone voice…"
            do {
                let mgr = PocketTtsManager(
                    defaultVoice: Self.powerVoiceID,
                    language: .english,
                    precision: .int8
                )
                try await mgr.initialize()
                pocket = mgr
                pocketReady = true
                statusLine = "Power baritone ready"
            } catch {
                statusLine = "Power download failed — using punchy Apple male"
            }
        }
        #else
        statusLine = "FluidAudio not linked — using Apple"
        #endif
    }

    func synthesizePower(text: String) async throws -> Data {
        #if canImport(FluidAudio)
        guard pocketReady, let pocket else { throw OnDeviceTTSError.notReady }
        return try await pocket.synthesize(
            text: text,
            voice: Self.powerVoiceID,
            temperature: Self.powerTemperature
        )
        #else
        throw OnDeviceTTSError.notReady
        #endif
    }

    func cacheURL(for text: String) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tts-power", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(stableHash(text)).wav")
    }

    func cachedWAV(for text: String) -> Data? {
        try? Data(contentsOf: cacheURL(for: text))
    }

    func prefetchPower(_ text: String) {
        #if canImport(FluidAudio)
        let url = cacheURL(for: text)
        if FileManager.default.fileExists(atPath: url.path) { return }
        guard isReady else { return }
        Task { @MainActor in
            do {
                let data = try await synthesizePower(text: text)
                try data.write(to: url, options: .atomic)
            } catch {}
        }
        #endif
    }

    private func stableHash(_ s: String) -> String {
        var h: UInt64 = 5381
        for b in s.utf8 { h = ((h << 5) &+ h) &+ UInt64(b) }
        return String(h, radix: 16)
    }
}

enum OnDeviceTTSError: Error {
    case notReady
    case timeout
}

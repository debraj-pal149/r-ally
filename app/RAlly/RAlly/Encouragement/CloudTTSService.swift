import Foundation

enum CloudTTSProvider: String, Sendable, CaseIterable {
    case fishAudio = "Fish Audio"
    case elevenLabs = "ElevenLabs"
    case appleFallback = "Apple Neural"
}

struct CoachVoiceOption: Identifiable, Equatable, Sendable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var vibe: String
    var previewText: String
    var elevenLabsVoiceId: String?

    static let defaultVoiceId = "a0ef13957a8442dca8139d6a345bdf66"

    static let top5: [CoachVoiceOption] = [
        CoachVoiceOption(
            id: "a0ef13957a8442dca8139d6a345bdf66",
            title: "The Sarge",
            subtitle: "Drill Commander",
            vibe: "Loud military drill coach delivery with zero pity",
            previewText: "I see the slip! Pick your damn knees up and earn this run!",
            elevenLabsVoiceId: "onwK4e9ZLuTAKqWW03F9"
        ),
        CoachVoiceOption(
            id: "6b2ef1931c30417981cb1f13742496b0",
            title: "The Southpaw",
            subtitle: "Ringside Corner Coach",
            vibe: "Raspy, gritty fighter intensity with urgent corner cadence",
            previewText: "One more round! Dig into the dirt, find that second wind, and fight back!",
            elevenLabsVoiceId: "ErXwobaYiN019PkySvjV"
        ),
        CoachVoiceOption(
            id: "ff5468d06c2443dba9b8d2f9c6aa26b0",
            title: "The Beast",
            subtitle: "Hardcore Motivator",
            vibe: "Deep, aggressive mental toughness. Pain is fuel",
            previewText: "Your mind wants to quit before your legs do. Push through the wall right now!",
            elevenLabsVoiceId: "pNInz6obpgDQGcFmaJgB"
        ),
        CoachVoiceOption(
            id: "bc44dad8dbab41f28afbe4092094e07c",
            title: "The Drill Master",
            subtitle: "Iron Instructor",
            vibe: "Booming, loud boot-camp delivery with zero mercy",
            previewText: "You call that running? Move it, move it! Drop the excuses and drive!",
            elevenLabsVoiceId: "VR6AewLTigWG4xSOukaG"
        ),
        CoachVoiceOption(
            id: "9865a69980674b94b58a39daa5455cee",
            title: "The Gunny",
            subtitle: "Gravel & Grit Coach",
            vibe: "Deep raspy gravel, hardcore battlefield intensity",
            previewText: "Hold the standard! Quiet mouth, heavy lungs, keep pushing until the finish!",
            elevenLabsVoiceId: "N2lVS1w4EtoT3dr4eOWO"
        )
    ]

    static func find(_ id: String) -> CoachVoiceOption {
        top5.first { $0.id == id } ?? top5[0]
    }
}

actor CloudTTSService {
    static let shared = CloudTTSService()

    private let session: URLSession
    private var memoryCache: [String: Data] = [:]
    private let fileManager = FileManager.default

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6.0
        config.timeoutIntervalForResource = 12.0
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    /// Read API keys from Bundle
    nonisolated static func fishAudioKey() -> String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "FISH_AUDIO_API_KEY") as? String,
              !key.isEmpty, !key.hasPrefix("$") else {
            return ""
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func elevenLabsKey() -> String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "ELEVENLABS_API_KEY") as? String,
              !key.isEmpty, !key.hasPrefix("$") else {
            return ""
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Precedence: Fish Audio (if key present) > ElevenLabs (if key present & no Fish) > Apple Fallback
    nonisolated static var activeProvider: CloudTTSProvider {
        let fish = fishAudioKey()
        let eleven = elevenLabsKey()
        if !fish.isEmpty {
            return .fishAudio
        } else if !eleven.isEmpty {
            return .elevenLabs
        } else {
            return .appleFallback
        }
    }

    nonisolated static var hasCloudAPI: Bool {
        activeProvider != .appleFallback
    }

    func synthesize(text: String, voiceId: String) async throws -> Data {
        let provider = Self.activeProvider
        let cacheKey = "\(provider.rawValue):\(voiceId):\(text)"

        // 1. In-memory check
        if let mem = memoryCache[cacheKey] {
            return mem
        }

        // 2. Disk cache check
        let diskURL = cacheURL(key: cacheKey)
        if let diskData = try? Data(contentsOf: diskURL), !diskData.isEmpty {
            memoryCache[cacheKey] = diskData
            return diskData
        }

        // 3. Network fetch
        let data: Data
        switch provider {
        case .fishAudio:
            data = try await fetchFishAudio(text: text, voiceId: voiceId)
        case .elevenLabs:
            data = try await fetchElevenLabs(text: text, voiceId: voiceId)
        case .appleFallback:
            throw CloudTTSError.noAPIKey
        }

        guard !data.isEmpty else {
            throw CloudTTSError.emptyResponse
        }

        // Store in cache
        memoryCache[cacheKey] = data
        try? data.write(to: diskURL, options: .atomic)
        return data
    }

    nonisolated func prefetch(text: String, voiceId: String) {
        Task {
            _ = try? await self.synthesize(text: text, voiceId: voiceId)
        }
    }

    func cachedData(text: String, voiceId: String) -> Data? {
        let provider = Self.activeProvider
        let cacheKey = "\(provider.rawValue):\(voiceId):\(text)"
        if let mem = memoryCache[cacheKey] { return mem }
        let diskURL = cacheURL(key: cacheKey)
        if let diskData = try? Data(contentsOf: diskURL), !diskData.isEmpty {
            memoryCache[cacheKey] = diskData
            return diskData
        }
        return nil
    }

    private func fetchFishAudio(text: String, voiceId: String) async throws -> Data {
        let apiKey = Self.fishAudioKey()
        guard !apiKey.isEmpty else { throw CloudTTSError.noAPIKey }

        guard let url = URL(string: "https://api.fish.audio/v1/tts") else {
            throw CloudTTSError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("s2-pro", forHTTPHeaderField: "model")

        let payload: [String: Any] = [
            "text": text,
            "reference_id": voiceId,
            "format": "mp3",
            "latency": "balanced"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudTTSError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw CloudTTSError.serverError(statusCode: http.statusCode, message: msg)
        }

        return data
    }

    private func fetchElevenLabs(text: String, voiceId: String) async throws -> Data {
        let apiKey = Self.elevenLabsKey()
        guard !apiKey.isEmpty else { throw CloudTTSError.noAPIKey }

        let opt = CoachVoiceOption.find(voiceId)
        let resolvedVoiceId = opt.elevenLabsVoiceId ?? "onwK4e9ZLuTAKqWW03F9"

        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(resolvedVoiceId)?output_format=mp3_44100_128") else {
            throw CloudTTSError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": [
                "stability": 0.45,
                "similarity_boost": 0.85,
                "style": 0.4,
                "use_speaker_boost": true
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CloudTTSError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw CloudTTSError.serverError(statusCode: http.statusCode, message: msg)
        }

        return data
    }

    private func cacheURL(key: String) -> URL {
        let dir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tts-cloud", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        var hash: UInt64 = 5381
        for byte in key.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return dir.appendingPathComponent("\(String(hash, radix: 16)).mp3")
    }
}

enum CloudTTSError: LocalizedError, Sendable {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case emptyResponse
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No cloud TTS API key configured."
        case .invalidURL: return "Invalid TTS request URL."
        case .invalidResponse: return "Invalid server response."
        case .emptyResponse: return "Received empty audio from TTS provider."
        case .serverError(let code, let msg): return "TTS Server Error (\(code)): \(msg)"
        }
    }
}

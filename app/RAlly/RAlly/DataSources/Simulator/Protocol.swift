import Foundation

enum SimulatorProtocol {
    static let version = 1

    struct Hello: Codable {
        var v: Int
        var type: String
        var scenarioId: String
        var activity: String
        var timeScale: Double
        var tickHz: Double
    }

    struct Metrics: Codable {
        var v: Int
        var type: String
        var t: Double
        var samples: [WireSample]
    }

    struct WireSample: Codable {
        var k: String
        var x: Double
    }

    struct ScenarioEnded: Codable {
        var v: Int
        var type: String
        var t: Double
    }

    struct AppHello: Codable {
        var v: Int = 1
        var type: String = "appHello"
        var appVersion: String
        var persona: String
    }

    struct Risk: Codable {
        var v: Int = 1
        var type: String = "risk"
        var t: Double
        var score: Double
        var state: String
    }

    struct Trigger: Codable {
        var v: Int = 1
        var type: String = "trigger"
        var t: Double
        var kind: String
        var persona: String
        var text: String
        var sourceLLM: Bool
        var latencyMs: Int
    }

    struct SpeechDone: Codable {
        var v: Int = 1
        var type: String = "speechDone"
        var t: Double
    }

    static func encode<T: Encodable>(_ value: T) -> String? {
        let enc = JSONEncoder()
        guard let data = try? enc.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

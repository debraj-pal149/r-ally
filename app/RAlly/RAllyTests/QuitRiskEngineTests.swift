import Foundation
import Testing
@testable import RAlly

struct QuitRiskEngineTests {
    @Test func replayEveryFixture() throws {
        let dir = fixtureDir()
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let csvs = files.filter { $0.hasSuffix(".csv") }
        #expect(!csvs.isEmpty)
        for name in csvs {
            let text = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
            let activity: ActivityKind = {
                if name.contains("ride") { return .cycling }
                if name.contains("lift") { return .strength }
                if name.contains("box") { return .boxing }
                if name.contains("swim") { return .swimming }
                if name.contains("row") { return .rowing }
                if name.contains("hiit") { return .hiit }
                return .running
            }()
            let engine = QuitRiskEngine()
            engine.reset(activity: activity, maxHR: 190, sessionCap: 7)
            var lastT: TimeInterval = -1
            var triggers: [(TimeInterval, TriggerKind)] = []
            for line in text.split(separator: "\n") {
                if line.hasPrefix("#") || line.hasPrefix("t,") { continue }
                let parts = line.split(separator: ",")
                guard parts.count == 3, let t = Double(parts[0]), let v = Double(parts[2]) else { continue }
                let kind = MetricKind(rawValue: String(parts[1])) ?? .motionIntensityG
                engine.ingest(MetricSample(kind: kind, value: v, timestamp: t, source: .simulator))
                if floor(t) > lastT {
                    lastT = floor(t)
                    let r = engine.tick(t: lastT)
                    if let k = r.trigger { triggers.append((lastT, k)) }
                }
            }
            if name.contains("bonk") {
                #expect(triggers.contains { $0.1 == .preQuitFade })
            }
        }
    }
}

func fixtureDir() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("fixtures")
}

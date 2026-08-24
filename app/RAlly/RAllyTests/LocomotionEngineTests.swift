import Foundation
import Testing
@testable import RAlly

struct LocomotionEngineTests {
    private func tick(_ engine: QuitRiskEngine, t: TimeInterval) -> EngineTickResult {
        let r = engine.tick(t: t)
        if r.trigger != nil {
            engine.policy.noteSpeechEndedImmediate(t: t)
        }
        return r
    }

    @Test func standingStillDoesNotFlickerCriticalUILabel() {
        let engine = QuitRiskEngine()
        engine.reset(activity: .running, maxHR: 190, sessionCap: 24)
        for t in 0..<30 {
            let tt = TimeInterval(t)
            engine.ingest(MetricSample(kind: .speedMps, value: 3.0, timestamp: tt, source: .device))
            engine.ingest(MetricSample(kind: .cadenceSpm, value: 165, timestamp: tt, source: .device))
            _ = tick(engine, t: tt)
        }
        var leftStopped = false
        var restNags = 0
        for t in 30..<150 {
            let tt = TimeInterval(t)
            let jitter = (t % 7 == 0) ? 0.4 : 0.0
            engine.ingest(MetricSample(kind: .speedMps, value: jitter, timestamp: tt, source: .device))
            engine.ingest(MetricSample(kind: .cadenceSpm, value: 0, timestamp: tt, source: .device))
            engine.ingest(MetricSample(kind: .motionStationary, value: 1, timestamp: tt, source: .device))
            let r = tick(engine, t: tt)
            if r.locomotion == .stopped {
                if r.trigger == .stopped || r.trigger == .stillStopped { restNags += 1 }
            } else if t > 40 {
                leftStopped = true
            }
        }
        #expect(leftStopped == false)
        #expect(restNags >= 3)
    }

    @Test func restNagsContinueAfterFadeCapExhausted() {
        let engine = QuitRiskEngine()
        engine.reset(activity: .running, maxHR: 190, sessionCap: 2)
        for t in 0..<200 {
            let tt = TimeInterval(t)
            let speed = t < 60 ? 3.2 : 2.5
            engine.ingest(MetricSample(kind: .speedMps, value: speed, timestamp: tt, source: .device))
            engine.ingest(MetricSample(kind: .cadenceSpm, value: 160, timestamp: tt, source: .device))
            _ = tick(engine, t: tt)
        }
        var restNags = 0
        for t in 200..<320 {
            let tt = TimeInterval(t)
            engine.ingest(MetricSample(kind: .speedMps, value: 0, timestamp: tt, source: .device))
            engine.ingest(MetricSample(kind: .cadenceSpm, value: 0, timestamp: tt, source: .device))
            engine.ingest(MetricSample(kind: .motionStationary, value: 1, timestamp: tt, source: .device))
            let r = tick(engine, t: tt)
            if r.trigger == .stopped || r.trigger == .stillStopped { restNags += 1 }
        }
        #expect(restNags >= 3)
    }

    @Test func baseOutFrozenWhileStopped() {
        let engine = QuitRiskEngine()
        engine.reset(activity: .running, maxHR: 190, sessionCap: 24)
        for t in 0..<40 {
            let tt = TimeInterval(t)
            engine.ingest(MetricSample(kind: .speedMps, value: 3.0, timestamp: tt, source: .device))
            _ = tick(engine, t: tt)
        }
        let baseBefore = engine.store.tick(
            t: 40,
            channelsIn: EngineChannels(output: 3.0, hr: nil, rhythm: 160, plannedRest: false, snapshot: ""),
            freezeBaseline: false
        ).baseOut
        var baseAtStop: Double?
        for t in 41..<100 {
            let tt = TimeInterval(t)
            engine.ingest(MetricSample(kind: .speedMps, value: 0, timestamp: tt, source: .device))
            let r = tick(engine, t: tt)
            if r.locomotion == .stopped {
                if baseAtStop == nil { baseAtStop = r.store.baseOut }
                #expect(abs(r.store.baseOut - (baseAtStop ?? r.store.baseOut)) < 0.001)
            }
        }
        #expect(baseAtStop != nil)
        #expect(abs((baseAtStop ?? 0) - baseBefore) < 0.5)
    }

    @Test func gpsJitterDoesNotTriggerResume() {
        let c = LocomotionClassifier()
        for _ in 0..<5 {
            _ = c.update(speed: 0, cadence: 0, hint: .init(stationary: true, walking: nil, running: nil))
        }
        #expect(c.state == .stopped)
        for _ in 0..<10 {
            _ = c.update(speed: 0.9, cadence: 0, hint: .init(stationary: true, walking: nil, running: nil))
        }
        #expect(c.state == .stopped)
    }

    @Test func keepGoingFiresWhileHoldingPace() {
        let engine = QuitRiskEngine()
        engine.reset(activity: .running, maxHR: 190, sessionCap: 24)
        var keeps = 0
        for t in 0..<200 {
            let tt = TimeInterval(t)
            engine.ingest(MetricSample(kind: .speedMps, value: 3.1, timestamp: tt, source: .device))
            engine.ingest(MetricSample(kind: .cadenceSpm, value: 168, timestamp: tt, source: .device))
            let r = tick(engine, t: tt)
            if r.trigger == .keepGoing { keeps += 1 }
        }
        #expect(keeps >= 1)
    }

    @Test func paceSlipFiresOnMildSlowdown() {
        let engine = QuitRiskEngine()
        engine.reset(activity: .running, maxHR: 190, sessionCap: 24)
        for t in 0..<80 {
            let tt = TimeInterval(t)
            engine.ingest(MetricSample(kind: .speedMps, value: 3.2, timestamp: tt, source: .device))
            engine.ingest(MetricSample(kind: .cadenceSpm, value: 170, timestamp: tt, source: .device))
            _ = tick(engine, t: tt)
        }
        var slips = 0
        for t in 80..<130 {
            let tt = TimeInterval(t)
            engine.ingest(MetricSample(kind: .speedMps, value: 2.8, timestamp: tt, source: .device))
            engine.ingest(MetricSample(kind: .cadenceSpm, value: 158, timestamp: tt, source: .device))
            let r = tick(engine, t: tt)
            if r.trigger == .paceSlip { slips += 1 }
        }
        #expect(slips >= 1)
    }

    @Test func speechGateBlocksUntilEnded() {
        let policy = TriggerPolicy()
        policy.reset(fadeShoutCap: 24)
        #expect(policy.allow(kind: .keepGoing, t: 50, warmupOver: true, goalDone: false))
        policy.record(kind: .keepGoing, t: 50)
        #expect(policy.allow(kind: .keepGoing, t: 51, warmupOver: true, goalDone: false) == false)
        policy.noteSpeechEnded(t: 60)
        #expect(policy.allow(kind: .stillStopped, t: 62, warmupOver: true, goalDone: false))
    }
}

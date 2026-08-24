import Foundation
import Testing
@testable import RAlly

struct AdapterTests {
    @Test func runningUsesSpeed() {
        let ch = RunningAdapter().channels(from: [.speedMps: 3.2, .cadenceSpm: 170], t: 10)
        #expect(ch.output == 3.2)
        #expect(ch.rhythm == 170)
        #expect(ch.outputIsProxy == false)
    }

    @Test func runningGradeAdjustsUphill() {
        let flat = RunningAdapter().channels(from: [.speedMps: 3.0], t: 1)
        let hill = RunningAdapter().channels(from: [.speedMps: 3.0, .gradePercent: 10], t: 1)
        #expect(hill.output > flat.output)
    }

    @Test func cyclingUsesPowerNotSpeed() {
        let powered = CyclingAdapter().channels(from: [.powerWatts: 220, .speedMps: 8], t: 1)
        #expect(powered.output == 220)
        #expect(powered.outputIsProxy == false)
        let proxy = CyclingAdapter().channels(from: [.speedMps: 8], t: 1)
        #expect(proxy.output == 8)
        #expect(proxy.outputIsProxy)
    }

    @Test func runningDoesNotInventHealthyCadence() {
        let slow = RunningAdapter().channels(from: [.speedMps: 0.4], t: 1)
        #expect(slow.rhythm <= 100)
    }

    @Test func labSportsStaySilent() {
        let ch = SilentLabAdapter().channels(from: [.repVelocityMps: 0.8], t: 1)
        #expect(ch.plannedRest)
        #expect(ch.output == 0)
    }
}

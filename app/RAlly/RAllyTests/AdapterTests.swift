import Foundation
import Testing
@testable import RAlly

struct AdapterTests {
    @Test func runningUsesSpeed() {
        let ch = RunningAdapter().channels(from: [.speedMps: 3.2, .cadenceSpm: 170], t: 10)
        #expect(ch.output == 3.2)
        #expect(ch.rhythm == 170)
    }

    @Test func cyclingFallsBackToSpeed() {
        let ch = CyclingAdapter().channels(from: [.speedMps: 8], t: 1)
        #expect(ch.output == 240)
    }
}

import Foundation
import Testing
@testable import RAlly

struct MetricStoreTests {
    @Test func ewmaMovesTowardInput() {
        let store = MetricStore()
        store.reset()
        var last = 0.0
        for t in 0..<200 {
            let snap = store.tick(t: Double(t), channelsIn: EngineChannels(output: 10, hr: 140, rhythm: 160, plannedRest: false, snapshot: ""))
            last = snap.baseOut
        }
        #expect(last > 8)
        #expect(last <= 10.1)
    }
}

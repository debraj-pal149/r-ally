import Foundation
import Testing
@testable import RAlly

struct ProtocolCodableTests {
    @Test func riskRoundTrip() throws {
        let r = SimulatorProtocol.Risk(t: 688, score: 58.2, state: "WOBBLING")
        let data = try JSONEncoder().encode(r)
        let back = try JSONDecoder().decode(SimulatorProtocol.Risk.self, from: data)
        #expect(back.score == 58.2)
        #expect(back.type == "risk")
    }

    @Test func metricsLiteral() throws {
        let json = """
        {"v":1,"type":"metrics","t":412.0,"samples":[{"k":"heartRateBpm","x":163.2},{"k":"paceSecPerKm","x":341.0}]}
        """
        let m = try JSONDecoder().decode(SimulatorProtocol.Metrics.self, from: Data(json.utf8))
        #expect(m.samples.count == 2)
        #expect(m.samples[0].k == "heartRateBpm")
    }
}

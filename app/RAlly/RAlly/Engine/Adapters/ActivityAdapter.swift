import Foundation

protocol ActivityAdapter {
    func channels(from latest: [MetricKind: Double], t: TimeInterval) -> EngineChannels
    var usesStructuredRest: Bool { get }
}

extension ActivityAdapter {
    var usesStructuredRest: Bool { false }

    func dropPhrase(outputDrop: Double, stutter: Double, grind: Double) -> String {
        var bits: [String] = []
        if outputDrop > 0.06 {
            bits.append("output slipping about \(Int((outputDrop * 100).rounded())) percent below their normal")
        } else {
            bits.append("output holding near their normal")
        }
        if stutter > 0.4 { bits.append("rhythm choppy") }
        if grind > 0.3 { bits.append("effort high for several minutes") }
        return bits.joined(separator: ", ")
    }
}

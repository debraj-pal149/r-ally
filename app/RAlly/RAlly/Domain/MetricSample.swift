import Foundation

struct MetricSample: Sendable, Equatable {
    var kind: MetricKind
    var value: Double
    var timestamp: TimeInterval
    var source: SampleSource
}

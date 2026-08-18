import Foundation

struct RallyMoment: Identifiable, Sendable, Equatable {
    var id: UUID = UUID()
    var t: TimeInterval
    var kind: TriggerKind
    var text: String
    var sourceLLM: Bool
    var latencyMs: Int
    var aftermath: String
    var outputAtTrigger: Double?
    var outputAfter40s: Double?
}

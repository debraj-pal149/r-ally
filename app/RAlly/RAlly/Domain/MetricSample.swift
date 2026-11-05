import Foundation

struct MetricSample: Sendable, Equatable {
    var kind: MetricKind
    var value: Double
    var timestamp: TimeInterval
    var source: SampleSource
}

/// Maps wall-clock sensor timestamps onto workout-active time.
///
/// Data sources keep running while the workout is paused, so their timestamps
/// include the pause. Subtracting accumulated pause time here keeps every
/// downstream consumer—live timer, pace, splits, breadcrumbs and coaching—on
/// one pause-free timeline.
struct ActiveWorkoutClock: Sendable, Equatable {
    private(set) var accumulatedPause: TimeInterval = 0
    private(set) var pausedAt: Date?

    mutating func reset() {
        accumulatedPause = 0
        pausedAt = nil
    }

    mutating func setPaused(_ paused: Bool, now: Date = Date()) {
        if paused {
            if pausedAt == nil { pausedAt = now }
        } else if let pausedAt {
            accumulatedPause += max(0, now.timeIntervalSince(pausedAt))
            self.pausedAt = nil
        }
    }

    func activeTimestamp(for rawTimestamp: TimeInterval) -> TimeInterval {
        max(0, rawTimestamp - accumulatedPause)
    }
}

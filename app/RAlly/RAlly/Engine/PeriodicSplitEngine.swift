import Foundation

/// In-Run Periodic Distance Milestone Voice Engine.
/// Detects integer kilometre (or mile) crossovers and prepares concise split announcements.
final class PeriodicSplitEngine: @unchecked Sendable {
    private var lastAnnouncedUnit: Int = 0
    private var lastSplitTimestamp: TimeInterval = 0
    private var lastSplitDistance: Double = 0

    func reset() {
        lastAnnouncedUnit = 0
        lastSplitTimestamp = 0
        lastSplitDistance = 0
    }

    func checkKilometerSplit(
        currentDistanceM: Double,
        currentElapsedT: TimeInterval,
        persona: Persona,
        currentPaceSecPerKm: Double,
        unit: DistanceUnit = .kilometre
    ) -> String? {
        let segmentM = unit == .mile ? 1609.344 : 1000.0
        let currentMark = Int(currentDistanceM / segmentM)
        guard currentMark > lastAnnouncedUnit, currentMark >= 1 else { return nil }

        let splitDuration = currentElapsedT - lastSplitTimestamp
        let splitPace = splitDuration > 0 ? splitDuration : currentPaceSecPerKm
        // Formatters.pace expects sec/km; for miles convert if needed for display consistency
        let paceForDisplay: Double = {
            if unit == .mile {
                // splitDuration for one mile segment → sec/mile; convert to sec/km for Formatters? Better show unit pace.
                return splitPace // already duration of one segment
            }
            return splitPace
        }()
        let paceText = Formatters.pace(unit == .mile ? (paceForDisplay / 1.609344) : paceForDisplay)

        lastAnnouncedUnit = currentMark
        lastSplitTimestamp = currentElapsedT
        lastSplitDistance = currentDistanceM

        let label = unit == .mile ? "Mile" : "Kilometre"
        let labelLower = unit == .mile ? "mile" : "kilometre"

        switch persona.id {
        case .sarge:
            return "\(label) \(currentMark) down. Split pace: \(paceText). Keep those boots driving."
        case .southpaw:
            return "Round \(currentMark) in the book, kid. Pace: \(paceText). Stay light and stay mean."
        case .machine:
            return "\(label) \(currentMark) complete. Split: \(paceText). Output consistent."
        default:
            return "\(label) \(currentMark) logged. Pace: \(paceText). Hold that \(labelLower) rhythm and keep rolling."
        }
    }
}

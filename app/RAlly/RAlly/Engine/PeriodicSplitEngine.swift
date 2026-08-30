import Foundation

/// In-Run Periodic 1-Kilometer Milestone Voice Engine.
/// Detects integer kilometer crossovers (1.0 km, 2.0 km, 3.0 km...) and prepares
/// concise, in-character vocal announcements without blocking quit-risk prompts.
final class PeriodicSplitEngine: @unchecked Sendable {
    private var lastAnnouncedKm: Int = 0
    private var lastSplitTimestamp: TimeInterval = 0
    private var lastSplitDistance: Double = 0

    func reset() {
        lastAnnouncedKm = 0
        lastSplitTimestamp = 0
        lastSplitDistance = 0
    }

    /// Checks if a new integer kilometer mark has been crossed and returns a spoken split line if due.
    func checkKilometerSplit(
        currentDistanceM: Double,
        currentElapsedT: TimeInterval,
        persona: Persona,
        currentPaceSecPerKm: Double
    ) -> String? {
        let currentKm = Int(currentDistanceM / 1000.0)
        guard currentKm > lastAnnouncedKm, currentKm >= 1 else { return nil }

        let splitDuration = currentElapsedT - lastSplitTimestamp
        let splitPace = splitDuration > 0 ? splitDuration : currentPaceSecPerKm
        let paceText = Formatters.pace(splitPace)

        lastAnnouncedKm = currentKm
        lastSplitTimestamp = currentElapsedT
        lastSplitDistance = currentDistanceM

        // Generate persona-tailored discrete split line
        switch persona.id {
        case .sarge:
            return "Kilometer \(currentKm) down. Split pace: \(paceText). Keep those boots driving."
        case .southpaw:
            return "Round \(currentKm) in the book, kid. Pace: \(paceText). Stay light and stay mean."
        case .machine:
            return "Kilometer \(currentKm) complete. Split: \(paceText). Output consistent."
        default:
            return "Kilometer \(currentKm) logged. Pace: \(paceText). Hold that rhythm and keep rolling."
        }
    }
}

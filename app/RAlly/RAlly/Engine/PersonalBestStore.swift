import Foundation

/// Lifetime Personal Best (PB) Store & Achievement Matrix.
/// Tracks lifetime running records and detects when an athlete sets new milestones.
@MainActor
final class PersonalBestStore: ObservableObject {
    static let shared = PersonalBestStore()

    private let storageKey = "rally.lifetime.personal_bests"
    @Published private(set) var records: [PersonalBestAchievement.PBKind: PersonalBestAchievement] = [:]

    init() {
        loadRecords()
    }

    func reset() {
        records.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([PersonalBestAchievement].self, from: data) {
            for item in decoded {
                records[item.kind] = item
            }
        }
    }

    private func saveRecords() {
        let array = Array(records.values)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Evaluates completed session metrics and saves any newly unlocked Personal Bests.
    /// Returns the list of newly broken achievements.
    @discardableResult
    func evaluateSession(
        distanceM: Double,
        durationSec: Double,
        elevationGainM: Double,
        splits: [LapSplitRecord]
    ) -> [PersonalBestAchievement] {
        var newlyUnlocked: [PersonalBestAchievement] = []

        // 1. Longest Run
        if distanceM >= 1000 {
            let prevLongest = records[.longestRun]?.recordValue ?? 0
            if distanceM > prevLongest {
                let badge = PersonalBestAchievement(
                    kind: .longestRun,
                    title: "Longest Run",
                    recordValue: distanceM,
                    formattedValue: Formatters.km(distanceM)
                )
                records[.longestRun] = badge
                newlyUnlocked.append(badge)
            }
        }

        // 2. Maximum Elevation Gain
        if elevationGainM > 15 {
            let prevElev = records[.maxElevation]?.recordValue ?? 0
            if elevationGainM > prevElev {
                let badge = PersonalBestAchievement(
                    kind: .maxElevation,
                    title: "Max Elevation",
                    recordValue: elevationGainM,
                    formattedValue: "\(Int(elevationGainM)) m"
                )
                records[.maxElevation] = badge
                newlyUnlocked.append(badge)
            }
        }

        // 3. Fastest 1K (check splits)
        let valid1KSplits = splits.filter { $0.distanceM >= 950 && $0.durationSec > 60 }
        if let fastest1K = valid1KSplits.min(by: { $0.durationSec < $1.durationSec }) {
            let prevFastest1K = records[.fastest1K]?.recordValue ?? 999999
            if fastest1K.durationSec < prevFastest1K {
                let badge = PersonalBestAchievement(
                    kind: .fastest1K,
                    title: "Fastest 1K",
                    recordValue: fastest1K.durationSec,
                    formattedValue: Formatters.pace(fastest1K.paceSecPerKm)
                )
                records[.fastest1K] = badge
                newlyUnlocked.append(badge)
            }
        }

        // 4. Fastest 5K
        if distanceM >= 5000 {
            let estimated5kSec = (durationSec / distanceM) * 5000.0
            let prev5K = records[.fastest5K]?.recordValue ?? 999999
            if estimated5kSec < prev5K {
                let badge = PersonalBestAchievement(
                    kind: .fastest5K,
                    title: "Fastest 5K",
                    recordValue: estimated5kSec,
                    formattedValue: Formatters.clock(estimated5kSec)
                )
                records[.fastest5K] = badge
                newlyUnlocked.append(badge)
            }
        }

        // 5. Fastest 10K
        if distanceM >= 10000 {
            let estimated10kSec = (durationSec / distanceM) * 10000.0
            let prev10K = records[.fastest10K]?.recordValue ?? 999999
            if estimated10kSec < prev10K {
                let badge = PersonalBestAchievement(
                    kind: .fastest10K,
                    title: "Fastest 10K",
                    recordValue: estimated10kSec,
                    formattedValue: Formatters.clock(estimated10kSec)
                )
                records[.fastest10K] = badge
                newlyUnlocked.append(badge)
            }
        }

        if !newlyUnlocked.isEmpty {
            saveRecords()
        }

        return newlyUnlocked
    }

    /// All badges sorted by logical progression.
    var allBadges: [PersonalBestAchievement] {
        PersonalBestAchievement.PBKind.allCases.compactMap { records[$0] }
    }
}

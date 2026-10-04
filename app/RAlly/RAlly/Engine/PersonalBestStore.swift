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
        migrateScaledDistancePBsIfNeeded()
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

        // 4. Fastest 5K — best consecutive 5×~1 km splits (real segment, not pace-scaled).
        if let best5K = bestConsecutiveSplitTime(splits: splits, lapCount: 5) {
            let prev5K = records[.fastest5K]?.recordValue ?? 999999
            if best5K < prev5K {
                let badge = PersonalBestAchievement(
                    kind: .fastest5K,
                    title: "Fastest 5K",
                    recordValue: best5K,
                    formattedValue: Formatters.clock(best5K)
                )
                records[.fastest5K] = badge
                newlyUnlocked.append(badge)
            }
        }

        // 5. Fastest 10K — best consecutive 10×~1 km splits.
        if let best10K = bestConsecutiveSplitTime(splits: splits, lapCount: 10) {
            let prev10K = records[.fastest10K]?.recordValue ?? 999999
            if best10K < prev10K {
                let badge = PersonalBestAchievement(
                    kind: .fastest10K,
                    title: "Fastest 10K",
                    recordValue: best10K,
                    formattedValue: Formatters.clock(best10K)
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

    /// Fastest time across any window of `lapCount` consecutive km splits in order.
    /// Example: a 7 km run yields three candidate 5Ks (km 1–5, 2–6, 3–7); the best wins.
    /// Invalid laps (GPS jump / rest blob) are not dropped from the sequence — they
    /// only invalidate windows that include them, so km 2 and km 4 never become "consecutive".
    private func bestConsecutiveSplitTime(splits: [LapSplitRecord], lapCount: Int) -> Double? {
        guard splits.count >= lapCount else { return nil }
        var best: Double?
        for i in 0...(splits.count - lapCount) {
            let window = splits[i..<(i + lapCount)]
            guard window.allSatisfy(Self.isPlausibleKmSplit) else { continue }
            let dist = window.reduce(0.0) { $0 + $1.distanceM }
            let time = window.reduce(0.0) { $0 + $1.durationSec }
            // ~5.00–5.75 km for a 5-lap window; rejects a 2 km lump counted as one split.
            guard dist >= Double(lapCount) * 950, dist <= Double(lapCount) * 1150 else { continue }
            if best == nil || time < best! {
                best = time
            }
        }
        return best
    }

    /// One km lap: real distance and not a GPS teleport or a long standstill.
    private static func isPlausibleKmSplit(_ split: LapSplitRecord) -> Bool {
        (950...1150).contains(split.distanceM) && split.durationSec > 45 && split.durationSec < 1800
    }

    /// Old 5K/10K badges were average-pace projections. Drop them once so real
    /// consecutive-split times can take their place.
    private func migrateScaledDistancePBsIfNeeded() {
        let flag = "rally.pb.consecutive_split_5k_v1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        records[.fastest5K] = nil
        records[.fastest10K] = nil
        saveRecords()
        UserDefaults.standard.set(true, forKey: flag)
    }
}

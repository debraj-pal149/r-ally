import Foundation

/// Compact athlete history for lean LLM prompts + right-time coaching cues.
struct AthleteHistoryCard: Codable, Sendable, Equatable {
    var totalRuns: Int = 0
    var daysSinceLastRun: Int? = nil
    var lastDistanceM: Double = 0
    var lastDurationSec: Double = 0
    var lastAvgPaceSecPerKm: Double = 0
    var longestDistanceM: Double = 0
    var previousQuitDistanceM: Double = 0
    var thirtyDayBestPaceSecPerKm: Double = 0
    var recentDistancesM: [Double] = []
    var recentPacesSecPerKm: [Double] = []
    var trend: Trend = .unknown
    var consistency: Consistency = .unknown
    var isNewAthlete: Bool = true

    enum Trend: String, Codable, Sendable {
        case improving, holding, declining, unknown
    }

    enum Consistency: String, Codable, Sendable {
        case consistent, spaced, inconsistent, unknown
    }

    /// Always-on card for prompts (~40-60 tokens).
    var leanPromptLines: [String] {
        var lines: [String] = []
        if isNewAthlete || totalRuns == 0 {
            lines.append("history: brand-new / first runs. Big initiation push")
            return lines
        }
        lines.append("history: \(totalRuns) runs | last \(daysSinceLastRun.map { "\($0)d ago" } ?? "recent") | \(Formatters.km(lastDistanceM)) km")
        if lastAvgPaceSecPerKm > 0 {
            lines.append("last_pace: \(Formatters.pace(lastAvgPaceSecPerKm))/km | trend: \(trend.rawValue) | consistency: \(consistency.rawValue)")
        } else {
            lines.append("trend: \(trend.rawValue) | consistency: \(consistency.rawValue)")
        }
        if longestDistanceM > 0 {
            lines.append("longest: \(Formatters.km(longestDistanceM)) km")
        }
        return lines
    }

    /// First-minute opening push line (deterministic, no LLM required).
    func openingPushLine(persona: Persona, unit: DistanceUnit) -> String {
        let name = "" // persona voice handles vocatives
        _ = name
        if isNewAthlete || totalRuns == 0 {
            switch persona.id {
            case .sarge: return "First days on the road. Lock in now, earn every \(unit.singular), and set the standard."
            case .southpaw: return "Brand new fight kid. This is round one, stay mean and write your first honest \(unit.plural)."
            case .machine: return "New engine online. Establish baseline output and hold form through the first \(unit.plural)."
            case .preacher: return "A new chapter begins. Rise into this run and claim your first honest \(unit.plural)."
            case .steady: return "Fresh start. Breathe, settle the stride, and build something you can trust."
            }
        }

        let days = daysSinceLastRun ?? 0
        let lastDist = spokenDistance(lastDistanceM, unit: unit)

        // Inconsistent / spaced
        if consistency == .inconsistent || consistency == .spaced || days >= 5 {
            switch persona.id {
            case .sarge:
                return days >= 5
                    ? "\(days) days since your last run. That gap ends now. Drive harder than last time."
                    : "Your recent runs have been inconsistent. Today we fix that. Hold the standard."
            case .southpaw:
                return days >= 5
                    ? "Been \(days) days kid. Rust is talking. Shake it off and fight harder than last round."
                    : "You've been patchy lately. Today we stitch it back together. Stay mean."
            case .machine:
                return "Output gap detected. \(days) days idle. Re-engage and exceed last session distance \(lastDist)."
            case .preacher:
                return "You've been away. Return with purpose and outwork the last run."
            case .steady:
                return "It's been a few days. Ease in, then build. Make this one count."
            }
        }

        // Improving streak
        if trend == .improving {
            switch persona.id {
            case .sarge: return "You've been improving. Keep that climb. Match last run's \(lastDist) and push past it."
            case .southpaw: return "You've been getting sharper kid. Keep the streak alive and take another step up."
            case .machine: return "Positive trajectory confirmed. Maintain tempo from last run and extend the edge."
            case .preacher: return "You have been rising. Honor that progress and keep walking into stronger work."
            case .steady: return "Nice progress lately. Settle into that rhythm and keep building."
            }
        }

        // Declining
        if trend == .declining {
            switch persona.id {
            case .sarge: return "Recent runs slipped. Today we correct course. Stronger than last time, no excuses."
            case .southpaw: return "Last few rounds got soft. Dig in, reclaim the fight, and outwork them."
            case .machine: return "Downtrend flagged. Override it. Target better output than the last session."
            case .preacher: return "You dipped. Rise again now. This run is the turn."
            case .steady: return "Things got harder lately. Breathe, reset, and reclaim one honest run."
            }
        }

        // Holding / default
        switch persona.id {
        case .sarge: return "Back on the line. Last run was \(lastDist). Hold that tempo and earn more."
        case .southpaw: return "Back in the ring. Last time \(lastDist). Keep that fire and stay mean."
        case .machine: return "Session resume. Prior distance \(lastDist). Match baseline then exceed."
        case .preacher: return "You return. Last run \(lastDist). Stay faithful and build on it."
        case .steady: return "Welcome back. Last run \(lastDist). Find your breath and settle in."
        }
    }

    /// Event-gated one-liner for right-time injection (nil = don't inject).
    func gatedCue(
        distanceM: Double,
        currentPaceSecPerKm: Double,
        milestone: MilestoneState?,
        engineState: EngineState,
        elapsed: TimeInterval
    ) -> String? {
        // Beyond historical quit / longest
        if previousQuitDistanceM > 1000, distanceM > previousQuitDistanceM * 0.95, distanceM < previousQuitDistanceM * 1.15 {
            return "approaching/beyond last stop point (\(Formatters.km(previousQuitDistanceM)) km). Celebrate grit"
        }
        if longestDistanceM > 1000, distanceM > longestDistanceM * 0.98 {
            return "past longest-ever distance (\(Formatters.km(longestDistanceM)) km). Lifetime breakthrough"
        }
        // Chasing 30d pace PB
        if thirtyDayBestPaceSecPerKm > 0, currentPaceSecPerKm > 0,
           currentPaceSecPerKm <= thirtyDayBestPaceSecPerKm + 8,
           elapsed > 180 {
            return "near 30-day pace PB (\(Formatters.pace(thirtyDayBestPaceSecPerKm))/km). Chase it"
        }
        // Mid-run grind vs last similar
        if engineState == .critical || engineState == .wobbling, lastDistanceM > 0, elapsed > 300 {
            return "grind vs last run (\(Formatters.km(lastDistanceM)) km @ \(Formatters.pace(lastAvgPaceSecPerKm))/km). Outlast it"
        }
        if isNewAthlete, elapsed < 600 {
            return "new athlete week-one energy. Normalize effort, celebrate motion"
        }
        if let m = milestone {
            switch m {
            case .prevQuitVanquished:
                return "just passed historical quit distance. Name the victory"
            case .pacePBLatest:
                return "pace PB territory. Validate the surge"
            default:
                break
            }
        }
        return nil
    }

    /// Whether this cue should be shouted immediately (not wait for a risk trigger).
    func shouldSpeakDirectly(_ cue: String) -> Bool {
        cue.contains("last stop")
            || cue.contains("longest-ever")
            || cue.contains("pace PB")
            || cue.contains("historical quit")
    }

    /// Deterministic spoken beat for a breakthrough history cue.
    func spokenBeat(for cue: String, persona: Persona, unit: DistanceUnit) -> String {
        let dist = spokenDistance(max(previousQuitDistanceM, longestDistanceM), unit: unit)
        if cue.contains("longest-ever") {
            switch persona.id {
            case .sarge: return "That's your longest ever. Hold the line and keep taking ground."
            case .southpaw: return "Longest fight of your life kid. Stay mean and don't give it back."
            case .machine: return "Lifetime distance ceiling broken. Maintain output and extend."
            case .preacher: return "You have gone farther than ever. Honor it and keep rising."
            case .steady: return "Furthest you've ever gone. Breathe, stay honest, keep moving."
            }
        }
        if cue.contains("last stop") || cue.contains("historical quit") {
            switch persona.id {
            case .sarge: return "Beyond your last stop. This is new ground. Earn it."
            case .southpaw: return "Past where you usually fold. Keep the fists up and push through."
            case .machine: return "Historical abort point exceeded. Continue sequence."
            case .preacher: return "You have passed your old wall. Walk into the breakthrough."
            case .steady: return "You're past where you usually stop. Stay with it."
            }
        }
        if cue.contains("pace PB") {
            switch persona.id {
            case .sarge: return "You're chasing a pace PB. Lock it and don't leak seconds."
            case .southpaw: return "PB pace is right there kid. Hunt it down."
            case .machine: return "Near thirty-day pace record. Hold the rate."
            case .preacher: return "A personal best pace is near. Claim it with faith."
            case .steady: return "You're near your best recent pace. Settle and hold."
            }
        }
        // Fallback uses unit-aware distance so TTS normalizer isn't the only safety net.
        return "Keep going. \(dist) and beyond. Make this one count."
    }

    private func spokenDistance(_ meters: Double, unit: DistanceUnit) -> String {
        switch unit {
        case .kilometre:
            return String(format: "%.1f kilometres", meters / 1000)
        case .mile:
            return String(format: "%.1f miles", meters / 1609.344)
        }
    }
}

@MainActor
enum AthleteHistoryBuilder {
    private static let storageKey = "rally.athlete.history_card"

    static func loadPersisted() -> AthleteHistoryCard {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let card = try? JSONDecoder().decode(AthleteHistoryCard.self, from: data) else {
            return AthleteHistoryCard()
        }
        return card
    }

    static func persist(_ card: AthleteHistoryCard) {
        if let data = try? JSONEncoder().encode(card) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Rebuild from recent workout records (newest first).
    static func build(from sessions: [WorkoutSessionRecord], now: Date = Date()) -> AthleteHistoryCard {
        var card = AthleteHistoryCard()
        let runs = sessions.filter { $0.distanceM >= 200 }.prefix(12)
        card.totalRuns = sessions.count
        card.isNewAthlete = sessions.count < 3

        guard let latest = runs.first else {
            persist(card)
            return card
        }

        card.lastDistanceM = latest.distanceM
        card.lastDurationSec = latest.durationSec
        card.lastAvgPaceSecPerKm = latest.distanceM > 0 ? (latest.durationSec / latest.distanceM) * 1000 : 0
        card.daysSinceLastRun = Calendar.current.dateComponents([.day], from: latest.endedAt, to: now).day

        card.longestDistanceM = sessions.map(\.distanceM).max() ?? latest.distanceM
        // Approx "quit" as prior session distance (last unfinished-feeling proxy = previous max before today)
        let prior = Array(runs.dropFirst())
        card.previousQuitDistanceM = prior.map(\.distanceM).max() ?? latest.distanceM

        let monthAgo = now.addingTimeInterval(-30 * 24 * 3600)
        let recentMonth = sessions.filter { $0.startedAt >= monthAgo && $0.distanceM >= 800 }
        let paces = recentMonth.compactMap { s -> Double? in
            guard s.distanceM > 0, s.durationSec > 60 else { return nil }
            return (s.durationSec / s.distanceM) * 1000
        }
        card.thirtyDayBestPaceSecPerKm = paces.min() ?? 0

        card.recentDistancesM = runs.prefix(5).map(\.distanceM)
        card.recentPacesSecPerKm = runs.prefix(5).compactMap { s in
            s.distanceM > 0 ? (s.durationSec / s.distanceM) * 1000 : nil
        }

        card.trend = inferTrend(distances: card.recentDistancesM, paces: card.recentPacesSecPerKm)
        card.consistency = inferConsistency(sessions: Array(runs), now: now)

        persist(card)
        return card
    }

    /// Update card after a finished workout without needing full SwiftData query.
    static func incorporateFinished(
        distanceM: Double,
        durationSec: Double,
        endedAt: Date = Date(),
        into existing: AthleteHistoryCard
    ) -> AthleteHistoryCard {
        var card = existing
        card.totalRuns += 1
        card.isNewAthlete = card.totalRuns < 3
        card.daysSinceLastRun = 0
        card.previousQuitDistanceM = max(card.previousQuitDistanceM, card.lastDistanceM)
        card.lastDistanceM = distanceM
        card.lastDurationSec = durationSec
        card.lastAvgPaceSecPerKm = distanceM > 0 ? (durationSec / distanceM) * 1000 : 0
        card.longestDistanceM = max(card.longestDistanceM, distanceM)
        card.recentDistancesM = ([distanceM] + card.recentDistancesM).prefix(5).map { $0 }
        if card.lastAvgPaceSecPerKm > 0 {
            card.recentPacesSecPerKm = ([card.lastAvgPaceSecPerKm] + card.recentPacesSecPerKm).prefix(5).map { $0 }
            if card.thirtyDayBestPaceSecPerKm <= 0 || card.lastAvgPaceSecPerKm < card.thirtyDayBestPaceSecPerKm {
                card.thirtyDayBestPaceSecPerKm = card.lastAvgPaceSecPerKm
            }
        }
        card.trend = inferTrend(distances: card.recentDistancesM, paces: card.recentPacesSecPerKm)
        persist(card)
        return card
    }

    private static func inferTrend(distances: [Double], paces: [Double]) -> AthleteHistoryCard.Trend {
        guard distances.count >= 2 else { return .unknown }
        // Newer first: compare average of newest 2 vs older 2
        let newer = Array(distances.prefix(2))
        let older = Array(distances.dropFirst(2).prefix(2))
        if older.count == 2 {
            let n = newer.reduce(0, +) / 2
            let o = older.reduce(0, +) / 2
            if n > o * 1.08 { return .improving }
            if n < o * 0.92 { return .declining }
        }
        if paces.count >= 3 {
            let newest = paces[0]
            let olderAvg = paces.dropFirst().prefix(2).reduce(0, +) / 2
            if newest < olderAvg - 12 { return .improving } // faster pace
            if newest > olderAvg + 15 { return .declining }
        }
        return .holding
    }

    private static func inferConsistency(sessions: [WorkoutSessionRecord], now: Date) -> AthleteHistoryCard.Consistency {
        guard sessions.count >= 2 else { return .unknown }
        var gaps: [Int] = []
        for i in 0..<(min(sessions.count, 5) - 1) {
            let d = Calendar.current.dateComponents([.day], from: sessions[i + 1].endedAt, to: sessions[i].endedAt).day ?? 7
            gaps.append(max(0, d))
        }
        guard !gaps.isEmpty else { return .unknown }
        let avg = Double(gaps.reduce(0, +)) / Double(gaps.count)
        let maxGap = gaps.max() ?? 0
        if maxGap >= 8 || avg >= 6 { return .spaced }
        if avg <= 3 && maxGap <= 5 { return .consistent }
        return .inconsistent
    }
}

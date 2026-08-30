import Foundation

struct BurnedPhraseEntry: Codable, Sendable {
    var text: String
    var timestamp: Date
}

/// Persistent Anti-Repetition Store.
/// Keeps recent phrases from the current run and the last 3 days to prevent repetition
/// while keeping the LLM prompt payload ultra-lean and low-latency.
@MainActor
final class LifetimePromptMemory {
    static let shared = LifetimePromptMemory()

    private let maxStoredEntries = 100
    private let storageKey = "rally.lifetime.burned_records"
    private var entries: [BurnedPhraseEntry] = []

    init() {
        loadEntries()
    }

    private func loadEntries() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([BurnedPhraseEntry].self, from: data) {
            self.entries = decoded
        } else if let legacy = UserDefaults.standard.stringArray(forKey: "rally.lifetime.burned_prompts") {
            // Migrate legacy plain string format with current date
            self.entries = legacy.prefix(30).map { BurnedPhraseEntry(text: $0, timestamp: Date()) }
            saveEntries()
        }
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Logs a newly spoken line with its timestamp.
    func recordSpokenLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Remove duplicate entry if already present and prepend fresh record
        entries.removeAll { $0.text.caseInsensitiveCompare(trimmed) == .orderedSame }
        entries.insert(BurnedPhraseEntry(text: trimmed, timestamp: Date()), at: 0)

        // Prune older entries
        if entries.count > maxStoredEntries {
            entries = Array(entries.prefix(maxStoredEntries))
        }

        saveEntries()
    }

    /// Returns a lean list of phrases spoken within the last 3 days (max 6-8 items)
    /// to keep LLM token usage and latency to an absolute minimum.
    var recent3DayPhrases: [String] {
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 3600)
        let activeRecent = entries.filter { $0.timestamp >= threeDaysAgo }
        return Array(activeRecent.prefix(8).map { $0.text })
    }

    /// Dynamic blacklist for LLM prompt generation.
    var dynamicBlacklist: [String] {
        recent3DayPhrases
    }

    /// Checks if a proposed candidate line is too similar to any phrase from the last 3 days.
    func isTooSimilarToBurned(_ candidate: String) -> Bool {
        let candidateLower = candidate.lowercased()
        for phrase in recent3DayPhrases {
            let phraseLower = phrase.lowercased()
            if candidateLower == phraseLower { return true }
            if candidateLower.contains(phraseLower) || phraseLower.contains(candidateLower) {
                return true
            }
        }
        return false
    }
}

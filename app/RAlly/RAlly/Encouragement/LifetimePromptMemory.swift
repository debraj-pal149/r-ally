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

    /// In-run spoken lines (cleared each workout). Used for hard near-dupe rejection.
    private(set) var runSpokenLines: [String] = []
    private let maxRunLines = 40

    init() {
        loadEntries()
    }

    func beginRun() {
        runSpokenLines.removeAll(keepingCapacity: true)
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

        runSpokenLines.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        runSpokenLines.insert(trimmed, at: 0)
        if runSpokenLines.count > maxRunLines {
            runSpokenLines = Array(runSpokenLines.prefix(maxRunLines))
        }

        // Remove duplicate entry if already present and prepend fresh record
        entries.removeAll { $0.text.caseInsensitiveCompare(trimmed) == .orderedSame }
        entries.insert(BurnedPhraseEntry(text: trimmed, timestamp: Date()), at: 0)

        // Prune older entries
        if entries.count > maxStoredEntries {
            entries = Array(entries.prefix(maxStoredEntries))
        }

        saveEntries()
    }

    /// Priors for hard rejection: this-run lines first, then recent lifetime.
    var rejectionPriors: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for line in runSpokenLines + recent3DayPhrases {
            let key = line.lowercased()
            if seen.insert(key).inserted {
                out.append(line)
            }
            if out.count >= 24 { break }
        }
        return out
    }

    /// Returns a lean list of phrases spoken within the last 3 days (max 6-8 items)
    /// to keep LLM token usage and latency to an absolute minimum.
    var recent3DayPhrases: [String] {
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 3600)
        let activeRecent = entries.filter { $0.timestamp >= threeDaysAgo }
        return Array(activeRecent.prefix(8).map { $0.text })
    }

    /// Dynamic blacklist for LLM prompt generation. Full lines (few) + lean motifs.
    var dynamicBlacklist: [String] {
        var out: [String] = []
        // Prefer freshest full lines from this run (exact avoid)
        for line in runSpokenLines.prefix(4) {
            out.append(line)
        }
        // Top lifetime lines not already included
        for line in recent3DayPhrases where !out.contains(line) {
            out.append(line)
            if out.count >= 6 { break }
        }
        return out
    }

    /// Token-cheap motif hints for the prompt (bigrams / short stems).
    var leanMotifBlacklist: [String] {
        PhraseFingerprint.leanMotifs(from: runSpokenLines + recent3DayPhrases, limit: 10)
    }

    /// Hard gate: candidate too similar to this-run or recent burned lines.
    func isTooSimilarToBurned(_ candidate: String) -> Bool {
        PhraseFingerprint.isTooSimilar(candidate, to: rejectionPriors)
    }
}

import Foundation

/// Cheap local fingerprinting so near-paraphrases ("hold the line" / "hold this rhythm")
/// can be rejected without another Claude call.
enum PhraseFingerprint {
    /// Content words kept after stopword strip (stems are light lowercase tokens).
    struct Signature: Equatable, Sendable {
        var tokens: Set<String>
        var bigrams: Set<String>
        var motifs: [String]

        var isEmpty: Bool { tokens.isEmpty && bigrams.isEmpty }
    }

    private static let stopwords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "if", "to", "of", "in", "on", "at", "for",
        "is", "are", "was", "were", "be", "been", "being", "it", "its", "this", "that",
        "these", "those", "you", "your", "yours", "me", "my", "we", "our", "i", "im",
        "do", "does", "did", "dont", "not", "no", "yes", "with", "from", "into", "out",
        "up", "down", "as", "so", "than", "then", "there", "here", "just", "very",
        "now", "again", "more", "most", "some", "any", "all", "can", "will", "gonna",
        "let", "lets", "get", "got", "go", "going", "keep", "one", "two", "back"
    ]

    static func signature(of text: String) -> Signature {
        let tokens = tokenize(text)
        var bigrams: Set<String> = []
        if tokens.count >= 2 {
            for i in 0..<(tokens.count - 1) {
                bigrams.insert("\(tokens[i])|\(tokens[i + 1])")
            }
        }
        let motifs = motifCandidates(from: tokens)
        return Signature(tokens: Set(tokens), bigrams: bigrams, motifs: motifs)
    }

    /// Jaccard on tokens + bigram overlap + set-containment. 0 = unrelated, 1 = identical.
    static func similarity(_ a: String, _ b: String) -> Double {
        similarity(signature(of: a), signature(of: b))
    }

    static func similarity(_ a: Signature, _ b: Signature) -> Double {
        if a.isEmpty || b.isEmpty { return 0 }
        let inter = a.tokens.intersection(b.tokens)
        let tokenInter = Double(inter.count)
        let tokenUnion = Double(a.tokens.union(b.tokens).count)
        let tokenScore = tokenUnion > 0 ? tokenInter / tokenUnion : 0

        let bigInter = Double(a.bigrams.intersection(b.bigrams).count)
        let bigUnion = Double(a.bigrams.union(b.bigrams).count)
        let bigScore = bigUnion > 0 ? bigInter / bigUnion : 0

        // Containment catches short paraphrases of a longer line.
        let smaller = min(a.tokens.count, b.tokens.count)
        let containment = smaller > 0 ? tokenInter / Double(smaller) : 0

        return (0.35 * tokenScore) + (0.40 * bigScore) + (0.25 * containment)
    }

    /// True when candidate is too close to any prior line (exact, containment, or fingerprint).
    static func isTooSimilar(_ candidate: String, to priors: [String], threshold: Double = 0.34) -> Bool {
        let cand = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cand.isEmpty else { return false }
        let candLower = cand.lowercased()
        let candSig = signature(of: cand)
        for prior in priors {
            let p = prior.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !p.isEmpty else { continue }
            let pLower = p.lowercased()
            if candLower == pLower { return true }
            // Only treat substring containment as a hit when the shorter side is a real clause.
            let shorter = min(candLower.count, pLower.count)
            if shorter >= 18, candLower.contains(pLower) || pLower.contains(candLower) {
                return true
            }
            let priorSig = signature(of: p)
            if similarity(candSig, priorSig) >= threshold {
                return true
            }
            // Shared content-word core (3+ stems, ≥65% of the smaller set).
            let shared = candSig.tokens.intersection(priorSig.tokens)
            let smallerCount = min(candSig.tokens.count, priorSig.tokens.count)
            if shared.count >= 3, smallerCount > 0,
               Double(shared.count) / Double(smallerCount) >= 0.65 {
                return true
            }
        }
        return false
    }

    /// Lean motif strings for the LLM avoid list (token-cheap).
    static func leanMotifs(from lines: [String], limit: Int = 10) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for line in lines {
            for motif in signature(of: line).motifs {
                if seen.insert(motif).inserted {
                    out.append(motif)
                    if out.count >= limit { return out }
                }
            }
        }
        return out
    }

    private static func tokenize(_ text: String) -> [String] {
        let lowered = text.lowercased()
        let scalars = lowered.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        let raw = String(scalars)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { $0.count > 1 && !stopwords.contains($0) }
        return raw.map(lightStem)
    }

    /// Ultra-light stemmer (no NLP dependency): strip common English suffixes.
    private static func lightStem(_ word: String) -> String {
        var w = word
        let suffixes = ["ing", "ers", "ies", "ied", "ed", "es", "ly", "s"]
        for s in suffixes where w.count > s.count + 2 && w.hasSuffix(s) {
            w = String(w.dropLast(s.count))
            break
        }
        return w
    }

    private static func motifCandidates(from tokens: [String]) -> [String] {
        guard tokens.count >= 2 else { return tokens }
        var motifs: [String] = []
        // Prefer informative bigrams
        for i in 0..<min(tokens.count - 1, 6) {
            motifs.append("\(tokens[i]) \(tokens[i + 1])")
        }
        return motifs
    }
}

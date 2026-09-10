import Foundation

/// Running distance speech/display unit. Miles only for US/GB/LR/MM running culture; kilometres everywhere else.
enum DistanceUnit: String, Codable, Sendable, Equatable {
    case kilometre
    case mile

    /// Spoken singular / plural for coach lines.
    var singular: String { self == .mile ? "mile" : "kilometre" }
    var plural: String { self == .mile ? "miles" : "kilometres" }
    var shortLabel: String { self == .mile ? "mi" : "km" }

    /// Prompt-facing instruction (tiny token cost).
    var promptRule: String {
        switch self {
        case .kilometre:
            return "Always say kilometre/kilometres. Never mile/miles."
        case .mile:
            return "Always say mile/miles. Never kilometre/kilometer."
        }
    }

    /// Locale regions where runners typically speak in miles.
    private static let mileRegions: Set<String> = ["US", "GB", "LR", "MM"]
    private static let overrideKey = "coach.distanceUnit"

    /// Resolves display/speech unit from locale. Metric countries (e.g. India) always get kilometres
    /// unless the region is an explicit mile culture (US/GB/LR/MM).
    static func detect(locale: Locale = .current) -> DistanceUnit {
        let region = resolvedRegion(locale)

        if let override = UserDefaults.standard.string(forKey: overrideKey),
           let unit = DistanceUnit(rawValue: override) {
            // Stale "mile" override on a metric region (common after testing) → clear it.
            if unit == .mile && !mileRegions.contains(region) {
                UserDefaults.standard.removeObject(forKey: overrideKey)
            } else if unit == .kilometre || mileRegions.contains(region) {
                return unit
            }
        }

        if mileRegions.contains(region) {
            return .mile
        }

        // India, EU, most of world: metric measurement system → kilometres.
        if locale.measurementSystem == .metric {
            return .kilometre
        }

        // Default safe: kilometres unless region is explicitly mile culture.
        return .kilometre
    }

    private static func resolvedRegion(_ locale: Locale) -> String {
        if let id = locale.region?.identifier {
            return id.uppercased()
        }
        if let id = (locale as NSLocale).object(forKey: .countryCode) as? String {
            return id.uppercased()
        }
        return ""
    }
}

/// Deterministic pre-TTS rewrite so wrong unit language never reaches the voice model.
enum DistanceUnitNormalizer {
    static func normalize(_ text: String, to unit: DistanceUnit) -> String {
        var t = text
        switch unit {
        case .kilometre:
            t = replaceWord(t, from: #"\bmiles\b"#, to: "kilometres")
            t = replaceWord(t, from: #"\bmile\b"#, to: "kilometre")
            t = replaceWord(t, from: #"\bMiles\b"#, to: "Kilometres")
            t = replaceWord(t, from: #"\bMile\b"#, to: "Kilometre")
            t = replaceWord(t, from: #"\bkilometers\b"#, to: "kilometres")
            t = replaceWord(t, from: #"\bkilometer\b"#, to: "kilometre")
            t = replaceWord(t, from: #"\bKilometers\b"#, to: "Kilometres")
            t = replaceWord(t, from: #"\bKilometer\b"#, to: "Kilometre")
        case .mile:
            t = replaceWord(t, from: #"\bkilometres\b"#, to: "miles")
            t = replaceWord(t, from: #"\bkilometre\b"#, to: "mile")
            t = replaceWord(t, from: #"\bkilometers\b"#, to: "miles")
            t = replaceWord(t, from: #"\bkilometer\b"#, to: "mile")
            t = replaceWord(t, from: #"\bKilometres\b"#, to: "Miles")
            t = replaceWord(t, from: #"\bKilometre\b"#, to: "Mile")
            t = replaceWord(t, from: #"\bKilometers\b"#, to: "Miles")
            t = replaceWord(t, from: #"\bKilometer\b"#, to: "Mile")
        }
        return DashNormalizer.normalize(t)
    }

    private static func replaceWord(_ text: String, from pattern: String, to replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }
}

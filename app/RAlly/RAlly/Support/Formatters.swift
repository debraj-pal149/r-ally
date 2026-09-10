import Foundation

enum Formatters {
    static func clock(_ t: TimeInterval) -> String {
        let s = Int(max(0, t))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    static func pace(_ secPerKm: Double) -> String {
        guard secPerKm.isFinite, secPerKm > 0, secPerKm < 3600 else { return "-" }
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d", m, s)
    }

    static func km(_ meters: Double) -> String {
        String(format: "%.2f", meters / 1000)
    }

    static func greeting(now: Date = Date()) -> String {
        let h = Calendar.current.component(.hour, from: now)
        if h < 12 { return "Morning" }
        if h < 17 { return "Afternoon" }
        return "Evening"
    }
}

/// Strips em/en dashes from coach and UI-facing copy. Prefer periods, commas, or hyphens.
enum DashNormalizer {
    private static let em = "\u{2014}"
    private static let en = "\u{2013}"

    static func normalize(_ text: String) -> String {
        var t = text
        t = t.replacingOccurrences(of: " \(em) ", with: ". ")
        t = t.replacingOccurrences(of: " \(en) ", with: ". ")
        t = t.replacingOccurrences(of: em, with: ", ")
        t = t.replacingOccurrences(of: en, with: "-")
        var chars = Array(t)
        var i = 0
        while i + 2 < chars.count {
            if chars[i] == ".", chars[i + 1] == " ", chars[i + 2].isLowercase {
                chars[i + 2] = Character(chars[i + 2].uppercased())
            }
            i += 1
        }
        t = String(chars)
        while t.contains("  ") {
            t = t.replacingOccurrences(of: "  ", with: " ")
        }
        return t
    }

    static func normalizeLines(_ lines: [String]) -> [String] {
        lines.map(normalize)
    }
}

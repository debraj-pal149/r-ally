import Foundation

/// Calculates Grade-Adjusted Pace (GAP) and metabolic equivalent speeds
/// using the Minetti (2002) physiological cost equations for human locomotion.
enum GradeAdjustedCalculator {

    /// Returns the metabolic cost ratio relative to flat running (grade = 0).
    /// Grade is passed as percentage (e.g. +5.0 for a 5% uphill, -4.0 for a 4% downhill).
    static func costRatio(gradePercent: Double) -> Double {
        // Clamp grade between -30% and +30% for mathematical stability
        let g = max(-0.30, min(0.30, gradePercent / 100.0))
        
        // Minetti polynomial: C(i) in J/kg/m = 155.4*i^5 - 30.4*i^4 - 43.3*i^3 + 46.3*i^2 + 19.5*i + 3.6
        let g2 = g * g
        let g3 = g2 * g
        let g4 = g3 * g
        let g5 = g4 * g
        
        let cost = 155.4 * g5 - 30.4 * g4 - 43.3 * g3 + 46.3 * g2 + 19.5 * g + 3.6
        let flatCost = 3.6
        
        // Return ratio (>= 0.6 for downhills, > 1.0 for uphills)
        return max(0.55, cost / flatCost)
    }

    /// Computes Grade-Adjusted Pace (GAP in sec/km) given raw pace and slope.
    /// When running uphill, GAP is faster (lower seconds) than raw pace.
    static func gradeAdjustedPace(rawPaceSecPerKm: Double, gradePercent: Double) -> Double {
        guard rawPaceSecPerKm > 0 else { return 0 }
        let ratio = costRatio(gradePercent: gradePercent)
        return rawPaceSecPerKm / ratio
    }

    /// Computes Grade-Adjusted Speed (m/s) given raw speed and slope.
    static func gradeAdjustedSpeed(rawSpeedMps: Double, gradePercent: Double) -> Double {
        guard rawSpeedMps > 0 else { return 0 }
        let ratio = costRatio(gradePercent: gradePercent)
        return rawSpeedMps * ratio
    }
}

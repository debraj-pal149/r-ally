import Foundation

/// Sideline coach timing. Speech-duration-aware: never stack lines on estimated WPM.
enum CoachRhythm {
    /// After real speech finish (AVSpeech / booth drain), wait this long before another shout.
    static let breathGapSec: Double = 1.5

    /// Keep-going while holding pace (hellfire presence without spam).
    static let keepGoingSec: Double = 40

    /// Rest nag while stopped (escalation window).
    static let restNagSec: Double = 12

    /// After this many rest nags in one stop episode, slow down (plateau. Not an alarm clock).
    static let restNagEscalateMax: Int = 4
    static let restNagPlateauSec: Double = 22

    static let fadeRefractorySec: Double = 35
    static let paceSlipRefractorySec: Double = 30
    static let followUpRefractorySec: Double = 12

    static func restInterval(afterNagCount n: Int) -> Double {
        n < restNagEscalateMax ? restNagSec : restNagPlateauSec
    }
}

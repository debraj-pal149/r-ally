import Foundation

enum EngineConstants {
    static let ewmaHalfLife: Double = 90
    static var ewmaAlpha: Double { 1 - pow(2.0, -1.0 / ewmaHalfLife) }
    static let shortWindow: Int = 15
    static let slopeWindow: Int = 30
    static let cvWindow: Int = 20
    static let epsilon: Double = 1e-6

    static let decaySlopeFull: Double = 0.005
    static let hrTrendFull: Double = 0.05
    static let cooldownHrFall: Double = 0.15
    static let stutterCv: Double = 0.10
    static let grindSeconds: Double = 300
    static let hardHRFraction: Double = 0.88
    static let hardOutputFraction: Double = 0.92

    static let wOutputDrop: Double = 3.2
    static let wDecaySlope: Double = 2.0
    static let wDecoupling: Double = 2.4
    static let wStutter: Double = 1.2
    static let wGrind: Double = 0.6
    static let wCooldown: Double = 2.8
    static let bias: Double = 2.2
    static let riskSmooth: Double = 0.7

    static let wobbleEnter: Double = 45
    static let criticalEnter: Double = 65
    static let wobbleTicks: Int = 3
    static let criticalTicks: Int = 3
    static let cruiseReturn: Double = 35
    static let cruiseTicks: Int = 10
    static let criticalExit: Double = 50
    static let criticalExitTicks: Int = 15

    static let stopFraction: Double = 0.15
    static let collapseWindow: Double = 4
    static let graceSec: Double = 8
    static let resumeFraction: Double = 0.5
    static let stopHRPeakFraction: Double = 0.75
    static let structuredRestMul: Double = 1.5

    static let warmupSec: Double = 180
    static let refractorySec: Double = 90
    static let defaultSessionCap: Int = 7
    static let grindCap: Int = 2
    static let finalPushCap: Int = 1
    static let resumeGraceSec: Double = 30
    static let escalationWindow: Double = 300
    static let finalPushProgress: Double = 0.90
}

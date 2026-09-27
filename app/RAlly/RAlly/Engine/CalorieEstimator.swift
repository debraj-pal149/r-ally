import Foundation

/// Accumulates kilocalories during a run using the Minetti (2002) metabolic cost
/// model (same model used by GradeAdjustedCalculator).
///
/// Device calorie samples always win: when a device sends `.activeEnergyKcal`,
/// call `receiveDeviceSample(_:)` so the estimator stops adding and the device
/// value is used directly in the display and summary.
///
/// Source priority (highest wins):
///   BLE-FTMS / Simulator device value  →  Minetti estimate from weight + grade + speed
final class CalorieEstimator {

    /// Total accumulated kcal this session. Read from AppModel.liveLatest[.activeEnergyKcal].
    private(set) var totalKcal: Double = 0

    /// True once a real device calorie sample has been received this session.
    private(set) var isDeviceOwned: Bool = false

    private var lastDeviceKcal: Double = 0

    // MARK: - Public API

    func reset() {
        totalKcal = 0
        isDeviceOwned = false
        lastDeviceKcal = 0
    }

    /// Called every second from AppModel.tick(). Ignored when device owns the value.
    /// - Parameters:
    ///   - speedMps: Current GPS/BLE speed in m/s.
    ///   - gradePercent: Current slope in % (+uphill, −downhill).
    ///   - weightKg: Athlete body mass. Pass nil to skip estimation for this tick.
    func tick(speedMps: Double, gradePercent: Double, weightKg: Double?) {
        // Same rest threshold as the quit engine so GPS wander does not mint calories.
        guard !isDeviceOwned, let weightKg, weightKg > 0, speedMps >= EngineConstants.vStop else { return }

        // Minetti cost in J/kg/m (same clamping as GradeAdjustedCalculator)
        let g = max(-0.30, min(0.30, gradePercent / 100.0))
        let g2 = g * g; let g3 = g2 * g; let g4 = g3 * g; let g5 = g4 * g
        let costJPerKgPerM = 155.4 * g5 - 30.4 * g4 - 43.3 * g3 + 46.3 * g2 + 19.5 * g + 3.6

        // Energy per second: cost(J/kg/m) × weight(kg) × speed(m/s) / 4184 (J→kcal)
        let kcalPerSec = costJPerKgPerM * weightKg * speedMps / 4184.0
        totalKcal += max(0, kcalPerSec)
    }

    /// Called when a device (BLE-FTMS, Simulator) sends a real cumulative calorie sample.
    /// The device value replaces the estimate and becomes the session total.
    func receiveDeviceSample(_ kcal: Double) {
        guard kcal > lastDeviceKcal else { return }
        isDeviceOwned = true
        lastDeviceKcal = kcal
        totalKcal = kcal
    }
}

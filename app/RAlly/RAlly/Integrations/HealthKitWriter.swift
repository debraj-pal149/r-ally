import Foundation

#if canImport(HealthKit)
import HealthKit

@MainActor
final class HealthKitWriter {
    private let store = HKHealthStore()

    func save(session: WorkoutSessionRecord) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        // WorkoutSessionRecord.durationSec is active (unpaused) time. HealthKit
        // otherwise derives elapsed time from startedAt...endedAt and would put
        // pauses back into the workout. Keep the real finish date and synthesize
        // an active-only collection window ending there.
        let activeEnd = session.endedAt
        let activeStart = activeEnd.addingTimeInterval(-max(0, session.durationSec))
        let config = HKWorkoutConfiguration()
        config.activityType = hkType(session.activity)
        config.locationType = session.activity == .running || session.activity == .cycling ? .outdoor : .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: activeStart)
            var samples: [HKSample] = []
            if session.distanceM > 0,
               let distType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                let q = HKQuantity(unit: .meter(), doubleValue: session.distanceM)
                samples.append(HKQuantitySample(type: distType, quantity: q, start: activeStart, end: activeEnd))
            }
            if session.activeEnergyKcal > 0,
               let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let q = HKQuantity(unit: .kilocalorie(), doubleValue: session.activeEnergyKcal)
                samples.append(HKQuantitySample(type: energyType, quantity: q, start: activeStart, end: activeEnd))
            }
            if !samples.isEmpty {
                try await builder.addSamples(samples)
            }
            try await builder.endCollection(at: activeEnd)
            _ = try await builder.finishWorkout()
            return true
        } catch {
            Log.app.error("HealthKit save failed: \(error.localizedDescription)")
            return false
        }
    }

    private func hkType(_ a: ActivityKind) -> HKWorkoutActivityType {
        switch a {
        case .running: .running
        case .cycling: .cycling
        case .strength: .traditionalStrengthTraining
        case .boxing: .boxing
        case .swimming: .swimming
        case .rowing: .rowing
        case .hiit: .highIntensityIntervalTraining
        }
    }
}
#else
@MainActor
final class HealthKitWriter {
    func save(session: WorkoutSessionRecord) async -> Bool { false }
}
#endif

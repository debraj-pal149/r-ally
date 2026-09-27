import Foundation

#if canImport(HealthKit)
import HealthKit

@MainActor
final class HealthKitWriter {
    private let store = HKHealthStore()

    func save(session: WorkoutSessionRecord) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = hkType(session.activity)
        config.locationType = session.activity == .running || session.activity == .cycling ? .outdoor : .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: session.startedAt)
            var samples: [HKSample] = []
            if session.distanceM > 0,
               let distType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
                let q = HKQuantity(unit: .meter(), doubleValue: session.distanceM)
                samples.append(HKQuantitySample(type: distType, quantity: q, start: session.startedAt, end: session.endedAt))
            }
            if session.activeEnergyKcal > 0,
               let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let q = HKQuantity(unit: .kilocalorie(), doubleValue: session.activeEnergyKcal)
                samples.append(HKQuantitySample(type: energyType, quantity: q, start: session.startedAt, end: session.endedAt))
            }
            if !samples.isEmpty {
                try await builder.addSamples(samples)
            }
            try await builder.endCollection(at: session.endedAt)
            _ = try await builder.finishWorkout()
        } catch {
            Log.app.error("HealthKit save failed: \(error.localizedDescription)")
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
    func save(session: WorkoutSessionRecord) async {}
}
#endif

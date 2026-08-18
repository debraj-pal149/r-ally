import Foundation

#if canImport(HealthKit)
import HealthKit

final class HealthKitDataSource: SupplementalHRSource, @unchecked Sendable {
    private let store = HKHealthStore()
    private var query: HKAnchoredObjectQuery?
    private var handler: (@Sendable (MetricSample) -> Void)?
    private var sessionStart = Date()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard Self.isAvailable else { return false }
        let read: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType(),
        ]
        let write: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType(),
        ]
        do {
            try await store.requestAuthorization(toShare: write, read: read)
            return true
        } catch {
            return false
        }
    }

    func start(handler: @escaping @Sendable (MetricSample) -> Void) {
        self.handler = handler
        sessionStart = Date()
        guard let hr = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let q = HKAnchoredObjectQuery(type: hr, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { [weak self] _, samples, _, _, _ in
            self?.emit(samples)
        }
        q.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.emit(samples)
        }
        query = q
        store.execute(q)
    }

    func stop() {
        if let query { store.stop(query) }
        handler = nil
    }

    /// Nike Run Club and other apps sync here. Used for history/baselines.
    func recentWorkouts(limit: Int = 20) async -> [HKWorkout] {
        let pred = HKQuery.predicateForWorkouts(with: .running)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: pred, limit: limit, sortDescriptors: [sort]) { _, samples, _ in
                cont.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
    }

    private func emit(_ samples: [HKSample]?) {
        guard let samples else { return }
        for sample in samples {
            guard let q = sample as? HKQuantitySample else { continue }
            let bpm = q.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            let t = q.endDate.timeIntervalSince(sessionStart)
            handler?(MetricSample(kind: .heartRateBpm, value: bpm, timestamp: max(0, t), source: .healthKit))
        }
    }
}
#else
final class HealthKitDataSource: SupplementalHRSource, @unchecked Sendable {
    static var isAvailable: Bool { false }
    func requestAuthorization() async -> Bool { false }
    func start(handler: @escaping @Sendable (MetricSample) -> Void) {}
    func stop() {}
    func recentWorkouts(limit: Int = 20) async -> [Any] { [] }
}
#endif


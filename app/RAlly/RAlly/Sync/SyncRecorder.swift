import Foundation

/// Enqueues local writes for SyncEngine. Call from every synced mutation path.
@MainActor
enum SyncRecorder {
    private static var canEnqueue: Bool {
        AuthService.shared.isSignedIn
    }

    static func profileChanged(updatedAt: Date = Date()) {
        guard canEnqueue else { return }
        SyncOutbox.shared.enqueue(
            SyncOutboxItem(entity: .profile, entityId: "main", op: .upsert, updatedAt: updatedAt)
        )
        SyncEngine.shared.kick()
    }

    static func workoutUpserted(id: UUID, updatedAt: Date = Date()) {
        guard canEnqueue else { return }
        SyncOutbox.shared.enqueue(
            SyncOutboxItem(entity: .workout, entityId: id.uuidString, op: .upsert, updatedAt: updatedAt)
        )
        SyncEngine.shared.kick()
    }

    static func workoutTombstoned(id: UUID, updatedAt: Date = Date()) {
        guard canEnqueue else { return }
        SyncOutbox.shared.enqueue(
            SyncOutboxItem(entity: .workout, entityId: id.uuidString, op: .tombstone, updatedAt: updatedAt)
        )
        SyncEngine.shared.kick()
    }

    static func personalBestsChanged(updatedAt: Date = Date()) {
        guard canEnqueue else { return }
        SyncOutbox.shared.enqueue(
            SyncOutboxItem(entity: .personalBests, entityId: "map", op: .upsert, updatedAt: updatedAt)
        )
        SyncEngine.shared.kick()
    }

    static func enqueueAll(workoutIDs: [UUID], now: Date = Date()) {
        // Force enqueue even if AuthService snapshot lags one tick after sign-in.
        SyncOutbox.shared.enqueue(
            SyncOutboxItem(entity: .profile, entityId: "main", op: .upsert, updatedAt: now)
        )
        SyncOutbox.shared.enqueue(
            SyncOutboxItem(entity: .personalBests, entityId: "map", op: .upsert, updatedAt: now)
        )
        for id in workoutIDs {
            SyncOutbox.shared.enqueue(
                SyncOutboxItem(entity: .workout, entityId: id.uuidString, op: .upsert, updatedAt: now)
            )
        }
        SyncEngine.shared.kick()
    }
}

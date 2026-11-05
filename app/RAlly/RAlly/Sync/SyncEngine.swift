import Foundation
import SwiftData
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore

enum SyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case error(String)
}

@MainActor
final class SyncEngine {
    static let shared = SyncEngine()

    private(set) var status: SyncStatus = .idle
    var onStatusChange: ((SyncStatus) -> Void)?

    private weak var modelContext: ModelContext?
    private weak var appModel: AppModel?
    private var listeners: [ListenerRegistration] = []
    private var draining = false
    private var kickPending = false

    private init() {}

    func attach(modelContext: ModelContext, appModel: AppModel) {
        self.modelContext = modelContext
        self.appModel = appModel
    }

    func startIfSignedIn() {
        guard Auth.auth().currentUser != nil else {
            stopListening()
            return
        }
        startListening()
        kick()
    }

    func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    func kick() {
        guard Auth.auth().currentUser != nil else { return }
        guard !draining else {
            kickPending = true
            return
        }
        Task { await drainOutbox() }
    }

    func enqueueAllLocal() {
        guard let modelContext else { return }
        let ids = ((try? modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())) ?? [])
            .filter { $0.deletedAt == nil }
            .map(\.id)
        SyncRecorder.enqueueAll(workoutIDs: ids)
    }

    func deleteCloudTree(uid: String) async throws {
        let db = Firestore.firestore()
        let root = db.collection("users").document(uid)
        let collections = ["profile", "workouts", "personalBests", "meta", "moments"]
        for name in collections {
            let snap = try await root.collection(name).getDocuments()
            for doc in snap.documents {
                try await doc.reference.delete()
            }
        }
        try await root.delete()
    }

    // MARK: - Outbox

    private func drainOutbox() async {
        draining = true
        setStatus(.syncing)
        defer {
            draining = false
            if kickPending {
                kickPending = false
                kick()
            }
        }
        guard let uid = Auth.auth().currentUser?.uid else {
            setStatus(.idle)
            return
        }
        let batch = SyncOutbox.shared.items
        guard !batch.isEmpty else {
            setStatus(.idle)
            return
        }
        var done: [String] = []
        do {
            for item in batch {
                try await push(item: item, uid: uid)
                done.append(item.id)
            }
            SyncOutbox.shared.remove(ids: done)
            setStatus(.idle)
        } catch {
            SyncOutbox.shared.remove(ids: done)
            setStatus(.error(error.localizedDescription))
        }
    }

    private func push(item: SyncOutboxItem, uid: String) async throws {
        let db = Firestore.firestore()
        let root = db.collection("users").document(uid)
        switch item.entity {
        case .profile:
            guard let appModel else { return }
            let data = CloudCodec.encodeProfile(
                name: appModel.name,
                age: appModel.age,
                bodyWeightKg: appModel.bodyWeightKg,
                hrMaxOverride: appModel.hrMaxOverride,
                thresholdPace: appModel.thresholdPace,
                personaRaw: appModel.persona.id.rawValue,
                runnerLevel: appModel.runnerLevel.rawValue,
                voiceId: appModel.voiceId,
                sessionCap: appModel.sessionCap,
                appearance: appModel.appearanceMode.rawValue,
                distanceUnit: appModel.distanceUnit.rawValue,
                displayName: AuthService.shared.current?.displayName,
                email: AuthService.shared.current?.email,
                providers: AuthService.shared.current?.providers.map(\.rawValue) ?? [],
                updatedAt: item.updatedAt
            )
            try await root.collection("profile").document("main").setData(data, merge: true)
            try await root.setData([
                "updatedAt": Timestamp(date: item.updatedAt),
                "schemaVersion": AccountKeys.schemaVersion,
            ], merge: true)

        case .personalBests:
            let data = CloudCodec.encodePersonalBests(PersonalBestStore.shared.allBadges, updatedAt: item.updatedAt)
            try await root.collection("personalBests").document("map").setData(data, merge: true)

        case .workout:
            guard let modelContext else { return }
            guard let uuid = UUID(uuidString: item.entityId) else { return }
            let all = (try? modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())) ?? []
            guard let record = all.first(where: { $0.id == uuid }) else {
                if item.op == .tombstone {
                    try await root.collection("workouts").document(item.entityId).setData([
                        "id": item.entityId,
                        "deletedAt": Timestamp(date: item.updatedAt),
                        "updatedAt": Timestamp(date: item.updatedAt),
                        "schemaVersion": AccountKeys.schemaVersion,
                    ], merge: true)
                }
                return
            }
            record.ownerUid = uid
            if item.op == .tombstone, record.deletedAt == nil {
                record.deletedAt = item.updatedAt
            }
            record.updatedAt = max(record.updatedAt, item.updatedAt)
            let data = CloudCodec.encodeWorkout(record)
            try await root.collection("workouts").document(item.entityId).setData(data, merge: true)
            try? modelContext.save()
        }
    }

    // MARK: - Listeners

    private func startListening() {
        stopListening()
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let root = Firestore.firestore().collection("users").document(uid)

        listeners.append(root.collection("profile").document("main").addSnapshotListener { [weak self] snap, _ in
            guard let self, let data = snap?.data() else { return }
            Task { @MainActor in self.applyProfile(data) }
        })
        listeners.append(root.collection("workouts").addSnapshotListener { [weak self] snap, _ in
            guard let self, let docs = snap?.documents else { return }
            Task { @MainActor in
                for doc in docs {
                    self.applyWorkout(doc.data())
                }
            }
        })
        listeners.append(root.collection("personalBests").document("map").addSnapshotListener { [weak self] snap, _ in
            guard let self, let data = snap?.data() else { return }
            Task { @MainActor in self.applyPersonalBests(data) }
        })
    }

    private func applyProfile(_ data: [String: Any]) {
        guard let appModel else { return }
        let remoteAt = CloudCodec.decodeProfileUpdatedAt(data)
        // Local profile edits enqueue outbox; if local is newer, skip overwrite.
        let localOutbox = SyncOutbox.shared.items.first { $0.entity == .profile }
        if let localOutbox, localOutbox.updatedAt > remoteAt { return }

        if let name = data["name"] as? String { appModel.name = name }
        if let age = data["age"] as? Int { appModel.age = age }
        if let weight = data["bodyWeightKg"] as? Double { appModel.bodyWeightKg = weight }
        if let hr = data["hrMaxOverride"] as? Double { appModel.hrMaxOverride = hr }
        if let pace = data["thresholdPace"] as? Double { appModel.thresholdPace = pace }
        if let personaRaw = data["personaRaw"] as? String, let id = Persona.ID(rawValue: personaRaw) {
            appModel.persona = Persona.named(id)
        }
        if let levelRaw = data["runnerLevel"] as? String, let level = RunnerLevel(rawValue: levelRaw) {
            appModel.runnerLevel = level
        }
        if let voiceId = data["voiceId"] as? String { appModel.voiceId = voiceId }
        if let cap = data["sessionCap"] as? Int { appModel.sessionCap = cap }
        if let appearance = data["appearance"] as? String, let mode = AppearanceMode(rawValue: appearance) {
            appModel.appearanceMode = mode
        }
        appModel.persistProfile(touchSync: false)
    }

    private func applyWorkout(_ data: [String: Any]) {
        guard let modelContext else { return }
        guard let idString = data["id"] as? String, let id = UUID(uuidString: idString) else { return }
        let remoteAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
        let all = (try? modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())) ?? []
        let existing = all.first(where: { $0.id == id })
        if let existing, existing.updatedAt > remoteAt { return }
        if let pending = SyncOutbox.shared.items.first(where: { $0.entity == .workout && $0.entityId == idString }),
           pending.updatedAt > remoteAt {
            return
        }
        guard let record = CloudCodec.applyWorkout(data: data, onto: existing) else { return }
        if existing == nil {
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    private func applyPersonalBests(_ data: [String: Any]) {
        guard let decoded = CloudCodec.decodePersonalBests(data) else { return }
        if let pending = SyncOutbox.shared.items.first(where: { $0.entity == .personalBests }),
           pending.updatedAt > decoded.updatedAt {
            return
        }
        PersonalBestStore.shared.replaceAll(decoded.items, touchSync: false)
    }

    private func setStatus(_ status: SyncStatus) {
        self.status = status
        onStatusChange?(status)
    }
}

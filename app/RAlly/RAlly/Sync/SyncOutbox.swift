import Foundation

enum SyncEntityKind: String, Codable, Sendable {
    case profile
    case workout
    case personalBests
}

enum SyncOutboxOp: String, Codable, Sendable {
    case upsert
    case tombstone
}

struct SyncOutboxItem: Codable, Sendable, Identifiable, Equatable {
    var id: String
    var entity: SyncEntityKind
    var entityId: String
    var op: SyncOutboxOp
    var updatedAt: Date
    var enqueuedAt: Date

    init(
        entity: SyncEntityKind,
        entityId: String,
        op: SyncOutboxOp,
        updatedAt: Date = Date(),
        enqueuedAt: Date = Date()
    ) {
        self.id = "\(entity.rawValue):\(entityId):\(op.rawValue)"
        self.entity = entity
        self.entityId = entityId
        self.op = op
        self.updatedAt = updatedAt
        self.enqueuedAt = enqueuedAt
    }
}

@MainActor
final class SyncOutbox {
    static let shared = SyncOutbox()

    private(set) var items: [SyncOutboxItem] = []

    private init() {
        load()
    }

    func enqueue(_ item: SyncOutboxItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            if items[idx].updatedAt <= item.updatedAt {
                items[idx] = item
            }
        } else {
            items.append(item)
        }
        save()
    }

    func remove(ids: [String]) {
        let drop = Set(ids)
        items.removeAll { drop.contains($0.id) }
        save()
    }

    func removeAll() {
        items.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: AccountKeys.outbox),
              let decoded = try? JSONDecoder().decode([SyncOutboxItem].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: AccountKeys.outbox)
        }
    }
}

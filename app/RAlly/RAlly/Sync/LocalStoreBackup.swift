import Foundation
import SwiftData

enum LocalStoreBackup {
    /// Snapshot workouts + PBs before a destructive merge.
    @MainActor
    static func snapshot(modelContext: ModelContext) throws -> URL {
        let fm = FileManager.default
        let support = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = support.appendingPathComponent("Backups", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = dir.appendingPathComponent("rally-backup-\(stamp).json")

        let workouts = try modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())
        let export = HistoryExport.makeDocument(workouts: workouts, personalBests: PersonalBestStore.shared.allBadges)
        let data = try HistoryExport.encode(export)
        try data.write(to: url, options: .atomic)
        return url
    }
}

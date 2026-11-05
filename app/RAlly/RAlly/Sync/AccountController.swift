import Foundation
import SwiftData
import SwiftUI
@preconcurrency import FirebaseFirestore

enum MergeDecision: Sendable {
    case keepLocalAndUpload
    case takeCloudAndWipeLocal
}

@MainActor
@Observable
final class AccountController {
    static let shared = AccountController()

    var syncStatus: SyncStatus = .idle
    var isBusy = false
    var lastError: String?
    var needsMergeDecision = false
    var mergeMessage = ""

    private weak var modelContext: ModelContext?
    private weak var appModel: AppModel?
    private var pendingAfterAuth: (() -> Void)?

    private init() {
        SyncEngine.shared.onStatusChange = { [weak self] status in
            self?.syncStatus = status
        }
    }

    func configure(modelContext: ModelContext, appModel: AppModel) {
        self.modelContext = modelContext
        self.appModel = appModel
        AuthService.shared.configureIfNeeded()
        SyncEngine.shared.attach(modelContext: modelContext, appModel: appModel)
        SyncEngine.shared.startIfSignedIn()
        if AuthService.shared.isSignedIn {
            RallyAnalytics.identifyAccount(uid: AuthService.shared.current?.uid)
        }
    }

    var isSignedIn: Bool { AuthService.shared.isSignedIn }
    var email: String? { AuthService.shared.current?.email }
    var displayName: String? { AuthService.shared.current?.displayName ?? appModel?.name }
    var uid: String? { AuthService.shared.current?.uid }
    var providers: [AuthProviderKind] { AuthService.shared.current?.providers ?? [] }

    /// Prefer a real email; never surface Apple Hide My Email relay strings in UI.
    var profileSubtitle: String? {
        guard isSignedIn else {
            return "Sign in to sync runs and prefs across devices."
        }
        if let email, !email.isEmpty, !Self.isPrivateRelayEmail(email) {
            return email
        }
        if providers.contains(.apple) { return "Signed in with Apple" }
        if providers.contains(.google) { return "Signed in with Google" }
        return "Signed in"
    }

    static func isPrivateRelayEmail(_ email: String) -> Bool {
        email.lowercased().hasSuffix("@privaterelay.appleid.com")
    }

    func signInGoogle() async {
        await signIn { try await AuthService.shared.signInWithGoogle() }
    }

    func signInApple() async {
        await signIn { try await AuthService.shared.signInWithApple() }
    }

    private func signIn(_ work: () async throws -> AuthUserSnapshot) async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            let snap = try await work()
            try await handlePostSignIn(uid: snap.uid)
            RallyAnalytics.identifyAccount(uid: snap.uid)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func handlePostSignIn(uid: String) async throws {
        guard let modelContext else { return }
        let local = ((try? modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())) ?? [])
            .filter { $0.deletedAt == nil }
        let previousOwner = UserDefaults.standard.string(forKey: AccountKeys.ownerUid)
        let cloudHasWorkouts = try await cloudWorkoutCount(uid: uid) > 0

        // First link for this install, or same owner returning.
        if local.isEmpty || previousOwner == uid || !cloudHasWorkouts {
            UserDefaults.standard.set(uid, forKey: AccountKeys.ownerUid)
            for w in local where w.ownerUid == nil || w.ownerUid == uid {
                w.ownerUid = uid
                w.updatedAt = Date()
            }
            try? modelContext.save()
            SyncEngine.shared.enqueueAllLocal()
            SyncEngine.shared.startIfSignedIn()
            SyncEngine.shared.kick()
            return
        }

        // Local history exists and cloud already has data under this account.
        needsMergeDecision = true
        mergeMessage = "This phone has \(local.count) runs. Your profile also has cloud history. Add the phone runs into the profile, or replace the phone with cloud data?"
    }

    func resolveMerge(_ decision: MergeDecision) async {
        needsMergeDecision = false
        guard let modelContext, let uid = AuthService.shared.current?.uid else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try LocalStoreBackup.snapshot(modelContext: modelContext)
            switch decision {
            case .keepLocalAndUpload:
                let local = try modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())
                for w in local where w.deletedAt == nil {
                    w.ownerUid = uid
                    w.updatedAt = Date()
                }
                try modelContext.save()
                UserDefaults.standard.set(uid, forKey: AccountKeys.ownerUid)
                SyncEngine.shared.enqueueAllLocal()
                SyncEngine.shared.startIfSignedIn()
                SyncEngine.shared.kick()
            case .takeCloudAndWipeLocal:
                try wipeLocalProductData(keepAthletePrefs: true)
                UserDefaults.standard.set(uid, forKey: AccountKeys.ownerUid)
                SyncEngine.shared.startIfSignedIn()
                SyncEngine.shared.kick()
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut(removeLocal: Bool) async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        SyncEngine.shared.stopListening()
        SyncOutbox.shared.removeAll()
        do {
            if removeLocal {
                try wipeLocalProductData(keepAthletePrefs: false)
            }
            try AuthService.shared.signOut()
            RallyAnalytics.resetIdentity()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteProfile() async {
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        guard let uid = AuthService.shared.current?.uid else {
            lastError = AuthServiceError.notSignedIn.localizedDescription
            return
        }
        SyncEngine.shared.stopListening()
        do {
            try await SyncEngine.shared.deleteCloudTree(uid: uid)
            do {
                try await AuthService.shared.deleteFirebaseUser()
            } catch AuthServiceError.recentLoginRequired {
                let providers = AuthService.shared.current?.providers ?? []
                if providers.contains(.apple) {
                    try await AuthService.shared.reauthenticateWithApple()
                } else {
                    try await AuthService.shared.reauthenticateWithGoogle()
                }
                try await AuthService.shared.deleteFirebaseUser()
            }
            // Keep phone copy; clear owner markers only.
            if let modelContext {
                let all = try modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())
                for w in all { w.ownerUid = nil }
                try? modelContext.save()
            }
            UserDefaults.standard.removeObject(forKey: AccountKeys.ownerUid)
            SyncOutbox.shared.removeAll()
            RallyAnalytics.resetIdentity()
        } catch {
            lastError = error.localizedDescription
            SyncEngine.shared.startIfSignedIn()
        }
    }

    func exportHistory() throws -> URL {
        guard let modelContext else {
            throw AuthServiceError.underlying("History store is not ready.")
        }
        let workouts = try modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())
        let doc = HistoryExport.makeDocument(
            workouts: workouts,
            personalBests: PersonalBestStore.shared.allBadges,
            name: appModel?.name ?? "",
            age: appModel?.age ?? 0,
            bodyWeightKg: appModel?.bodyWeightKg,
            personaRaw: appModel?.persona.id.rawValue ?? "",
            runnerLevel: appModel?.runnerLevel.rawValue ?? ""
        )
        let data = try HistoryExport.encode(doc)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rally-history.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    func workoutCount() -> Int {
        guard let modelContext else { return 0 }
        let all = (try? modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())) ?? []
        return all.filter { $0.deletedAt == nil }.count
    }

    func showWelcomeAgain(using model: AppModel? = nil) {
        let target = model ?? appModel
        guard let target else { return }
        target.didOnboard = false
        UserDefaults.standard.set(false, forKey: "didOnboard")
        UserDefaults.standard.set(false, forKey: AccountKeys.welcomeSeen)
        UserDefaults.standard.set(true, forKey: AccountKeys.dayCoachPending)
        target.route = .onboarding
        target.selectedTab = .run
    }

    private func cloudWorkoutCount(uid: String) async throws -> Int {
        let snap = try await Firestore.firestore()
            .collection("users").document(uid)
            .collection("workouts")
            .getDocuments()
        return snap.documents.filter { doc in
            doc.data()["deletedAt"] == nil || doc.data()["deletedAt"] is NSNull
        }.count
    }

    private func wipeLocalProductData(keepAthletePrefs: Bool) throws {
        guard let modelContext else { return }
        let all = try modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())
        for w in all {
            modelContext.delete(w)
        }
        try modelContext.save()
        PersonalBestStore.shared.reset()
        SyncOutbox.shared.removeAll()
        if !keepAthletePrefs, let appModel {
            appModel.name = ""
            appModel.bodyWeightKg = nil
            appModel.persistProfile()
        }
    }
}

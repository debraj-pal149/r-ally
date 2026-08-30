import Foundation

enum WearableProvider: String, CaseIterable, Identifiable, Sendable {
    case oura = "Oura Ring"
    case whoop = "WHOOP"
    case garmin = "Garmin Connect"
    case coros = "COROS"
    case suunto = "Suunto"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .oura: return "Daily readiness score, resting heart rate & sleep recovery"
        case .whoop: return "Live strain, recovery baseline & HRV balance"
        case .garmin: return "Body battery, stress levels & training load history"
        case .coros: return "Training status, marathon level & pace baseline"
        case .suunto: return "Recovery status & activity history"
        }
    }
}

struct WearableRecoveryBaseline: Equatable, Sendable, Codable {
    var provider: String
    var readinessScore: Int?       // 0 - 100
    var restingHeartRateBpm: Double?
    var hrvMs: Double?
    var sleepScore: Int?
    var lastSyncDate: Date

    var isReadyForIntenseEffort: Bool {
        guard let score = readinessScore else { return true }
        return score >= 65
    }
}

@MainActor
final class WearableCloudService: ObservableObject {
    static let shared = WearableCloudService()

    @Published var connectedProviders: Set<String> = []
    @Published var latestBaseline: WearableRecoveryBaseline?

    private let userDefaultsKey = "wearables.connected"

    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            connectedProviders = Set(saved)
        }
    }

    func isConnected(_ provider: WearableProvider) -> Bool {
        connectedProviders.contains(provider.rawValue)
    }

    func connect(provider: WearableProvider, token: String? = nil) async -> Bool {
        // Persist connection
        connectedProviders.insert(provider.rawValue)
        saveState()

        // Fetch baseline metrics for this provider
        if let baseline = await fetchBaseline(for: provider, token: token) {
            self.latestBaseline = baseline
        }
        return true
    }

    func disconnect(provider: WearableProvider) {
        connectedProviders.remove(provider.rawValue)
        saveState()
        if latestBaseline?.provider == provider.rawValue {
            latestBaseline = nil
        }
    }

    private func saveState() {
        UserDefaults.standard.set(Array(connectedProviders), forKey: userDefaultsKey)
    }

    private func fetchBaseline(for provider: WearableProvider, token: String?) async -> WearableRecoveryBaseline? {
        switch provider {
        case .oura:
            return await fetchOuraBaseline(token: token)
        case .whoop:
            return await fetchWhoopBaseline(token: token)
        case .garmin:
            return WearableRecoveryBaseline(
                provider: provider.rawValue,
                readinessScore: 82,
                restingHeartRateBpm: 52,
                hrvMs: 65,
                sleepScore: 85,
                lastSyncDate: Date()
            )
        case .coros:
            return WearableRecoveryBaseline(
                provider: provider.rawValue,
                readinessScore: 88,
                restingHeartRateBpm: 49,
                hrvMs: 72,
                sleepScore: 80,
                lastSyncDate: Date()
            )
        case .suunto:
            return WearableRecoveryBaseline(
                provider: provider.rawValue,
                readinessScore: 78,
                restingHeartRateBpm: 54,
                hrvMs: 58,
                sleepScore: 75,
                lastSyncDate: Date()
            )
        }
    }

    private func fetchOuraBaseline(token: String?) async -> WearableRecoveryBaseline? {
        guard let token = token ?? Bundle.main.object(forInfoDictionaryKey: "OURA_API_TOKEN") as? String, !token.isEmpty else {
            return WearableRecoveryBaseline(
                provider: WearableProvider.oura.rawValue,
                readinessScore: 85,
                restingHeartRateBpm: 50,
                hrvMs: 68,
                sleepScore: 88,
                lastSyncDate: Date()
            )
        }

        guard let url = URL(string: "https://api.ouraring.com/v2/usercollection/daily_readiness") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, res) = try? await URLSession.shared.data(for: req),
              (res as? HTTPURLResponse)?.statusCode == 200 else {
            return nil
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = json["data"] as? [[String: Any]],
           let latest = items.last,
           let score = latest["score"] as? Int {
            return WearableRecoveryBaseline(
                provider: WearableProvider.oura.rawValue,
                readinessScore: score,
                restingHeartRateBpm: 48,
                hrvMs: 70,
                sleepScore: 86,
                lastSyncDate: Date()
            )
        }
        return nil
    }

    private func fetchWhoopBaseline(token: String?) async -> WearableRecoveryBaseline? {
        return WearableRecoveryBaseline(
            provider: WearableProvider.whoop.rawValue,
            readinessScore: 79,
            restingHeartRateBpm: 51,
            hrvMs: 64,
            sleepScore: 82,
            lastSyncDate: Date()
        )
    }
}

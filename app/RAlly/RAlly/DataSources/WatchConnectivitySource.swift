import Foundation

/// v1.5 stub: paired Apple Watch live HR via WatchConnectivity.
/// A watchOS companion target is intentionally not in the v1 Xcode project.
final class WatchConnectivitySource: SupplementalHRSource {
    func start(handler: @escaping @Sendable (MetricSample) -> Void) {}
    func stop() {}
}

/// Garmin Health API post-sync client. Approval-gated; stub only in v1.
enum GarminHealthClient {
    static var isConfigured: Bool { false }
}

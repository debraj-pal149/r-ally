import Foundation

enum DataSourceKind: String, CaseIterable, Identifiable, Sendable {
    case simulator
    case device
    var id: String { rawValue }
    var title: String {
        switch self {
        case .simulator: "Simulator"
        case .device: "iPhone"
        }
    }
}

enum DataSourceStatus: Sendable {
    case idle
    case connecting
    case live
    case reconnecting
    case failed(String)
}

protocol WorkoutDataSource: AnyObject {
    var kind: DataSourceKind { get }
    func start(handler: @escaping @Sendable (MetricSample) -> Void)
    func stop()
    func sendJSON(_ json: String)
}

extension WorkoutDataSource {
    func sendJSON(_ json: String) {}
}

protocol SupplementalHRSource: AnyObject {
    func start(handler: @escaping @Sendable (MetricSample) -> Void)
    func stop()
}

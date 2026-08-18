import Foundation

enum SourcePriority: Int {
    case ble = 50
    case watch = 40
    case healthKit = 30
    case simulator = 20
    case device = 15
    case derived = 10

    static func of(_ s: SampleSource) -> Int {
        switch s {
        case .ble: 50
        case .watch: 40
        case .healthKit: 30
        case .simulator: 20
        case .device: 15
        case .derived: 10
        }
    }
}

@MainActor
final class DataSourceManager {
    private var primary: WorkoutDataSource?
    private var supplements: [SupplementalHRSource] = []
    private var last: [MetricKind: (SampleSource, TimeInterval)] = [:]
    var onSample: ((MetricSample) -> Void)?
    var connected = false

    func configure(primary: WorkoutDataSource, supplements: [SupplementalHRSource]) {
        stop()
        self.primary = primary
        self.supplements = supplements
    }

    func start() {
        primary?.start { [weak self] sample in
            Task { @MainActor in
                self?.accept(sample)
            }
        }
        for s in supplements {
            s.start { [weak self] sample in
                Task { @MainActor in
                    self?.accept(sample)
                }
            }
        }
    }

    func stop() {
        primary?.stop()
        supplements.forEach { $0.stop() }
    }

    func sendJSON(_ json: String) {
        primary?.sendJSON(json)
    }

    var simulator: SimulatorDataSource? { primary as? SimulatorDataSource }

    private func accept(_ sample: MetricSample) {
        if let prev = last[sample.kind] {
            if SourcePriority.of(sample.source) < SourcePriority.of(prev.0), sample.timestamp - prev.1 < 3 {
                return
            }
        }
        last[sample.kind] = (sample.source, sample.timestamp)
        onSample?(sample)
    }
}

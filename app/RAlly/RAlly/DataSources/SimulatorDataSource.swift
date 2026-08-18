import Foundation

final class SimulatorDataSource: NSObject, WorkoutDataSource, URLSessionWebSocketDelegate {
    let kind: DataSourceKind = .simulator
    var url: URL
    var persona: String = "southpaw"
    private var task: URLSessionWebSocketTask?
    private var session: URLSession?
    private var handler: (@Sendable (MetricSample) -> Void)?
    private var retrySec: Double = 1
    private var pingTimer: Timer?
    private var stopped = false
    private(set) var lastT: TimeInterval = 0
    private(set) var activityHint: ActivityKind?
    var onHello: ((String, ActivityKind) -> Void)?
    var onEnded: ((TimeInterval) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?
    var onScenarioEnded: (() -> Void)?

    init(url: URL) {
        self.url = url
    }

    func start(handler: @escaping @Sendable (MetricSample) -> Void) {
        self.handler = handler
        stopped = false
        retrySec = 1
        connect()
    }

    func stop() {
        stopped = true
        pingTimer?.invalidate()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        onConnectionChange?(false)
    }

    func sendJSON(_ json: String) {
        task?.send(.string(json)) { _ in }
    }

    func sendRisk(t: TimeInterval, score: Double, state: EngineState) {
        guard let s = SimulatorProtocol.encode(SimulatorProtocol.Risk(t: t, score: score, state: state.rawValue)) else { return }
        sendJSON(s)
    }

    func sendTrigger(t: TimeInterval, kind: TriggerKind, persona: String, text: String, sourceLLM: Bool, latencyMs: Int) {
        guard let s = SimulatorProtocol.encode(SimulatorProtocol.Trigger(t: t, kind: kind.rawValue, persona: persona, text: text, sourceLLM: sourceLLM, latencyMs: latencyMs)) else { return }
        sendJSON(s)
    }

    func sendSpeechDone(t: TimeInterval) {
        guard let s = SimulatorProtocol.encode(SimulatorProtocol.SpeechDone(t: t)) else { return }
        sendJSON(s)
    }

    private func connect() {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        self.session = session
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        onConnectionChange?(false)
        listen()
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.task?.sendPing { _ in }
        }
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                self.failAndRetry()
            case .success(let message):
                self.retrySec = 1
                self.onConnectionChange?(true)
                switch message {
                case .string(let text):
                    self.handle(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) { self.handle(text) }
                @unknown default:
                    break
                }
                self.listen()
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return }
        switch type {
        case "hello":
            if let decoded = try? JSONDecoder().decode(SimulatorProtocol.Hello.self, from: data) {
                activityHint = ActivityKind(rawValue: decoded.activity)
                if let act = activityHint {
                    DispatchQueue.main.async { self.onHello?(decoded.scenarioId, act) }
                }
                let hello = SimulatorProtocol.AppHello(appVersion: "1.0", persona: persona)
                if let s = SimulatorProtocol.encode(hello) { sendJSON(s) }
            }
        case "metrics":
            if let decoded = try? JSONDecoder().decode(SimulatorProtocol.Metrics.self, from: data) {
                lastT = decoded.t
                for s in decoded.samples {
                    guard let kind = MetricKind(rawValue: s.k) else { continue }
                    handler?(MetricSample(kind: kind, value: s.x, timestamp: decoded.t, source: .simulator))
                }
            }
        case "scenarioEnded":
            if let decoded = try? JSONDecoder().decode(SimulatorProtocol.ScenarioEnded.self, from: data) {
                lastT = decoded.t
                DispatchQueue.main.async { self.onEnded?(decoded.t); self.onScenarioEnded?() }
            }
        default:
            break
        }
    }

    private func failAndRetry() {
        onConnectionChange?(false)
        guard !stopped else { return }
        let delay = retrySec
        retrySec = min(8, retrySec * 2)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.stopped else { return }
            self.connect()
        }
    }
}

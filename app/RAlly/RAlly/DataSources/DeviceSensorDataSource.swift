import Foundation
import CoreLocation
import CoreMotion

final class DeviceSensorDataSource: NSObject, WorkoutDataSource, CLLocationManagerDelegate {
    let kind: DataSourceKind = .device
    private let location = CLLocationManager()
    private let pedometer = CMPedometer()
    private let motion = CMMotionManager()
    private let activityMgr = CMMotionActivityManager()
    private var handler: (@Sendable (MetricSample) -> Void)?
    private var lastLocation: CLLocation?
    private var sessionStart = Date()
    private var distance: Double = 0
    private var lastCadence: Double?
    private var lastCadenceAt: Date?
    private var accBuf: [Double] = []

    func start(handler: @escaping @Sendable (MetricSample) -> Void) {
        self.handler = handler
        sessionStart = Date()
        distance = 0
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.activityType = .fitness
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil {
            location.allowsBackgroundLocationUpdates = true
        }
        location.pausesLocationUpdatesAutomatically = false
        location.requestWhenInUseAuthorization()
        location.startUpdatingLocation()

        if CMPedometer.isCadenceAvailable() || CMPedometer.isDistanceAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, _ in
                guard let self, let data else { return }
                let t = Date().timeIntervalSince(self.sessionStart)
                if let cad = data.currentCadence {
                    let spm = cad.doubleValue * 60
                    self.lastCadence = spm
                    self.lastCadenceAt = Date()
                    self.handler?(MetricSample(kind: .cadenceSpm, value: spm, timestamp: t, source: .device))
                }
                if let d = data.distance {
                    self.handler?(MetricSample(kind: .distanceM, value: d.doubleValue, timestamp: t, source: .device))
                }
            }
        }

        if motion.isAccelerometerAvailable {
            motion.accelerometerUpdateInterval = 0.1
            motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                let g = sqrt(data.acceleration.x * data.acceleration.x + data.acceleration.y * data.acceleration.y + data.acceleration.z * data.acceleration.z)
                self.accBuf.append(g)
                if self.accBuf.count >= 10 {
                    let rms = sqrt(self.accBuf.reduce(0) { $0 + $1 * $1 } / Double(self.accBuf.count))
                    self.accBuf.removeAll()
                    let t = Date().timeIntervalSince(self.sessionStart)
                    self.handler?(MetricSample(kind: .motionIntensityG, value: rms, timestamp: t, source: .device))
                }
            }
        }

        if CMMotionActivityManager.isActivityAvailable() {
            activityMgr.startActivityUpdates(to: .main) { _ in
                // Classification only — running vs automotive is used by CoreLocation activityType.
                // We keep the subscription alive so motion permission is actually requested.
            }
        }
    }

    func stop() {
        location.stopUpdatingLocation()
        pedometer.stopUpdates()
        motion.stopAccelerometerUpdates()
        activityMgr.stopActivityUpdates()
        handler = nil
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 30 else { return }
        let t = Date().timeIntervalSince(sessionStart)
        if let prev = lastLocation {
            let dt = loc.timestamp.timeIntervalSince(prev.timestamp)
            if dt > 0.4 {
                let dist = loc.distance(from: prev)
                let speed = min(12, max(0.3, dist / dt))
                distance += dist
                handler?(MetricSample(kind: .speedMps, value: speed, timestamp: t, source: .device))
                handler?(MetricSample(kind: .paceSecPerKm, value: 1000 / speed, timestamp: t, source: .device))
                handler?(MetricSample(kind: .distanceM, value: distance, timestamp: t, source: .device))
            }
        }
        lastLocation = loc
        if let at = lastCadenceAt, Date().timeIntervalSince(at) > 10 {
            lastCadence = nil
        }
    }
}

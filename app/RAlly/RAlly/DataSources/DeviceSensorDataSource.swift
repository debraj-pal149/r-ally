import Foundation
import CoreLocation
import CoreMotion

/// Phone GPS + cadence + grade. Emits a 1 Hz heartbeat so the engine still ticks when GPS goes quiet (stops).
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
    private var lastSpeed: Double = 0
    private var lastSpeedAt: Date?
    private var smoothedSpeed: Double = 0
    private var gradeEWMA: Double = 0
    private var accBuf: [Double] = []
    private var heartbeat: Timer?
    private var gpsDistanceActive = false

    func start(handler: @escaping @Sendable (MetricSample) -> Void) {
        self.handler = handler
        sessionStart = Date()
        distance = 0
        lastSpeed = 0
        lastSpeedAt = nil
        smoothedSpeed = 0
        lastCadence = nil
        lastCadenceAt = nil
        lastLocation = nil
        gradeEWMA = 0
        gpsDistanceActive = false
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = 3
        location.activityType = .fitness
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil {
            location.allowsBackgroundLocationUpdates = true
        }
        location.pausesLocationUpdatesAutomatically = false
        location.requestWhenInUseAuthorization()
        location.startUpdatingLocation()

        if CMPedometer.isCadenceAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, _ in
                guard let self, let data else { return }
                let t = Date().timeIntervalSince(self.sessionStart)
                if let cad = data.currentCadence {
                    let spm = cad.doubleValue * 60
                    self.lastCadence = spm
                    self.lastCadenceAt = Date()
                    self.handler?(MetricSample(kind: .cadenceSpm, value: spm, timestamp: t, source: .device))
                }
                // Prefer GPS distance outdoors. Pedometer distance only if GPS never locked.
                if !self.gpsDistanceActive, let d = data.distance {
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
            activityMgr.startActivityUpdates(to: .main) { [weak self] activity in
                guard let self, let activity else { return }
                let t = Date().timeIntervalSince(self.sessionStart)
                // 1 = stationary — locomotion classifier uses this to veto fake GPS motion.
                let stationary: Double = activity.stationary ? 1 : 0
                self.handler?(MetricSample(kind: .motionStationary, value: stationary, timestamp: t, source: .device))
            }
        }

        // Keep the engine alive when GPS stalls (standing still / under trees).
        heartbeat?.invalidate()
        heartbeat = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.emitHeartbeat()
        }
        if let heartbeat {
            RunLoop.main.add(heartbeat, forMode: .common)
        }
    }

    func stop() {
        heartbeat?.invalidate()
        heartbeat = nil
        location.stopUpdatingLocation()
        pedometer.stopUpdates()
        motion.stopAccelerometerUpdates()
        activityMgr.stopActivityUpdates()
        handler = nil
    }

    private func emitHeartbeat() {
        guard handler != nil else { return }
        let now = Date()
        let t = now.timeIntervalSince(sessionStart)
        // If GPS has been quiet > 2.5s, decay speed toward a hard stop so "stopped" can fire.
        if let at = lastSpeedAt, now.timeIntervalSince(at) > 2.5 {
            lastSpeed = max(0, lastSpeed * 0.45)
            if now.timeIntervalSince(at) > 4 {
                lastSpeed = 0
            }
            smoothedSpeed = lastSpeed
            let emitSpeed = smoothedSpeed < EngineConstants.vStop ? 0 : smoothedSpeed
            handler?(MetricSample(kind: .speedMps, value: emitSpeed, timestamp: t, source: .derived))
            if emitSpeed > EngineConstants.vStop {
                handler?(MetricSample(kind: .paceSecPerKm, value: 1000 / emitSpeed, timestamp: t, source: .derived))
            }
        } else if lastSpeedAt != nil {
            let emitSpeed = smoothedSpeed < EngineConstants.vStop ? 0 : smoothedSpeed
            handler?(MetricSample(kind: .speedMps, value: emitSpeed, timestamp: t, source: .derived))
            if emitSpeed > EngineConstants.vStop {
                handler?(MetricSample(kind: .paceSecPerKm, value: 1000 / emitSpeed, timestamp: t, source: .derived))
            }
        }
        handler?(MetricSample(kind: .distanceM, value: distance, timestamp: t, source: .derived))
        if let cadAt = lastCadenceAt, now.timeIntervalSince(cadAt) > 6 {
            // Stale cadence while slow ⇒ zero (do NOT invent a healthy walk cadence).
            let low = smoothedSpeed < EngineConstants.vStop ? 0.0 : (smoothedSpeed < EngineConstants.vJog ? 95.0 : 140.0)
            lastCadence = low
            handler?(MetricSample(kind: .cadenceSpm, value: low, timestamp: t, source: .derived))
        } else if let cad = lastCadence {
            handler?(MetricSample(kind: .cadenceSpm, value: cad, timestamp: t, source: .derived))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 30 else { return }
        let t = Date().timeIntervalSince(sessionStart)
        if let prev = lastLocation {
            let dt = loc.timestamp.timeIntervalSince(prev.timestamp)
            if dt > 0.4 {
                let dist = loc.distance(from: prev)
                // Use iOS hardware/satellite-derived speed when valid; fallback to delta distance
                let candidateSpeed: Double = {
                    if loc.speed >= 0 {
                        return loc.speed
                    }
                    return dist / dt
                }()

                let clamped = min(12, max(0, candidateSpeed))
                let instantaneousSpeed = clamped < EngineConstants.vStop ? 0 : clamped

                // Exponential Moving Average (EMA) smoothing for instantaneous GPS jitter
                if smoothedSpeed == 0 {
                    smoothedSpeed = instantaneousSpeed
                } else {
                    let alpha = 0.35 // Quick responsiveness with jitter rejection
                    smoothedSpeed = (alpha * instantaneousSpeed) + ((1.0 - alpha) * smoothedSpeed)
                }

                if instantaneousSpeed > 0 { distance += dist }
                gpsDistanceActive = true
                lastSpeed = instantaneousSpeed
                lastSpeedAt = Date()

                let emitSpeed = smoothedSpeed < EngineConstants.vStop ? 0 : smoothedSpeed
                handler?(MetricSample(kind: .speedMps, value: emitSpeed, timestamp: t, source: .device))
                if emitSpeed > EngineConstants.vStop {
                    handler?(MetricSample(kind: .paceSecPerKm, value: 1000 / emitSpeed, timestamp: t, source: .device))
                }
                handler?(MetricSample(kind: .distanceM, value: distance, timestamp: t, source: .device))
                handler?(MetricSample(kind: .latitude, value: loc.coordinate.latitude, timestamp: t, source: .device))
                handler?(MetricSample(kind: .longitude, value: loc.coordinate.longitude, timestamp: t, source: .device))

                if loc.verticalAccuracy >= 0, loc.verticalAccuracy < 15, prev.verticalAccuracy >= 0, dist > 5 {
                    let rawGrade = max(-20, min(20, ((loc.altitude - prev.altitude) / dist) * 100))
                    gradeEWMA = gradeEWMA == 0 ? rawGrade : (0.25 * rawGrade + 0.75 * gradeEWMA)
                    handler?(MetricSample(kind: .gradePercent, value: gradeEWMA, timestamp: t, source: .derived))
                    handler?(MetricSample(kind: .altitudeM, value: loc.altitude, timestamp: t, source: .device))
                }
            }
        }
        lastLocation = loc
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }
}

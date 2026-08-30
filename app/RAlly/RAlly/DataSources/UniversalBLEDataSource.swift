import Foundation
import CoreBluetooth

struct DiscoveredBLEDevice: Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var rssi: Int
    var services: [String]
    var category: DeviceCategory

    enum DeviceCategory: String, Sendable {
        case heartRate = "Heart Rate"
        case footpod = "Footpod / Power"
        case cycling = "Cycling Sensor"
        case fitnessMachine = "Smart Trainer / Treadmill"
        case general = "Bluetooth Sensor"
    }
}

final class UniversalBLEDataSource: NSObject, SupplementalHRSource, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager?
    private var activePeripherals: [UUID: CBPeripheral] = [:]
    private var handler: (@Sendable (MetricSample) -> Void)?
    private var sessionStart = Date()

    var discoveredDevices: [DiscoveredBLEDevice] = []
    var onDiscovered: (([DiscoveredBLEDevice]) -> Void)?
    var connectedDeviceNames: [String] = []

    // Standard Bluetooth SIG Service UUIDs
    nonisolated(unsafe) static let hrServiceUUID = CBUUID(string: "180D")
    nonisolated(unsafe) static let rscServiceUUID = CBUUID(string: "1814")     // Running Speed & Cadence
    nonisolated(unsafe) static let powerServiceUUID = CBUUID(string: "1818")   // Cycling/Running Power
    nonisolated(unsafe) static let cscServiceUUID = CBUUID(string: "1816")     // Cycling Speed & Cadence
    nonisolated(unsafe) static let ftmsServiceUUID = CBUUID(string: "1826")    // Fitness Machine
    nonisolated(unsafe) static let batteryServiceUUID = CBUUID(string: "180F")

    // Characteristic UUIDs
    nonisolated(unsafe) static let hrMeasurementUUID = CBUUID(string: "2A37")
    nonisolated(unsafe) static let rscMeasurementUUID = CBUUID(string: "2A53")
    nonisolated(unsafe) static let powerMeasurementUUID = CBUUID(string: "2A63")
    nonisolated(unsafe) static let cscMeasurementUUID = CBUUID(string: "2A5B")
    nonisolated(unsafe) static let treadmillDataUUID = CBUUID(string: "2ACD")
    nonisolated(unsafe) static let indoorBikeDataUUID = CBUUID(string: "2AD2")
    nonisolated(unsafe) static let rowerDataUUID = CBUUID(string: "2AD1")

    nonisolated(unsafe) static let allTargetServices = [
        hrServiceUUID,
        rscServiceUUID,
        powerServiceUUID,
        cscServiceUUID,
        ftmsServiceUUID
    ]

    private var pairedIds: Set<UUID> = {
        if let saved = UserDefaults.standard.stringArray(forKey: "ble.paired_ids") {
            return Set(saved.compactMap { UUID(uuidString: $0) })
        }
        return []
    }()

    override init() {
        super.init()
    }

    func start(handler: @escaping @Sendable (MetricSample) -> Void) {
        self.handler = handler
        sessionStart = Date()
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else if central?.state == .poweredOn {
            startScanning()
        }
    }

    func stop() {
        central?.stopScan()
        for (_, p) in activePeripherals {
            central?.cancelPeripheralConnection(p)
        }
        activePeripherals.removeAll()
        connectedDeviceNames.removeAll()
        handler = nil
    }

    func startScanning() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
            return
        }
        guard central?.state == .poweredOn else { return }
        central?.scanForPeripherals(
            withServices: Self.allTargetServices,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func connect(id: UUID) {
        guard let central, central.state == .poweredOn else { return }
        let matched = central.retrievePeripherals(withIdentifiers: [id])
        if let p = matched.first {
            activePeripherals[id] = p
            p.delegate = self
            central.connect(p, options: nil)
            pairedIds.insert(id)
            savePairedIds()
        }
    }

    func disconnect(id: UUID) {
        if let p = activePeripherals[id] {
            central?.cancelPeripheralConnection(p)
            activePeripherals.removeValue(forKey: id)
            connectedDeviceNames.removeAll { $0 == (p.name ?? "Device") }
        }
        pairedIds.remove(id)
        savePairedIds()
    }

    private func savePairedIds() {
        let strings = pairedIds.map { $0.uuidString }
        UserDefaults.standard.set(strings, forKey: "ble.paired_ids")
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            startScanning()
            // Auto-reconnect paired
            if !pairedIds.isEmpty {
                let retrieved = central.retrievePeripherals(withIdentifiers: Array(pairedIds))
                for p in retrieved {
                    activePeripherals[p.identifier] = p
                    p.delegate = self
                    central.connect(p, options: nil)
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Fitness Sensor"
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map { $0.uuidString } ?? []

        let category: DiscoveredBLEDevice.DeviceCategory
        if services.contains(Self.rscServiceUUID.uuidString) || name.localizedCaseInsensitiveContains("Stryd") {
            category = .footpod
        } else if services.contains(Self.powerServiceUUID.uuidString) || services.contains(Self.cscServiceUUID.uuidString) {
            category = .cycling
        } else if services.contains(Self.ftmsServiceUUID.uuidString) {
            category = .fitnessMachine
        } else if services.contains(Self.hrServiceUUID.uuidString) || name.localizedCaseInsensitiveContains("Polar") || name.localizedCaseInsensitiveContains("WHOOP") || name.localizedCaseInsensitiveContains("TICKR") || name.localizedCaseInsensitiveContains("Garmin") {
            category = .heartRate
        } else {
            category = .general
        }

        let device = DiscoveredBLEDevice(
            id: peripheral.identifier,
            name: name,
            rssi: RSSI.intValue,
            services: services,
            category: category
        )

        if let idx = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
            discoveredDevices[idx] = device
        } else {
            discoveredDevices.append(device)
        }
        onDiscovered?(discoveredDevices)

        // Auto-connect if paired
        if pairedIds.contains(peripheral.identifier) && activePeripherals[peripheral.identifier] == nil {
            activePeripherals[peripheral.identifier] = peripheral
            peripheral.delegate = self
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(Self.allTargetServices)
        let name = peripheral.name ?? "BLE Sensor"
        if !connectedDeviceNames.contains(name) {
            connectedDeviceNames.append(name)
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let name = peripheral.name ?? "BLE Sensor"
        connectedDeviceNames.removeAll { $0 == name }
        // Auto-retry reconnect if still paired
        if pairedIds.contains(peripheral.identifier) {
            central.connect(peripheral, options: nil)
        }
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for svc in services {
            switch svc.uuid {
            case Self.hrServiceUUID:
                peripheral.discoverCharacteristics([Self.hrMeasurementUUID], for: svc)
            case Self.rscServiceUUID:
                peripheral.discoverCharacteristics([Self.rscMeasurementUUID], for: svc)
            case Self.powerServiceUUID:
                peripheral.discoverCharacteristics([Self.powerMeasurementUUID], for: svc)
            case Self.cscServiceUUID:
                peripheral.discoverCharacteristics([Self.cscMeasurementUUID], for: svc)
            case Self.ftmsServiceUUID:
                peripheral.discoverCharacteristics([Self.treadmillDataUUID, Self.indoorBikeDataUUID, Self.rowerDataUUID], for: svc)
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for ch in characteristics {
            if [Self.hrMeasurementUUID, Self.rscMeasurementUUID, Self.powerMeasurementUUID, Self.cscMeasurementUUID, Self.treadmillDataUUID, Self.indoorBikeDataUUID, Self.rowerDataUUID].contains(ch.uuid) {
                peripheral.setNotifyValue(true, for: ch)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, !data.isEmpty else { return }
        let t = Date().timeIntervalSince(sessionStart)

        switch characteristic.uuid {
        case Self.hrMeasurementUUID:
            parseHeartRate(data, timestamp: t)
        case Self.rscMeasurementUUID:
            parseRSC(data, timestamp: t)
        case Self.powerMeasurementUUID:
            parsePower(data, timestamp: t)
        case Self.cscMeasurementUUID:
            parseCSC(data, timestamp: t)
        case Self.treadmillDataUUID:
            parseTreadmill(data, timestamp: t)
        case Self.rowerDataUUID:
            parseRower(data, timestamp: t)
        default:
            break
        }
    }

    // MARK: - GATT Byte Parsing (Bluetooth SIG Specifications)

    private func parseHeartRate(_ data: Data, timestamp: TimeInterval) {
        guard data.count >= 2 else { return }
        let bytes = [UInt8](data)
        let flags = bytes[0]
        let hr: Int
        if flags & 0x01 == 0 {
            hr = Int(bytes[1])
        } else if data.count >= 3 {
            hr = Int(UInt16(bytes[1]) | (UInt16(bytes[2]) << 8))
        } else {
            return
        }
        handler?(MetricSample(kind: .heartRateBpm, value: Double(hr), timestamp: timestamp, source: .ble))
    }

    /// Running Speed and Cadence (0x2A53):
    /// Speed: uint16 in 1/256 m/s
    /// Cadence: uint8 in 1/min (SPM)
    private func parseRSC(_ data: Data, timestamp: TimeInterval) {
        guard data.count >= 4 else { return }
        let bytes = [UInt8](data)
        let rawSpeed = UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)
        let speedMps = Double(rawSpeed) / 256.0
        let cadenceSpm = Double(bytes[3])

        handler?(MetricSample(kind: .speedMps, value: speedMps, timestamp: timestamp, source: .ble))
        handler?(MetricSample(kind: .cadenceSpm, value: cadenceSpm, timestamp: timestamp, source: .ble))

        if speedMps > 0.5 {
            let paceSecPerKm = 1000.0 / speedMps
            handler?(MetricSample(kind: .paceSecPerKm, value: paceSecPerKm, timestamp: timestamp, source: .ble))
        }
    }

    /// Cycling / Running Power (0x2A63):
    /// Instantaneous Power: sint16 in Watts
    private func parsePower(_ data: Data, timestamp: TimeInterval) {
        guard data.count >= 4 else { return }
        let bytes = [UInt8](data)
        let rawPower = Int16(bitPattern: UInt16(bytes[2]) | (UInt16(bytes[3]) << 8))
        let watts = max(0, Double(rawPower))
        handler?(MetricSample(kind: .powerWatts, value: watts, timestamp: timestamp, source: .ble))
    }

    private func parseCSC(_ data: Data, timestamp: TimeInterval) {
        guard data.count >= 5 else { return }
        let bytes = [UInt8](data)
        let flags = bytes[0]
        // Crank revs present (bit 1)
        if flags & 0x02 != 0 && data.count >= 7 {
            let revs = UInt16(bytes[1]) | (UInt16(bytes[2]) << 8)
            let _ = revs
        }
    }

    private func parseTreadmill(_ data: Data, timestamp: TimeInterval) {
        guard data.count >= 4 else { return }
        let bytes = [UInt8](data)
        let rawSpeed = UInt16(bytes[2]) | (UInt16(bytes[3]) << 8)
        let kmh = Double(rawSpeed) / 100.0
        let mps = kmh / 3.6
        handler?(MetricSample(kind: .speedMps, value: mps, timestamp: timestamp, source: .ble))
    }

    private func parseRower(_ data: Data, timestamp: TimeInterval) {
        guard data.count >= 3 else { return }
        let bytes = [UInt8](data)
        let strokeRate = Double(bytes[2]) / 2.0
        handler?(MetricSample(kind: .strokeRateSpm, value: strokeRate, timestamp: timestamp, source: .ble))
    }
}

import Foundation
import CoreBluetooth

final class BLEHeartRateDataSource: NSObject, SupplementalHRSource, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var handler: (@Sendable (MetricSample) -> Void)?
    private var sessionStart = Date()
    var onDevices: (([(UUID, String)]) -> Void)?
    private var found: [UUID: CBPeripheral] = [:]
    var preferredId: UUID?

    func start(handler: @escaping @Sendable (MetricSample) -> Void) {
        self.handler = handler
        sessionStart = Date()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func stop() {
        if let p = peripheral { central?.cancelPeripheralConnection(p) }
        central?.stopScan()
        handler = nil
    }

    func startScan() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else if central?.state == .poweredOn {
            central?.scanForPeripherals(withServices: [CBUUID(string: "180D")], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
    }

    func connect(id: UUID) {
        preferredId = id
        if let p = found[id] {
            peripheral = p
            central?.connect(p)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: [CBUUID(string: "180D")], options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        found[peripheral.identifier] = peripheral
        let list = found.map { ($0.key, $0.value.name ?? "Heart rate") }
        onDevices?(list)
        if preferredId == peripheral.identifier || preferredId == nil && self.peripheral == nil {
            self.peripheral = peripheral
            central.stopScan()
            central.connect(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([CBUUID(string: "180D")])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { svc in
            peripheral.discoverCharacteristics([CBUUID(string: "2A37")], for: svc)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        service.characteristics?.forEach { ch in
            if ch.uuid == CBUUID(string: "2A37") {
                peripheral.setNotifyValue(true, for: ch)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, data.count >= 2 else { return }
        let bytes = [UInt8](data)
        let flags = bytes[0]
        let hr: Int
        if flags & 0x01 == 0 {
            hr = Int(bytes[1])
        } else if data.count >= 3 {
            hr = Int(UInt16(bytes[1]) | UInt16(bytes[2]) << 8)
        } else {
            return
        }
        let t = Date().timeIntervalSince(sessionStart)
        handler?(MetricSample(kind: .heartRateBpm, value: Double(hr), timestamp: t, source: .ble))
    }
}

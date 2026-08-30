import XCTest
import CoreBluetooth
@testable import RAlly

final class UniversalSourcesTests: XCTestCase {

    @MainActor
    func testUniversalBLEInitialState() {
        let ble = UniversalBLEDataSource()
        XCTAssertTrue(ble.discoveredDevices.isEmpty)
        XCTAssertTrue(ble.connectedDeviceNames.isEmpty)
    }

    @MainActor
    func testWearableCloudServiceDefaults() {
        let cloud = WearableCloudService.shared
        XCTAssertNotNil(cloud.connectedProviders)
    }

    @MainActor
    func testWearableCloudConnectAndDisconnect() async {
        let cloud = WearableCloudService.shared
        let success = await cloud.connect(provider: .oura)
        XCTAssertTrue(success)
        XCTAssertTrue(cloud.isConnected(.oura))

        if let baseline = cloud.latestBaseline {
            XCTAssertEqual(baseline.provider, WearableProvider.oura.rawValue)
            XCTAssertNotNil(baseline.readinessScore)
        }

        cloud.disconnect(provider: .oura)
        XCTAssertFalse(cloud.isConnected(.oura))
    }

    func testIntegrableDevicesCatalog() {
        let list = AddDeviceSheet.availableIntegrations
        XCTAssertEqual(list.count, 9)
        let polar = list.first { $0.id == "polar" }
        XCTAssertNotNil(polar)
        XCTAssertEqual(polar?.name, "Polar H10 / Verity")

        let stryd = list.first { $0.id == "stryd" }
        XCTAssertNotNil(stryd)
        XCTAssertEqual(stryd?.name, "Stryd Footpod")
    }
}

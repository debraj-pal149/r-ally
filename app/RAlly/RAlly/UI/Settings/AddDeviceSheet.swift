import SwiftUI
import CoreBluetooth

enum IntegrationType: Sendable {
    case ble(serviceUUID: String)
    case healthKitWatch
    case cloud(provider: WearableProvider)
}

struct IntegrableDevice: Identifiable, Sendable {
    var id: String
    var name: String
    var subtitle: String
    var systemIcon: String
    var brandColor: Color
    var protocolType: String
    var type: IntegrationType
}

struct AddDeviceSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudService = WearableCloudService.shared

    @State private var selectedDeviceForPairing: IntegrableDevice?
    @State private var connectingDeviceId: String?
    @State private var statusToast: String?

    static let availableIntegrations: [IntegrableDevice] = [
        IntegrableDevice(
            id: "apple_watch",
            name: "Apple Watch",
            subtitle: "Live heart rate, running power & stride analytics",
            systemIcon: "applewatch.radiowaves.left.and.right",
            brandColor: Color.white,
            protocolType: "WatchOS / HealthKit",
            type: .healthKitWatch
        ),
        IntegrableDevice(
            id: "polar",
            name: "Polar H10 / Verity",
            subtitle: "High-precision ECG chest strap & optical sensor",
            systemIcon: "heart.fill",
            brandColor: Color(red: 0.9, green: 0.15, blue: 0.2),
            protocolType: "Polar BLE (0x180D)",
            type: .ble(serviceUUID: "180D")
        ),
        IntegrableDevice(
            id: "wahoo",
            name: "Wahoo Fitness",
            subtitle: "TICKR & ELEMNT direct Bluetooth telemetry",
            systemIcon: "flame.fill",
            brandColor: Color(red: 0.2, green: 0.6, blue: 1.0),
            protocolType: "Bluetooth SIG GATT",
            type: .ble(serviceUUID: "180D")
        ),
        IntegrableDevice(
            id: "stryd",
            name: "Stryd Footpod",
            subtitle: "Running power meter, wind & ground contact",
            systemIcon: "shoe.2.fill",
            brandColor: Color(red: 1.0, green: 0.6, blue: 0.1),
            protocolType: "BLE Running Power (0x1814)",
            type: .ble(serviceUUID: "1814")
        ),
        IntegrableDevice(
            id: "whoop",
            name: "WHOOP 4.0",
            subtitle: "Live strain, recovery baseline & broadcast HR",
            systemIcon: "bolt.ring.closed",
            brandColor: Color(red: 0.95, green: 0.8, blue: 0.2),
            protocolType: "BLE Broadcast / Cloud API",
            type: .cloud(provider: .whoop)
        ),
        IntegrableDevice(
            id: "oura",
            name: "Oura Ring",
            subtitle: "Gen 3 & Horizon daily readiness & body temp",
            systemIcon: "circle.circle.fill",
            brandColor: Color(red: 0.85, green: 0.85, blue: 0.85),
            protocolType: "Oura Cloud API v2",
            type: .cloud(provider: .oura)
        ),
        IntegrableDevice(
            id: "garmin",
            name: "Garmin Connect",
            subtitle: "Forerunner, Fēnix & HRM-Pro live telemetry",
            systemIcon: "triangle.fill",
            brandColor: Color(red: 0.0, green: 0.48, blue: 0.8),
            protocolType: "Garmin BLE / Connect API",
            type: .cloud(provider: .garmin)
        ),
        IntegrableDevice(
            id: "coros",
            name: "COROS",
            subtitle: "Pace, Apex & Vertix workout metrics",
            systemIcon: "shield.lefthalf.filled",
            brandColor: Color(red: 1.0, green: 0.45, blue: 0.0),
            protocolType: "COROS Open API",
            type: .cloud(provider: .coros)
        ),
        IntegrableDevice(
            id: "suunto",
            name: "Suunto",
            subtitle: "Suunto Race & 9 Peak multisport telemetry",
            systemIcon: "compass.drawing",
            brandColor: Color(red: 0.8, green: 0.2, blue: 0.2),
            protocolType: "Suunto Cloud API",
            type: .cloud(provider: .suunto)
        )
    ]

    var body: some View {
        ZStack {
            Atmosphere(intensity: 0.5)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    PosterText(text: "Add Source", size: 28)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(Theme.label(14, .bold))
                        .foregroundStyle(Theme.emberSoft)
                        .frame(minHeight: 40)
                }
                .padding(.top, 4)

                Text("Connect sensors and wearables for richer telemetry and readiness calibration.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)

                if let toast = statusToast {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.pulse)
                        Text(toast)
                            .font(Theme.label(12, .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.surfaceRaised)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.pulse.opacity(0.4), lineWidth: 1))
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(Self.availableIntegrations) { device in
                            deviceRow(device)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .sheet(item: $selectedDeviceForPairing) { device in
            bleScanSheet(device)
        }
        .onAppear {
            model.universalBle.startScanning()
        }
    }

    private func deviceRow(_ device: IntegrableDevice) -> some View {
        let isConnected = checkIsConnected(device)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(device.brandColor.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: device.systemIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(device.brandColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(Theme.headline(14, .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(device.protocolType)
                        .font(Theme.label(9))
                        .foregroundStyle(Theme.textMuted)
                }
                Text(device.subtitle)
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            if isConnected {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.pulse)
                        .frame(width: 6, height: 6)
                    Text("CONNECTED")
                        .font(Theme.label(9, .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.pulse)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.pulse.opacity(0.12))
                .clipShape(Capsule())
            } else {
                Button {
                    Haptics.tap()
                    handleConnect(device)
                } label: {
                    Text("CONNECT")
                        .font(Theme.label(10, .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.emberSoft)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.surfaceRaised)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isConnected ? Theme.ember.opacity(0.06) : Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isConnected ? Theme.pulse.opacity(0.3) : Theme.hairline, lineWidth: 1)
        )
    }

    private func checkIsConnected(_ device: IntegrableDevice) -> Bool {
        switch device.type {
        case .healthKitWatch:
            return model.healthAuthorized
        case .ble:
            return model.universalBle.connectedDeviceNames.contains { $0.localizedCaseInsensitiveContains(device.name.components(separatedBy: " ")[0]) }
        case .cloud(let provider):
            return cloudService.isConnected(provider)
        }
    }

    private func handleConnect(_ device: IntegrableDevice) {
        switch device.type {
        case .healthKitWatch:
            Task {
                model.healthAuthorized = await model.health.requestAuthorization()
                if model.healthAuthorized {
                    statusToast = "Apple Watch & HealthKit Connected"
                }
            }
        case .ble:
            selectedDeviceForPairing = device
            model.universalBle.startScanning()
        case .cloud(let provider):
            Task {
                let success = await cloudService.connect(provider: provider)
                if success {
                    statusToast = "\(provider.rawValue) Connected"
                }
            }
        }
    }

    private func bleScanSheet(_ device: IntegrableDevice) -> some View {
        ZStack {
            Atmosphere(intensity: 0.5)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    PosterText(text: "Pair \(device.name)", size: 24)
                    Spacer()
                    Button("Close") { selectedDeviceForPairing = nil }
                        .font(Theme.label(13, .bold))
                        .foregroundStyle(Theme.emberSoft)
                }

                Text("Hold your sensor close. Discovered Bluetooth accessories appear below.")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textSecondary)

                if model.universalBle.discoveredDevices.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Theme.ember)
                        Text("Searching for nearby Bluetooth sensors…")
                            .font(Theme.label(12))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(model.universalBle.discoveredDevices) { found in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(found.name)
                                            .font(Theme.headline(14, .bold))
                                            .foregroundStyle(Theme.textPrimary)
                                        Text("\(found.category.rawValue) · Signal: \(found.rssi) dBm")
                                            .font(Theme.body(11))
                                            .foregroundStyle(Theme.textMuted)
                                    }
                                    Spacer()
                                    Button("PAIR") {
                                        Haptics.heavy()
                                        model.universalBle.connect(id: found.id)
                                        statusToast = "Paired \(found.name)"
                                        selectedDeviceForPairing = nil
                                    }
                                    .font(Theme.label(11, .bold))
                                    .foregroundStyle(Theme.emberSoft)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.surfaceRaised)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                                }
                                .padding(12)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .presentationDetents([.medium])
    }
}

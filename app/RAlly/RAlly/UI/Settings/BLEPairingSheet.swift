import SwiftUI

struct BLEPairingSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Atmosphere(intensity: 0.5)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    PosterText(text: "Heart rate", size: 30)
                    Spacer()
                    Button("Close") { dismiss() }
                        .font(Theme.label(15, .bold))
                        .foregroundStyle(Theme.emberSoft)
                        .frame(minHeight: 44)
                }
                if model.bleDevices.isEmpty {
                    Text("Hold your strap close. Compatible belts show up here.")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(model.bleDevices, id: \.id) { d in
                                Button {
                                    model.ble.connect(id: d.id)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "heart.fill")
                                            .foregroundStyle(Theme.ember)
                                        Text(d.name)
                                            .font(Theme.body(16, .semibold))
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(Theme.textMuted)
                                    }
                                    .padding(16)
                                    .background(Theme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Theme.hairline, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(22)
        }
        .presentationDetents([.medium, .large])
        .onAppear { model.ble.startScan() }
    }
}

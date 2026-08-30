import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case run = "run"
    case activity = "activity"
    case corner = "corner"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .run: return "RUN"
        case .activity: return "ACTIVITY"
        case .corner: return "CORNER"
        }
    }

    var icon: String {
        switch self {
        case .run: return "figure.run"
        case .activity: return "chart.bar.xaxis"
        case .corner: return "person.crop.circle"
        }
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var bindableModel = model
        ZStack(alignment: .bottom) {
            Group {
                switch model.selectedTab {
                case .run:
                    HomeView()
                case .activity:
                    ActivityView()
                case .corner:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom R·ALLY Bottom Tab Bar
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    Haptics.selection()
                    model.selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: model.selectedTab == tab ? .black : .semibold))
                            .foregroundColor(model.selectedTab == tab ? Theme.accent : Theme.secondaryText.opacity(0.65))
                        
                        Text(tab.title)
                            .font(Theme.font(size: 9.5, weight: model.selectedTab == tab ? .black : .bold))
                            .tracking(1.0)
                            .foregroundColor(model.selectedTab == tab ? Theme.accent : Theme.secondaryText.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(
            ZStack {
                Theme.surface.opacity(0.94)
                VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark)
            }
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 12, y: 6)
        )
        .padding(.horizontal, 32)
        .padding(.bottom, 6)
    }
}

// SwiftUI Blur Helper
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

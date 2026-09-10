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
    @Namespace private var tabGlassNamespace

    var body: some View {
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

            customTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    private var customTabBar: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    tabBarContent
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
            } else {
                tabBarContent
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
        .shadow(color: Theme.emberDeep.opacity(0.22), radius: 16, y: 8)
    }

    private var tabBarContent: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                let on = model.selectedTab == tab
                Button {
                    Haptics.selection()
                    withAnimation(Theme.spring) { model.selectedTab = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: on ? .black : .semibold))
                        Text(tab.title)
                            .font(Theme.font(size: 9.5, weight: on ? .black : .bold))
                            .tracking(1.0)
                    }
                    .foregroundStyle(on ? Theme.emberSoft : Theme.secondaryText.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                    .background {
                        if on {
                            Capsule()
                                .fill(Theme.ember.opacity(0.18))
                                .overlay(Capsule().stroke(Theme.emberDeep.opacity(0.35), lineWidth: 1))
                        }
                    }
                }
                .buttonStyle(.plain)
                .modifier(TabGlassIDModifier(id: tab.id, namespace: tabGlassNamespace, enabled: on))
            }
        }
    }
}

private struct TabGlassIDModifier: ViewModifier {
    var id: String
    var namespace: Namespace.ID
    var enabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), enabled {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}

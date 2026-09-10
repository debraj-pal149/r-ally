import SwiftUI
import SwiftData

@main
struct RAllyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(model.appearanceMode.preferredColorScheme)
                .tint(Theme.ember)
                // Forces SwiftUI trait refresh when switching System/Light/Dark.
                .id(model.appearanceMode)
                .onAppear {
                    AppearanceMode.applyToWindows(model.appearanceMode)
                }
        }
        .modelContainer(for: [WorkoutSessionRecord.self, RallyMomentRecord.self])
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            switch model.route {
            case .onboarding:
                FirstRunFlow()
            case .home:
                MainTabView()
            case .live:
                LiveWorkoutView()
            case .summary(let rec):
                SummaryView(record: rec, liveRallies: model.liveRallies)
            case .history:
                HistoryView()
            case .settings:
                SettingsView()
            }
        }
        .preferredColorScheme(model.appearanceMode.preferredColorScheme)
        .tint(Theme.ember)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: model.appearanceMode) { _, mode in
            AppearanceMode.applyToWindows(mode)
        }
    }
}

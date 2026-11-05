import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct RAllyApp: App {
    @State private var model = AppModel()

    init() {
        AuthService.shared.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(model.appearanceMode.preferredColorScheme)
                .tint(Theme.ember)
                .onAppear {
                    AppearanceMode.applyToWindows(model.appearanceMode)
                    RallyAnalytics.start()
                    RallyAnalytics.sync(
                        persona: model.persona.id.rawValue,
                        runnerLevel: model.runnerLevel.rawValue,
                        hasWeight: model.bodyWeightKg != nil,
                        stravaConnected: model.strava.isConnected
                    )
                }
                .onChange(of: model.appearanceMode) { _, mode in
                    AppearanceMode.applyToWindows(mode)
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(for: [WorkoutSessionRecord.self, RallyMomentRecord.self])
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext

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
        .onAppear {
            AccountController.shared.configure(modelContext: modelContext, appModel: model)
        }
        .onChange(of: model.appearanceMode) { _, mode in
            AppearanceMode.applyToWindows(mode)
        }
    }
}

import SwiftUI
import SwiftData

@main
struct RAllyApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.ember)
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
                HomeView()
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
        .tint(Theme.ember)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \WorkoutSessionRecord.startedAt, order: .reverse) private var sessions: [WorkoutSessionRecord]

    var body: some View {
        ZStack {
            Atmosphere(intensity: 0.5)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    PosterText(text: "The sessions", size: 42)
                    if sessions.isEmpty {
                        Text("Nothing in the book yet. Finish a session and it lands here.")
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 24)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(sessions) { s in
                                Button {
                                    Haptics.tap()
                                    model.route = .summary(s)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(s.activity.title.uppercased())
                                                .font(Theme.headline(17, .bold))
                                            Text(s.startedAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(Theme.body(13))
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        Spacer()
                                        Text("\(s.rallyCount)")
                                            .font(Theme.numeric(24, .bold))
                                            .foregroundStyle(Theme.ember)
                                        Text("RALLIES")
                                            .font(Theme.label(10, .semibold))
                                            .tracking(1)
                                            .foregroundStyle(Theme.textMuted)
                                    }
                                    .padding(16)
                                    .background(Theme.surface.opacity(0.88))
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Theme.hairline, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.textPrimary)
                                .accessibilityLabel("\(s.activity.title), \(s.rallyCount) rallies, \(s.startedAt.formatted(date: .abbreviated, time: .shortened))")
                            }
                        }
                    }
                }
                .padding(22)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton(title: "Home") { model.route = .home }
            }
        }
    }
}

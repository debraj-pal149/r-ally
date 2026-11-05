import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Share button that renders a branded story image and hands it to the system share sheet.
struct CoachShareControls: View {
    var record: WorkoutSessionRecord
    var report: CoachFieldReport
    var persona: Persona

    @State private var shareImage: UIImage?
    @State private var isRendering = false
    @State private var sharePayload: SharePayload?
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                Haptics.tap()
                Task { await prepareAndShare() }
            } label: {
                HStack(spacing: 6) {
                    if isRendering {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(isRendering ? "PREPARING CARD…" : "SHARE STORY CARD")
                        .font(Theme.label(11, .bold))
                        .tracking(0.8)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .rallyGlassCapsule(.regular)
            }
            .buttonStyle(.plain)
            .disabled(isRendering)

            if let errorText {
                Text(errorText)
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(items: payload.items)
        }
    }

    @MainActor
    private func prepareAndShare() async {
        isRendering = true
        errorText = nil
        defer { isRendering = false }
        let theme = ShareStoryTheme.forRun(startedAt: record.startedAt) == .receiptDay ? "day" : "night"
        if let image = await ShareStoryRenderer.renderImage(record: record, report: report, persona: persona) {
            shareImage = image
            sharePayload = SharePayload(items: [image])
            RallyAnalytics.shareCardReady(theme: theme, format: "image")
        } else {
            // Text fallback so share still works if ImageRenderer fails.
            let text = """
            R·ALLY COACH DEBRIEF · \(persona.name.uppercased())

            \(report.headline)

            \(report.debrief)

            "\(report.coachQuote)"

            Distance: \(Formatters.km(record.distanceM)) | Time: \(Formatters.clock(record.durationSec)) | Grade: \(report.athleteGrade)
            """
            errorText = "Image render failed — sharing text instead."
            sharePayload = SharePayload(items: [text])
            RallyAnalytics.shareCardReady(theme: theme, format: "text")
        }
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

#if os(iOS)
private struct ActivityShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

import SwiftUI
import MapKit
import CoreLocation

#if canImport(UIKit)
import UIKit
#endif

enum ShareStoryTheme {
    case receiptDay
    case bloodlineNight

    static func forRun(startedAt: Date, calendar: Calendar = .current) -> Self {
        let hour = calendar.component(.hour, from: startedAt)
        return (6..<18).contains(hour) ? .receiptDay : .bloodlineNight
    }
}

/// Fixed 9:16 story card for WhatsApp / Instagram / Messages image share.
struct ShareStoryCard: View {
    var record: WorkoutSessionRecord
    var report: CoachFieldReport
    var persona: Persona
    var mapImage: UIImage?

    private let width: CGFloat = 1080
    private let height: CGFloat = 1920
    private let blood = Color(red: 0.78, green: 0.06, blue: 0.18)
    private let hotBlood = Color(red: 0.94, green: 0.21, blue: 0.33)
    private let ink = Color(red: 0.055, green: 0.043, blue: 0.047)
    private let receipt = Color(red: 0.94, green: 0.91, blue: 0.86)

    private var storyTheme: ShareStoryTheme {
        .forRun(startedAt: record.startedAt)
    }

    private var paceText: String {
        guard record.distanceM > 0 else { return "-" }
        return Formatters.pace(record.durationSec / (record.distanceM / 1000))
    }

    private var caloriesText: String {
        record.activeEnergyKcal > 0 ? "\(Int(record.activeEnergyKcal.rounded()))" : "—"
    }

    var body: some View {
        Group {
            switch storyTheme {
            case .receiptDay:
                receiptCard
            case .bloodlineNight:
                bloodlineCard
            }
        }
        .frame(width: width, height: height)
        .clipped()
    }

    private var bloodlineCard: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.12, green: 0.025, blue: 0.045)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .stroke(blood.opacity(0.72), lineWidth: 170)
                .frame(width: 850, height: 850)
                .offset(x: 570, y: -650)

            VStack(alignment: .leading, spacing: 0) {
                storyHeader
                routeBlock(dark: true, height: 650).padding(.top, 42)
                distanceHero(color: .white).padding(.top, 30)
                metricsRow(dark: true).padding(.top, 30)
                coachDebrief(dark: true).padding(.top, 35)
                Spacer(minLength: 18)
                storyFooter(dark: true)
            }
            .padding(.horizontal, 72)
            .padding(.top, 78)
            .padding(.bottom, 62)
        }
    }

    private var receiptCard: some View {
        ZStack {
            receipt
            VStack(alignment: .leading, spacing: 0) {
                receiptHeader
                Rectangle().fill(ink).frame(height: 6).padding(.top, 36)
                distanceHero(color: blood).padding(.top, 35)
                HStack {
                    Text("KM / \(record.activity.title.uppercased())")
                    Spacer()
                    Text(record.startedAt.formatted(date: .abbreviated, time: .omitted).uppercased())
                }
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .tracking(3)
                metricsRow(dark: false).padding(.top, 32)
                routeBlock(dark: false, height: 470).padding(.top, 32)
                coachDebrief(dark: false).padding(.top, 32)
                barcode.frame(height: 60).padding(.top, 26)
                Spacer(minLength: 12)
                storyFooter(dark: false)
            }
            .padding(.horizontal, 72)
            .padding(.top, 75)
            .padding(.bottom, 58)
            .foregroundStyle(ink)
        }
    }

    private var storyHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 11) {
                Text("R·ALLY")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .tracking(7)
                Text("RUN REPORT · \(record.startedAt.formatted(date: .abbreviated, time: .shortened).uppercased())")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(hotBlood)
            }
            Spacer()
            Text(report.athleteGrade)
                .font(.system(size: 47, weight: .black, design: .rounded))
                .frame(width: 108, height: 108)
                .overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 3))
        }
        .foregroundStyle(.white)
    }

    private var receiptHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 11) {
                Text("R·ALLY")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .tracking(7)
                Text("PROOF OF WORK · \(record.activity.title.uppercased())")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .tracking(3)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("EARNED").font(.system(size: 17, weight: .black, design: .rounded))
                Text(report.athleteGrade).font(.system(size: 38, weight: .black, design: .rounded))
            }
            .foregroundStyle(blood)
            .padding(.horizontal, 25)
            .padding(.vertical, 17)
            .overlay(Rectangle().stroke(blood, lineWidth: 5))
            .rotationEffect(.degrees(4))
        }
    }

    private func distanceHero(color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Formatters.km(record.distanceM))
                .font(.system(size: 190, weight: .black, design: .rounded))
                .tracking(-12)
                .foregroundStyle(color)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
            Text("KILOMETRES · ACTIVE PERFORMANCE")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .tracking(5)
                .foregroundStyle(color == .white ? hotBlood : ink)
        }
    }

    private func metricsRow(dark: Bool) -> some View {
        HStack(alignment: .top, spacing: 18) {
            storyMetric(Formatters.km(record.distanceM), "DISTANCE / KM", dark: dark)
            storyMetric(Formatters.clock(record.durationSec), "ACTIVE TIME", dark: dark)
            storyMetric(paceText, "AVG PACE / KM", dark: dark)
            storyMetric(caloriesText, "CALORIES / KCAL", dark: dark)
        }
        .padding(.vertical, 25)
        .overlay(alignment: .top) {
            Rectangle().fill(dark ? Color.white.opacity(0.18) : ink.opacity(0.7)).frame(height: 2)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(dark ? Color.white.opacity(0.18) : ink.opacity(0.7)).frame(height: 2)
        }
    }

    private func storyMetric(_ value: String, _ label: String, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value.uppercased())
                .font(.system(size: 40, weight: .black, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(dark ? Color.white.opacity(0.48) : ink.opacity(0.58))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func coachDebrief(dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("\(persona.name.uppercased())’S RUN SUMMARY")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(blood)
            Text(report.headline.uppercased())
                .font(.system(size: 37, weight: .black, design: .rounded))
                .tracking(-1)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text(report.debrief)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .lineSpacing(5)
                .foregroundStyle(dark ? Color.white.opacity(0.72) : ink.opacity(0.72))
                .lineLimit(3)
                .minimumScaleFactor(0.84)
            HStack(alignment: .top, spacing: 14) {
                Rectangle().fill(blood).frame(width: 7)
                Text("“\(report.coachQuote)”")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .italic()
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
            }
        }
        .foregroundStyle(dark ? Color.white : ink)
    }

    @ViewBuilder
    private func routeBlock(dark: Bool, height: CGFloat) -> some View {
        ZStack {
            dark ? Color.white.opacity(0.045) : ink.opacity(0.07)
            if let mapImage {
                Image(uiImage: mapImage)
                    .resizable()
                    .scaledToFill()
                    .contrast(dark ? 1.18 : 1.05)
            } else {
                VStack(spacing: 18) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 82, weight: .bold))
                    Text("ROUTE LOCKED IN")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .tracking(4)
                }
                .foregroundStyle(dark ? hotBlood : blood)
            }
        }
        .frame(height: height)
        .clipped()
        .overlay(Rectangle().stroke(dark ? Color.white.opacity(0.15) : ink.opacity(0.18), lineWidth: 2))
    }

    private func storyFooter(dark: Bool) -> some View {
        HStack {
            Text("COACHED BY \(persona.name.uppercased())")
            Spacer()
            Text("RUN WITH R·ALLY · RALLY.RUN ↗")
        }
        .font(.system(size: 15, weight: .black, design: .rounded))
        .tracking(2.2)
        .foregroundStyle(dark ? Color.white.opacity(0.46) : ink.opacity(0.62))
    }

    private var barcode: some View {
        let bars: [CGFloat] = [3, 7, 2, 4, 9, 3, 6, 2, 8, 4, 3, 7, 2, 5, 9, 2, 6, 4, 8, 3, 2, 7, 5, 3, 9, 4, 2, 6, 8, 3, 5, 2, 9, 4]
        return HStack(spacing: 7) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, width in
                Rectangle().fill(ink).frame(width: width)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

enum ShareStoryRenderer {
    @MainActor
    static func renderImage(
        record: WorkoutSessionRecord,
        report: CoachFieldReport,
        persona: Persona
    ) async -> UIImage? {
        let storyTheme = ShareStoryTheme.forRun(startedAt: record.startedAt)
        let map = await snapshotMap(
            coordinates: record.routeCoordinates,
            size: CGSize(width: 936, height: 650),
            theme: storyTheme
        )
        let view = ShareStoryCard(record: record, report: report, persona: persona, mapImage: map)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        #if os(iOS)
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        #endif
        return renderer.uiImage
    }

    private static func snapshotMap(
        coordinates: [GPSBreadcrumb],
        size: CGSize,
        theme: ShareStoryTheme
    ) async -> UIImage? {
        guard coordinates.count >= 2 else { return nil }
        let coords = coordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        var rect = MKMapRect.null
        for coordinate in coords {
            let point = MKMapPoint(coordinate)
            rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }
        rect = rect.insetBy(dx: -rect.size.width * 0.18, dy: -rect.size.height * 0.18)

        let options = MKMapSnapshotter.Options()
        options.mapRect = rect
        options.size = size
        options.showsBuildings = false
        #if os(iOS)
        let style: UIUserInterfaceStyle = theme == .receiptDay ? .light : .dark
        options.traitCollection = UITraitCollection(userInterfaceStyle: style)
        #endif

        let snapshotter = MKMapSnapshotter(options: options)
        do {
            let snapshot = try await snapshotter.start()
            return drawRoute(on: snapshot, coordinates: coords)
        } catch {
            return nil
        }
    }

    private static func drawRoute(on snapshot: MKMapSnapshotter.Snapshot, coordinates: [CLLocationCoordinate2D]) -> UIImage {
        let image = snapshot.image
        #if os(iOS)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)
            guard coordinates.count >= 2 else { return }
            let path = UIBezierPath()
            path.lineWidth = 9
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: snapshot.point(for: coordinates[0]))
            for c in coordinates.dropFirst() {
                path.addLine(to: snapshot.point(for: c))
            }
            UIColor(red: 0.78, green: 0.06, blue: 0.18, alpha: 1).setStroke()
            path.stroke()

            let start = snapshot.point(for: coordinates[0])
            let finish = snapshot.point(for: coordinates[coordinates.count - 1])
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: start.x - 8, y: start.y - 8, width: 16, height: 16)).fill()
            UIColor(red: 0.78, green: 0.06, blue: 0.18, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: finish.x - 10, y: finish.y - 10, width: 20, height: 20)).fill()
        }
        #else
        return image
        #endif
    }
}

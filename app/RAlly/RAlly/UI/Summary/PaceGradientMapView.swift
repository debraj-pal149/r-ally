import SwiftUI
import MapKit

struct PaceGradientMapView: View {
    let coordinates: [GPSBreadcrumb]

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if coordinates.count >= 2 {
                Map(position: $position) {
                    // Draw continuous segments with gradient coloring based on speed/pace
                    ForEach(segmentPairs, id: \.id) { seg in
                        MapPolyline(coordinates: [seg.start, seg.end])
                            .stroke(seg.color, lineWidth: 5)
                    }

                    // Start Pin
                    if let first = coordinates.first {
                        Annotation("START", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 3)
                        }
                    }

                    // Finish Pin
                    if let last = coordinates.last {
                        Annotation("FINISH", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude)) {
                            Image(systemName: "flag.checkered.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.white, Color.red)
                                .shadow(radius: 3)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                .mapControlVisibility(.hidden)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
            } else {
                // Fallback placeholder when no GPS breadcrumbs were recorded (e.g. indoor / stationary run)
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Theme.cardBorder, lineWidth: 1)
                        )
                    VStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.secondaryText)
                        Text("Indoor or Treadmill Session")
                            .font(Theme.font(size: 13, weight: .bold))
                            .foregroundColor(Theme.secondaryText)
                        Text("No external GPS breadcrumbs recorded")
                            .font(Theme.font(size: 11, weight: .regular))
                            .foregroundColor(Theme.secondaryText.opacity(0.7))
                    }
                    .padding()
                }
                .frame(height: 180)
            }
        }
        .onAppear {
            setupCamera()
        }
    }

    private func setupCamera() {
        guard !coordinates.isEmpty else { return }
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.005, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.005, (maxLon - minLon) * 1.4)
        )
        position = .region(MKCoordinateRegion(center: center, span: span))
    }

    private struct RouteSegment: Identifiable {
        var id: String
        var start: CLLocationCoordinate2D
        var end: CLLocationCoordinate2D
        var color: Color
    }

    private var segmentPairs: [RouteSegment] {
        guard coordinates.count >= 2 else { return [] }
        let avgSpeed = coordinates.map(\.speedMps).reduce(0, +) / Double(coordinates.count)
        var segments: [RouteSegment] = []

        for i in 0..<(coordinates.count - 1) {
            let p1 = coordinates[i]
            let p2 = coordinates[i + 1]
            let segSpeed = (p1.speedMps + p2.speedMps) / 2.0

            let segColor: Color
            if segSpeed >= avgSpeed * 1.15 {
                segColor = Color.green // Fast / Surge
            } else if segSpeed <= avgSpeed * 0.85 {
                segColor = Color.red   // Hill grind / Slow
            } else {
                segColor = Color.yellow // Cruising pace
            }

            segments.append(RouteSegment(
                id: "\(i)",
                start: CLLocationCoordinate2D(latitude: p1.latitude, longitude: p1.longitude),
                end: CLLocationCoordinate2D(latitude: p2.latitude, longitude: p2.longitude),
                color: segColor
            ))
        }
        return segments
    }
}

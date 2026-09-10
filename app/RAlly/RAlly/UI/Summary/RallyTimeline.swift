import SwiftUI

struct RallyTimeline: View {
    var spark: [Double]
    var rallies: [RallyMomentRecord]
    @Binding var selected: RallyMomentRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Rally moments")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Path { p in
                        guard spark.count > 1 else { return }
                        let maxV = max(spark.max() ?? 1, 0.01)
                        for (i, v) in spark.enumerated() {
                            let x = geo.size.width * CGFloat(i) / CGFloat(spark.count - 1)
                            let y = geo.size.height * (1 - CGFloat(v / maxV))
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(
                        LinearGradient(colors: [Theme.textMuted, Theme.emberSoft], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    let lastT = max(rallies.map(\.t).max() ?? 1, 1)
                    ForEach(rallies) { r in
                        Circle()
                            .fill(Theme.ember)
                            .frame(width: 11, height: 11)
                            .shadow(color: Theme.ember.opacity(0.7), radius: 6)
                            .offset(x: geo.size.width * CGFloat(r.t / lastT) - 5.5)
                            .onTapGesture { selected = r }
                    }
                }
            }
            .frame(height: 88)
            .padding(16)
            .rallyGlass(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

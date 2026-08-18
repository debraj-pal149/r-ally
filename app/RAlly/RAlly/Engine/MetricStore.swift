import Foundation

struct EngineChannels: Sendable {
    var output: Double
    var hr: Double?
    var rhythm: Double
    var plannedRest: Bool
    var snapshot: String
}

struct StoreSnapshot: Sendable {
    var t: TimeInterval
    var latest: [MetricKind: Double]
    var baseOut: Double
    var shortOut: Double
    var slope30Out: Double
    var cv20Rhythm: Double
    var baseCv: Double
    var slope30HR: Double?
    var peakHR: Double
    var secondsHard: Double
}

/// 1 Hz store. Driven by sample timestamps (`t`), never wall clock.
final class MetricStore: @unchecked Sendable {
    private struct Sample {
        var t: TimeInterval
        var x: Double
    }

    private var channels: [MetricKind: [Sample]] = [:]
    private var lastValues: [MetricKind: Double] = [:]
    private var lastTick: TimeInterval = -1
    private var baseOut = 0.0
    private var baseCv = 0.05
    private var initializedBase = false
    private var peakHR = 0.0
    private var secondsHard = 0.0
    private var outputHistory: [(t: TimeInterval, x: Double)] = []
    var maxHR: Double = 190

    func reset(maxHR: Double = 190) {
        channels.removeAll()
        lastValues.removeAll()
        lastTick = -1
        baseOut = 0
        baseCv = 0.05
        initializedBase = false
        peakHR = 0
        secondsHard = 0
        outputHistory.removeAll()
        self.maxHR = maxHR
    }

    func ingest(_ sample: MetricSample) {
        lastValues[sample.kind] = sample.value
        var arr = channels[sample.kind] ?? []
        arr.append(Sample(t: sample.timestamp, x: sample.value))
        if arr.count > 2400 { arr.removeFirst(arr.count - 2400) }
        channels[sample.kind] = arr
        if sample.kind == .heartRateBpm {
            peakHR = max(peakHR, sample.value)
        }
    }

    func latest(_ kind: MetricKind) -> Double? { lastValues[kind] }

    func sparkline(maxPoints: Int = 120) -> [Double] {
        let pts = outputHistory.map(\.x)
        if pts.count <= maxPoints { return pts }
        let step = Double(pts.count) / Double(maxPoints)
        return (0..<maxPoints).map { pts[Int(Double($0) * step)] }
    }

    func value(kind: MetricKind, around t: TimeInterval, plus: TimeInterval) -> Double? {
        guard let arr = channels[kind] else { return nil }
        let target = t + plus
        return arr.min(by: { abs($0.t - target) < abs($1.t - target) })?.x
    }

    /// Advance the 1 Hz grid to integer second `t` (floor).
    func tick(t: TimeInterval, channelsIn: EngineChannels) -> StoreSnapshot {
        let tt = floor(t)
        outputHistory.append((tt, channelsIn.output))
        if outputHistory.count > 2400 { outputHistory.removeFirst(outputHistory.count - 2400) }

        if !initializedBase {
            baseOut = max(channelsIn.output, EngineConstants.epsilon)
            initializedBase = true
        } else {
            let a = EngineConstants.ewmaAlpha
            baseOut = a * channelsIn.output + (1 - a) * baseOut
        }

        let shortOut = sma(of: outputHistory.map(\.x), window: EngineConstants.shortWindow)
        let slope30Out = slope(of: outputHistory, window: EngineConstants.slopeWindow)

        var rhythmHist: [Double] = []
        if let arr = channels[rhythmKindGuess()] {
            rhythmHist = arr.suffix(EngineConstants.cvWindow + 5).map(\.x)
        }
        // Prefer adapter rhythm via a synthetic channel we keep:
        rhythmBuffer.append(channelsIn.rhythm)
        if rhythmBuffer.count > 400 { rhythmBuffer.removeFirst(rhythmBuffer.count - 400) }
        let cv = coefficientOfVariation(Array(rhythmBuffer.suffix(EngineConstants.cvWindow)))
        let a = EngineConstants.ewmaAlpha
        baseCv = a * cv + (1 - a) * baseCv

        var slopeHR: Double?
        if let hr = channelsIn.hr {
            hrBuffer.append((tt, hr))
            if hrBuffer.count > 400 { hrBuffer.removeFirst(hrBuffer.count - 400) }
            slopeHR = slope(of: hrBuffer, window: EngineConstants.slopeWindow)
            peakHR = max(peakHR, hr)
        }

        let hard: Bool = {
            if let hr = channelsIn.hr, hr > EngineConstants.hardHRFraction * maxHR { return true }
            return channelsIn.output > EngineConstants.hardOutputFraction * max(baseOut, EngineConstants.epsilon)
        }()
        if hard { secondsHard += max(tt - lastTick, 1) } else { secondsHard = max(0, secondsHard - 1) }
        lastTick = tt

        return StoreSnapshot(
            t: tt,
            latest: lastValues,
            baseOut: baseOut,
            shortOut: shortOut,
            slope30Out: slope30Out,
            cv20Rhythm: cv,
            baseCv: baseCv,
            slope30HR: slopeHR,
            peakHR: peakHR,
            secondsHard: secondsHard
        )
    }

    private var rhythmBuffer: [Double] = []
    private var hrBuffer: [(t: TimeInterval, x: Double)] = []

    private func rhythmKindGuess() -> MetricKind { .cadenceSpm }

    private func sma(of xs: [Double], window: Int) -> Double {
        let slice = xs.suffix(window)
        guard !slice.isEmpty else { return xs.last ?? 0 }
        return slice.reduce(0, +) / Double(slice.count)
    }

    private func slope(of pts: [(t: TimeInterval, x: Double)], window: Int) -> Double {
        let slice = Array(pts.suffix(window))
        guard slice.count >= 3 else { return 0 }
        let n = Double(slice.count)
        let meanT = slice.map(\.t).reduce(0, +) / n
        let meanX = slice.map(\.x).reduce(0, +) / n
        var num = 0.0, den = 0.0
        for p in slice {
            num += (p.t - meanT) * (p.x - meanX)
            den += (p.t - meanT) * (p.t - meanT)
        }
        guard den > EngineConstants.epsilon else { return 0 }
        return num / den
    }

    private func coefficientOfVariation(_ xs: [Double]) -> Double {
        guard xs.count >= 3 else { return 0 }
        let mean = xs.reduce(0, +) / Double(xs.count)
        guard mean > EngineConstants.epsilon else { return 0 }
        let var_ = xs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(xs.count)
        return sqrt(var_) / mean
    }
}

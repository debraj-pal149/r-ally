import Foundation

struct LineContext: Sendable {
    var activity: ActivityKind
    var elapsed: TimeInterval
    var distanceM: Double
    var goal: WorkoutGoal
    var snapshot: String
    var prompt: String?
    var name: String
    var intensityMaximum: Bool
    var recent: [String]
    var persona: Persona
    var progressLabel: String
    var runnerLevel: RunnerLevel = .intermediate
    var paceSlopeDescription: String = "steady"
    var milestoneState: MilestoneState? = nil
    var closedLoopFeedback: String? = nil
    var distanceUnit: DistanceUnit = .kilometre
    var athleteHistoryLines: [String] = []
    var historyCue: String? = nil
}

@MainActor
final class LineCache {
    private var lines: PepLines?
    private var generatedAt: TimeInterval = -1
    private var generatedDistance: Double = 0
    private var persona: Persona.ID?
    private var inflight = false
    /// If a pop wanted a refill while prefetch was in flight, run it next.
    private var pendingRefill: (ctx: LineContext, justSpoken: String?)? = nil
    private let client: AnthropicClient
    var llmOffline = false

    init(client: AnthropicClient) {
        self.client = client
        llmOffline = !client.isConfigured
    }

    func maybePrefetch(ctx: LineContext, risk: Double) {
        guard client.isConfigured else { return }
        if risk < 20, ctx.elapsed < EngineConstants.warmupSec + 30 { return }
        if inflight { return }
        if let p = persona, p == ctx.persona.id, lines != nil {
            if ctx.elapsed - generatedAt < 240,
               abs(ctx.distanceM - generatedDistance) < 500 {
                return
            }
        }
        startGenerate(ctx: ctx, justSpoken: nil)
    }

    func pop(kind: TriggerKind, ctx: LineContext) -> (text: String, sourceLLM: Bool) {
        let priors = rejectionPriors(for: ctx)
        if let lines {
            let arr = array(for: kind, in: lines)
            if let pick = arr.first(where: { !PhraseFingerprint.isTooSimilar($0, to: priors) }) {
                self.lines = mutate(lines, kind: kind, dropping: pick)
                let normalized = DistanceUnitNormalizer.normalize(pick, to: ctx.distanceUnit)
                requestRefill(ctx: ctx, justSpoken: normalized)
                return (normalized, true)
            }
            // Cache exhausted of fresh lines. Drop stale batch and refill with full avoid context.
            self.lines = nil
            requestRefill(ctx: ctx, justSpoken: nil)
        }
        return (FallbackLines.line(kind: kind, ctx: ctx), false)
    }

    private func array(for kind: TriggerKind, in lines: PepLines) -> [String] {
        switch kind {
        case .preQuitFade: lines.pre_quit_fade
        case .paceSlip: lines.pace_slip ?? lines.pre_quit_fade
        case .keepGoing: lines.keep_going ?? lines.grind_support
        case .stopped: lines.stopped
        case .stillStopped: lines.still_stopped ?? lines.stopped
        case .recovery: lines.recovery ?? lines.grind_support
        case .grindSupport, .finalPush, .milestone: lines.grind_support
        }
    }

    private func rejectionPriors(for ctx: LineContext) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for line in ctx.recent + LifetimePromptMemory.shared.rejectionPriors {
            let key = line.lowercased()
            if seen.insert(key).inserted { out.append(line) }
        }
        return out
    }

    private func mutate(_ pep: PepLines, kind: TriggerKind, dropping: String) -> PepLines {
        var p = pep
        switch kind {
        case .preQuitFade: p.pre_quit_fade.removeAll { $0 == dropping }
        case .paceSlip:
            var s = p.pace_slip ?? []
            s.removeAll { $0 == dropping }
            p.pace_slip = s
        case .keepGoing:
            var s = p.keep_going ?? []
            s.removeAll { $0 == dropping }
            p.keep_going = s
        case .stopped: p.stopped.removeAll { $0 == dropping }
        case .stillStopped:
            var s = p.still_stopped ?? []
            s.removeAll { $0 == dropping }
            p.still_stopped = s
        case .recovery:
            var r = p.recovery ?? []
            r.removeAll { $0 == dropping }
            p.recovery = r
        case .grindSupport, .finalPush, .milestone: p.grind_support.removeAll { $0 == dropping }
        }
        return p
    }

    private func requestRefill(ctx: LineContext, justSpoken: String?) {
        if inflight {
            // Prefer the refill that knows what was just spoken.
            if pendingRefill == nil || justSpoken != nil {
                pendingRefill = (ctx, justSpoken)
            }
            return
        }
        startGenerate(ctx: ctx, justSpoken: justSpoken)
    }

    private func startGenerate(ctx: LineContext, justSpoken: String?) {
        guard client.isConfigured else { return }
        inflight = true
        var extra: [String] = []
        if let justSpoken { extra.append(justSpoken) }
        let promptCtx = makePromptContext(from: ctx, extraRecent: extra)
        let sys = PromptBuilder.system(
            persona: ctx.persona,
            runnerLevel: ctx.runnerLevel,
            distanceUnit: ctx.distanceUnit
        )
        let user = PromptBuilder.user(promptCtx)
        Task {
            defer {
                self.inflight = false
                if let pending = self.pendingRefill {
                    self.pendingRefill = nil
                    self.startGenerate(ctx: pending.ctx, justSpoken: pending.justSpoken)
                }
            }
            do {
                let pep = try await client.generate(system: sys, user: user)
                self.lines = pep
                self.generatedAt = ctx.elapsed
                self.generatedDistance = ctx.distanceM
                self.persona = ctx.persona.id
                self.llmOffline = false
            } catch {
                self.llmOffline = true
            }
        }
    }

    private func makePromptContext(from ctx: LineContext, extraRecent: [String]) -> PromptBuilder.Context {
        let memory = LifetimePromptMemory.shared
        var recent = extraRecent + ctx.recent
        // Dedupe while preserving order
        var seen = Set<String>()
        recent = recent.filter { seen.insert($0.lowercased()).inserted }
        return PromptBuilder.Context(
            activity: ctx.activity,
            elapsed: ctx.elapsed,
            progressLabel: ctx.progressLabel,
            snapshot: ctx.snapshot,
            prompt: ctx.prompt,
            athleteName: ctx.name,
            intensityMaximum: ctx.intensityMaximum,
            recent: recent,
            persona: ctx.persona,
            runnerLevel: ctx.runnerLevel,
            paceSlopeDescription: ctx.paceSlopeDescription,
            milestoneState: ctx.milestoneState,
            closedLoopFeedback: ctx.closedLoopFeedback,
            burnedPhrasesBlacklist: memory.dynamicBlacklist,
            distanceUnit: ctx.distanceUnit,
            athleteHistoryLines: ctx.athleteHistoryLines,
            historyCue: ctx.historyCue,
            avoidMotifs: memory.leanMotifBlacklist
        )
    }
}

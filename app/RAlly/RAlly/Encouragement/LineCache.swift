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
}

@MainActor
final class LineCache {
    private var lines: PepLines?
    private var generatedAt: TimeInterval = -1
    private var generatedDistance: Double = 0
    private var persona: Persona.ID?
    private var inflight = false
    private let client: AnthropicClient
    var llmOffline = false

    init(client: AnthropicClient) {
        self.client = client
        llmOffline = !client.isConfigured
    }

    func maybePrefetch(ctx: LineContext, risk: Double) {
        guard client.isConfigured else { return }
        if risk < 35 { return }
        if inflight { return }
        if let p = persona, p == ctx.persona.id, lines != nil {
            if ctx.elapsed - generatedAt < 240,
               abs(ctx.distanceM - generatedDistance) < 500 {
                return
            }
        }
        inflight = true
        let sys = PromptBuilder.system(persona: ctx.persona)
        let user = PromptBuilder.user(.init(
            activity: ctx.activity,
            elapsed: ctx.elapsed,
            progressLabel: ctx.progressLabel,
            snapshot: ctx.snapshot,
            prompt: ctx.prompt,
            athleteName: ctx.name,
            intensityMaximum: ctx.intensityMaximum,
            recent: ctx.recent,
            persona: ctx.persona
        ))
        Task {
            defer { inflight = false }
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

    func pop(kind: TriggerKind, ctx: LineContext) -> (text: String, sourceLLM: Bool) {
        if let lines {
            let arr: [String] = {
                switch kind {
                case .preQuitFade: lines.pre_quit_fade
                case .stopped: lines.stopped
                case .grindSupport: lines.grind_support
                case .finalPush: lines.grind_support
                }
            }()
            if let first = arr.first(where: { !ctx.recent.contains($0) }) ?? arr.first {
                self.lines = mutate(lines, kind: kind, dropping: first)
                Task { refill(ctx: ctx) }
                return (first, true)
            }
        }
        return (FallbackLines.line(kind: kind, ctx: ctx), false)
    }

    private func mutate(_ pep: PepLines, kind: TriggerKind, dropping: String) -> PepLines {
        var p = pep
        switch kind {
        case .preQuitFade: p.pre_quit_fade.removeAll { $0 == dropping }
        case .stopped: p.stopped.removeAll { $0 == dropping }
        case .grindSupport, .finalPush: p.grind_support.removeAll { $0 == dropping }
        }
        return p
    }

    private func refill(ctx: LineContext) {
        guard client.isConfigured else { return }
        inflight = true
        let sys = PromptBuilder.system(persona: ctx.persona)
        let user = PromptBuilder.user(.init(
            activity: ctx.activity, elapsed: ctx.elapsed, progressLabel: ctx.progressLabel,
            snapshot: ctx.snapshot, prompt: ctx.prompt, athleteName: ctx.name,
            intensityMaximum: ctx.intensityMaximum, recent: ctx.recent, persona: ctx.persona
        ))
        Task {
            defer { inflight = false }
            if let pep = try? await client.generate(system: sys, user: user) {
                self.lines = pep
                self.generatedAt = ctx.elapsed
                self.generatedDistance = ctx.distanceM
            }
        }
    }
}

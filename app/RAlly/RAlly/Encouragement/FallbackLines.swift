import Foundation

enum FallbackLines {
    static func line(kind: TriggerKind, ctx: LineContext) -> String {
        let bank = all(persona: ctx.persona.id, kind: kind)
        let idx = abs(Int(ctx.elapsed) + ctx.recent.count) % bank.count
        return slot(bank[idx], ctx: ctx)
    }

    static func all(persona: Persona.ID, kind: TriggerKind) -> [String] {
        let cores = core(persona, kind)
        let tails = tail(persona)
        var out: [String] = []
        for c in cores {
            for t in tails {
                let line = t.isEmpty ? c : "\(c) \(t)"
                if wordCount(line) <= 12 { out.append(line) }
            }
        }
        var i = 0
        while out.count < 40 {
            out.append(cores[i % cores.count])
            i += 1
        }
        return out
    }

    static func preview(persona: Persona) -> String {
        switch persona.id {
        case .southpaw: "Kid, this is your round. Stay in it."
        case .machine: "The pain is the point. Keep going."
        case .preacher: "You decided. Now rise to it."
        case .sarge: "On your feet. We are not done."
        case .steady: "Breathe. One more step. That's all."
        }
    }

    private static func slot(_ raw: String, ctx: LineContext) -> String {
        var s = raw
        s = s.replacingOccurrences(of: "{name}", with: ctx.name.isEmpty ? "champ" : ctx.name)
        let leftKm = remainingKm(ctx)
        s = s.replacingOccurrences(of: "{left}", with: leftKm)
        return s
    }

    private static func remainingKm(_ ctx: LineContext) -> String {
        if case .distance(let m) = ctx.goal {
            let left = max(0, m - ctx.distanceM) / 1000
            if left < 0.2 { return "the last stretch" }
            return String(format: "%.1f K", left)
        }
        return "this"
    }

    private static func wordCount(_ s: String) -> Int {
        s.split { $0.isWhitespace || $0.isNewline }.count
    }

    private static func tail(_ p: Persona.ID) -> [String] {
        switch p {
        case .southpaw: ["", "Kid.", "Champ.", "Now."]
        case .machine: ["", "Yes.", "Come on.", "Good."]
        case .preacher: ["", "Now.", "Rise.", "Believe."]
        case .sarge: ["", "Move.", "Now.", "Go."]
        case .steady: ["", "Breathe.", "Easy.", "Here."]
        }
    }

    private static func core(_ p: Persona.ID, _ k: TriggerKind) -> [String] {
        switch (p, k) {
        case (.southpaw, .preQuitFade):
            ["Don't you quit on me", "This is the round that counts", "Get up kid stay in it", "The hill ain't got nothing", "You came here to fight", "Legs are lying you keep going", "One more minute champ", "Heart over heavy legs", "We don't stop here", "Show me that fire"]
        case (.southpaw, .stopped):
            ["Get back in there kid", "On your feet champ", "Don't park it here", "Shake it off and go", "Clock is still running", "Walk it in then run", "Come on get moving", "This ain't the finish", "Back to work kid", "Stand up and go"]
        case (.southpaw, .grindSupport):
            ["That's the stuff kid", "You're eating this up", "Beautiful ugly work", "Stay mean stay moving", "This is your movie", "Hold that line champ", "You look like a fighter", "Keep punching the road", "Yes that's it", "Don't give this away"]
        case (.southpaw, .finalPush):
            ["Bring it home champ", "Last stretch kid go", "This is your bell", "Take the house now", "Finish like you mean it", "Go get that line", "One more burst", "Leave it all here", "You can see it", "Run through the tape"]
        case (.machine, .preQuitFade):
            ["Pain is just weakness leaving", "You are a machine keep rolling", "Do not negotiate with tired", "Stronger than this moment", "Smile at the burn", "I love this pain for you", "No room for maybe", "Push because you can", "The body follows the mind", "Keep the engine loud"]
        case (.machine, .stopped):
            ["Machines do not park", "Back on the throttle", "Start the engine again", "Up up we go", "Rest is later not now", "Move those mountains", "Come come keep pumping", "I said go", "No sitting on greatness", "Restart now"]
        case (.machine, .grindSupport):
            ["This is magnificent pain", "You are crushing it", "Look at this power", "Hold and dominate", "Beautiful suffering yes", "You were built for this", "Keep feeding the fire", "Unstoppable today", "Yes more of that", "Stay monstrous"]
        case (.machine, .finalPush):
            ["Finish like a champion", "Last meters belong to you", "Now you win this", "Take it all home", "Empty the tank now", "Victory is a choice", "Go claim it", "Final surge now", "No leftovers", "End it strong"]
        case (.preacher, .preQuitFade):
            ["You decided who you are", "Greatness is calling keep walking", "Do not bury this moment", "Your future is watching", "Stand in your power", "You are bigger than tired", "Speak life into these legs", "Destiny does not jog back", "Rise because you chose this", "Hold the vision"]
        case (.preacher, .stopped):
            ["Get up you are not done", "Walk back into your promise", "The story continues now", "On your feet and believe", "Do not sit on the calling", "Start again with purpose", "Move toward the person you want", "This pause is not the end", "Step forward now", "Return to the work"]
        case (.preacher, .grindSupport):
            ["This is the becoming", "You are writing character", "Stay faithful to the work", "Look at your courage", "Keep the covenant with yourself", "You are already winning", "Honor the decision", "This grind is glory", "Hold your head high", "Yes live this fully"]
        case (.preacher, .finalPush):
            ["Finish the promise", "Walk into the victory", "This is your harvest", "Close it with greatness", "The last stretch is holy", "Go claim your name", "Complete what you started", "Now become it", "See it through", "Arrive"]
        case (.sarge, .preQuitFade):
            ["Drop the pity keep moving", "I did not hear quit", "Straighten up drive on", "Pain is information only", "Lock in and push", "We do not break here", "Faster not softer", "Eyes up drive the legs", "Stay on my count", "That fade is unauthorized"]
        case (.sarge, .stopped):
            ["On your feet now", "I said move", "Back on the line", "This is not a rest", "Get going soldier", "Pick it up immediately", "No freeze on my watch", "Walk then run now", "Recover in motion", "Up and drive"]
        case (.sarge, .grindSupport):
            ["That's the standard", "Hold this pace", "Good keep earning it", "Quiet mouth loud legs", "Stay in the hurt", "This is acceptable work", "Don't you dare ease", "Keep that form", "Yes that's discipline", "Drive drive drive"]
        case (.sarge, .finalPush):
            ["Sprint the last bit", "Finish the objective", "No coasting to the line", "Empty it now", "Last push authorized", "Take the hill", "Close it clean", "Go now go", "Finish strong", "Mission almost complete"]
        case (.steady, .preQuitFade):
            ["Soft breath long spine", "One more honest step", "Stay with this stride", "Nothing to prove just continue", "Return to the breath", "Gentle and relentless", "You can do the next minute", "Ease the jaw keep going", "This wave will pass", "Find the quiet power"]
        case (.steady, .stopped):
            ["Begin again without drama", "Stand and walk it in", "Soft start then flow", "Come back to motion", "No judgment just go", "A small step is enough", "Breathe and restart", "The path is still here", "Lift and continue", "Gently back in"]
        case (.steady, .grindSupport):
            ["Steady as the tide", "You are right on time", "Hold this calm fire", "Beautiful even effort", "Stay kind and strong", "This is enough keep it", "Anchored and moving", "Quiet courage yes", "Let the rhythm carry you", "Remain"]
        case (.steady, .finalPush):
            ["Float it home", "Last minutes with grace", "Finish as you began", "Open the stride slightly", "Arrive whole", "Let it flow to the end", "You are nearly there", "Complete this kindly", "One calm surge", "Home"]
        }
    }
}

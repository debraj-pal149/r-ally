import Foundation

enum FallbackLines {
    @MainActor
    static func line(kind: TriggerKind, ctx: LineContext) -> String {
        let bank = all(persona: ctx.persona.id, kind: kind)
        let priors = ctx.recent + LifetimePromptMemory.shared.rejectionPriors
        let start = abs(Int(ctx.elapsed) + ctx.recent.count) % max(bank.count, 1)
        // Walk the bank from a rotating start; skip near-dupes of already-spoken lines.
        for offset in 0..<bank.count {
            let idx = (start + offset) % bank.count
            let slotted = slot(bank[idx], ctx: ctx)
            let normalized = DistanceUnitNormalizer.normalize(slotted, to: ctx.distanceUnit)
            if !PhraseFingerprint.isTooSimilar(normalized, to: priors) {
                return normalized
            }
        }
        let slotted = slot(bank[start], ctx: ctx)
        return DistanceUnitNormalizer.normalize(slotted, to: ctx.distanceUnit)
    }

    static func all(persona: Persona.ID, kind: TriggerKind) -> [String] {
        let cores = core(persona, kind)
        let tails = tail(persona)
        let maxWords = maxWords(for: kind)
        var out: [String] = []
        for c in cores {
            for t in tails {
                let line = t.isEmpty ? c : "\(c) \(t)"
                if wordCount(line) <= maxWords { out.append(line) }
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
        case .southpaw: "Kid, this is your round. Stay with me and keep those legs honest."
        case .machine: "The pain is the point. Keep the engine rolling and do not negotiate."
        case .preacher: "You decided who you are. Now rise into that decision and keep going."
        case .sarge: "On your feet. We are not done. Drive those legs and move now."
        case .steady: "Breathe. One more honest step. That is all you need right now."
        }
    }

    private static func maxWords(for kind: TriggerKind) -> Int {
        switch kind {
        case .stopped: 14
        case .stillStopped, .paceSlip: 24
        case .keepGoing: 28
        case .preQuitFade: 32
        case .recovery, .grindSupport, .finalPush, .milestone: 24
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
        case (.southpaw, .stopped):
            [
                "Get back in there kid now",
                "On your feet champ let's go",
                "Don't park it here keep moving",
                "Shake it off and start running",
                "Come on get moving right now",
                "Back to work kid pick it up",
            ]
        case (.southpaw, .stillStopped):
            [
                "Still here kid. You cannot rest on this road while the fight is unfinished",
                "I'm still with you champ. Stand up, find a soft start, and go again",
                "Brother you cannot park it here. One step then another until the legs wake",
                "Don't leave me hanging. Rest is later, motion is now, get moving",
            ]
        case (.southpaw, .keepGoing):
            [
                "That's it kid. You are doing the honest work, stay mean and keep rolling forward",
                "Beautiful ugly kilometres champ. Hold this rhythm and eat the road like you mean it",
                "This is your movie kid. Stay with the scene and keep those legs honest",
                "You're looking strong out here. Keep that fire and do not negotiate with comfort",
            ]
        case (.southpaw, .paceSlip):
            [
                "Pace is slipping kid. Reel it back in and find the earlier stride now",
                "Don't fade on me. Push those legs and reclaim the tempo you had",
                "I see the dip champ. Speed up, stay mean, and take your pace back",
            ]
        case (.southpaw, .preQuitFade):
            [
                "Don't you quit on me now kid. This is the round that counts and your heart is still louder than your legs",
                "The doubt is talking but it is lying. Get up inside the stride and stay in this fight",
                "One more minute champ that is all. Heart over heavy legs, show me that fire again",
            ]
        case (.southpaw, .recovery):
            [
                "There it is kid. That's the stuff, you picked it back up, now hold it",
                "Yes champ. You came back, keep that pace and stay in the fight",
            ]
        case (.southpaw, .grindSupport):
            [
                "That's the stuff kid. Keep eating this effort and stay mean through it",
                "Beautiful ugly work. Hold the line and keep moving through the burn",
            ]
        case (.southpaw, .finalPush):
            [
                "Bring it home champ. Last stretch, leave it all out here now",
                "This is your bell. Take the house and finish like you mean every step",
            ]

        case (.machine, .stopped):
            [
                "Machines do not park. Restart now",
                "Back on the throttle right now",
                "Rest is later not now. Move",
                "Start the engine again and go",
            ]
        case (.machine, .stillStopped):
            [
                "Still stopped. You cannot rest while the engine is supposed to be loud",
                "I said go. Get moving again and keep pumping until the road answers",
                "No sitting on greatness. Restart now and reclaim the throttle",
            ]
        case (.machine, .keepGoing):
            [
                "Clean power. Keep the engine loud and do not negotiate with the burn",
                "You are rolling perfectly. Stay locked in and keep crushing meters like this",
                "Magnificent pace. Hold this line and smile at the work",
            ]
        case (.machine, .paceSlip):
            [
                "Output dropping. Correct it now and push the throttle back up",
                "Pace slip. Do not accept slower, reclaim the speed you had",
            ]
        case (.machine, .preQuitFade):
            [
                "Pain is just weakness leaving. You are stronger than this moment so keep rolling",
                "Do not negotiate with tired legs. Smile at the burn and push through it now",
            ]
        case (.machine, .recovery):
            [
                "Yes. The engine is back, keep it loud and stay unstoppable",
            ]
        case (.machine, .grindSupport):
            [
                "This is magnificent pain. Hold it and keep the power coming",
            ]
        case (.machine, .finalPush):
            [
                "Finish like a champion. Empty the tank and take the last meters",
            ]

        case (.preacher, .stopped):
            [
                "Get up. You are not done yet",
                "Walk back into your promise now",
                "On your feet and believe again",
            ]
        case (.preacher, .stillStopped):
            [
                "This pause is not the chapter. Rise, return to the work, and move with purpose",
                "You cannot rest in this story. Begin again, your calling is waiting on the road",
            ]
        case (.preacher, .keepGoing):
            [
                "You are becoming. Stay faithful to this stride and keep walking forward with courage",
                "Beautiful courage. Hold your head high and continue writing this kilometre with purpose",
            ]
        case (.preacher, .paceSlip):
            [
                "Your pace is softening. Rise into it with purpose and reclaim your stride now",
                "Do not shrink. Speed up, honor your word, and lift the tempo again",
            ]
        case (.preacher, .preQuitFade):
            [
                "You decided who you are. Greatness is calling, so do not bury this moment, rise and keep going",
                "Your future is watching. Stand in your power and continue walking into who you chose to be",
            ]
        case (.preacher, .recovery):
            [
                "Yes. That is the becoming, you returned, stay faithful and keep going",
            ]
        case (.preacher, .grindSupport):
            [
                "This is the becoming. Stay faithful and hold your head high through it",
            ]
        case (.preacher, .finalPush):
            [
                "Finish the promise you made. Walk into the victory and complete what you started",
            ]

        case (.sarge, .stopped):
            [
                "On your feet now. Move",
                "I said move. Get going",
                "This is not a rest period",
                "Pick it up immediately",
            ]
        case (.sarge, .stillStopped):
            [
                "Still frozen. That is unauthorized, recover in motion, up and drive",
                "You cannot rest soldier. Get moving, I am waiting on the line",
            ]
        case (.sarge, .keepGoing):
            [
                "Good pace. Hold the standard, quiet mouth, strong legs, keep driving",
                "That is solid. You are earning meters, stay on this line and continue",
            ]
        case (.sarge, .paceSlip):
            [
                "Pace dropping. Correct it now, override the slip, and drive those legs",
                "I see the slip. Do not accept slower, pick the pace back up",
            ]
        case (.sarge, .preQuitFade):
            [
                "Drop the pity and keep moving. Pain is information only, lock in and push through this",
                "I did not hear quit. Straighten up, drive those legs, and push through this moment",
            ]
        case (.sarge, .recovery):
            [
                "That's the standard. You earned that restart, hold this pace and keep driving",
            ]
        case (.sarge, .grindSupport):
            [
                "That's the standard. Hold this pace, quiet mouth, earn every meter",
            ]
        case (.sarge, .finalPush):
            [
                "Sprint the last bit. Finish the objective clean and empty it now",
            ]

        case (.steady, .stopped):
            [
                "Begin again without drama",
                "Come back to motion kindly",
                "A small step is enough now",
            ]
        case (.steady, .stillStopped):
            [
                "Still here. Rest can wait, lift gently and begin again on the path",
                "Standing still is not the work. Breathe, then move, the path is waiting",
            ]
        case (.steady, .keepGoing):
            [
                "You are right on time. Beautiful even effort, stay with this calm fire",
                "Steady as the tide. Quiet courage, continue like this and remain in motion",
            ]
        case (.steady, .paceSlip):
            [
                "Your pace softened. Lift it gently and return to your earlier tempo",
                "Don't drift slower. Reclaim the stride with an easy honest push",
            ]
        case (.steady, .preQuitFade):
            [
                "Soft breath, long spine. One more honest step is enough, stay with this stride gently",
                "Nothing to prove. You can do the next minute, continue with calm strength",
            ]
        case (.steady, .recovery):
            [
                "There you are. Steady as the tide, beautiful even effort, stay with it",
            ]
        case (.steady, .grindSupport):
            [
                "Steady as the tide. You are right on time, hold this calm fire",
            ]
        case (.steady, .finalPush):
            [
                "Float it home with grace. Last minutes with calm strength, arrive whole",
            ]
        case (_, .milestone):
            [
                "You're in the pocket now. Keep this exact tempo and drive through the mark.",
                "Target is in sight. Stay tall, breathe deep, and finish the job.",
                "Hold this rhythm. You are making this look easy, keep rolling forward.",
            ]
        }
    }
}

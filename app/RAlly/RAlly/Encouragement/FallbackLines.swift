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
        case .recovery, .grindSupport, .finalPush: 24
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
                "Still here kid — you cannot rest on this road while the fight is unfinished",
                "I'm still with you champ — stand up, find a soft start, and go again",
                "Brother you cannot park it here — one step then another until the legs wake",
                "Don't leave me hanging — rest is later, motion is now, get moving",
            ]
        case (.southpaw, .keepGoing):
            [
                "That's it kid — you are doing the honest work, stay mean and keep rolling forward",
                "Beautiful ugly miles champ — hold this rhythm and eat the road like you mean it",
                "This is your movie kid — stay with the scene and keep those legs honest",
                "You're looking strong out here — keep that fire and do not negotiate with comfort",
            ]
        case (.southpaw, .paceSlip):
            [
                "Pace is slipping kid — reel it back in and find the earlier stride now",
                "Don't fade on me — push those legs and reclaim the tempo you had",
                "I see the dip champ — speed up, stay mean, and take your pace back",
            ]
        case (.southpaw, .preQuitFade):
            [
                "Don't you quit on me now kid — this is the round that counts and your heart is still louder than your legs",
                "The doubt is talking but it is lying — get up inside the stride and stay in this fight",
                "One more minute champ that is all — heart over heavy legs, show me that fire again",
            ]
        case (.southpaw, .recovery):
            [
                "There it is kid — that's the stuff, you picked it back up, now hold it",
                "Yes champ — you came back, keep that pace and stay in the fight",
            ]
        case (.southpaw, .grindSupport):
            [
                "That's the stuff kid — keep eating this effort and stay mean through it",
                "Beautiful ugly work — hold the line and keep moving through the burn",
            ]
        case (.southpaw, .finalPush):
            [
                "Bring it home champ — last stretch, leave it all out here now",
                "This is your bell — take the house and finish like you mean every step",
            ]

        case (.machine, .stopped):
            [
                "Machines do not park — restart now",
                "Back on the throttle right now",
                "Rest is later not now — move",
                "Start the engine again and go",
            ]
        case (.machine, .stillStopped):
            [
                "Still stopped — you cannot rest while the engine is supposed to be loud",
                "I said go — get moving again and keep pumping until the road answers",
                "No sitting on greatness — restart now and reclaim the throttle",
            ]
        case (.machine, .keepGoing):
            [
                "Clean power — keep the engine loud and do not negotiate with the burn",
                "You are rolling perfectly — stay locked in and keep crushing meters like this",
                "Magnificent pace — hold this line and smile at the work",
            ]
        case (.machine, .paceSlip):
            [
                "Output dropping — correct it now and push the throttle back up",
                "Pace slip — do not accept slower, reclaim the speed you had",
            ]
        case (.machine, .preQuitFade):
            [
                "Pain is just weakness leaving — you are stronger than this moment so keep rolling",
                "Do not negotiate with tired legs — smile at the burn and push through it now",
            ]
        case (.machine, .recovery):
            [
                "Yes — the engine is back, keep it loud and stay unstoppable",
            ]
        case (.machine, .grindSupport):
            [
                "This is magnificent pain — hold it and keep the power coming",
            ]
        case (.machine, .finalPush):
            [
                "Finish like a champion — empty the tank and take the last meters",
            ]

        case (.preacher, .stopped):
            [
                "Get up — you are not done yet",
                "Walk back into your promise now",
                "On your feet and believe again",
            ]
        case (.preacher, .stillStopped):
            [
                "This pause is not the chapter — rise, return to the work, and move with purpose",
                "You cannot rest in this story — begin again, your calling is waiting on the road",
            ]
        case (.preacher, .keepGoing):
            [
                "You are becoming — stay faithful to this stride and keep walking forward with courage",
                "Beautiful courage — hold your head high and continue writing this mile with purpose",
            ]
        case (.preacher, .paceSlip):
            [
                "Your pace is softening — rise into it with purpose and reclaim your stride now",
                "Do not shrink — speed up, honor your word, and lift the tempo again",
            ]
        case (.preacher, .preQuitFade):
            [
                "You decided who you are — greatness is calling, so do not bury this moment, rise and keep going",
                "Your future is watching — stand in your power and continue walking into who you chose to be",
            ]
        case (.preacher, .recovery):
            [
                "Yes — that is the becoming, you returned, stay faithful and keep going",
            ]
        case (.preacher, .grindSupport):
            [
                "This is the becoming — stay faithful and hold your head high through it",
            ]
        case (.preacher, .finalPush):
            [
                "Finish the promise you made — walk into the victory and complete what you started",
            ]

        case (.sarge, .stopped):
            [
                "On your feet now — move",
                "I said move — get going",
                "This is not a rest period",
                "Pick it up immediately",
            ]
        case (.sarge, .stillStopped):
            [
                "Still frozen — that is unauthorized, recover in motion, up and drive",
                "You cannot rest soldier — get moving, I am waiting on the line",
            ]
        case (.sarge, .keepGoing):
            [
                "Good pace — hold the standard, quiet mouth, strong legs, keep driving",
                "That is solid — you are earning meters, stay on this line and continue",
            ]
        case (.sarge, .paceSlip):
            [
                "Pace dropping — correct it now, override the slip, and drive those legs",
                "I see the slip — do not accept slower, pick the pace back up",
            ]
        case (.sarge, .preQuitFade):
            [
                "Drop the pity and keep moving — pain is information only, lock in and push through this",
                "I did not hear quit — straighten up, drive those legs, and push through this moment",
            ]
        case (.sarge, .recovery):
            [
                "That's the standard — you earned that restart, hold this pace and keep driving",
            ]
        case (.sarge, .grindSupport):
            [
                "That's the standard — hold this pace, quiet mouth, earn every meter",
            ]
        case (.sarge, .finalPush):
            [
                "Sprint the last bit — finish the objective clean and empty it now",
            ]

        case (.steady, .stopped):
            [
                "Begin again without drama",
                "Come back to motion kindly",
                "A small step is enough now",
            ]
        case (.steady, .stillStopped):
            [
                "Still here — rest can wait, lift gently and begin again on the path",
                "Standing still is not the work — breathe, then move, the path is waiting",
            ]
        case (.steady, .keepGoing):
            [
                "You are right on time — beautiful even effort, stay with this calm fire",
                "Steady as the tide — quiet courage, continue like this and remain in motion",
            ]
        case (.steady, .paceSlip):
            [
                "Your pace softened — lift it gently and return to your earlier tempo",
                "Don't drift slower — reclaim the stride with an easy honest push",
            ]
        case (.steady, .preQuitFade):
            [
                "Soft breath, long spine — one more honest step is enough, stay with this stride gently",
                "Nothing to prove — you can do the next minute, continue with calm strength",
            ]
        case (.steady, .recovery):
            [
                "There you are — steady as the tide, beautiful even effort, stay with it",
            ]
        case (.steady, .grindSupport):
            [
                "Steady as the tide — you are right on time, hold this calm fire",
            ]
        case (.steady, .finalPush):
            [
                "Float it home with grace — last minutes with calm strength, arrive whole",
            ]
        }
    }
}

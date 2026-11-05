import Foundation

/// Rotating running tip / health tip / joke banks while cruising.
enum EngagementLines {
    enum Bucket: Int, CaseIterable {
        case runningTip
        case joke
        case healthTip
    }

    @MainActor
    static func line(persona: Persona.ID, elapsed: TimeInterval, sequence: Int, recent: [String]) -> String {
        // Weight the rotation toward jokes and health—the two categories runners
        // asked to hear more often—without dropping form coaching entirely.
        // Advance only when a line actually fires so a preempted slot cannot
        // silently skip the next joke or health beat.
        let rotation: [Bucket] = [.joke, .healthTip, .runningTip, .joke, .healthTip]
        let bucket = rotation[sequence % rotation.count]
        let bank = lines(persona: persona, bucket: bucket)
        let priors = recent + LifetimePromptMemory.shared.rejectionPriors
        let start = abs(Int(elapsed) + recent.count) % max(bank.count, 1)
        for offset in 0..<bank.count {
            let idx = (start + offset) % bank.count
            let candidate = bank[idx]
            if !PhraseFingerprint.isTooSimilar(candidate, to: priors) {
                return candidate
            }
        }
        return bank[start]
    }

    /// Static samples for cache priming (no MainActor / memory access).
    static func sampleBank(persona: Persona.ID) -> [String] {
        tips(for: persona).prefix(3).map { $0 }
            + jokes(for: persona).prefix(3).map { $0 }
            + health(for: persona).prefix(3).map { $0 }
    }

    private static func lines(persona: Persona.ID, bucket: Bucket) -> [String] {
        switch bucket {
        case .runningTip: return tips(for: persona)
        case .joke: return jokes(for: persona)
        case .healthTip: return health(for: persona)
        }
    }

    private static func tips(for p: Persona.ID) -> [String] {
        switch p {
        case .sarge, .major:
            [
                "Quick form check. Soft knees, tall spine, quiet shoulders. Hold that.",
                "Breathe in for three steps, out for two. Rhythm beats panic.",
                "Cadence up a notch. Shorter steps, quicker feet, same effort.",
                "Eyes ahead, not at your shoes. Drive from the hips and stay tall.",
                "Land under your center. Don't reach. Pull the road under you.",
            ]
        case .southpaw, .whip:
            [
                "Stay light on the feet kid. Quick steps, loose hands, quiet jaw.",
                "Breathe like you mean it. Nose in, mouth out, keep the round honest.",
                "Don't slap the ground. Kiss it and roll. Soft landings win late rounds.",
                "Chin up, shoulders down. Looking tough starts with posture.",
                "Shorten the stride a hair and pick up the tempo. Stay mean.",
            ]
        case .machine, .hardline:
            [
                "Optimize cadence. Quicker turnover, same power, less waste.",
                "Upright torso. Arms drive back. Forward is the only vector.",
                "Breathing protocol. Three in, two out. Lock the rhythm.",
                "Footstrike under the mass. No overstride. Efficiency first.",
                "Shoulders down. Jaw soft. Tension is stolen watts.",
            ]
        case .preacher, .steady:
            [
                "Settle tall. Soft knees. Let the breath lead the stride.",
                "Easy arms, quiet hands. The road meets you when you stay calm.",
                "Find a cadence you could hum to. Then stay with it.",
                "Look forward, not down. The path opens when you stand in it.",
                "Light feet, long spine. Effort without thrashing.",
            ]
        }
    }

    private static func jokes(for p: Persona.ID) -> [String] {
        switch p {
        case .sarge, .major:
            [
                "Why did the runner bring a ladder? To reach a new personal best.",
                "My GPS says you're crushing it. My stopwatch says don't get cocky.",
                "Running is free therapy. The sweat is just the co-pay.",
                "You vs. the couch. Spoiler. You're winning this round.",
                "Your comfort zone called in sick. Good. Keep moving.",
                "The hill has requested a ceasefire. Request denied.",
                "If excuses burned calories, we'd be done already.",
                "Your legs filed a grievance. Command rejected.",
                "That pace is classified. Keep it away from the couch.",
                "You paid for the whole road. Use it.",
            ]
        case .southpaw, .whip:
            [
                "Kid, if this were easy they'd call it sitting. Keep swinging.",
                "Your shoes are filing a complaint. Tell them to toughen up.",
                "I told a hill to move. It laughed. So we ran it anyway.",
                "Champ, the only bad run is the one that stayed on the couch.",
                "The road threw a jab. Cute. Keep your feet moving.",
                "Your lungs are being dramatic. They've done this before.",
                "That hill talks big for something that cannot chase you.",
                "Kid, sweat is just your body leaking applause.",
                "Your watch says one more kilometre. I say it has excellent taste.",
                "The couch misses you. Let it learn independence.",
            ]
        case .machine, .hardline:
            [
                "Humor module online. Your pace is the punchline. Keep crushing it.",
                "Error four zero four. Quit not found. Continue sequence.",
                "Calories fear you. That is scientifically hilarious. Keep going.",
                "Motivation.exe is running. Do not close the window.",
                "Complaint detected. Permission denied. Maintain output.",
                "Couch compatibility test failed. Excellent result.",
                "Hill resistance identified. Applying legs.",
                "System alert. You are making this look suspiciously possible.",
                "Sarcasm battery full. Energy battery still operational.",
                "Rest-day software attempted installation. Blocked.",
            ]
        case .preacher, .steady:
            [
                "Even the sidewalk is rooting for you. Quietly. Like sidewalks do.",
                "You are outrunning yesterday. Yesterday is not even dressed yet.",
                "If peace had a pace, you'd be close. Stay with this calm fire.",
                "The finish line called. It said take your time. Lie. Speed up a little.",
                "Your inner critic is out of breath. How peaceful.",
                "The hill is temporary. Your bragging rights are annoyingly permanent.",
                "A gentle reminder. Nobody has ever regretted passing a lamppost.",
                "Your shoes know the route. They're just pretending to need supervision.",
                "The breeze is free air-conditioning. Luxury run.",
                "You left the couch on read. Healthy boundaries.",
            ]
        }
    }

    private static func health(for p: Persona.ID) -> [String] {
        switch p {
        case .sarge, .major:
            [
                "Sip water when you can. Dehydration makes quitters loud.",
                "Sharp pain is a stop signal. Dull burn is work. Know the difference.",
                "Warm muscles move better. You earned this stride. Protect it.",
                "After this, protein and sleep. Recovery is part of the mission.",
                "Hot day protocol. Ease the pace, drink early, and respect the heat.",
                "Cold day protocol. Stay covered until your engine is properly warm.",
                "Headache, chills, or dizziness means stop and cool down. No debate.",
                "Loose shoulders save energy. Tension is not toughness.",
                "Fuel longer runs before you feel empty. Late rescue is bad logistics.",
                "Recovery starts now. Smooth form beats reckless speed.",
            ]
        case .southpaw, .whip:
            [
                "Hydrate when you get a window kid. Dry mouths lose rounds.",
                "If something sharp lights up, we smart-stop. Heroics can wait.",
                "Fuel later. A real meal beats a sugar crash every time.",
                "Sleep is training too. Don't skip the quiet work tonight.",
                "Feeling dizzy or chilled? Stop the round, cool down, and get fluids.",
                "On hot roads, slow the opening pace. Save your best work for later.",
                "A little water early beats a desperate bottle late, kid.",
                "Keep the jaw loose and hands soft. Save that energy for the legs.",
                "Long run today? Carbs are corner support, not a character flaw.",
                "Recovery pace is still training. Smart fighters do not brawl every round.",
            ]
        case .machine, .hardline:
            [
                "Hydration check. Fluids in, output holds. Do not ignore thirst.",
                "Sharp pain equals abort. Muscular burn equals continue.",
                "Post-run protocol. Protein, carbs, sleep. Rebuild the system.",
                "Mobility later. Tight hips steal pace. Stay loose when you can.",
                "Thermal warning. In heat, reduce output and increase fluids.",
                "Dizziness, confusion, or chills. Terminate run and cool down.",
                "Fuel before depletion. Carbohydrates sustain long-duration output.",
                "Relax upper-body tension. Wasted force lowers efficiency.",
                "Easy sessions build the system. Maximum output is not daily protocol.",
                "Recovery input required. Fluids, food, and sleep complete the workout.",
            ]
        case .preacher, .steady:
            [
                "Drink when you need. The body asks quietly before it shouts.",
                "Honor sharp pain with a stop. Honor fatigue with courage.",
                "Eat real food after. Your future self is already grateful.",
                "Rest is sacred too. Finish strong, then recover kindly.",
                "If heat makes you dizzy or chilled, stop and find shade. Listen early.",
                "Drink before thirst becomes a demand. Small sips are enough.",
                "On longer runs, a little carbohydrate can keep the road friendly.",
                "Let the shoulders fall away from the ears. Ease creates endurance.",
                "An easy day is not a lesser day. It is where strength settles in.",
                "Cool down gently after this. Your heart deserves a graceful landing.",
            ]
        }
    }
}

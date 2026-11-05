# R·ALLY — UI REDESIGN BRIEF FOR CLAUDE

**Paste this whole document into Claude together with screenshots of the app.**  
Ask Claude to return a single implementable file: **`UI.md`** — a complete visual/UX redesign spec that another coding agent can apply to the SwiftUI codebase without guessing.

---

## Your job (Claude)

You are redesigning the **visual UI/UX** of R·ALLY, an iOS running motivation app. Screenshots are attached — treat them as ground truth for *what exists today*. This brief is ground truth for *product, vibe, voice, and code map*.

**Deliverable:** one markdown file `UI.md` that includes:

1. Design principles (voice-first, fight-poster, not fitness-dashboard)
2. Unified design tokens (color, type, radius, spacing, motion)
3. Screen-by-screen redesign (layout, hierarchy, copy, motion) for every major surface
4. Component inventory (reuse / rewrite / delete)
5. Exact SwiftUI file paths + symbol names to edit
6. What must NOT change (engine, coaching logic, audio pipeline)
7. A phased implement checklist (P0 → P2)
8. Explicit “anti-slop” rules so the UI does not look like generic AI fitness chrome

Be concrete. Prefer “change X in `HomeView.swift` to Y” over vague “make it nicer.”

---

## 1. Product in one sentence

**R·ALLY is the corner man in your ear** — it watches your live effort, detects the moment you’re about to quit, and shouts a short, personal, persona-voiced pep line so you don’t stop.

Tagline energy: *“The app that shouts at you at the exact moment you want to quit — so you don’t.”*  
CTA: **Let’s Rally.**  
Name meaning: **rally + ally.** Prefer brand mark **R·ALLY** (middot) everywhere in UI.

---

## 2. Vibe & emotional design (CRITICAL)

This is **not** Strava, Nike Run Club, or a wellness tracker. It is closer to:

- A **fight poster** / corner stool / boxing gym
- A **drill sergeant / gravel-voiced coach** in one earbud
- Night run, street light, ember, grit — not pastel, not “mindfulness”

### Feeling words
Dark · urgent · intimate · athletic · commanding · warm-under-the-bark · cinematic · audio-first

### Feeling words to avoid
Corporate fitness · social feed · purple SaaS · cream lifestyle brochure · newspaper/broadsheet density · soft wellness · dashboard clutter · emoji-candy

### Voice is the product
- Phone in pocket. Eyes optional. **Ears mandatory.**
- Music ducks → coach speaks → music returns. UI must support that primacy.
- Live screen is a **status stage**, not a spreadsheet.
- When the coach speaks, the UI should feel like the line is *in your ear* (`SpokenLineOverlay` — “IN YOUR EAR”).

### Brand test
If you remove the word R·ALLY from the first viewport of Home, it should still feel like *this* product — not a generic run app. Brand must be a **hero signal**, not a tiny nav eyebrow.

---

## 3. What the app does (functionality Claude must respect)

### Core loop
1. Pick activity (v1 flagship = **running**), goal distance, **coach persona**, optional prompt chip  
2. **Let’s Rally** → live outdoor tracking (phone GPS + cadence; optional BLE HR)  
3. Quit-risk engine at ~1 Hz detects fade / stop / recovery / pace slip  
4. Claude Haiku (or fallback bank) writes short pep lines  
5. **Cloud TTS** (Fish Audio preferred if key present, else ElevenLabs, else Apple male neural) speaks them  
6. Post-run: story summary, coach field report, map (pace-colored), splits, HR zones, rally timeline, PBs  
7. History lives under **ACTIVITY**; athlete/settings/voices under **CORNER**

### Coaching intelligence (do not redesign away)
- Locale distance units (km vs mile) + pre-TTS rewrite  
- Athlete history card: first-minute opening push; event-gated cues (beyond last stop, longest ever, chasing PB, grind vs last)  
- Anti-repetition fingerprints so phrases don’t recycle mid-run  
- 34 milestones, closed-loop “did they surge after the shout?”  
- Personas: Sarge / The Southpaw / The Beast / The Drill Master / The Gunny  

### Non-goals (do not invent UI for)
- Social feed, followers, leaderboards, accounts, backend  
- Apple Watch app (not yet)  
- Strength / HIIT / boxing / swim as first-class shipped modes  
- Light mode (app is forced dark)

---

## 4. Current navigation & screens

```
RootView (NavigationStack) — preferredColorScheme(.dark)
├── Onboarding (FirstRunFlow) — name → age → persona → permissions
├── MainTabView (custom floating capsule tab bar — NOT system TabView)
│   ├── RUN      → HomeView
│   ├── ACTIVITY → ActivityView → sheet WorkoutDetailView
│   └── CORNER   → SettingsView (athlete, voices, sources, Health, Strava, shout budget)
├── LiveWorkoutView (+ SpokenLineOverlay when a line is speaking)
└── SummaryView (post-run)
```

**Tab labels:** RUN · ACTIVITY · CORNER  
**Icons:** `figure.run` · `chart.bar.xaxis` · `person.crop.circle`

Orphan / debt: `AppRoute.history` → `HistoryView` exists but is not in the tab bar; Settings also exists as a standalone route.

---

## 5. Current design system (code truth)

**File:** `app/RAlly/RAlly/UI/Theme.swift`

| Token | Value |
|------|--------|
| `Theme.bg` | `#07080A` |
| `Theme.surface` | `#12151A` |
| `Theme.surfaceRaised` | `#1A1F26` |
| `Theme.hairline` | white @ 0.07 |
| `Theme.ember` | `#FF5A1F` (primary accent) |
| `Theme.emberSoft` | `#FF8A50` |
| `Theme.emberDeep` | `#C43A12` |
| `Theme.pulse` | `#3EE08A` (holding / healthy) |
| `Theme.warn` | `#F5B942` (fading / slowing) |
| Text | `#F4F1EC` / `#8B938C` / `#5C6370` |
| Radii | card 24 · chip 999 · button 18 (often ignored in views) |
| Motion | `Theme.spring` response 0.38 damping 0.84 |

**Type (SF only today):** compressed heavy display · condensed headlines/labels/numerics · plain body.

**Shared chrome:** `Atmosphere`, `PosterText`, `SectionLabel`, `HairlineCard`, `RallyButtonStyle`, `GhostButtonStyle`, `BackButton`, `GoalStepper`, `ChipWrap`, `Haptics`.

**Problem today:** Home/Live/Corner feel like one “fight poster” system; Activity/analytics feel like a second flatter dashboard. Radii and brand spelling are inconsistent (`R-ALLY` vs `R·ALLY` vs `r-ally`).

---

## 6. Screen inventory (files to redesign)

Base path: `app/RAlly/RAlly/UI/`

| Screen | File(s) | Role today |
|--------|---------|------------|
| Tab shell | `MainTabView.swift` | Floating capsule bottom bar |
| Home / Run | `Home/HomeView.swift` + `ActivityCarousel`, `GoalRow`, `PersonaPicker`, `PromptChips` | Pre-run cockpit |
| Live | `Live/LiveWorkoutView.swift`, `PulseRing`, `MetricTiles`, `SpokenLineOverlay` | In-run stage |
| Activity | `Activity/ActivityView.swift`, `WorkoutDetailView.swift` | History + PBs + analytics entry |
| Summary | `Summary/SummaryView.swift` + map, splits, HR, coach card, rally timeline | Post-run story |
| Corner | `Settings/SettingsView.swift` + device sheets | Profile / voice / integrations |
| Onboarding | `Onboarding/FirstRunFlow.swift` | First-run |
| Theme | `Theme.swift` | Tokens + shared components |
| Orphan | `History/HistoryView.swift` | Unused alternate history |

App routing lives in `AppModel.swift` (`AppRoute`, `startWorkout`, `endWorkout`).

---

## 7. Personas & voice (UI must sell the coach)

| ID | UI name | Tagline energy | Symbol |
|----|---------|----------------|--------|
| `sarge` | Sarge | Barked. Clipped. Zero pity. | `megaphone.fill` |
| `southpaw` | The Southpaw | Gravel and corner grit. | `figure.boxing` |
| `machine` | The Beast | Pain is fuel. | `bolt.fill` |
| `preacher` | The Drill Master | Booming iron command. | `shield.fill` |
| `steady` | The Gunny | Hold the line. | `star.fill` |

Voice audition happens in Corner (`SettingsView`) and optionally on Home persona cards. Cloud voices (Fish / ElevenLabs) are the *sound* of the brand — UI should make **coach identity** feel as important as pace numbers.

---

## 8. What screenshots will show you

Expect screenshots of some or all of:

1. Home (brand, activity, goal, persona, prompts, Let’s Rally, bottom tabs)  
2. Live run (clock, pulse ring, status HOLDING/FADING/PUSH/REST, metrics, mute/pause/end)  
3. Spoken line overlay (“IN YOUR EAR”)  
4. Activity / history list + PBs  
5. Workout detail / analytics (map, splits, HR zones)  
6. Post-run Summary + coach debrief card  
7. Corner / settings / voice picker  
8. Onboarding steps  
9. Tab bar close-ups / CTA vs navbar collisions (known past issue: CTA hiding behind tabs)

Critique the screenshots honestly. Call out hierarchy failures, weak branding, clutter, inconsistent cards, and anything that feels like a generic fitness template.

---

## 9. Known UI debt (must address in UI.md)

1. Brand string inconsistency: `R-ALLY` / `R·ALLY` / `r-ally`  
2. Two visual systems (poster Home vs dashboard Activity)  
3. Radius soup (10–24) ignoring `Theme` tokens  
4. Duplicate Settings entry points; Back button on a tab root  
5. Orphan `HistoryView`  
6. Persona ID vs display-name drift  
7. Magic padding for tab clearance (Home ~150, Activity ~100, Corner ~90)  
8. HR zone / map colors not on Theme palette  
9. Activity “carousel” for a single shipped sport  
10. Forced dark only — redesign within dark  

---

## 10. Hard constraints for the redesign

### Keep
- SwiftUI, iOS 17+, no new third-party UI kits unless essential and justified  
- Dark-only  
- Ember accent family as the emotional core (you may refine hex values, don’t replace with purple/indigo)  
- Custom bottom tabs (can restyle; don’t revert to stock `TabView` without strong reason)  
- Audio-first live experience; overlay for spoken lines  
- Existing feature set (don’t invent social, don’t cut coaching)

### Change freely
- Layout hierarchy, typography scale, spacing, component shapes  
- How brand appears on Home (must be stronger)  
- How persona/voice is presented (must feel premium and audible)  
- Activity/Summary visual language (unify with Home)  
- Microcopy tone (gritty, short, coach-like — not corporate)

### Anti-slop (DO NOT propose)
- Purple-on-white or purple→indigo gradient “AI app” look  
- Warm cream `#F4F1EA` + terracotta + serif lifestyle brochure  
- Broadsheet / dense newspaper columns / hairline-everything zero radius  
- Default Inter/Roboto/system-only blandness without intentional display type  
- Hero clutter: stats strips, promo chips, floating badges on hero media  
- Card-everything; cards only when they aid interaction  
- Emoji as decoration in primary UI  

### Composition rules for marketing/hero surfaces (Home, onboarding)
- First viewport = one composition, not a dashboard  
- Brand hero-level; one headline; one supporting line; one CTA group; one dominant visual idea  
- No detached floating badges on hero  

Live run is exempt from “landing page” rules — it is a **performance instrument** — but it must still feel cinematic and calm, not crowded.

---

## 11. Output format for UI.md (required structure)

```markdown
# R·ALLY UI.md — Implementation Spec

## 0. North star
## 1. Design principles
## 2. Tokens (color, type, space, radius, motion) — before/after table
## 3. Components (Atmosphere, buttons, cards, tabs, overlays, etc.)
## 4. Screen specs
### 4.1 Onboarding
### 4.2 Home (RUN)
### 4.3 Live + SpokenLineOverlay
### 4.4 ACTIVITY + WorkoutDetail
### 4.5 Summary
### 4.6 CORNER (Settings)
### 4.7 Tab bar
## 5. Motion & haptics map
## 6. Copy deck (exact strings where possible)
## 7. File-by-file edit list (path → changes)
## 8. Out of scope / do not touch
## 9. Implementation order (P0 / P1 / P2)
## 10. Acceptance checklist (visual QA)
```

For each screen: wireframe-in-words (top→bottom), typography sizes, spacing, states (empty / loading / live / speaking / ended), and how it supports **voice**.

---

## 12. Success criteria

A runner should open the app and feel: *“This is my corner man.”*  
They should hear the product before they “read” it.  
Home should look like a fight poster, not a settings form.  
Live should look like a bout clock, not Garmin.  
Activity/Summary should feel like the same world as Home — denser data, same blood.  
Corner should make choosing a **voice** feel as important as choosing shoes.

---

## 13. Final instruction to Claude

Study the screenshots + this brief.  
Then write **`UI.md`** as a complete implementation spec for a coding agent.  
Be opinionated. Prefer one strong visual direction over options.  
Call out anything in the screenshots that contradicts this brief.  
Do not invent backend/social features.  
Do not weaken the coach/voice primacy for the sake of more charts on Home.

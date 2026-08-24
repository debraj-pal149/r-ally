# r-ally v2 — sports the v1 engine must not pretend to understand

The shipped product is documented in the root [`README.md`](../../README.md). v1 is running (flagship), cycling, and rowing — continuous locomotor sports with a real fade signature and an earbud. **Do not compile this folder into the app.**

v1 ships **physiological inference**. That engine asks: *is output falling while the body is still working?* That question is real sports science (aerobic decoupling). It is also **the wrong question** for everything parked here.

This folder is not a graveyard. It is the honest second product.

## Two detection philosophies

| Engine | Question | Sports | Accuracy if built honestly |
|---|---|---|---|
| Physiological inference (v1) | Output falling while HR stays high / cadence falling apart | Run, ride + power/HR, erg | ~80–90% with HR |
| Schedule adherence (v2) | Did the next work bout start when the plan said it would? | Strength, HIIT, boxing | ~85%+ because it is mostly a clock |

The original app stretched engine 1 over all seven sports. The simulator then generated data from the same model family the detector assumed, so eval passed. That proved the math was coherent. It did **not** prove a gym detection product.

A missed shout costs nothing. A shout during programmed rest costs the product. Precision over recall, always.

## Strength — rest-creep coach

The quit is not mid-rep. It is on the bench: 90 seconds of rest becomes four minutes becomes Instagram becomes "I'll finish Friday."

**Do not** point a fade detector at a lifter. Rest is the protocol. Output=0 + HR falling is a successful set.

v2 mechanic:

1. Athlete declares the session: e.g. 5×5, ~2:00 rests.
2. Detect a work bout (accelerometer burst, or "I finished the set" tap).
3. Start a rest timer.
4. Shout only when rest exceeds declared rest + a generous grace (default +45s), **and** no work bout has started.
5. Never shout during the declared rest window. Never shout mid-set.

This is a plan-adherence product, not a vitals product. It may end up more useful than running. It is a different app.

## HIIT — late to the next interval

Same shape as strength, denser clock.

1. Declare the protocol (Tabata 20/10 × 8, or custom).
2. Baseline motion intensity from intervals 1–3.
3. Triggers (deterministic):
   - Work interval N should have started 20s ago and motion is still rest-level.
   - Work interval N is happening at <50% of the within-session baseline.
4. Do not infer "fade" from HR during rest intervals.

## Boxing — round clock

Rounds are a declared structure (3:00/1:00 × 6). The tell is not punch-rate physics from a phone in a pocket (that signal is junk). The tell is:

- Round N+1 did not start when the bell should have.
- Motion in round N is half of rounds 1–2.

Rebuild on the round timer. Throw away punch-rate-as-output.

## Swimming — cut

Two independent failures:

1. The phone is not on the body. Detection is a watch problem we do not have.
2. Even with perfect detection, **you cannot deliver a TTS pep line underwater.** The intervention channel *is* the product. It is broken.

Keep the simulator scenario as engine-test coverage. Do not put swimming in the app.

## What is in this folder

- `app/Engine/Adapters/` — the original v1 adapters that treated interval sports as if they were a 5K. Reference only. Do not compile them back into the app as-is.
- `app/ActivityKind+v2.swift` — chips, goals, symbols for the parked sports.
- `fixtures/` — gym/HIIT/swim CSVs used by the old "replay every fixture" test. The live app no longer claims them.
- `simulator/scenarios/` — copies of the lab scenarios. Canonical copies still live in `simulator/scenarios/` marked `"lab": true` so the Node engine can keep testing itself. The dashboard labels them LAB.

## What v2 must not do

- Compile these adapters into the shipped app.
- Fire `pre_quit_fade` because a lifter racked the bar.
- Promise underwater audio.
- Treat GPS cycling speed as watts. (v1 already refuses this.)

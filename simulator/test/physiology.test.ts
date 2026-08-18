import { describe, expect, it } from "vitest";
import { DEFAULT_ATHLETE, initialState, tickPhysiology } from "../src/engine/physiology";
import { mulberry32 } from "../src/engine/rng";
import { loadScenario } from "../src/serverShared";
import { ScenarioLoop } from "../src/engine/loop";

describe("rng determinism", () => {
  it("same seed same sequence", () => {
    const a = mulberry32(42);
    const b = mulberry32(42);
    expect([a(), a(), a()]).toEqual([b(), b(), b()]);
  });
});

describe("physiology", () => {
  it("HR approaches a high target with rise tau", () => {
    const rng = mulberry32(1);
    const state = initialState(DEFAULT_ATHLETE);
    for (let t = 0; t < 180; t++) {
      tickPhysiology(state, {
        t,
        dt: 1,
        effort: 0.9,
        activity: "running",
        athlete: DEFAULT_ATHLETE,
        fading: false,
        rng,
        plannedRest: false,
      });
    }
    const target = DEFAULT_ATHLETE.hrRest + 0.9 * (DEFAULT_ATHLETE.hrMax - DEFAULT_ATHLETE.hrRest);
    expect(state.hr).toBeGreaterThan(DEFAULT_ATHLETE.hrRest + 40);
    expect(Math.abs(state.hr - target)).toBeLessThan(target * 0.25);
  });

  it("identical streams for same seed", () => {
    const s = loadScenario("run-5k-bonk");
    const a = new ScenarioLoop({ scenario: s, seed: 42, timeScale: 1, rescuable: false }).runHeadless();
    const b = new ScenarioLoop({ scenario: s, seed: 42, timeScale: 1, rescuable: false }).runHeadless();
    expect(a.length).toBe(b.length);
    expect(a[100].samples).toEqual(b[100].samples);
  });

  it("fade reduces running speed", () => {
    const s = loadScenario("run-5k-bonk");
    const rows = new ScenarioLoop({ scenario: s, seed: 42, timeScale: 1, rescuable: false }).runHeadless();
    const effort = (t: number) => rows[t].effort;
    expect(effort(760)).toBeLessThan(effort(600) * 0.75);
  });
});

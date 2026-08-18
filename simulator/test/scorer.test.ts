import { describe, expect, it } from "vitest";
import { loadScenario } from "../src/serverShared";
import { scoreRun } from "../src/eval/scorer";

describe("scorer", () => {
  it("counts a well-timed fade trigger as a hit", () => {
    const scenario = loadScenario("run-5k-bonk");
    const report = scoreRun({
      scenario,
      seed: 42,
      rescuedIds: new Set(),
      triggers: [
        {
          v: 1,
          type: "trigger",
          t: 700,
          kind: "pre_quit_fade",
          persona: "southpaw",
          text: "go",
          sourceLLM: false,
          latencyMs: 10,
        },
      ],
    });
    const fade = report.events.find((e) => e.kind === "gradual_fade");
    expect(fade?.detected).toBe(true);
  });

  it("treats distractor-window triggers as weighted FPs", () => {
    const scenario = loadScenario("run-5k-bonk");
    const report = scoreRun({
      scenario,
      seed: 42,
      rescuedIds: new Set(),
      triggers: [
        {
          v: 1,
          type: "trigger",
          t: 482,
          kind: "stopped",
          persona: "southpaw",
          text: "nope",
          sourceLLM: false,
          latencyMs: 10,
        },
      ],
    });
    expect(report.distractorTriggers).toBeGreaterThan(0);
    expect(report.weightedFalsePositives).toBeGreaterThanOrEqual(2);
  });
});

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import type { TriggerKind, TriggerMsg } from "../protocol.js";
import { eventEnd, matchingTriggerKind, type Scenario, type ScenarioEvent } from "../engine/scenario.js";

export interface ScoredEvent {
  id: string;
  kind: ScenarioEvent["kind"];
  atSec: number;
  detected: boolean;
  leadTimeSec: number | null;
  rescued: boolean;
  triggerKind?: TriggerKind;
  distractor: boolean;
}

export interface EvalReport {
  scenarioId: string;
  seed: number;
  durationSec: number;
  events: ScoredEvent[];
  recall: number;
  meanLeadTime: number | null;
  falsePositives: number;
  weightedFalsePositives: number;
  distractorTriggers: number;
  falsePositivesPer10Min: number;
  rescueRate: number;
  verdict: "pass" | "fail";
  generatedAt: string;
}

export interface ScoreInput {
  scenario: Scenario;
  seed: number;
  triggers: TriggerMsg[];
  rescuedIds: Set<string>;
  adHoc?: { id: string; kind: string; atSec: number }[];
}

function isDistractor(e: ScenarioEvent): boolean {
  return e.kind === "pause_resume" || e.kind === "interval_rest";
}

function inWindow(e: ScenarioEvent, triggerT: number): boolean {
  if (e.kind === "sudden_stop") {
    const grace = 8;
    return triggerT >= e.atSec + grace && triggerT <= e.atSec + 30;
  }
  return triggerT >= e.atSec - 10 && triggerT <= e.atSec + 45;
}

export function scoreRun(input: ScoreInput): EvalReport {
  const { scenario, triggers } = input;
  const scored: ScoredEvent[] = [];
  const used = new Set<number>();

  scenario.events.forEach((e, idx) => {
    const id = e.id ?? `${e.kind}-${idx}-${e.atSec}`;
    const distractor = isDistractor(e);
    if (distractor) {
      scored.push({
        id,
        kind: e.kind,
        atSec: e.atSec,
        detected: false,
        leadTimeSec: null,
        rescued: false,
        distractor: true,
      });
      return;
    }
    const wanted = matchingTriggerKind(e.kind);
    if (wanted.length === 0) {
      scored.push({
        id,
        kind: e.kind,
        atSec: e.atSec,
        detected: false,
        leadTimeSec: null,
        rescued: input.rescuedIds.has(id),
        distractor: false,
      });
      return;
    }
    let matchIdx = -1;
    let lead: number | null = null;
    for (let i = 0; i < triggers.length; i++) {
      if (used.has(i)) continue;
      const tr = triggers[i];
      if (!inWindow(e, tr.t)) continue;
      if (!wanted.includes(tr.kind)) continue;
      matchIdx = i;
      lead = e.atSec - tr.t;
      break;
    }
    if (matchIdx >= 0) used.add(matchIdx);
    scored.push({
      id,
      kind: e.kind,
      atSec: e.atSec,
      detected: matchIdx >= 0,
      leadTimeSec: lead,
      rescued: input.rescuedIds.has(id),
      triggerKind: matchIdx >= 0 ? triggers[matchIdx].kind : undefined,
      distractor: false,
    });
  });

  const targets = scored.filter((s) => !s.distractor && matchingTriggerKind(s.kind).length);
  const recall =
    targets.length === 0 ? 1 : targets.filter((s) => s.detected).length / targets.length;
  const leads = targets.filter((s) => s.leadTimeSec != null).map((s) => s.leadTimeSec as number);
  const meanLeadTime = leads.length ? leads.reduce((a, b) => a + b, 0) / leads.length : null;

  let falsePositives = 0;
  let weighted = 0;
  let distractorTriggers = 0;
  for (let i = 0; i < triggers.length; i++) {
    if (used.has(i)) continue;
    const tr = triggers[i];
    falsePositives += 1;
    const onDistractor = scenario.events.some(
      (e) => isDistractor(e) && tr.t >= e.atSec && tr.t <= eventEnd(e),
    );
    const onCooldown = scenario.segments.some(
      (seg) => /cool/i.test(seg.label) && tr.t > (scenario.segments[scenario.segments.indexOf(seg) - 1]?.untilSec ?? 0) && tr.t <= seg.untilSec,
    );
    if (onDistractor || onCooldown) {
      weighted += 2;
      distractorTriggers += 1;
    } else {
      weighted += 1;
    }
  }

  const rescuable = scenario.events.filter((e) => e.rescuable);
  const rescuedCount = [...input.rescuedIds].length;
  const rescueRate = rescuable.length === 0 ? 1 : rescuedCount / rescuable.length;
  const per10 = (weighted / Math.max(scenario.durationSec, 1)) * 600;

  const verdict: "pass" | "fail" =
    recall >= 0.85 && distractorTriggers === 0 && weighted <= Math.ceil(scenario.durationSec / 1800)
      ? "pass"
      : "fail";

  return {
    scenarioId: scenario.id,
    seed: input.seed,
    durationSec: scenario.durationSec,
    events: scored,
    recall,
    meanLeadTime,
    falsePositives,
    weightedFalsePositives: weighted,
    distractorTriggers,
    falsePositivesPer10Min: per10,
    rescueRate,
    verdict,
    generatedAt: new Date().toISOString(),
  };
}

export function writeReport(report: EvalReport, dir: string): string {
  mkdirSync(dir, { recursive: true });
  const path = join(dir, `${report.scenarioId}-${Date.now()}.json`);
  writeFileSync(path, JSON.stringify(report, null, 2));
  return path;
}

export { dirname };

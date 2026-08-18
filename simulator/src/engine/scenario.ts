import { z } from "zod";
import type { ActivityKind, EventKind } from "../protocol.js";
import type { Athlete } from "./physiology.js";
import { DEFAULT_ATHLETE, clamp } from "./physiology.js";

export const SegmentSchema = z.object({
  untilSec: z.number(),
  effort: z.number().min(0).max(1),
  label: z.string(),
});

export const EventSchema = z.object({
  atSec: z.number(),
  kind: z.enum([
    "gradual_fade",
    "sudden_stop",
    "pause_resume",
    "grind",
    "interval_rest",
  ]),
  rampSec: z.number().optional(),
  effortFloor: z.number().optional(),
  holdSec: z.number().optional(),
  rescuable: z.boolean().optional(),
  rescueWindowSec: z.number().optional(),
  recoverySec: z.number().optional(),
  id: z.string().optional(),
  label: z.string().optional(),
});

export const SetSchema = z.object({
  reps: z.number(),
  restSec: z.number(),
  load: z.number(),
});

export const ScenarioSchema = z.object({
  id: z.string(),
  name: z.string(),
  activity: z.enum([
    "running",
    "cycling",
    "strength",
    "boxing",
    "swimming",
    "rowing",
    "hiit",
  ]),
  athlete: z
    .object({
      age: z.number().optional(),
      hrRest: z.number().optional(),
      hrMax: z.number().optional(),
      thresholdPaceSecPerKm: z.number().optional(),
      ftpWatts: z.number().optional(),
      weightKg: z.number().optional(),
    })
    .optional(),
  durationSec: z.number(),
  segments: z.array(SegmentSchema).min(1),
  events: z.array(EventSchema).default([]),
  sets: z.array(SetSchema).optional(),
  boxing: z
    .object({ workSec: z.number(), restSec: z.number(), count: z.number() })
    .optional(),
  hiit: z
    .object({ workSec: z.number(), restSec: z.number(), count: z.number() })
    .optional(),
  goal: z
    .object({
      distanceM: z.number().optional(),
      durationSec: z.number().optional(),
    })
    .optional(),
});

export type Scenario = z.infer<typeof ScenarioSchema>;
export type ScenarioEvent = z.infer<typeof EventSchema>;
export type Segment = z.infer<typeof SegmentSchema>;

export function parseScenario(raw: unknown): Scenario {
  return ScenarioSchema.parse(raw);
}

export function resolveAthlete(s: Scenario): Athlete {
  return { ...DEFAULT_ATHLETE, ...(s.athlete ?? {}) };
}

export interface ActiveEvent {
  event: ScenarioEvent;
  id: string;
  rescued: boolean;
  rescueUntil: number;
  recoveryUntil: number;
  startedAt: number;
}

export function eventId(e: ScenarioEvent, idx: number): string {
  return e.id ?? `${e.kind}-${idx}-${e.atSec}`;
}

export function segmentAt(s: Scenario, t: number): Segment {
  for (const seg of s.segments) {
    if (t <= seg.untilSec) return seg;
  }
  return s.segments[s.segments.length - 1];
}

export function isCooldownSegment(seg: Segment): boolean {
  return /cool/i.test(seg.label);
}

/**
 * Resolve commanded effort at time t given segments, events, rescue, puppeteer.
 */
export function resolveEffort(opts: {
  scenario: Scenario;
  t: number;
  active: ActiveEvent | null;
  puppeteerEffort: number | null;
  rescuableEnabled: boolean;
}): { effort: number; fading: boolean; plannedRest: boolean; segment: Segment } {
  const { scenario, t, active, puppeteerEffort } = opts;
  const segment = segmentAt(scenario, t);
  let effort = segment.effort;
  let fading = false;
  let plannedRest = isCooldownSegment(segment);

  if (puppeteerEffort != null) {
    return {
      effort: clamp(puppeteerEffort, 0, 1),
      fading: puppeteerEffort < segment.effort - 0.15,
      plannedRest,
      segment,
    };
  }

  if (active) {
    const e = active.event;
    const elapsed = t - active.startedAt;
    if (active.rescued && t <= active.recoveryUntil) {
      const rec = Math.max(active.event.recoverySec ?? 30, 1);
      const u = (t - (active.rescueUntil - (e.rescueWindowSec ?? 0))) / rec;
      // simpler: lerp from current fade floor back to segment
      const start = e.effortFloor ?? 0;
      const u2 = clamp((t - (active.startedAt + Math.min(elapsed, e.rampSec ?? 0))) / rec, 0, 1);
      // use recoveryUntil
      const p = 1 - clamp((active.recoveryUntil - t) / rec, 0, 1);
      effort = start + (segment.effort - start) * p;
      fading = effort < segment.effort - 0.08;
    } else if (active.rescued && t > active.recoveryUntil) {
      effort = segment.effort;
    } else {
      switch (e.kind) {
        case "gradual_fade": {
          const ramp = e.rampSec ?? 60;
          const floor = e.effortFloor ?? 0.4;
          const u = clamp(elapsed / ramp, 0, 1);
          effort = segment.effort + (floor - segment.effort) * u;
          fading = true;
          break;
        }
        case "sudden_stop": {
          const down = clamp(elapsed / 2, 0, 1);
          effort = segment.effort * (1 - down);
          if (elapsed > 2) effort = 0;
          fading = true;
          break;
        }
        case "pause_resume": {
          const hold = e.holdSec ?? 6;
          if (elapsed < 1) effort = segment.effort * (1 - elapsed);
          else if (elapsed < hold) effort = 0;
          else effort = segment.effort;
          plannedRest = true;
          break;
        }
        case "grind": {
          effort = 0.93;
          fading = false;
          break;
        }
        case "interval_rest": {
          const hold = e.holdSec ?? 60;
          effort = elapsed < hold ? 0.18 : segment.effort;
          plannedRest = true;
          break;
        }
      }
    }
  }

  return { effort: clamp(effort, 0, 1), fading, plannedRest, segment };
}

export function eventActiveAt(
  scenario: Scenario,
  t: number,
): { event: ScenarioEvent; idx: number } | null {
  for (let i = 0; i < scenario.events.length; i++) {
    const e = scenario.events[i];
    const end = eventEnd(e);
    if (t >= e.atSec && t <= end) return { event: e, idx: i };
  }
  return null;
}

export function eventEnd(e: ScenarioEvent): number {
  switch (e.kind) {
    case "gradual_fade":
      return e.atSec + (e.rampSec ?? 60) + 15;
    case "sudden_stop":
      return e.atSec + (e.holdSec ?? 20) + 4;
    case "pause_resume":
      return e.atSec + (e.holdSec ?? 6) + 2;
    case "grind":
      return e.atSec + (e.holdSec ?? 180);
    case "interval_rest":
      return e.atSec + (e.holdSec ?? 60);
  }
}

export function matchingTriggerKind(kind: EventKind): string[] {
  switch (kind) {
    case "gradual_fade":
      return ["pre_quit_fade"];
    case "sudden_stop":
      return ["stopped"];
    case "grind":
      return ["grind_support"];
    default:
      return [];
  }
}

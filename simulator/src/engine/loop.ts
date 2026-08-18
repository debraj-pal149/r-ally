import type {
  EngineDebugMsg,
  GroundTruthMsg,
  MetricsMsg,
  ScenarioEndedMsg,
  TriggerMsg,
} from "../protocol.js";
import { PROTOCOL_VERSION } from "../protocol.js";
import {
  initialState,
  tickPhysiology,
  type PhysioState,
} from "./physiology.js";
import { mulberry32 } from "./rng.js";
import {
  eventActiveAt,
  eventEnd,
  eventId,
  resolveAthlete,
  resolveEffort,
  type ActiveEvent,
  type Scenario,
} from "./scenario.js";

export interface LoopConfig {
  scenario: Scenario;
  seed: number;
  timeScale: number;
  rescuable: boolean;
}

export type LoopListener = (msg: MetricsMsg | ScenarioEndedMsg | GroundTruthMsg | EngineDebugMsg) => void;

export class ScenarioLoop {
  scenario: Scenario;
  seed: number;
  timeScale: number;
  rescuable: boolean;
  t = 0;
  running = false;
  paused = false;
  puppeteerEffort: number | null = null;
  private state: PhysioState;
  private rng: () => number;
  private timer: NodeJS.Timeout | null = null;
  private listeners = new Set<LoopListener>();
  private firedOnsets = new Set<string>();
  active: ActiveEvent | null = null;
  rescuedIds = new Set<string>();
  adHocEvents: { id: string; kind: string; atSec: number; label: string }[] = [];

  constructor(cfg: LoopConfig) {
    this.scenario = cfg.scenario;
    this.seed = cfg.seed;
    this.timeScale = cfg.timeScale;
    this.rescuable = cfg.rescuable;
    this.rng = mulberry32(cfg.seed);
    this.state = initialState(resolveAthlete(cfg.scenario));
  }

  on(fn: LoopListener) {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  private emit(msg: MetricsMsg | ScenarioEndedMsg | GroundTruthMsg | EngineDebugMsg) {
    for (const fn of this.listeners) fn(msg);
  }

  reset(cfg?: Partial<LoopConfig>) {
    this.stopTimer();
    if (cfg?.scenario) this.scenario = cfg.scenario;
    if (cfg?.seed != null) this.seed = cfg.seed;
    if (cfg?.timeScale != null) this.timeScale = cfg.timeScale;
    if (cfg?.rescuable != null) this.rescuable = cfg.rescuable;
    this.t = 0;
    this.running = false;
    this.paused = false;
    this.puppeteerEffort = null;
    this.rng = mulberry32(this.seed);
    this.state = initialState(resolveAthlete(this.scenario));
    this.firedOnsets.clear();
    this.active = null;
    this.rescuedIds.clear();
    this.adHocEvents = [];
  }

  start() {
    if (this.t >= this.scenario.durationSec) this.reset();
    this.running = true;
    this.paused = false;
    this.arm();
  }

  pause() {
    this.paused = true;
    this.stopTimer();
  }

  resume() {
    if (!this.running) return this.start();
    this.paused = false;
    this.arm();
  }

  setTimeScale(x: number) {
    this.timeScale = Math.max(1, Math.min(30, x));
    if (this.running && !this.paused) this.arm();
  }

  injectFade() {
    this.puppeteerEffort = Math.max(0.2, (this.puppeteerEffort ?? 0.45) - 0.25);
    this.adHocEvents.push({
      id: `adhoc-fade-${this.t}`,
      kind: "gradual_fade",
      atSec: this.t,
      label: "puppeteer fade",
    });
    this.emitGround("adhoc-fade", "gradual_fade", "puppeteer fade");
  }

  hardStop() {
    this.puppeteerEffort = 0;
    this.adHocEvents.push({
      id: `adhoc-stop-${this.t}`,
      kind: "sudden_stop",
      atSec: this.t,
      label: "puppeteer stop",
    });
    this.emitGround("adhoc-stop", "sudden_stop", "puppeteer stop");
  }

  resumeAthlete() {
    this.puppeteerEffort = null;
  }

  handleTrigger(msg: TriggerMsg): boolean {
    if (!this.rescuable || !this.active) return false;
    const e = this.active.event;
    if (!e.rescuable) return false;
    const window = e.rescueWindowSec ?? 45;
    if (msg.t >= this.active.startedAt && msg.t <= this.active.startedAt + window) {
      this.active.rescued = true;
      this.active.rescueUntil = msg.t;
      this.active.recoveryUntil = msg.t + (e.recoverySec ?? 30);
      this.rescuedIds.add(this.active.id);
      return true;
    }
    return false;
  }

  /** Run to completion synchronously (export / tests). */
  runHeadless(): { t: number; samples: MetricsMsg["samples"]; effort: number; fatigue: number }[] {
    const rows = [];
    while (this.t < this.scenario.durationSec) {
      rows.push(this.step(1));
    }
    return rows;
  }

  private arm() {
    this.stopTimer();
    const interval = Math.max(15, 1000 / this.timeScale);
    this.timer = setInterval(() => {
      if (!this.running || this.paused) return;
      this.step(1);
      if (this.t >= this.scenario.durationSec) {
        this.running = false;
        this.stopTimer();
        this.emit({
          v: PROTOCOL_VERSION,
          type: "scenarioEnded",
          t: this.t,
        });
      }
    }, interval);
  }

  private stopTimer() {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  step(dt: number) {
    const found = eventActiveAt(this.scenario, this.t);
    if (found) {
      const id = eventId(found.event, found.idx);
      if (!this.active || this.active.id !== id) {
        this.active = {
          event: found.event,
          id,
          rescued: false,
          rescueUntil: 0,
          recoveryUntil: 0,
          startedAt: found.event.atSec,
        };
      }
      if (!this.firedOnsets.has(id)) {
        this.firedOnsets.add(id);
        this.emitGround(id, found.event.kind, found.event.label ?? found.event.kind);
      }
    } else if (this.active && this.t > eventEnd(this.active.event)) {
      this.active = null;
    }

    const resolved = resolveEffort({
      scenario: this.scenario,
      t: this.t,
      active: this.active,
      puppeteerEffort: this.puppeteerEffort,
      rescuableEnabled: this.rescuable,
    });

    const athlete = resolveAthlete(this.scenario);
    const result = tickPhysiology(this.state, {
      t: this.t,
      dt,
      effort: resolved.effort,
      activity: this.scenario.activity,
      athlete,
      fading: resolved.fading,
      rng: this.rng,
      sets: this.scenario.sets,
      boxing: this.scenario.boxing,
      hiit: this.scenario.hiit,
      plannedRest: resolved.plannedRest,
    });

    const metrics: MetricsMsg = {
      v: PROTOCOL_VERSION,
      type: "metrics",
      t: this.t,
      samples: result.samples,
    };
    this.emit(metrics);
    this.emit({
      v: PROTOCOL_VERSION,
      type: "engineDebug",
      t: this.t,
      effort: result.effort,
      fatigue: result.fatigue,
      eEff: result.eEff,
      segmentLabel: resolved.segment.label,
      rescued: this.active?.rescued,
    });

    const snapshot = {
      t: this.t,
      samples: result.samples,
      effort: result.effort,
      fatigue: result.fatigue,
    };
    this.t += dt;
    return snapshot;
  }

  private emitGround(eventId: string, kind: GroundTruthMsg["kind"], label: string) {
    this.emit({
      v: PROTOCOL_VERSION,
      type: "groundTruth",
      t: this.t,
      eventId,
      kind,
      label,
      onset: true,
    });
  }
}

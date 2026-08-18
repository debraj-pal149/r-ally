/**
 * WebSocket protocol v1 — single source of truth.
 * Hand-mirrored in app/RAlly/RAlly/DataSources/Simulator/Protocol.swift
 */

export const PROTOCOL_VERSION = 1 as const;

export type ActivityKind =
  | "running"
  | "cycling"
  | "strength"
  | "boxing"
  | "swimming"
  | "rowing"
  | "hiit";

export type MetricKind =
  | "heartRateBpm"
  | "paceSecPerKm"
  | "speedMps"
  | "cadenceSpm"
  | "powerWatts"
  | "strokeRateSpm"
  | "punchRatePpm"
  | "repVelocityMps"
  | "repCount"
  | "motionIntensityG"
  | "distanceM"
  | "activeEnergyKcal";

export type EngineState =
  | "CRUISING"
  | "WOBBLING"
  | "CRITICAL"
  | "PAUSED_UNKNOWN";

export type TriggerKind =
  | "pre_quit_fade"
  | "stopped"
  | "grind_support"
  | "final_push";

export type EventKind =
  | "gradual_fade"
  | "sudden_stop"
  | "pause_resume"
  | "grind"
  | "interval_rest";

export interface MetricSampleWire {
  k: MetricKind;
  x: number;
}

/** simulator → app */
export interface HelloMsg {
  v: 1;
  type: "hello";
  scenarioId: string;
  activity: ActivityKind;
  timeScale: number;
  tickHz: number;
}

export interface MetricsMsg {
  v: 1;
  type: "metrics";
  t: number;
  samples: MetricSampleWire[];
}

export interface ScenarioEndedMsg {
  v: 1;
  type: "scenarioEnded";
  t: number;
}

/** app → simulator */
export interface AppHelloMsg {
  v: 1;
  type: "appHello";
  appVersion: string;
  persona: string;
}

export interface RiskMsg {
  v: 1;
  type: "risk";
  t: number;
  score: number;
  state: EngineState;
}

export interface TriggerMsg {
  v: 1;
  type: "trigger";
  t: number;
  kind: TriggerKind;
  persona: string;
  text: string;
  sourceLLM: boolean;
  latencyMs: number;
}

export interface SpeechDoneMsg {
  v: 1;
  type: "speechDone";
  t: number;
}

/** dashboard-only (never sent on /stream) */
export interface GroundTruthMsg {
  v: 1;
  type: "groundTruth";
  t: number;
  eventId: string;
  kind: EventKind;
  label: string;
  onset: boolean;
}

export interface EngineDebugMsg {
  v: 1;
  type: "engineDebug";
  t: number;
  effort: number;
  fatigue: number;
  eEff: number;
  segmentLabel: string;
  rescued?: boolean;
}

export interface ControlStateMsg {
  v: 1;
  type: "controlState";
  running: boolean;
  paused: boolean;
  t: number;
  timeScale: number;
  seed: number;
  scenarioId: string;
  rescuable: boolean;
  appConnected: boolean;
  dashboardConnected: boolean;
}

export type StreamDownMsg = HelloMsg | MetricsMsg | ScenarioEndedMsg;
export type StreamUpMsg = AppHelloMsg | RiskMsg | TriggerMsg | SpeechDoneMsg;
export type DashboardMsg =
  | StreamDownMsg
  | StreamUpMsg
  | GroundTruthMsg
  | EngineDebugMsg
  | ControlStateMsg;

export function parseJsonMessage(raw: string): { type: string; v?: number } | null {
  try {
    const obj = JSON.parse(raw);
    if (!obj || typeof obj !== "object" || typeof obj.type !== "string") return null;
    return obj;
  } catch {
    return null;
  }
}

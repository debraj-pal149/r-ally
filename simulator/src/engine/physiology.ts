/**
 * Physiology engine — ALL constants live here.
 * Effort e(t) ∈ [0,1] drives HR, pace, power, cadence, etc.
 */

import type { ActivityKind, MetricKind, MetricSampleWire } from "../protocol.js";
import { gaussian } from "./rng.js";

export interface Athlete {
  age: number;
  hrRest: number;
  hrMax: number;
  thresholdPaceSecPerKm: number;
  ftpWatts: number;
  weightKg: number;
}

export const DEFAULT_ATHLETE: Athlete = {
  age: 32,
  hrRest: 58,
  hrMax: 190,
  thresholdPaceSecPerKm: 330,
  ftpWatts: 220,
  weightKg: 72,
};

export const PHYSIO = {
  hrRiseTauSec: 35,
  hrFallTauSec: 60,
  hrNoiseStd: 1.2,
  cardiacDriftBpmPerMin: 0.5,
  driftEffortFloor: 0.6,
  artifactP: 0.004,
  artifactMagMin: 8,
  artifactMagMax: 15,
  artifactDurMin: 2,
  artifactDurMax: 3,
  criticalEffort: 0.75,
  fatigueGainSec: 900,
  fatigueRecoverSec: 1800,
  fatiguePenalty: 0.25,
  gpsNoiseSigma: 0.025,
  runCadenceBase: 150,
  runCadenceSpan: 32,
  runCadenceFatigue: 0.06,
  runCadenceNoise: 1.5,
  fadeCadenceNoiseMul: 3,
  swimHrDropP: 0.15,
  swimGapStartP: 0.005,
  swimGapMin: 20,
  swimGapMax: 40,
  v0: 0.55,
} as const;

export interface PhysioState {
  hr: number;
  fatigue: number;
  distanceM: number;
  energyKcal: number;
  artifactRemain: number;
  artifactDelta: number;
  hrGapRemain: number;
  lastRepT: number;
  currentSet: number;
  currentRep: number;
  inRest: boolean;
  restRemain: number;
  workRemain: number;
  roundIndex: number;
  lastVelocity: number;
  punchRate: number;
}

export function initialState(athlete: Athlete): PhysioState {
  return {
    hr: athlete.hrRest,
    fatigue: 0,
    distanceM: 0,
    energyKcal: 0,
    artifactRemain: 0,
    artifactDelta: 0,
    hrGapRemain: 0,
    lastRepT: 0,
    currentSet: 0,
    currentRep: 0,
    inRest: false,
    restRemain: 0,
    workRemain: 180,
    roundIndex: 0,
    lastVelocity: PHYSIO.v0,
    punchRate: 40,
  };
}

export function clamp(x: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, x));
}

export interface TickContext {
  t: number;
  dt: number;
  effort: number; // commanded e(t)
  activity: ActivityKind;
  athlete: Athlete;
  fading: boolean;
  rng: () => number;
  sets?: { reps: number; restSec: number; load: number }[];
  boxing?: { workSec: number; restSec: number; count: number };
  hiit?: { workSec: number; restSec: number; count: number };
  plannedRest: boolean;
}

export interface TickResult {
  samples: MetricSampleWire[];
  eEff: number;
  fatigue: number;
  effort: number;
  plannedRest: boolean;
}

export function tickPhysiology(state: PhysioState, ctx: TickContext): TickResult {
  const { athlete, dt, rng } = ctx;
  let e = clamp(ctx.effort, 0, 1);

  // Fatigue (W′-balance-lite)
  if (e > PHYSIO.criticalEffort) {
    state.fatigue += ((e - PHYSIO.criticalEffort) * dt) / PHYSIO.fatigueGainSec;
  } else {
    state.fatigue -= ((PHYSIO.criticalEffort - e) * dt) / PHYSIO.fatigueRecoverSec;
  }
  state.fatigue = clamp(state.fatigue, 0, 1);
  const eEff = e * (1 - PHYSIO.fatiguePenalty * state.fatigue);

  // HR first-order lag + drift + noise
  const minutes = ctx.t / 60;
  const drift =
    PHYSIO.cardiacDriftBpmPerMin *
    minutes *
    (Math.max(0, eEff - PHYSIO.driftEffortFloor) / 0.4);
  const hrTarget = athlete.hrRest + eEff * (athlete.hrMax - athlete.hrRest) + drift;
  const rising = hrTarget > state.hr;
  const tau = rising ? PHYSIO.hrRiseTauSec : PHYSIO.hrFallTauSec;
  state.hr += (hrTarget - state.hr) * (1 - Math.exp(-dt / tau));
  state.hr += gaussian(rng, 0, PHYSIO.hrNoiseStd);

  if (state.artifactRemain > 0) {
    state.hr += state.artifactDelta;
    state.artifactRemain -= dt;
  } else if (rng() < PHYSIO.artifactP) {
    state.artifactRemain =
      PHYSIO.artifactDurMin + rng() * (PHYSIO.artifactDurMax - PHYSIO.artifactDurMin);
    const mag =
      PHYSIO.artifactMagMin + rng() * (PHYSIO.artifactMagMax - PHYSIO.artifactMagMin);
    state.artifactDelta = rng() < 0.5 ? mag : -mag;
  }
  state.hr = clamp(state.hr, 40, athlete.hrMax + 15);

  const samples: MetricSampleWire[] = [];
  const push = (k: MetricKind, x: number) => samples.push({ k, x });

  // Energy: MET-ish from effort
  const wattsApprox = 80 + eEff * 220;
  state.energyKcal += (wattsApprox * dt) / 4184;

  switch (ctx.activity) {
    case "running": {
      const threshSpeed = 1000 / athlete.thresholdPaceSecPerKm;
      const gps = 1 + gaussian(rng, 0, PHYSIO.gpsNoiseSigma);
      const speed = Math.max(0.2, threshSpeed * (0.55 + 0.6 * eEff) * gps);
      const pace = 1000 / speed;
      const cadNoise = ctx.fading
        ? PHYSIO.runCadenceNoise * PHYSIO.fadeCadenceNoiseMul
        : PHYSIO.runCadenceNoise;
      const cadence =
        (PHYSIO.runCadenceBase + PHYSIO.runCadenceSpan * eEff) *
          (1 - PHYSIO.runCadenceFatigue * state.fatigue) +
        gaussian(rng, 0, cadNoise);
      state.distanceM += speed * dt;
      push("speedMps", speed);
      push("paceSecPerKm", pace);
      push("cadenceSpm", clamp(cadence, 80, 220));
      push("distanceM", state.distanceM);
      push("motionIntensityG", 0.2 + 0.9 * eEff);
      break;
    }
    case "cycling": {
      const power = athlete.ftpWatts * (0.5 + 0.65 * eEff) + gaussian(rng, 0, 8);
      const cadence = 78 + 18 * eEff + gaussian(rng, 0, 1.2);
      const speed = 8.1 * Math.pow(Math.max(power, 1) / athlete.ftpWatts, 1 / 3);
      state.distanceM += speed * dt;
      push("powerWatts", Math.max(0, power));
      push("cadenceSpm", clamp(cadence, 40, 140));
      push("speedMps", speed);
      push("distanceM", state.distanceM);
      break;
    }
    case "strength": {
      tickStrength(state, ctx, eEff, push);
      break;
    }
    case "boxing": {
      tickBoxing(state, ctx, eEff, push);
      break;
    }
    case "swimming": {
      const speed = 1.1 * (0.55 + 0.6 * eEff) + gaussian(rng, 0, 0.03);
      const stroke = 28 + 16 * eEff + gaussian(rng, 0, 0.8);
      state.distanceM += Math.max(0, speed) * dt;
      push("speedMps", Math.max(0.2, speed));
      push("paceSecPerKm", 1000 / Math.max(speed, 0.2));
      push("strokeRateSpm", clamp(stroke, 15, 60));
      push("distanceM", state.distanceM);
      break;
    }
    case "rowing": {
      const power = 0.8 * athlete.ftpWatts * (0.5 + 0.65 * eEff) + gaussian(rng, 0, 6);
      const stroke = 18 + 10 * eEff + gaussian(rng, 0, 0.6);
      const speed = 3.5 * Math.pow(Math.max(power, 1) / (0.8 * athlete.ftpWatts), 1 / 3);
      state.distanceM += speed * dt;
      push("powerWatts", Math.max(0, power));
      push("strokeRateSpm", clamp(stroke, 12, 42));
      push("speedMps", speed);
      push("distanceM", state.distanceM);
      break;
    }
    case "hiit": {
      const motion = 0.15 + 0.85 * eEff + gaussian(rng, 0, 0.03);
      const freq = 1.2 + 1.8 * eEff + gaussian(rng, 0, 0.08);
      push("motionIntensityG", clamp(motion, 0.05, 2.2));
      push("cadenceSpm", clamp(freq * 60, 40, 220));
      break;
    }
  }

  push("activeEnergyKcal", state.energyKcal);

  // HR sample with swim dropouts
  let includeHr = true;
  if (ctx.activity === "swimming") {
    if (state.hrGapRemain > 0) {
      state.hrGapRemain -= dt;
      includeHr = false;
    } else if (rng() < PHYSIO.swimGapStartP) {
      state.hrGapRemain =
        PHYSIO.swimGapMin + rng() * (PHYSIO.swimGapMax - PHYSIO.swimGapMin);
      includeHr = false;
    } else if (rng() < PHYSIO.swimHrDropP) {
      includeHr = false;
    }
  }
  if (includeHr) push("heartRateBpm", state.hr);

  return {
    samples,
    eEff,
    fatigue: state.fatigue,
    effort: e,
    plannedRest: ctx.plannedRest,
  };
}

function tickStrength(
  state: PhysioState,
  ctx: TickContext,
  eEff: number,
  push: (k: MetricKind, x: number) => void,
) {
  const sets = ctx.sets ?? [{ reps: 5, restSec: 90, load: 80 }];
  const set = sets[Math.min(state.currentSet, sets.length - 1)];
  const vloss = 0.25 + 0.2 * state.fatigue;

  if (state.inRest) {
    state.restRemain -= ctx.dt;
    push("repVelocityMps", 0);
    push("repCount", state.currentRep);
    push("motionIntensityG", 0.08 + gaussian(ctx.rng, 0, 0.02));
    if (state.restRemain <= 0) {
      state.inRest = false;
      state.currentSet += 1;
      state.currentRep = 0;
    }
    return;
  }

  if (state.currentSet >= sets.length) {
    push("repVelocityMps", 0);
    push("repCount", state.currentRep);
    push("motionIntensityG", 0.08);
    return;
  }

  const interRep = 1.5 + 2.5 * (state.fatigue + (1 - eEff));
  if (ctx.t - state.lastRepT >= interRep) {
    state.currentRep += 1;
    state.lastRepT = ctx.t;
    const n = state.currentRep;
    const denom = Math.max(set.reps - 1, 1);
    const vel =
      PHYSIO.v0 * (1 - vloss * ((n - 1) / denom)) + gaussian(ctx.rng, 0, 0.02);
    state.lastVelocity = Math.max(0.08, vel);
    push("repVelocityMps", state.lastVelocity);
    push("repCount", n);
    push("motionIntensityG", 1.4 + gaussian(ctx.rng, 0, 0.15));
    if (n >= set.reps) {
      state.inRest = true;
      state.restRemain = set.restSec;
    }
  } else {
    push("repVelocityMps", state.lastVelocity * 0.15);
    push("repCount", state.currentRep);
    push("motionIntensityG", 0.25 + 0.4 * eEff);
  }
}

function tickBoxing(
  state: PhysioState,
  ctx: TickContext,
  eEff: number,
  push: (k: MetricKind, x: number) => void,
) {
  const spec = ctx.boxing ?? { workSec: 180, restSec: 60, count: 6 };
  if (state.roundIndex === 0 && state.workRemain === 180 && ctx.t < 1) {
    state.workRemain = spec.workSec;
    state.inRest = false;
    state.roundIndex = 1;
  }
  if (state.inRest) {
    state.restRemain -= ctx.dt;
    state.punchRate = 8 + gaussian(ctx.rng, 0, 1);
    push("punchRatePpm", Math.max(0, state.punchRate));
    push("motionIntensityG", 0.2);
    if (state.restRemain <= 0 && state.roundIndex < spec.count) {
      state.inRest = false;
      state.workRemain = spec.workSec;
      state.roundIndex += 1;
    }
    return;
  }
  const intra = 1 - 0.15 * (1 - state.workRemain / spec.workSec);
  state.punchRate = 55 * (0.6 + 0.5 * eEff) * intra + gaussian(ctx.rng, 0, 2);
  push("punchRatePpm", clamp(state.punchRate, 0, 140));
  push("motionIntensityG", 0.4 + 1.1 * eEff);
  state.workRemain -= ctx.dt;
  if (state.workRemain <= 0) {
    state.inRest = true;
    state.restRemain = spec.restSec;
  }
}

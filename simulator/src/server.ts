import Fastify from "fastify";
import cors from "@fastify/cors";
import websocket from "@fastify/websocket";
import fastifyStatic from "@fastify/static";
import { existsSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { ScenarioLoop } from "./engine/loop.js";
import { parseJsonMessage, PROTOCOL_VERSION, type TriggerMsg } from "./protocol.js";
import { listScenarioIds, loadAllScenarios, loadScenario } from "./serverShared.js";
import { scoreRun, writeReport, type EvalReport } from "./eval/scorer.js";

const PORT = 7777;
const root = join(dirname(fileURLToPath(import.meta.url)), "../..");

const app = Fastify({ logger: false });
await app.register(cors, { origin: true });
await app.register(websocket);

type Sock = {
  send: (s: string) => void;
  readyState: number;
  on: (ev: string, cb: (...args: unknown[]) => void) => void;
};

const streamClients = new Set<Sock>();
const dashClients = new Set<Sock>();
const triggers: TriggerMsg[] = [];
const suiteReports: EvalReport[] = [];
let suiteQueue: string[] = [];
let suiteRunning = false;

let scenario = loadScenario("run-5k-bonk");
let loop = new ScenarioLoop({
  scenario,
  seed: 42,
  timeScale: 10,
  rescuable: true,
});

function broadcastStream(obj: unknown) {
  const raw = JSON.stringify(obj);
  for (const ws of streamClients) {
    if (ws.readyState === 1) ws.send(raw);
  }
}

function broadcastDash(obj: unknown) {
  const raw = JSON.stringify(obj);
  for (const ws of dashClients) {
    if (ws.readyState === 1) ws.send(raw);
  }
}

function controlState() {
  return {
    v: PROTOCOL_VERSION,
    type: "controlState" as const,
    running: loop.running,
    paused: loop.paused,
    t: loop.t,
    timeScale: loop.timeScale,
    seed: loop.seed,
    scenarioId: loop.scenario.id,
    rescuable: loop.rescuable,
    appConnected: streamClients.size > 0,
    dashboardConnected: dashClients.size > 0,
  };
}

function hello() {
  return {
    v: PROTOCOL_VERSION,
    type: "hello" as const,
    scenarioId: loop.scenario.id,
    activity: loop.scenario.activity,
    timeScale: loop.timeScale,
    tickHz: 1,
  };
}

loop.on((msg) => {
  if (msg.type === "metrics" || msg.type === "scenarioEnded") {
    broadcastStream(msg);
    broadcastDash(msg);
    if (msg.type === "scenarioEnded") {
      const report = scoreRun({
        scenario: loop.scenario,
        seed: loop.seed,
        triggers,
        rescuedIds: loop.rescuedIds,
      });
      const path = writeReport(report, join(root, "eval-reports"));
      broadcastDash({ v: 1, type: "evalReport", path, report });
      if (suiteRunning) {
        suiteReports.push(report);
        setTimeout(() => startNextSuiteScenario(), 400);
      }
    }
  } else {
    // groundTruth + engineDebug — dashboard only
    broadcastDash(msg);
  }
});

app.get("/api/scenarios", async () => {
  return loadAllScenarios().map((s) => ({
    id: s.id,
    name: s.name,
    activity: s.activity,
    durationSec: s.durationSec,
    lab: Boolean(s.lab) || !["running", "cycling", "rowing"].includes(s.activity),
  }));
});

app.get("/api/state", async () => controlState());

app.post("/api/control", async (req) => {
  const body = (req.body ?? {}) as Record<string, unknown>;
  const action = String(body.action ?? "");
  switch (action) {
    case "load": {
      const id = String(body.scenarioId ?? "run-5k-bonk");
      scenario = loadScenario(id);
      const seed = Number(body.seed ?? loop.seed);
      const timeScale = Number(body.timeScale ?? loop.timeScale);
      const rescuable = body.rescuable != null ? Boolean(body.rescuable) : loop.rescuable;
      loop.reset({ scenario, seed, timeScale, rescuable });
      triggers.length = 0;
      broadcastStream(hello());
      broadcastDash(hello());
      break;
    }
    case "start":
      if (body.scenarioId) {
        scenario = loadScenario(String(body.scenarioId));
        loop.reset({
          scenario,
          seed: Number(body.seed ?? loop.seed),
          timeScale: Number(body.timeScale ?? loop.timeScale),
          rescuable: body.rescuable != null ? Boolean(body.rescuable) : loop.rescuable,
        });
        triggers.length = 0;
        broadcastStream(hello());
        broadcastDash(hello());
      }
      loop.start();
      break;
    case "pause":
      loop.pause();
      break;
    case "resume":
      loop.resume();
      break;
    case "reset":
      loop.reset();
      triggers.length = 0;
      broadcastStream(hello());
      broadcastDash(hello());
      break;
    case "setTimeScale":
      loop.setTimeScale(Number(body.timeScale ?? 10));
      break;
    case "setSeed":
      loop.reset({ seed: Number(body.seed ?? 42) });
      triggers.length = 0;
      break;
    case "setRescuable":
      loop.rescuable = Boolean(body.rescuable);
      break;
    case "setEffort":
      loop.puppeteerEffort = body.effort == null ? null : Number(body.effort);
      break;
    case "injectFade":
      loop.injectFade();
      break;
    case "hardStop":
      loop.hardStop();
      break;
    case "resumeAthlete":
      loop.resumeAthlete();
      break;
    case "fullEval":
      suiteQueue = listScenarioIds();
      suiteReports.length = 0;
      suiteRunning = true;
      startNextSuiteScenario();
      break;
    default:
      break;
  }
  const st = controlState();
  broadcastDash(st);
  return st;
});

app.get("/api/eval/latest", async () => {
  return suiteReports.at(-1) ?? { ok: true };
});

function startNextSuiteScenario() {
  const id = suiteQueue.shift();
  if (!id) {
    suiteRunning = false;
    broadcastDash({ v: 1, type: "evalSuite", reports: suiteReports });
    return;
  }
  scenario = loadScenario(id);
  loop.reset({ scenario, seed: 42, timeScale: 30, rescuable: true });
  triggers.length = 0;
  broadcastStream(hello());
  broadcastDash(hello());
  loop.start();
  broadcastDash(controlState());
}

app.register(async (fastify) => {
  fastify.get("/stream", { websocket: true }, (socket) => {
    const sock = socket as unknown as Sock;
    streamClients.add(sock);
    sock.send(JSON.stringify(hello()));
    broadcastDash(controlState());
    sock.on("message", (raw: unknown) => {
      const text = typeof raw === "string" ? raw : String(raw);
      const msg = parseJsonMessage(text);
      if (!msg) return;
      broadcastDash(JSON.parse(text));
      if (msg.type === "trigger") {
        const t = JSON.parse(text) as TriggerMsg;
        triggers.push(t);
        loop.handleTrigger(t);
      }
    });
    sock.on("close", () => {
      streamClients.delete(sock);
      broadcastDash(controlState());
    });
  });

  fastify.get("/dashboard", { websocket: true }, (socket) => {
    const sock = socket as unknown as Sock;
    dashClients.add(sock);
    sock.send(JSON.stringify(hello()));
    sock.send(JSON.stringify(controlState()));
    sock.on("close", () => {
      dashClients.delete(sock);
      broadcastDash(controlState());
    });
  });
});

try {
  mkdirSync(join(root, "eval-reports"), { recursive: true });
} catch {
  /* ignore */
}

const webDist = join(dirname(fileURLToPath(import.meta.url)), "../web/dist");
if (existsSync(webDist)) {
  await app.register(fastifyStatic, { root: webDist, prefix: "/" });
}

await app.listen({ port: PORT, host: "0.0.0.0" });
console.log(`r-ally simulator ws://localhost:${PORT}/stream  dashboard ws://localhost:${PORT}/dashboard`);

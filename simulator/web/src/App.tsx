import { useCallback, useEffect, useRef, useState } from "react";
import ChartPane, { type Marker, type SeriesPoint } from "./components/ChartPane";
import ControlBar from "./components/ControlBar";
import EvalPanel, { type EvalReport } from "./components/EvalPanel";
import Puppeteer from "./components/Puppeteer";
import Transcript, { type Line } from "./components/Transcript";

const API = "http://localhost:7777";
const WS = "ws://localhost:7777/dashboard";

interface ScenarioInfo {
  id: string;
  name: string;
  activity: string;
  durationSec: number;
  lab?: boolean;
}

function sampleVal(samples: { k: string; x: number }[], k: string): number | null {
  const s = samples.find((x) => x.k === k);
  return s ? s.x : null;
}

function outputOf(activity: string, samples: { k: string; x: number }[]): number | null {
  if (activity === "cycling" || activity === "rowing") return sampleVal(samples, "powerWatts");
  if (activity === "strength") return sampleVal(samples, "repVelocityMps");
  if (activity === "boxing") return sampleVal(samples, "punchRatePpm");
  if (activity === "hiit") return sampleVal(samples, "motionIntensityG");
  const pace = sampleVal(samples, "paceSecPerKm");
  if (pace && pace > 0) return 1000 / pace; // invert so up = faster
  return sampleVal(samples, "speedMps");
}

function rhythmOf(activity: string, samples: { k: string; x: number }[]): number | null {
  if (activity === "swimming" || activity === "rowing") return sampleVal(samples, "strokeRateSpm");
  if (activity === "boxing") return sampleVal(samples, "punchRatePpm");
  if (activity === "strength") return sampleVal(samples, "repVelocityMps");
  return sampleVal(samples, "cadenceSpm");
}

export default function App() {
  const [scenarios, setScenarios] = useState<ScenarioInfo[]>([]);
  const [scenarioId, setScenarioId] = useState("run-5k-bonk");
  const [activity, setActivity] = useState("running");
  const [timeScale, setTimeScale] = useState(10);
  const [seed, setSeed] = useState(42);
  const [rescuable, setRescuable] = useState(true);
  const [running, setRunning] = useState(false);
  const [paused, setPaused] = useState(false);
  const [appConnected, setAppConnected] = useState(false);
  const [t, setT] = useState(0);
  const [points, setPoints] = useState<SeriesPoint[]>([]);
  const [markers, setMarkers] = useState<Marker[]>([]);
  const [lines, setLines] = useState<Line[]>([]);
  const [report, setReport] = useState<EvalReport | null>(null);
  const [suite, setSuite] = useState<EvalReport[]>([]);
  const [effort, setEffort] = useState<number | null>(null);
  const riskRef = useRef<number | null>(null);
  const wsRef = useRef<WebSocket | null>(null);

  const control = useCallback(async (action: string, extra: Record<string, unknown> = {}) => {
    const res = await fetch(`${API}/api/control`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ action, ...extra }),
    });
    const st = await res.json();
    setRunning(st.running);
    setPaused(st.paused);
    setTimeScale(st.timeScale);
    setSeed(st.seed);
    setRescuable(st.rescuable);
    setScenarioId(st.scenarioId);
    setAppConnected(st.appConnected);
    setT(st.t);
    if (action === "start" || action === "load" || action === "reset") {
      setPoints([]);
      setMarkers([]);
      setLines([]);
      setReport(null);
      riskRef.current = null;
    }
  }, []);

  useEffect(() => {
    fetch(`${API}/api/scenarios`)
      .then((r) => r.json())
      .then(setScenarios)
      .catch(() => {});
  }, []);

  useEffect(() => {
    let ws: WebSocket;
    let retry: ReturnType<typeof setTimeout>;
    const connect = () => {
      ws = new WebSocket(WS);
      wsRef.current = ws;
      ws.onmessage = (ev) => {
        const msg = JSON.parse(ev.data);
        switch (msg.type) {
          case "hello":
            setScenarioId(msg.scenarioId);
            setActivity(msg.activity);
            setTimeScale(msg.timeScale);
            break;
          case "controlState":
            setRunning(msg.running);
            setPaused(msg.paused);
            setTimeScale(msg.timeScale);
            setSeed(msg.seed);
            setRescuable(msg.rescuable);
            setScenarioId(msg.scenarioId);
            setAppConnected(msg.appConnected);
            setT(msg.t);
            break;
          case "metrics": {
            setT(msg.t);
            setPoints((prev) => {
              const next = [
                ...prev,
                {
                  t: msg.t,
                  hr: sampleVal(msg.samples, "heartRateBpm"),
                  output: outputOf(activity, msg.samples),
                  rhythm: rhythmOf(activity, msg.samples),
                  risk: riskRef.current,
                },
              ];
              return next.length > 2400 ? next.slice(next.length - 2400) : next;
            });
            break;
          }
          case "groundTruth":
            setMarkers((m) => [...m, { t: msg.t, kind: "ground", label: msg.label }]);
            break;
          case "risk":
            riskRef.current = msg.score;
            break;
          case "trigger":
            setMarkers((m) => [...m, { t: msg.t, kind: "trigger", label: msg.text }]);
            setLines((ls) => [
              ...ls,
              {
                t: msg.t,
                kind: msg.kind,
                persona: msg.persona,
                text: msg.text,
                sourceLLM: msg.sourceLLM,
                latencyMs: msg.latencyMs,
              },
            ]);
            break;
          case "speechDone":
            setMarkers((m) => {
              const last = [...m].reverse().find((x) => x.kind === "trigger");
              if (!last) return m;
              return m.map((x) => (x === last ? { ...x, tEnd: msg.t } : x));
            });
            break;
          case "evalReport":
            setReport(msg.report);
            break;
          case "evalSuite":
            setSuite(msg.reports ?? []);
            break;
          case "scenarioEnded":
            break;
        }
      };
      ws.onclose = () => {
        retry = setTimeout(connect, 1000);
      };
    };
    connect();
    return () => {
      clearTimeout(retry);
      ws?.close();
    };
  }, [activity]);

  return (
    <div className="app">
      <ControlBar
        scenarios={scenarios}
        scenarioId={scenarioId}
        activity={activity}
        timeScale={timeScale}
        seed={seed}
        rescuable={rescuable}
        running={running}
        paused={paused}
        appConnected={appConnected}
        t={t}
        onChange={(patch) => {
          if (patch.seed != null) setSeed(Number(patch.seed));
        }}
        onControl={control}
      />
      <div className="layout">
        <div className="charts">
          <ChartPane points={points} markers={markers} activity={activity} />
        </div>
        <div className="side">
          <Puppeteer
            effort={effort}
            onEffort={(v) => {
              setEffort(v);
              control("setEffort", { effort: v });
            }}
            onFade={() => control("injectFade")}
            onStop={() => control("hardStop")}
            onResume={() => {
              setEffort(null);
              control("resumeAthlete");
            }}
          />
          <Transcript lines={lines} />
          <EvalPanel
            report={report}
            suite={suite}
            onFullEval={() => control("fullEval")}
            onExport={() => {
              if (!report) return;
              const blob = new Blob([JSON.stringify(report, null, 2)], { type: "application/json" });
              const a = document.createElement("a");
              a.href = URL.createObjectURL(blob);
              a.download = `${report.scenarioId}-eval.json`;
              a.click();
            }}
          />
        </div>
      </div>
    </div>
  );
}

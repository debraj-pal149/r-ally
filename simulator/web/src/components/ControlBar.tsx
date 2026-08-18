interface ScenarioInfo {
  id: string;
  name: string;
  activity: string;
  durationSec: number;
}

interface Props {
  scenarios: ScenarioInfo[];
  scenarioId: string;
  activity: string;
  timeScale: number;
  seed: number;
  rescuable: boolean;
  running: boolean;
  paused: boolean;
  appConnected: boolean;
  t: number;
  onChange: (patch: Record<string, unknown>) => void;
  onControl: (action: string, extra?: Record<string, unknown>) => void;
}

export default function ControlBar(p: Props) {
  return (
    <header className="bar">
      <h1>
        r-<span>ally</span>
      </h1>
      <select
        value={p.scenarioId}
        onChange={(e) => p.onControl("load", { scenarioId: e.target.value, seed: p.seed, timeScale: p.timeScale, rescuable: p.rescuable })}
      >
        {p.scenarios.map((s) => (
          <option key={s.id} value={s.id}>
            {s.name}
          </option>
        ))}
      </select>
      <span className="badge">{p.activity}</span>
      <label>
        time
        <input
          className="slider"
          type="range"
          min={1}
          max={30}
          value={p.timeScale}
          onChange={(e) => p.onControl("setTimeScale", { timeScale: Number(e.target.value) })}
        />
        {p.timeScale}×
      </label>
      <label>
        seed
        <input
          style={{ width: 70 }}
          value={p.seed}
          onChange={(e) => p.onChange({ seed: Number(e.target.value) || 0 })}
          onBlur={() => p.onControl("setSeed", { seed: p.seed })}
        />
      </label>
      <label>
        <input
          type="checkbox"
          checked={p.rescuable}
          onChange={(e) => p.onControl("setRescuable", { rescuable: e.target.checked })}
        />{" "}
        rescuable athlete
      </label>
      <button className="primary" onClick={() => p.onControl(p.running && !p.paused ? "pause" : "start", { scenarioId: p.scenarioId, seed: p.seed, timeScale: p.timeScale, rescuable: p.rescuable })}>
        {p.running && !p.paused ? "Pause" : "Start"}
      </button>
      <button onClick={() => p.onControl("reset")}>Reset</button>
      <span className="badge">t {Math.floor(p.t)}s</span>
      <span className="badge">
        <span className={`dot ${p.appConnected ? "on" : "off"}`} />
        app {p.appConnected ? "connected" : "offline"}
      </span>
      <span className="badge">
        <span className="dot on" />
        browser
      </span>
    </header>
  );
}

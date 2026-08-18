interface Props {
  effort: number | null;
  onEffort: (v: number | null) => void;
  onFade: () => void;
  onStop: () => void;
  onResume: () => void;
}

export default function Puppeteer({ effort, onEffort, onFade, onStop, onResume }: Props) {
  return (
    <div className="panel">
      <h2>Puppeteer</h2>
      <label>live effort override {effort == null ? "(auto)" : effort.toFixed(2)}</label>
      <input
        className="slider"
        style={{ width: "100%" }}
        type="range"
        min={0}
        max={100}
        value={effort == null ? 70 : effort * 100}
        onChange={(e) => onEffort(Number(e.target.value) / 100)}
      />
      <div className="row" style={{ marginTop: 8 }}>
        <button onClick={onFade}>inject fade</button>
        <button onClick={onStop}>hard stop</button>
        <button onClick={onResume}>resume</button>
      </div>
    </div>
  );
}

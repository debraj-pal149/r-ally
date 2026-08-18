export interface Line {
  t: number;
  kind: string;
  persona: string;
  text: string;
  sourceLLM: boolean;
  latencyMs: number;
}

export default function Transcript({ lines }: { lines: Line[] }) {
  return (
    <div className="panel">
      <h2>Transcript</h2>
      <div className="transcript">
        <ul>
          {lines.length === 0 && <li className="meta">No rallies yet.</li>}
          {lines.map((l, i) => (
            <li key={i}>
              <div className="meta">
                t={l.t.toFixed(0)}s · {l.kind} · {l.persona} · {l.sourceLLM ? "LLM" : "fallback"} · {l.latencyMs}ms
              </div>
              {l.text}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

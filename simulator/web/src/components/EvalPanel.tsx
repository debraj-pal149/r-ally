interface ScoredEvent {
  id: string;
  kind: string;
  atSec: number;
  detected: boolean;
  leadTimeSec: number | null;
  rescued: boolean;
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
}

export default function EvalPanel({
  report,
  suite,
  onExport,
  onFullEval,
}: {
  report: EvalReport | null;
  suite?: EvalReport[];
  onExport: () => void;
  onFullEval: () => void;
}) {
  if (!report) {
    return (
      <div className="panel">
        <h2>Eval</h2>
        <p className="meta">Finish a scenario to score detection.</p>
        <button className="primary" style={{ marginTop: 8 }} onClick={onFullEval}>
          Run full eval
        </button>
      </div>
    );
  }
  return (
    <div className="panel">
      <h2>
        Eval · <span className={report.verdict === "pass" ? "pass" : "fail"}>{report.verdict}</span>
      </h2>
      <p className="meta">
        recall {report.recall.toFixed(2)} · mean lead {report.meanLeadTime?.toFixed(1) ?? "—"}s · FP{" "}
        {report.falsePositives} · distractors {report.distractorTriggers} · rescue {report.rescueRate.toFixed(2)}
      </p>
      <table>
        <thead>
          <tr>
            <th>event</th>
            <th>t</th>
            <th>hit</th>
            <th>lead</th>
            <th>rescued</th>
          </tr>
        </thead>
        <tbody>
          {report.events.map((e) => (
            <tr key={e.id}>
              <td>
                {e.kind}
                {e.distractor ? " *" : ""}
              </td>
              <td>{e.atSec}</td>
              <td>{e.detected ? "yes" : "no"}</td>
              <td>{e.leadTimeSec ?? "—"}</td>
              <td>{e.rescued ? "yes" : "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <button style={{ marginTop: 8 }} onClick={onExport}>
        Export report
      </button>
      <button className="primary" style={{ marginTop: 8, marginLeft: 8 }} onClick={onFullEval}>
        Run full eval
      </button>
      {suite && suite.length > 0 && (
        <p className="meta" style={{ marginTop: 8 }}>
          suite {suite.filter((r) => r.verdict === "pass").length}/{suite.length} pass
        </p>
      )}
    </div>
  );
}

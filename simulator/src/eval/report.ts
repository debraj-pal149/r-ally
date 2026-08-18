import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { EvalReport } from "./scorer.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const dir = join(root, "eval-reports");

function latest(): { file: string; report: EvalReport } | null {
  let files: string[] = [];
  try {
    files = readdirSync(dir).filter((f) => f.endsWith(".json"));
  } catch {
    console.log("No eval-reports yet.");
    return null;
  }
  if (!files.length) {
    console.log("No eval-reports yet.");
    return null;
  }
  files.sort();
  const file = files[files.length - 1];
  const report = JSON.parse(readFileSync(join(dir, file), "utf8")) as EvalReport;
  return { file, report };
}

const found = latest();
if (!found) process.exit(0);
const r = found.report;
console.log(`\n${found.file}`);
console.log(`scenario: ${r.scenarioId}  seed: ${r.seed}  verdict: ${r.verdict.toUpperCase()}`);
console.log(
  `recall: ${r.recall.toFixed(2)}  meanLead: ${r.meanLeadTime?.toFixed(1) ?? "—"}s  FP: ${r.falsePositives}  distractors: ${r.distractorTriggers}  rescue: ${r.rescueRate.toFixed(2)}`,
);
console.log("events:");
for (const e of r.events) {
  console.log(
    `  ${e.kind.padEnd(14)} t=${String(e.atSec).padStart(5)}  detected=${e.detected}  lead=${e.leadTimeSec ?? "—"}  rescued=${e.rescued}${e.distractor ? "  (distractor)" : ""}`,
  );
}

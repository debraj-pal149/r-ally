import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { loadScenario } from "./serverShared.js";
import { ScenarioLoop } from "./engine/loop.js";
import { eventId } from "./engine/scenario.js";

function arg(name: string, fallback?: string): string {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx >= 0 && process.argv[idx + 1]) return process.argv[idx + 1];
  if (fallback != null) return fallback;
  throw new Error(`missing --${name}`);
}

const scenarioId = arg("scenario", "run-5k-bonk");
const seed = Number(arg("seed", "42"));
const defaultOut = join(dirname(fileURLToPath(import.meta.url)), "../../fixtures", `${scenarioId}.csv`);
const outArg = arg("out", defaultOut);

const scenario = loadScenario(scenarioId);
const loop = new ScenarioLoop({ scenario, seed, timeScale: 1, rescuable: false });
const rows = loop.runHeadless();

const destPath = outArg.startsWith("/") ? outArg : join(process.cwd(), outArg);
mkdirSync(dirname(destPath), { recursive: true });

const lines: string[] = ["t,kind,value"];
scenario.events.forEach((e, i) => {
  lines.push(`# event: ${eventId(e, i)} kind=${e.kind} atSec=${e.atSec}`);
});
for (const row of rows) {
  for (const s of row.samples) {
    lines.push(`${row.t},${s.k},${s.x}`);
  }
}
writeFileSync(destPath, lines.join("\n") + "\n");
console.log(`wrote ${destPath} (${rows.length} seconds)`);

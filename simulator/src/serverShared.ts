import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { parseScenario, type Scenario } from "./engine/scenario.js";

const here = dirname(fileURLToPath(import.meta.url));
export const SCENARIOS_DIR = join(here, "..", "scenarios");

export function listScenarioIds(): string[] {
  return readdirSync(SCENARIOS_DIR)
    .filter((f) => f.endsWith(".json"))
    .map((f) => f.replace(/\.json$/, ""))
    .sort();
}

export function loadScenario(id: string): Scenario {
  const path = join(SCENARIOS_DIR, `${id}.json`);
  return parseScenario(JSON.parse(readFileSync(path, "utf8")));
}

export function loadAllScenarios(): Scenario[] {
  return listScenarioIds().map(loadScenario);
}

import { describe, expect, it } from "vitest";
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { parseScenario } from "../src/engine/scenario";

describe("scenarios", () => {
  it("all 12 parse", () => {
    const dir = join(dirname(fileURLToPath(import.meta.url)), "../scenarios");
    const files = readdirSync(dir).filter((f) => f.endsWith(".json"));
    expect(files.length).toBeGreaterThanOrEqual(12);
    for (const f of files) {
      const raw = JSON.parse(readFileSync(join(dir, f), "utf8"));
      expect(() => parseScenario(raw)).not.toThrow();
    }
  });
});

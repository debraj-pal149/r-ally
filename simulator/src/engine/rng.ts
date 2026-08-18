/** Deterministic mulberry32 PRNG. Same seed → identical stream. */

export function mulberry32(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s += 0x6d2b79f5;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t ^= t + Math.imul(t ^ (t >>> 7), 61 | t);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function gaussian(rng: () => number, mean = 0, std = 1): number {
  // Box-Muller
  const u1 = Math.max(rng(), 1e-12);
  const u2 = rng();
  const mag = Math.sqrt(-2 * Math.log(u1));
  return mean + std * mag * Math.cos(2 * Math.PI * u2);
}

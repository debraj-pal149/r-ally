import { useEffect, useMemo, useRef, useState } from "react";
import uPlot from "uplot";
import "uplot/dist/uPlot.min.css";

export interface SeriesPoint {
  t: number;
  hr: number | null;
  output: number | null;
  rhythm: number | null;
  risk: number | null;
}

export interface Marker {
  t: number;
  kind: "ground" | "trigger" | "speech";
  label: string;
  tEnd?: number;
}

interface Props {
  points: SeriesPoint[];
  markers: Marker[];
  activity: string;
}

function lastN<T>(arr: T[], n: number): T[] {
  return arr.length <= n ? arr : arr.slice(arr.length - n);
}

export default function ChartPane({ points, markers, activity }: Props) {
  const el = useRef<HTMLDivElement>(null);
  const plot = useRef<uPlot | null>(null);
  const outputLabel = useMemo(() => {
    if (activity === "cycling" || activity === "rowing") return "power";
    if (activity === "strength") return "velocity";
    if (activity === "boxing") return "punch rate";
    if (activity === "hiit") return "motion";
    return "pace (faster ↑)";
  }, [activity]);

  useEffect(() => {
    if (!el.current) return;
    const sliced = lastN(points, 900);
    const xs = sliced.map((p) => p.t);
    const hr = sliced.map((p) => p.hr ?? null);
    const out = sliced.map((p) => p.output ?? null);
    const rhy = sliced.map((p) => p.rhythm ?? null);
    const risk = sliced.map((p) => p.risk ?? null);

    const make = (height: number, color: string, fill?: string): uPlot.Options => ({
      width: el.current!.clientWidth,
      height,
      cursor: { sync: { key: "rally" } },
      legend: { show: false },
      scales: { x: { time: false } },
      axes: [
        { stroke: "#8a94a0", grid: { stroke: "#1f252c" } },
        { stroke: "#8a94a0", grid: { stroke: "#1f252c" } },
      ],
      series: [
        {},
        { stroke: color, width: 1.6, fill, spanGaps: true },
      ],
      hooks: {
        draw: [
          (u) => {
            const ctx = u.ctx;
            for (const m of markers) {
              if (xs.length === 0) continue;
              const x = u.valToPos(m.t, "x", true);
              ctx.save();
              ctx.strokeStyle = m.kind === "ground" ? "#ff4d4d" : m.kind === "trigger" ? "#ff5a1f" : "#8a94a0";
              ctx.setLineDash(m.kind === "ground" ? [4, 4] : []);
              ctx.lineWidth = m.kind === "trigger" ? 2 : 1;
              ctx.beginPath();
              ctx.moveTo(x, u.bbox.top);
              ctx.lineTo(x, u.bbox.top + u.bbox.height);
              ctx.stroke();
              ctx.restore();
            }
          },
        ],
      },
    });

    el.current.innerHTML = "";
    const wrap = document.createElement("div");
    wrap.className = "u-wrap";
    el.current.appendChild(wrap);

    const panes: { data: (number | null)[]; color: string; fill?: string; h: number }[] = [
      { data: hr, color: "#ff4d4d", h: 140 },
      { data: out, color: "#ff5a1f", h: 140 },
      { data: rhy, color: "#8a94a0", h: 110 },
      { data: risk, color: "#ffb020", fill: "rgba(255,176,32,0.18)", h: 120 },
    ];
    const plots: uPlot[] = [];
    panes.forEach((p) => {
      const holder = document.createElement("div");
      wrap.appendChild(holder);
      plots.push(new uPlot(make(p.h, p.color, p.fill), [xs, p.data], holder));
    });
    plot.current = plots[0];

    const onResize = () => {
      const w = el.current?.clientWidth ?? 600;
      plots.forEach((pl) => pl.setSize({ width: w, height: pl.height }));
    };
    window.addEventListener("resize", onResize);
    return () => {
      window.removeEventListener("resize", onResize);
      plots.forEach((pl) => pl.destroy());
    };
  }, [points, markers, activity]);

  return (
    <div>
      <div className="row" style={{ padding: "4px 8px", gap: 16, color: "var(--text-secondary)", fontSize: 12 }}>
        <span style={{ color: "#ff4d4d" }}>HR</span>
        <span style={{ color: "#ff5a1f" }}>{outputLabel}</span>
        <span>rhythm</span>
        <span style={{ color: "#ffb020" }}>app risk</span>
        <span>— dashed red = ground truth · ember = rally</span>
      </div>
      <div ref={el} />
    </div>
  );
}

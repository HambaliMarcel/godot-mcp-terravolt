export type MetricsSnapshot = {
  callsStarted: number;
  callsSucceeded: number;
  callsFailed: number;
  totalLatencyMs: number;
  byTool: Record<string, { calls: number; successes: number; failures: number; latencyMs: number }>;
};

const snap: MetricsSnapshot = {
  callsStarted: 0,
  callsSucceeded: 0,
  callsFailed: 0,
  totalLatencyMs: 0,
  byTool: {},
};

export function metricsRecordToolStart(tool: string): void {
  snap.callsStarted += 1;
  if (!snap.byTool[tool]) {
    snap.byTool[tool] = { calls: 0, successes: 0, failures: 0, latencyMs: 0 };
  }
  snap.byTool[tool]!.calls += 1;
}

export function metricsRecordToolEnd(tool: string, ok: boolean, latencyMs: number): void {
  snap.totalLatencyMs += latencyMs;
  const b = snap.byTool[tool];
  if (!b) return;
  b.latencyMs += latencyMs;
  if (ok) {
    b.successes += 1;
    snap.callsSucceeded += 1;
  } else {
    b.failures += 1;
    snap.callsFailed += 1;
  }
}

/** §09 — ranked tools by average latency (lifecycle totals ÷ calls). */
export function metricsBottleneckReport(top: number): {
  readonly slowestAverageMs: ReadonlyArray<{ tool: string; avgMs: number; calls: number }>;
} {
  const n = Math.min(100, Math.max(1, Math.floor(top)));
  const rows = Object.entries(snap.byTool)
    .map(([tool, b]) => ({
      tool,
      calls: b.calls,
      avgMs: b.calls > 0 ? b.latencyMs / b.calls : 0,
    }))
    .sort((a, b) => b.avgMs - a.avgMs || a.tool.localeCompare(b.tool))
    .slice(0, n);
  return { slowestAverageMs: rows };
}

export function metricsSnapshot(): MetricsSnapshot {
  return JSON.parse(JSON.stringify(snap)) as MetricsSnapshot;
}

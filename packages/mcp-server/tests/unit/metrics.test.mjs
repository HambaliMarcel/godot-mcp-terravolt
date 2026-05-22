import { strict as assert } from "node:assert";
import test from "node:test";

import {
  metricsBottleneckReport,
  metricsRecordToolEnd,
  metricsRecordToolStart,
  metricsSnapshot,
} from "../../dist/telemetry/metrics.js";

test("metrics: records start/end and aggregates per tool", () => {
  metricsRecordToolStart("tools.alpha");
  metricsRecordToolEnd("tools.alpha", true, 10);
  metricsRecordToolStart("tools.alpha");
  metricsRecordToolEnd("tools.alpha", false, 30);
  const snap = metricsSnapshot();
  const t = snap.byTool["tools.alpha"];
  assert.equal(t.calls, 2);
  assert.equal(t.successes, 1);
  assert.equal(t.failures, 1);
  assert.equal(t.latencyMs, 40);
});

test("metrics: tools.bottlenecks ranks by avg latency desc", () => {
  metricsRecordToolStart("tools.slow");
  metricsRecordToolEnd("tools.slow", true, 500);
  metricsRecordToolStart("tools.fast");
  metricsRecordToolEnd("tools.fast", true, 5);

  const r = metricsBottleneckReport(5);
  assert.ok(Array.isArray(r.slowestAverageMs));
  const idxSlow = r.slowestAverageMs.findIndex((x) => x.tool === "tools.slow");
  const idxFast = r.slowestAverageMs.findIndex((x) => x.tool === "tools.fast");
  assert.notEqual(idxSlow, -1, "slow tool present");
  assert.notEqual(idxFast, -1, "fast tool present");
  assert.ok(idxSlow < idxFast, "slow tool ranks above fast tool");
});

test("metrics: bottlenecks clamps topN to [1,100]", () => {
  const r1 = metricsBottleneckReport(0);
  const r2 = metricsBottleneckReport(999);
  assert.ok(r1.slowestAverageMs.length >= 1, "lower bound clamps to 1");
  assert.ok(r2.slowestAverageMs.length <= 100, "upper bound clamps to 100");
});

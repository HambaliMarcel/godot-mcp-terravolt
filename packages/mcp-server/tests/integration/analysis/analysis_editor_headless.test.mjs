/**
 * Tasklist 16 — headless integration for analysis.* and editor.error_log_tail.
 */
import { strict as assert } from "node:assert";
import { existsSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const fixture = join(repoRoot, "tests", "_fixtures", "asset_zoo");
const skip = !godotBinary || !existsSync(fixture);
const skipReason = !godotBinary ? "TERRAVOLT_GODOT_BINARY not set" : `fixture missing: ${fixture}`;

test("analysis.* headless round-trips", { skip: skip && skipReason }, async () => {
  const coordinator = new HeadlessCoordinator(
    headlessConfig(godotBinary, fixture),
    () => {},
    import.meta.url,
  );
  try {
    await coordinator.ensureSession(fixture);

    const metricsA = await coordinator.rpc("analysis.metrics", {});
    const metricsB = await coordinator.rpc("analysis.metrics", {});
    assert.deepEqual(metricsA, metricsB);
    assert.ok(metricsA.loc && typeof metricsA.loc.total === "number");
    assert.ok(metricsA.scripts && typeof metricsA.scripts.count === "number");

    const complexity = await coordinator.rpc("analysis.scene_complexity", { scope: "project" });
    assert.ok(complexity.overall && typeof complexity.overall.node_count === "number");
    assert.ok(Array.isArray(complexity.offenders));

    const flow = await coordinator.rpc("analysis.signal_flow", { scope: "project" });
    assert.ok(flow.graph_summary && typeof flow.graph_summary.nodes === "number");
    assert.ok(Array.isArray(flow.orphans));

    const unused = await coordinator.rpc("analysis.unused_resources", {});
    assert.ok(Array.isArray(unused.unused));
    assert.ok(typeof unused.total_count === "number");

    await assert.rejects(
      () => coordinator.rpc("editor.screenshot", {}),
      (err) => {
        assert.match(String(err), /editor\.not_available|33400/i);
        return true;
      },
    );

    const logTail = await coordinator.rpc("editor.error_log_tail", { lines: 10, level: "all" });
    assert.ok(Array.isArray(logTail.entries));
  } finally {
    await coordinator.stop(true);
  }
});

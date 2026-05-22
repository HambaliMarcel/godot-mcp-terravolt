/**
 * Tasklist 23 — headless integration for testing.*, profile.*, export.*.
 */
import { strict as assert } from "node:assert";
import { existsSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const testingFixture = join(repoRoot, "tests", "_fixtures", "testing_zoo");
const exportFixture = join(repoRoot, "tests", "_fixtures", "export_zoo");
const skip = !godotBinary || !existsSync(testingFixture) || !existsSync(exportFixture);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set"
  : `fixture missing: ${testingFixture} or ${exportFixture}`;

async function withCoordinator(projectPath, fn) {
  const coordinator = new HeadlessCoordinator(
    headlessConfig(godotBinary, projectPath),
    () => {},
    import.meta.url,
  );
  try {
    await coordinator.ensureSession(projectPath);
    return await fn(coordinator);
  } finally {
    await coordinator.stop(true);
  }
}

test(
  "testing.* + profile.* + export.* headless round-trips",
  { skip: skip && skipReason },
  async () => {
    await withCoordinator(testingFixture, async (c) => {
      const suites = await c.rpc("testing.list_suites", { framework: "any" });
      assert.equal(suites.framework, "gut");
      assert.ok(suites.suites.length >= 2);

      const run = await c.rpc("testing.run", { framework: "auto", timeout_ms: 120000 });
      assert.equal(typeof run.ok, "boolean");
      assert.ok(run.summary.total >= 1);
      assert.ok(run.summary.failed >= 1);
      assert.ok(run.summary.passed >= 1);
      assert.ok(String(run.report_path || run.id || "").length >= 1);

      const reports = await c.rpc("testing.list_reports", { limit: 5 });
      assert.ok(reports.reports.length >= 1);
      const rid = reports.reports[0].id;
      const full = await c.rpc("testing.get_report", { id: rid });
      assert.equal(full.report.id, rid);

      const assertRes = await c.rpc("testing.assert_state", {
        assertions: [
          {
            kind: "text_contains",
            spec: { path: "HUD" },
            expect: "Score: 0",
          },
        ],
      });
      assert.equal(assertRes.ok, true);

      const match = await c.rpc("testing.screenshot_compare", {
        source: { mode: "file", path: "res://golden/baseline.png" },
        golden_path: "res://golden/baseline.png",
        tolerance: 0.02,
      });
      assert.equal(match.ok, true);
      assert.ok(match.mean_diff <= 0.02);

      const mismatch = await c.rpc("testing.screenshot_compare", {
        source: { mode: "file", path: "res://golden/mismatch.png" },
        golden_path: "res://golden/baseline.png",
        tolerance: 0.02,
      });
      assert.equal(mismatch.ok, false);
      assert.ok(mismatch.mean_diff > 0.02);

      const mon = await c.rpc("profile.monitor", {
        keys: ["time_fps", "memory_static"],
        window_ms: 200,
        samples: 2,
      });
      assert.equal(mon.samples.length, 2);
      assert.ok(typeof mon.averages.time_fps === "number");

      try {
        const flame = await c.rpc("profile.flamegraph", { duration_s: 0.2 });
        assert.ok(String(flame.flamegraph_path).includes("terravolt/flamegraphs"));
        assert.ok(flame.top_hot_functions.length >= 1);
      } catch (e) {
        assert.match(String(e), /flamegraph_unavailable|profile/i);
      }
    });

    await withCoordinator(exportFixture, async (c) => {
      const presets = await c.rpc("export.list_presets", {});
      assert.ok(presets.presets.length >= 1);
      assert.equal(presets.presets[0].name, "Linux/X11");

      const tmpl = await c.rpc("export.template_info", {});
      assert.ok(typeof tmpl.templates_dir === "string");
      assert.ok(typeof tmpl.mismatched === "boolean");

      if (tmpl.installed.length > 0) {
        const built = await c.rpc("export.build", {
          preset: "Linux/X11",
          with_pck_only: true,
          output_path: "res://build/linux_fixture.pck",
          timeout_ms: 600000,
        });
        assert.equal(typeof built.ok, "boolean");
        if (built.ok) {
          assert.ok(built.artifacts.length >= 1);
          assert.ok(built.artifacts[0].size_bytes > 0);
        }
      }
    });
  },
);

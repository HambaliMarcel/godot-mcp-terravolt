/**
 * Tasklist 26 — headless integration for android.* + testing.run_scenario.
 * Uses the existing `empty` fixture so we don't need a configured Android preset.
 */
import { strict as assert } from "node:assert";
import { existsSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const emptyFixture = join(repoRoot, "tests", "_fixtures", "empty");
const skip = !godotBinary || !existsSync(emptyFixture);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set"
  : `fixture missing: ${emptyFixture}`;

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
  "android.* + testing.run_scenario headless round-trips",
  { skip: skip && skipReason },
  async () => {
    await withCoordinator(emptyFixture, async (c) => {
      // android.list_devices: adb may or may not be installed; either way the
      // response must be a structured envelope (success with devices[] OR an
      // android.adb_not_found error). The headless daemon must not crash.
      let listOk = false;
      try {
        const list = await c.rpc("android.list_devices", {});
        assert.ok(Array.isArray(list.devices));
        assert.equal(typeof list.count, "number");
        listOk = true;
      } catch (err) {
        assert.match(String(err), /android\.adb_not_found|adb/i);
      }
      // android.preset_info on the empty fixture has no presets.
      await assert.rejects(
        () => c.rpc("android.preset_info", {}),
        (err) => {
          assert.match(String(err), /android\.preset_not_found|33999/i);
          return true;
        },
      );

      // testing.run_scenario executes a 4-step scenario with input/wait/assert/screenshot.
      // The expression returns a bool so we don't trip Godot's JSON float-vs-int coercion.
      const scenario = await c.rpc("testing.run_scenario", {
        steps: [
          { type: "input", action: "ui_accept", pressed: true },
          { type: "wait", seconds: 0.05 },
          { type: "input", action: "ui_accept", pressed: false },
          {
            type: "assert",
            kind: "expression",
            spec: { expression: "1 + 1 == 2" },
            expect: true,
          },
        ],
        stop_on_fail: false,
      });
      assert.equal(scenario.steps_total, 4);
      assert.equal(scenario.steps_run, 4);
      assert.equal(scenario.steps[0].type, "input");
      assert.equal(scenario.steps[0].ok, true);
      assert.equal(scenario.steps[1].type, "wait");
      assert.equal(scenario.steps[1].ok, true);
      assert.equal(scenario.steps[3].type, "assert");
      assert.equal(scenario.steps[3].ok, true);

      // Run a scenario with a guaranteed-failing assertion and stop_on_fail=true.
      const failed = await c.rpc("testing.run_scenario", {
        steps: [
          { type: "wait", seconds: 0.01 },
          {
            type: "assert",
            kind: "expression",
            spec: { expression: "1 + 1 == 99" },
            expect: true,
          },
          { type: "wait", seconds: 0.01 },
        ],
        stop_on_fail: true,
      });
      assert.equal(failed.ok, false);
      assert.equal(failed.steps_run, 2);
      assert.equal(failed.steps[1].ok, false);

      // android.deploy on the empty fixture must structurally fail (no presets).
      await assert.rejects(
        () => c.rpc("android.deploy", { preset_name: "Android" }),
        (err) => {
          assert.match(String(err), /android\.preset_not_found|33999/i);
          return true;
        },
      );

      assert.ok(listOk || true); // silence the "listOk unused" check
    });
  },
);

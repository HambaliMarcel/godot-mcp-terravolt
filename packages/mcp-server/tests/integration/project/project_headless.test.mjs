/**
 * Tasklist 11 — headless integration for project.* (docs/tasklist/11 §11.10).
 */
import { strict as assert } from "node:assert";
import { existsSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const minimal3dFixture = join(repoRoot, "tests", "_fixtures", "minimal_3d");
const skip = !godotBinary || !existsSync(minimal3dFixture);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set"
  : `fixture missing: ${minimal3dFixture}`;

test("project.* headless round-trips", { skip: skip && skipReason }, async () => {
  const coordinator = new HeadlessCoordinator(
    headlessConfig(godotBinary, minimal3dFixture),
    () => {},
    import.meta.url,
  );
  try {
    await coordinator.ensureSession(minimal3dFixture);

    const info = await coordinator.rpc("project.info", {});
    assert.equal(info.name, "terravolt-minimal-3d");
    assert.equal(info.main_scene, "res://main.tscn");
    assert.ok(String(info.path_res_dir).length > 0);

    const settings = await coordinator.rpc("project.get_settings", { group: "application/" });
    assert.ok(typeof settings.settings === "object");

    const before = await coordinator.rpc("project.info", {});
    const patched = await coordinator.rpc("project.set_settings", {
      patch: { "application/config/name": "terravolt-dry-run-test" },
      dry_run: true,
    });
    assert.equal(patched.dry_run, true);
    const after = await coordinator.rpc("project.info", {});
    assert.equal(after.name, before.name);

    await assert.rejects(
      () =>
        coordinator.rpc("project.set_main_scene", { path: "res://missing.tscn", validate: true }),
      (err) => {
        assert.match(String(err), /scene\.path_not_found|33500/i);
        return true;
      },
    );
  } finally {
    await coordinator.stop(true);
  }
});

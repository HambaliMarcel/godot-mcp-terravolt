/**
 * Tasklist 15 — headless integration for asset.* and batch_refactor.*.
 */
import { strict as assert } from "node:assert";
import { existsSync, rmSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const fixture = join(repoRoot, "tests", "_fixtures", "asset_zoo");
const skip = !godotBinary || !existsSync(fixture);
const skipReason = !godotBinary ? "TERRAVOLT_GODOT_BINARY not set" : `fixture missing: ${fixture}`;

const PNG_B64 =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADlcEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";

test("asset.* + batch_refactor.* headless round-trips", { skip: skip && skipReason }, async () => {
  const coordinator = new HeadlessCoordinator(
    headlessConfig(godotBinary, fixture),
    () => {},
    import.meta.url,
  );
  const livePath = "res://art/live_icon.png";
  const liveAbs = join(fixture, "art", "live_icon.png");
  rmSync(liveAbs, { force: true });
  try {
    await coordinator.ensureSession(fixture);

    const listed = await coordinator.rpc("asset.list", { kind: "texture" });
    assert.ok(listed.total >= 1);

    await coordinator.rpc("asset.add", {
      path: livePath,
      content_base64: PNG_B64,
      overwrite: true,
    });

    const meta = await coordinator.rpc("asset.metadata", { path: livePath });
    assert.equal(meta.kind, "texture");
    assert.ok(meta.metadata && typeof meta.metadata === "object");

    const unusedBefore = await coordinator.rpc("asset.find_unused", { kind: "texture" });
    assert.ok(Array.isArray(unusedBefore.unused));

    const previewPlan = await coordinator.rpc("batch_refactor.preview", {
      plan: {
        ops: [{ kind: "rename", from: "AssetProbe", to: "AssetProbeRenamed" }],
      },
    });
    assert.ok(String(previewPlan.confirm_token).length > 0);
    assert.ok(previewPlan.total_edits >= 1);

    const replaceDry = await coordinator.rpc("batch_refactor.replace_in_files", {
      pattern: "AssetProbeRenamed",
      replacement: "AssetProbe",
      files: ["**/*.gd"],
      dry_run: true,
    });
    assert.equal(replaceDry.dry_run, true);

    const history = await coordinator.rpc("batch_refactor.history", { limit: 5 });
    assert.ok(Array.isArray(history.history));
  } finally {
    await coordinator.stop(true);
    rmSync(liveAbs, { force: true });
  }
});

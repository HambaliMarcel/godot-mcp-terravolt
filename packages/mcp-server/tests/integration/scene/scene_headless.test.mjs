/**
 * Tasklist 11 — headless integration for scene.* (docs/tasklist/11 §11.10).
 */
import { strict as assert } from "node:assert";
import { existsSync, rmSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const emptyFixture = join(repoRoot, "tests", "_fixtures", "empty");
const minimal3dFixture = join(repoRoot, "tests", "_fixtures", "minimal_3d");
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

test("scene.* headless round-trips", { skip: skip && skipReason }, async () => {
  await withCoordinator(emptyFixture, async (c) => {
    const emptyList = await c.rpc("scene.list", {});
    // The empty fixture ships a friendly placeholder main.tscn so an
    // accidental F5 press in the editor doesn't error with "no main scene
    // defined". scene.list should find exactly that one placeholder.
    assert.ok(Array.isArray(emptyList.scenes));
    assert.equal(emptyList.total, 1, `expected 1 placeholder scene, got ${emptyList.total}`);
    assert.equal(emptyList.scenes[0]?.path, "res://main.tscn");

    await assert.rejects(
      () => c.rpc("scene.get", { path: "res://does_not_exist.tscn" }),
      (err) => {
        assert.match(String(err), /scene\.path_not_found|33500|not found/i);
        return true;
      },
    );

    await assert.rejects(
      () => c.rpc("scene.open", { path: "res://main.tscn" }),
      (err) => {
        assert.match(String(err), /editor\.not_available|33400/i);
        return true;
      },
    );
  });

  if (existsSync(minimal3dFixture)) {
    await withCoordinator(minimal3dFixture, async (c) => {
      const res = await c.rpc("scene.list", {});
      assert.ok(res.total >= 1, `expected >=1 scene, got ${res.total}`);
      assert.ok(res.scenes.some((s) => String(s.path).endsWith("main.tscn")));
    });
  }

  const createdPath = join(emptyFixture, "levels", "TestLevel.tscn");
  const resPath = "res://levels/TestLevel.tscn";
  try {
    await withCoordinator(emptyFixture, async (c) => {
      const created = await c.rpc("scene.create", {
        path: resPath,
        root_type: "Node3D",
        root_name: "TestRoot",
      });
      assert.equal(created.created, true);
      assert.equal(created.path, resPath);

      const meta = await c.rpc("scene.get", { path: resPath });
      assert.equal(meta.path, resPath);
      assert.equal(meta.root_type, "Node3D");
      assert.ok(meta.node_count >= 1);

      const deleted = await c.rpc("scene.delete", { path: resPath });
      assert.equal(deleted.deleted, true);
    });
  } finally {
    rmSync(createdPath, { force: true });
    rmSync(join(emptyFixture, "levels"), { recursive: true, force: true });
  }
});

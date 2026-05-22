/**
 * Tasklist 24 — headless integration for macro.* scaffolders.
 */
import { strict as assert } from "node:assert";
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const fixture = join(repoRoot, "tests", "_fixtures", "macro_zoo");
const skip = !godotBinary || !existsSync(fixture);
const skipReason = !godotBinary ? "TERRAVOLT_GODOT_BINARY not set" : `fixture missing: ${fixture}`;

async function withCoordinator(fn) {
  const coordinator = new HeadlessCoordinator(
    headlessConfig(godotBinary, fixture),
    () => {},
    import.meta.url,
  );
  try {
    await coordinator.ensureSession(fixture);
    return await fn(coordinator);
  } finally {
    await coordinator.stop(true);
  }
}

test(
  "macro.* headless dry_run + player_controller_2d apply",
  { skip: skip && skipReason },
  async () => {
    const playerScript = join(fixture, "scripts", "Hero.gd");
    rmSync(playerScript, { force: true });

    await withCoordinator(async (c) => {
      const mainOriginal = readFileSync(join(fixture, "main.tscn"), "utf8");
      try {
        const dry = await c.rpc("macro.player_controller_2d", {
          dry_run: true,
          name: "Hero",
          with_sprite: true,
          camera: true,
        });
        assert.equal(dry.ok, true);
        assert.equal(dry.dry_run, true);
        assert.ok(dry.ops_applied >= 5);
        assert.ok(Array.isArray(dry.plan?.ops));
        assert.ok(!existsSync(playerScript));

        const applied = await c.rpc("macro.player_controller_2d", {
          name: "Hero",
          with_sprite: true,
          camera: true,
        });
        assert.equal(applied.ok, true);
        assert.equal(applied.dry_run, false);
        assert.ok(applied.ops_applied >= 5);
        assert.ok(String(applied.revert_token).length > 8);
        assert.ok(existsSync(playerScript));
        assert.match(readFileSync(playerScript, "utf8"), /CharacterBody2D/);

        const scene = await c.rpc("scene.get", { path: "res://main.tscn" });
        assert.ok(scene.node_count >= 4);

        const dialogDry = await c.rpc("macro.dialog_system", { dry_run: true });
        assert.equal(dialogDry.dry_run, true);
        assert.ok(dialogDry.ops_applied >= 4);

        await assert.rejects(() => c.rpc("macro.inventory_system", {}));
      } finally {
        rmSync(playerScript, { force: true });
        rmSync(join(fixture, "scripts"), { recursive: true, force: true });
        writeFileSync(join(fixture, "main.tscn"), mainOriginal);
      }
    });
  },
);

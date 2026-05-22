/**
 * Tasklist 18 — headless integration for animation.* and animation_tree.*.
 */
import { strict as assert } from "node:assert";
import { existsSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const animFixture = join(repoRoot, "tests", "_fixtures", "animation_zoo");
const treeFixture = join(repoRoot, "tests", "_fixtures", "animation_tree_zoo");
const skip = !godotBinary || !existsSync(animFixture) || !existsSync(treeFixture);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set"
  : `fixture missing: ${animFixture} or ${treeFixture}`;

test("animation.* headless round-trips", { skip: skip && skipReason }, async () => {
  const coordinator = new HeadlessCoordinator(
    headlessConfig(godotBinary, animFixture),
    () => {},
    import.meta.url,
  );
  try {
    await coordinator.ensureSession(animFixture);

    const listed = await coordinator.rpc("animation.list", { scope: "active" });
    assert.ok(Array.isArray(listed.players));
    assert.ok(listed.players.length >= 1);
    const names = listed.players[0].animations.map((a) => a.name);
    assert.ok(names.includes("idle"));
    assert.ok(names.includes("walk"));

    const created = await coordinator.rpc("animation.create", {
      player_path: "AnimPlayer",
      name: "bow",
      length: 1.5,
    });
    assert.equal(created.created, true);
    assert.equal(created.name, "bow");

    const track = await coordinator.rpc("animation.add_track", {
      player_path: "AnimPlayer",
      animation: "bow",
      track: { type: "position3d", path: "." },
    });
    assert.equal(typeof track.track_index, "number");

    const keys = await coordinator.rpc("animation.set_keyframes", {
      player_path: "AnimPlayer",
      animation: "bow",
      track_index: track.track_index,
      keys: [
        { time: 0, value: [0, 0, 0] },
        { time: 0.5, value: [0, 0, 1] },
        { time: 1, value: [0, 0, 0] },
      ],
    });
    assert.ok(keys.inserted >= 1 || keys.updated >= 1);

    const played = await coordinator.rpc("animation.play", {
      player_path: "AnimPlayer",
      name: "idle",
      action: "play",
    });
    assert.equal(played.done, true);

    await assert.rejects(
      () => coordinator.rpc("animation.preview_export", { player_path: "AnimPlayer", name: "idle" }),
      (err) => {
        assert.match(String(err), /editor\.not_available|33400/i);
        return true;
      },
    );

    await assert.rejects(
      () =>
        coordinator.rpc("animation.create", {
          player_path: "AnimPlayer",
          name: "idle",
        }),
      (err) => {
        assert.match(String(err), /animation\.name_exists|33940/i);
        return true;
      },
    );
  } finally {
    await coordinator.stop(true);
  }
});

test("animation_tree.* headless round-trips", { skip: skip && skipReason }, async () => {
  const coordinator = new HeadlessCoordinator(
    headlessConfig(godotBinary, treeFixture),
    () => {},
    import.meta.url,
  );
  try {
    await coordinator.ensureSession(treeFixture);

    const described = await coordinator.rpc("animation_tree.describe", { tree_path: "AnimTree" });
    assert.equal(described.root_kind, "StateMachine");
    assert.ok(Array.isArray(described.parameters));

    const activated = await coordinator.rpc("animation_tree.set_active", {
      tree_path: "AnimTree",
      active: true,
    });
    assert.equal(activated.active, true);

    const added = await coordinator.rpc("animation_tree.add_state", {
      tree_path: "AnimTree",
      state: { name: "run", animation: "walk", position: [400, 100] },
    });
    assert.equal(added.added, true);

    const transition = await coordinator.rpc("animation_tree.add_transition", {
      tree_path: "AnimTree",
      from: "idle",
      to: "run",
      transition: { xfade_time: 0.2, advance_mode: "enabled" },
    });
    assert.equal(transition.added, true);

    const audit = await coordinator.rpc("animation_tree.blend_audit", { tree_path: "AnimTree" });
    assert.ok(typeof audit.blends === "object");

    const removed = await coordinator.rpc("animation_tree.remove_transition", {
      tree_path: "AnimTree",
      from: "idle",
      to: "run",
    });
    assert.equal(removed.removed, true);
  } finally {
    await coordinator.stop(true);
  }
});

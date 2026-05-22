/**
 * Tasklist 21 — headless integration for audio.* and input.*.
 */
import { strict as assert } from "node:assert";
import { existsSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const audioFixture = join(repoRoot, "tests", "_fixtures", "audio_zoo");
const inputFixture = join(repoRoot, "tests", "_fixtures", "input_zoo");
const skip = !godotBinary || !existsSync(audioFixture) || !existsSync(inputFixture);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set"
  : `fixture missing: ${audioFixture} or ${inputFixture}`;

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

test("audio.* headless round-trips", { skip: skip && skipReason }, async () => {
  await withCoordinator(audioFixture, async (c) => {
    const listed = await c.rpc("audio.list_buses", {});
    assert.ok(Array.isArray(listed.buses));
    assert.ok(listed.buses.length >= 1);
    const names = listed.buses.map((b) => b.name);
    assert.ok(names.includes("Master"));

    await c.rpc("audio.add_bus", { name: "Voice", send_to: "Master" });
    const afterAdd = await c.rpc("audio.list_buses", {});
    assert.ok(afterAdd.buses.some((b) => b.name === "Voice"));

    await c.rpc("audio.add_bus", { name: "SFX", send_to: "Master" });
    await c.rpc("audio.add_bus", { name: "Music", send_to: "Master" });

    await c.rpc("audio.set_bus", { bus: "SFX", patch: { volume_db: -9.0, mute: false } });
    const patched = await c.rpc("audio.list_buses", {});
    const sfx = patched.buses.find((b) => b.name === "SFX");
    assert.ok(sfx);
    assert.equal(sfx.volume_db, -9.0);

    await c.rpc("audio.add_effect", { bus: "Music", kind: "Reverb", params: { room_size: 0.7 } });
    const withFx = await c.rpc("audio.list_buses", {});
    const music = withFx.buses.find((b) => b.name === "Music");
    assert.ok(music?.effects?.length >= 1);

    await c.rpc("audio.remove_bus", { name: "Voice", reassign_sends_to: "Master" });
  });
});

test("input.* headless round-trips", { skip: skip && skipReason }, async () => {
  await withCoordinator(inputFixture, async (c) => {
    const listed = await c.rpc("input.list_actions", { include_builtin: false });
    assert.ok(Array.isArray(listed.actions));
    assert.ok(listed.actions.some((a) => a.name === "custom_fire"));

    await c.rpc("input.add_action", {
      name: "dash",
      deadzone: 0.4,
      events: [{ type: "key", physical_keycode: 4194325 }],
    });
    const afterAdd = await c.rpc("input.list_actions", { include_builtin: false });
    assert.ok(afterAdd.actions.some((a) => a.name === "dash"));

    await c.rpc("input.set_action_events", {
      name: "dash",
      events: [{ type: "key", physical_keycode: 4194326 }],
    });

    await c.rpc("input.simulate_action", {
      action: "custom_fire",
      hold_ms: 10,
      then_release: true,
    });

    const described = await c.rpc("input.describe_event", {
      event: { type: "key", physical_keycode: 70 },
    });
    assert.ok(Array.isArray(described.matched_actions));

    await c.rpc("input.rename_action", { from: "dash", to: "sprint", update_references: false });
    const renamed = await c.rpc("input.list_actions", { include_builtin: false });
    assert.ok(renamed.actions.some((a) => a.name === "sprint"));

    await c.rpc("input.remove_action", { name: "sprint" });
  });
});

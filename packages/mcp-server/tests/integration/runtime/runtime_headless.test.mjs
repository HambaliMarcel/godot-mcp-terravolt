/**
 * Tasklist 17 — headless integration for runtime.* via runtime.start_headless + bridge.
 */
import { strict as assert } from "node:assert";
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const gameFixture = join(repoRoot, "tests", "_fixtures", "minimal_game");
const driverFixture = join(repoRoot, "tests", "_fixtures", "empty");
const addonAutoload = join(repoRoot, "packages", "godot-mcp-addon", "autoloads", "runtime_bridge.gd");
const addonHelpers = join(repoRoot, "packages", "godot-mcp-addon", "handlers", "runtime_helpers.gd");
const fixtureAutoloadDir = join(gameFixture, "autoloads");

function stageRuntimeBridge() {
  mkdirSync(fixtureAutoloadDir, { recursive: true });
  cpSync(addonHelpers, join(fixtureAutoloadDir, "runtime_helpers.gd"));
  const bridgeSrc = readFileSync(addonAutoload, "utf8").replace(
    'preload("../handlers/runtime_helpers.gd")',
    'preload("res://autoloads/runtime_helpers.gd")',
  );
  writeFileSync(join(fixtureAutoloadDir, "runtime_bridge.gd"), bridgeSrc);
}

const skip = !godotBinary || !existsSync(gameFixture) || !existsSync(driverFixture) || !existsSync(addonAutoload);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set"
  : !existsSync(gameFixture)
    ? `fixture missing: ${gameFixture}`
    : !existsSync(driverFixture)
      ? `driver fixture missing: ${driverFixture}`
      : `bridge missing: ${addonAutoload}`;

test("registry lists 19 runtime.* methods", () => {
  const reg = JSON.parse(
    readFileSync(join(repoRoot, "packages", "shared", "methods", "registry.json"), "utf8"),
  );
  const runtime = reg.methods.filter((m) => String(m.method).startsWith("runtime."));
  assert.equal(runtime.length, 19);
});

test("runtime.* headless round-trips", { skip: skip && skipReason }, async () => {
  stageRuntimeBridge();

  const cfg = headlessConfig(godotBinary, driverFixture);
  cfg.headlessOpTimeoutMs = 90_000;
  cfg.headlessBootTimeoutMs = 45_000;
  const coordinator = new HeadlessCoordinator(cfg, () => {}, import.meta.url);
  try {
    await coordinator.ensureSession(driverFixture);

    await assert.rejects(
      () => coordinator.rpc("runtime.list_nodes", {}),
      (err) => {
        assert.match(String(err), /runtime\.no_session|33930/i);
        return true;
      },
    );

    const started = await coordinator.rpc("runtime.start_headless", {
      project_path: gameFixture,
      wait_handshake_ms: 0,
    });
    assert.equal(started.started, true);
    assert.ok(started.pid > 0);
    assert.ok(started.bridge_port > 0);

    const status = await coordinator.rpc("runtime.status", {});
    assert.equal(status.session.alive, true);

    let tree = null;
    for (let i = 0; i < 30; i++) {
      try {
        tree = await coordinator.rpc("runtime.list_nodes", { max_depth: 3 });
        if (tree?.root) break;
      } catch {
        /* bridge still booting */
      }
      await new Promise((r) => setTimeout(r, 1000));
    }
    assert.ok(tree, "runtime.list_nodes did not succeed after polling");
    assert.ok(tree.root);
    assert.ok(tree.total_node_count_estimate >= 1);

    const inspect = await coordinator.rpc("runtime.inspect_node", {
      path: "Main/Player",
      properties: ["speed"],
    });
    assert.equal(inspect.type, "CharacterBody2D");
    assert.ok(inspect.properties);

    const sent = await coordinator.rpc("runtime.send_input", {
      events: [{ type: "action", action: "ui_accept", pressed: true }],
    });
    assert.ok(sent.sent >= 0);

    await coordinator.rpc("runtime.stop", { force: true });
    const after = await coordinator.rpc("runtime.status", {});
    assert.equal(after.session.alive, false);
  } finally {
    await coordinator.stop(true);
    try {
      rmSync(join(fixtureAutoloadDir, "runtime_bridge.gd"), { force: true });
      rmSync(join(fixtureAutoloadDir, "runtime_helpers.gd"), { force: true });
    } catch {
      /* ignore */
    }
  }
});

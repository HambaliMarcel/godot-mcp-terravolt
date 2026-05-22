/**
 * Tasklist 13 — headless integration for script.* and signal.*.
 */
import { strict as assert } from "node:assert";
import { existsSync, rmSync } from "node:fs";
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

test("script.* + signal.graph headless round-trips", { skip: skip && skipReason }, async () => {
  const coordinator = new HeadlessCoordinator(
    headlessConfig(godotBinary, emptyFixture),
    () => {},
    import.meta.url,
  );
  const scriptPath = "res://scripts/Probe.gd";
  const absPath = join(emptyFixture, "scripts", "Probe.gd");
  try {
    await coordinator.ensureSession(emptyFixture);

    const content = "extends Node\n\nsignal probe_fired\n\nfunc ping() -> int:\n\treturn 1\n";
    const written = await coordinator.rpc("script.write", {
      path: scriptPath,
      content,
      mode: "overwrite",
    });
    assert.equal(written.written, true);

    const readBack = await coordinator.rpc("script.read", { path: scriptPath });
    assert.ok(String(readBack.content).includes("probe_fired"));

    const bad = await coordinator.rpc("script.validate", { path: scriptPath });
    assert.equal(bad.ok, true);

    const brokenPath = "res://scripts/Broken.gd";
    await coordinator.rpc("script.write", {
      path: brokenPath,
      content: "extends Node\nfunc broken(\n",
      mode: "overwrite",
    });
    const broken = await coordinator.rpc("script.validate", { path: brokenPath });
    assert.equal(broken.ok, false);
    assert.ok(broken.errors.length >= 1);

    const graph = await coordinator.rpc("signal.graph", { format: "mermaid", scope: "scene" });
    assert.equal(graph.format, "mermaid");
    assert.ok(String(graph.content_string).includes("flowchart"));
  } finally {
    await coordinator.stop(true);
    rmSync(absPath, { force: true });
    rmSync(join(emptyFixture, "scripts", "Broken.gd"), { force: true });
    rmSync(join(emptyFixture, "scripts"), { recursive: true, force: true });
  }
});

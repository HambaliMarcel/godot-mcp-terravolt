/**
 * Tasklist 14 — headless integration for resource.* and shader.*.
 */
import { strict as assert } from "node:assert";
import { existsSync, rmSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const fixture = join(repoRoot, "tests", "_fixtures", "resource_zoo");
const skip = !godotBinary || !existsSync(fixture);
const skipReason = !godotBinary ? "TERRAVOLT_GODOT_BINARY not set" : `fixture missing: ${fixture}`;

test("resource.* + shader.* headless round-trips", { skip: skip && skipReason }, async () => {
  const coordinator = new HeadlessCoordinator(
    headlessConfig(godotBinary, fixture),
    () => {},
    import.meta.url,
  );
  const grassPath = "res://materials/grass_live.tres";
  const grassDryPath = "res://materials/grass_dry.tres";
  const grassAbs = join(fixture, "materials", "grass_live.tres");
  const grassDryAbs = join(fixture, "materials", "grass_dry.tres");
  rmSync(grassAbs, { force: true });
  rmSync(grassDryAbs, { force: true });
  try {
    await coordinator.ensureSession(fixture);

    await coordinator.rpc("resource.create", {
      path: grassPath,
      class: "StandardMaterial3D",
      properties: {
        albedo_color: { __tv: "Color", r: 0.4, g: 0.7, b: 0.3, a: 1 },
      },
    });

    const listed = await coordinator.rpc("resource.list", {});
    assert.ok(listed.total >= 1);

    const got = await coordinator.rpc("resource.get", { path: grassPath });
    assert.equal(got.class, "StandardMaterial3D");

    const exported = await coordinator.rpc("resource.export_json", { path: grassPath });
    assert.ok(exported.hash.length > 0);
    const exported2 = await coordinator.rpc("resource.export_json", { path: grassPath });
    assert.equal(exported.hash, exported2.hash);

    await coordinator.rpc("resource.update", {
      path: grassPath,
      patch: { albedo_color: { __tv: "Color", r: 0.5, g: 0.5, b: 0.5, a: 1 } },
    });

    await coordinator.rpc("resource.duplicate", {
      source_path: grassPath,
      target_path: grassDryPath,
      overwrite: true,
    });

    const diff = await coordinator.rpc("resource.diff", { a: grassPath, b: grassDryPath });
    assert.ok(Array.isArray(diff.diff));

    const valid = await coordinator.rpc("resource.validate", { path: grassPath });
    assert.equal(valid.ok, true);

    const shaders = await coordinator.rpc("shader.list", { kind: "code" });
    assert.ok(shaders.total >= 2);

    const water = await coordinator.rpc("shader.read", { path: "res://shaders/water.gdshader" });
    assert.ok(String(water.content).includes("wave_speed"));

    const goodCompile = await coordinator.rpc("shader.compile_check", {
      path: "res://shaders/water.gdshader",
    });
    assert.equal(goodCompile.ok, true);

    const badCompile = await coordinator.rpc("shader.compile_check", {
      path: "res://shaders/broken.gdshader",
    });
    assert.equal(badCompile.ok, false);
  } finally {
    await coordinator.stop(true);
    rmSync(grassAbs, { force: true });
    rmSync(grassDryAbs, { force: true });
  }
});

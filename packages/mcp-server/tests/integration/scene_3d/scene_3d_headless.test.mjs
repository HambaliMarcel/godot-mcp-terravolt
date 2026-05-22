/**
 * Tasklist 22 — headless integration for scene_3d.*.
 */
import { strict as assert } from "node:assert";
import { existsSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const fixture = join(repoRoot, "tests", "_fixtures", "scene_3d_zoo");
const skip = !godotBinary || !existsSync(fixture);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set"
  : "fixture missing under tests/_fixtures/scene_3d_zoo";

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

test("scene_3d.* headless round-trips", { skip: skip && skipReason }, async () => {
  await withCoordinator(async (c) => {
    const mesh = await c.rpc("scene_3d.add_mesh_instance", {
      parent_path: ".",
      name: "AddedBox",
      transform: { position: { x: 2, y: 0, z: 0 } },
      mesh: {
        source: "primitive",
        primitive_kind: "box",
        primitive_params: { size: { x: 1, y: 1, z: 1 } },
      },
      material: {
        source: "inline",
        inline: { albedo_color: { r: 0.6, g: 0.4, b: 0.2, a: 1 } },
      },
    });
    assert.ok(String(mesh.added_path).includes("AddedBox"));

    const cam = await c.rpc("scene_3d.add_camera", {
      parent_path: ".",
      name: "EyeCam",
      fov: 70,
      current: true,
      transform: { position: { x: 0, y: 3, z: 5 } },
    });
    assert.ok(String(cam.added_path).includes("EyeCam"));
    assert.equal(cam.current, true);

    const light = await c.rpc("scene_3d.add_light", {
      parent_path: ".",
      name: "WarmOmni",
      kind: "omni",
      transform: { position: { x: 0, y: 2, z: 0 } },
      color: { r: 1, g: 0.85, b: 0.7, a: 1 },
      energy: 1.5,
    });
    assert.equal(light.kind, "omni");
    assert.ok(String(light.added_path).includes("WarmOmni"));

    const env1 = await c.rpc("scene_3d.set_environment", {
      spec: {
        background: "sky",
        sky: { kind: "procedural", params: { sky_top_color: { r: 0.4, g: 0.6, b: 1, a: 1 } } },
        tonemap: { mode: "filmic", exposure: 1.0 },
        fog: { enabled: true, density: 0.01 },
      },
    });
    assert.ok(String(env1.environment_path).includes("WorldEnvironment"));

    const env2 = await c.rpc("scene_3d.set_environment", {
      spec: {
        background: "sky",
        sky: { kind: "procedural" },
        tonemap: { mode: "linear" },
      },
    });
    assert.equal(env1.environment_path, env2.environment_path);

    const grid = await c.rpc("scene_3d.add_gridmap", {
      parent_path: ".",
      name: "TestFloor",
      mesh_library_path: "res://blocks.meshlib.tres",
      cell_size: { x: 1, y: 1, z: 1 },
      cells: [
        { position: [0, 0, 0], item: 0 },
        { position: [1, 0, 0], item: 0 },
        { position: [0, 0, 1], item: 0 },
      ],
    });
    assert.equal(grid.cells_written, 3);
    assert.ok(String(grid.added_path).includes("TestFloor"));

    const framed = await c.rpc("scene_3d.frame_subject", {
      camera_path: "MainCamera",
      subjects: ["Crate", mesh.added_path],
      margin: 1.2,
      pitch_deg: -15,
      yaw_deg: 30,
    });
    assert.equal(framed.updated, true);
    assert.ok(framed.framed_aabb?.center);
    assert.ok(framed.applied_transform?.position);
  });
});

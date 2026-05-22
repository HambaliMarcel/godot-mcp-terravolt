/**
 * Tasklist 19 — headless integration for physics.*, particle.*, navigation.*.
 */
import { strict as assert } from "node:assert";
import { existsSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const physicsFixture = join(repoRoot, "tests", "_fixtures", "physics_zoo");
const particleFixture = join(repoRoot, "tests", "_fixtures", "particle_zoo");
const navFixture = join(repoRoot, "tests", "_fixtures", "nav_zoo");
const skip =
  !godotBinary ||
  !existsSync(physicsFixture) ||
  !existsSync(particleFixture) ||
  !existsSync(navFixture);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set"
  : "fixture missing under tests/_fixtures/";

test(
  "physics.* + particle.* + navigation.* headless round-trips",
  { skip: skip && skipReason },
  async () => {
    const coordinator = new HeadlessCoordinator(
      headlessConfig(godotBinary, physicsFixture),
      () => {},
      import.meta.url,
    );
    try {
      await coordinator.ensureSession(physicsFixture);

      await coordinator.rpc("physics.set_layer_name", {
        dimension: "3d",
        index: 1,
        name: "world",
      });
      const layers = await coordinator.rpc("physics.list_layers", { dimension: "both" });
      assert.ok(Array.isArray(layers.layers_3d));

      const body = await coordinator.rpc("physics.add_body", {
        parent_path: "Ground",
        kind: "static",
        dimension: "3d",
        name: "Plate",
        transform: { position: { x: 0, y: 0, z: 0 } },
        shape: { kind: "box", params: { size: { x: 4, y: 0.2, z: 4 } } },
        layer: { named: ["world"] },
        mask: { bits: 1 },
      });
      assert.ok(String(body.added_path).includes("Plate"));

      await coordinator.rpc("physics.set_layers", {
        path: body.added_path,
        layer: { named: ["world"] },
        mask: { bits: 1 },
      });

      const ray = await coordinator.rpc("physics.raycast", {
        dimension: "3d",
        from: { x: 0, y: 2, z: 0 },
        to: { x: 0, y: -2, z: 0 },
        mask: { bits: 0xffff },
      });
      assert.ok(Array.isArray(ray.results));

      const gravity = await coordinator.rpc("physics.set_gravity", {
        dimension: "3d",
        direction: { x: 0, y: -1, z: 0 },
        magnitude: 9.8,
      });
      assert.ok(gravity.after.magnitude > 0);
    } finally {
      await coordinator.stop(true);
    }

    const particleCoord = new HeadlessCoordinator(
      headlessConfig(godotBinary, particleFixture),
      () => {},
      import.meta.url,
    );
    try {
      await particleCoord.ensureSession(particleFixture);

      const presets = await particleCoord.rpc("particle.list_presets", {});
      assert.ok(presets.presets.length >= 5);

      const system = await particleCoord.rpc("particle.add_system", {
        parent_path: ".",
        dimension: "3d",
        name: "Burst",
        amount: 100,
        lifetime: 1.0,
      });
      assert.ok(String(system.system_path).includes("Burst"));

      await particleCoord.rpc("particle.list_presets", {
        apply_to: system.system_path,
        preset_name: "fire",
      });

      const emission = await particleCoord.rpc("particle.set_emission", {
        system_path: system.system_path,
        action: "restart",
      });
      assert.equal(emission.emitting, true);

      const preview = await particleCoord.rpc("particle.preview", {
        system_path: system.system_path,
        duration_s: 0.5,
        fps: 12,
        format: "png_sequence",
      });
      assert.equal(preview.exported, true);
      assert.ok(preview.paths.length >= 1);
    } finally {
      await particleCoord.stop(true);
    }

    const navCoord = new HeadlessCoordinator(
      headlessConfig(godotBinary, navFixture),
      () => {},
      import.meta.url,
    );
    try {
      await navCoord.ensureSession(navFixture);

      await navCoord.rpc("navigation.set_layers", {
        dimension: "3d",
        layer_index: 1,
        layer_name: "walkable",
      });

      const region = await navCoord.rpc("navigation.add_region", {
        parent_path: ".",
        dimension: "3d",
        name: "Walkable",
      });
      assert.ok(String(region.region_path).includes("Walkable"));

      const agent = await navCoord.rpc("navigation.add_agent", {
        parent_path: ".",
        dimension: "3d",
        navigation_layers: 1,
      });
      assert.ok(String(agent.agent_path).includes("NavigationAgent"));

      const baked = await navCoord.rpc("navigation.bake", {
        scope: "all_in_scene",
        cell_size: 0.25,
        agent_radius: 0.5,
      });
      assert.ok(baked.baked >= 1);

      const pathResult = await navCoord.rpc("navigation.path", {
        dimension: "3d",
        from: { x: -5, y: 0.5, z: 0 },
        to: { x: 5, y: 0.5, z: 0 },
        layers: 1,
        optimize: true,
      });
      assert.ok(Array.isArray(pathResult.path));

      const overlay = await navCoord.rpc("navigation.debug_overlay", { enabled: true });
      assert.equal(overlay.enabled, true);
    } finally {
      await navCoord.stop(true);
    }
  },
);

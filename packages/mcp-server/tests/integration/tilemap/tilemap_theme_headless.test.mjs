/**
 * Tasklist 20 — headless integration for tilemap.* and theme_ui.*.
 */
import { strict as assert } from "node:assert";
import { existsSync, rmSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const tilemapFixture = join(repoRoot, "tests", "_fixtures", "tilemap_zoo");
const themeFixture = join(repoRoot, "tests", "_fixtures", "theme_zoo");
const skip = !godotBinary || !existsSync(tilemapFixture) || !existsSync(themeFixture);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set"
  : `fixture missing: ${tilemapFixture} or ${themeFixture}`;

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

test("tilemap.* + theme_ui.* headless round-trips", { skip: skip && skipReason }, async () => {
  await withCoordinator(tilemapFixture, async (c) => {
    const desc = await c.rpc("tilemap.describe", { path: "MapLayer" });
    assert.equal(desc.kind, "tilemaplayer");
    assert.ok(desc.used_rect);

    const tsInfo = await c.rpc("tilemap.tileset_info", { tileset_path: "res://tileset.tres" });
    assert.ok(tsInfo.sources.length >= 1);
    assert.equal(tsInfo.tile_size.w, 16);

    await c.rpc("tilemap.fill", {
      path: "MapLayer",
      rect: { x: 0, y: 0, w: 4, h: 4 },
      source_id: 0,
      atlas_coords: [0, 0],
    });

    const queried = await c.rpc("tilemap.query_cells", {
      path: "MapLayer",
      rect: { x: 0, y: 0, w: 4, h: 4 },
    });
    assert.equal(queried.cells.length, 16);
    for (const cell of queried.cells) {
      assert.deepEqual(cell.atlas_coords, [0, 0]);
      assert.equal(cell.source_id, 0);
    }
  });

  const pauseOut = join(themeFixture, "ui", "PauseMenu.tscn");
  const pauseRes = "res://ui/PauseMenu.tscn";
  rmSync(pauseOut, { force: true });

  await withCoordinator(themeFixture, async (c) => {
    const themeDesc = await c.rpc("theme_ui.describe", { theme_path: "res://ui/main_theme.tres" });
    assert.equal(themeDesc.kind, "theme");
    assert.ok(Object.keys(themeDesc.styles).length >= 1);

    await c.rpc("theme_ui.set_color", {
      target: { theme_path: "res://ui/main_theme.tres" },
      type: "Button",
      name: "font_color",
      value: { r: 1, g: 0.9, b: 0.8, a: 1 },
    });

    const afterColor = await c.rpc("theme_ui.describe", { theme_path: "res://ui/main_theme.tres" });
    const key = "Button/font_color";
    assert.ok(afterColor.colors[key]);

    await c.rpc("theme_ui.set_color", {
      target: { control_path: "PlayButton" },
      type: "Button",
      name: "font_color",
      value: "#FFEECCFF",
    });
    const ctrlDesc = await c.rpc("theme_ui.describe", { control_path: "PlayButton" });
    assert.equal(ctrlDesc.kind, "control_overrides");

    const preview = await c.rpc("theme_ui.preview", {
      theme_path: "res://ui/main_theme.tres",
      size: { w: 256, h: 256 },
    });
    assert.equal(preview.mime, "image/png");
    assert.ok(String(preview.image_base64).length > 100);
    assert.ok(preview.widgets_rendered.length >= 1);

    const scaffold = await c.rpc("theme_ui.scaffold_screen", {
      output_path: pauseRes,
      kind: "pause",
      theme_path: "res://ui/main_theme.tres",
      options: { title: "Paused" },
    });
    assert.equal(scaffold.created, true);

    const sceneMeta = await c.rpc("scene.get", { path: pauseRes });
    assert.ok(sceneMeta.node_count >= 2);
  });

  rmSync(pauseOut, { force: true });
});

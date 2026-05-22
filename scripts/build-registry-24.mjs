#!/usr/bin/env node
/** Tasklist 24 — macro.* (15 scaffolders) */
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

const root = findTerravoltRepoRoot(import.meta.url);
const regPath = join(root, "packages", "shared", "methods", "registry.json");
const existing = JSON.parse(readFileSync(regPath, "utf8"));

function tool(name, desc, inputSchema, opts = {}) {
  return {
    method: name,
    category: "macro",
    since: "0.16.0",
    description: desc,
    inputSchema,
    outputSchema: { type: "object" },
    mcpTool: { name, title: name, description: desc },
    requiresEditor: opts.requiresEditor ?? false,
    requiresRuntime: opts.requiresRuntime ?? false,
    safe: opts.safe ?? false,
    mutates: opts.mutates ?? true,
    errorCodes: opts.errorCodes ?? [
      "macro.not_implemented",
      "macro.ops_limit",
      "macro.file_exists",
    ],
    examples: opts.examples ?? [],
    headlessFallback: opts.headlessFallback ?? true,
  };
}

const common = {
  dry_run: { type: "boolean" },
  confirm_high_risk: { type: "boolean" },
  scene_path: { type: "string" },
};

const methods = [
  tool("macro.player_controller_2d", "Scaffold a 2D platformer player.", {
    type: "object",
    properties: {
      ...common,
      name: { type: "string" },
      with_sprite: { type: "boolean" },
      camera: { type: "boolean" },
      animation_set: { type: "string" },
      input_actions: { type: "array" },
    },
    additionalProperties: false,
  }),
  tool("macro.player_controller_3d", "Scaffold a 3D first/third-person player.", {
    type: "object",
    properties: {
      ...common,
      name: { type: "string" },
      perspective: { type: "string" },
      with_mesh: { type: "boolean" },
      camera_offset: { type: "object" },
      with_jump: { type: "boolean" },
      input_actions: { type: "array" },
    },
    additionalProperties: false,
  }),
  tool("macro.enemy_with_state_machine", "Scaffold an enemy with patrol/chase states.", {
    type: "object",
    properties: {
      ...common,
      name: { type: "string" },
      dimension: { type: "string" },
      patrol_radius: { type: "number" },
      aggro_radius: { type: "number" },
      attack_range: { type: "number" },
      health: { type: "integer" },
    },
    additionalProperties: false,
  }),
  tool("macro.enemy_wave_spawner", "Scaffold a wave spawner.", {
    type: "object",
    required: ["enemy_scene_path"],
    properties: {
      ...common,
      enemy_scene_path: { type: "string" },
      spawn_points: { type: "array" },
      wave_count: { type: "integer" },
      base_enemies: { type: "integer" },
      scale_per_wave: { type: "number" },
      between_wave_pause_s: { type: "number" },
    },
    additionalProperties: false,
  }),
  tool("macro.dialog_system", "Scaffold a dialog UI system.", {
    type: "object",
    properties: {
      ...common,
      theme_path: { type: "string" },
      with_portrait: { type: "boolean" },
      with_choices: { type: "boolean" },
      typewriter_chars_per_s: { type: "integer" },
    },
    additionalProperties: false,
  }),
  tool("macro.inventory_system", "Scaffold an inventory UI.", {
    type: "object",
    properties: {
      ...common,
      slot_count: { type: "integer" },
      stackable: { type: "boolean" },
      with_drag_drop: { type: "boolean" },
      theme_path: { type: "string" },
    },
    additionalProperties: false,
  }),
  tool("macro.save_load_system", "Scaffold save/load slots.", {
    type: "object",
    properties: {
      dry_run: { type: "boolean" },
      confirm_high_risk: { type: "boolean" },
      scope: { type: "string" },
      slot_count: { type: "integer" },
      include_screenshot: { type: "boolean" },
    },
    additionalProperties: false,
  }),
  tool("macro.settings_menu", "Scaffold a settings menu scene.", {
    type: "object",
    properties: {
      dry_run: { type: "boolean" },
      confirm_high_risk: { type: "boolean" },
      theme_path: { type: "string" },
      output_path: { type: "string" },
      categories: { type: "array" },
      bind_to_main_menu: { type: "string" },
    },
    additionalProperties: false,
  }),
  tool("macro.main_menu", "Scaffold a main menu scene.", {
    type: "object",
    properties: {
      dry_run: { type: "boolean" },
      confirm_high_risk: { type: "boolean" },
      theme_path: { type: "string" },
      output_path: { type: "string" },
      with_continue: { type: "boolean" },
      with_credits: { type: "boolean" },
      start_scene_path: { type: "string" },
    },
    additionalProperties: false,
  }),
  tool("macro.pause_overlay", "Scaffold a pause overlay.", {
    type: "object",
    properties: { ...common, theme_path: { type: "string" }, options: { type: "array" } },
    additionalProperties: false,
  }),
  tool("macro.hud_health_score", "Scaffold HUD health/score widgets.", {
    type: "object",
    properties: { ...common, player_path: { type: "string" }, theme_path: { type: "string" } },
    additionalProperties: false,
  }),
  tool("macro.day_night_cycle", "Scaffold a day/night cycle controller.", {
    type: "object",
    properties: {
      ...common,
      duration_s: { type: "number" },
      start_hour: { type: "number" },
      with_fog: { type: "boolean" },
    },
    additionalProperties: false,
  }),
  tool("macro.basic_2d_level", "Scaffold a basic 2D level scene.", {
    type: "object",
    required: ["output_path"],
    properties: {
      dry_run: { type: "boolean" },
      confirm_high_risk: { type: "boolean" },
      output_path: { type: "string" },
      with_parallax: { type: "boolean" },
      tileset_path: { type: "string" },
      level_width_tiles: { type: "integer" },
      level_height_tiles: { type: "integer" },
    },
    additionalProperties: false,
  }),
  tool("macro.basic_3d_level", "Scaffold a basic 3D level scene.", {
    type: "object",
    required: ["output_path"],
    properties: {
      dry_run: { type: "boolean" },
      confirm_high_risk: { type: "boolean" },
      output_path: { type: "string" },
      mesh_library_path: { type: "string" },
      with_sky: { type: "boolean" },
      size_meters: { type: "number" },
    },
    additionalProperties: false,
  }),
  tool("macro.localization_setup", "Scaffold localization tables and wiring.", {
    type: "object",
    properties: {
      dry_run: { type: "boolean" },
      confirm_high_risk: { type: "boolean" },
      locales: { type: "array" },
      table_path: { type: "string" },
      wire_into_ui_root: { type: "string" },
    },
    additionalProperties: false,
  }),
];

const kept = existing.methods.filter((m) => !String(m.method).startsWith("macro."));
const out = { catalog_version: "0.16.0", methods: [...kept, ...methods] };
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`build-registry-24: ${out.methods.length} methods @ ${out.catalog_version}`);

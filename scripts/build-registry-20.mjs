#!/usr/bin/env node
/**
 * Build packages/shared/methods/registry.json entries for tasklist 20 (tilemap.* + theme_ui.*).
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

const root = findTerravoltRepoRoot(import.meta.url);
const regPath = join(root, "packages", "shared", "methods", "registry.json");
const existing = JSON.parse(readFileSync(regPath, "utf8"));

const np = { type: "string", minLength: 1 };
const nodePath = { type: "string", minLength: 1 };

function tool(name, category, desc, inputSchema, opts = {}) {
  return {
    method: name,
    category,
    since: "0.12.0",
    description: desc,
    inputSchema,
    outputSchema: { type: "object" },
    mcpTool: { name, title: name, description: desc },
    requiresEditor: opts.requiresEditor ?? false,
    requiresRuntime: opts.requiresRuntime ?? false,
    safe: opts.safe ?? false,
    mutates: opts.mutates ?? false,
    errorCodes: opts.errorCodes ?? [],
    examples: opts.examples ?? [],
    headlessFallback: opts.headlessFallback ?? true,
  };
}

const tilemapMethods = [
  tool(
    "tilemap.describe",
    "tilemap",
    "Describe a TileMapLayer or legacy TileMap (tileset, layers, used rect, atlas sources).",
    {
      type: "object",
      required: ["path"],
      properties: { path: nodePath },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "tilemap.set_cells",
    "tilemap",
    "Set or clear cells in bulk on a tilemap layer.",
    {
      type: "object",
      required: ["path", "cells"],
      properties: {
        path: nodePath,
        layer_name: { type: "string" },
        cells: { type: "array" },
        if_match: {},
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      errorCodes: [
        "tilemap.cell_batch_too_large",
        "tilemap.atlas_unknown",
        "tilemap.layer_unknown",
      ],
    },
  ),
  tool(
    "tilemap.fill",
    "tilemap",
    "Fill a rectangle or polygon with one tile.",
    {
      type: "object",
      required: ["path", "source_id", "atlas_coords"],
      properties: {
        path: nodePath,
        layer_name: { type: "string" },
        rect: { type: "object" },
        polygon: { type: "array" },
        source_id: { type: "integer" },
        atlas_coords: { type: "array" },
        alternative_id: { type: "integer" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["tilemap.cell_batch_too_large"] },
  ),
  tool(
    "tilemap.query_cells",
    "tilemap",
    "Read tiles in a region or the used rect.",
    {
      type: "object",
      required: ["path"],
      properties: {
        path: nodePath,
        layer_name: { type: "string" },
        rect: { type: "object" },
        used_rect_only: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "tilemap.tileset_info",
    "tilemap",
    "Describe a TileSet resource (sources, terrains, custom data).",
    {
      type: "object",
      required: ["tileset_path"],
      properties: { tileset_path: np },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "tilemap.terrain_paint",
    "tilemap",
    "Paint cells using terrain auto-tiling.",
    {
      type: "object",
      required: ["path", "cells", "terrain_set", "terrain"],
      properties: {
        path: nodePath,
        layer_name: { type: "string" },
        cells: { type: "array" },
        terrain_set: { type: "integer" },
        terrain: { type: "integer" },
        ignore_empty_terrains: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["tilemap.terrain_unknown", "tilemap.cell_batch_too_large"] },
  ),
];

const themeUiMethods = [
  tool(
    "theme_ui.describe",
    "theme_ui",
    "Describe a Theme resource or per-Control theme overrides.",
    {
      type: "object",
      properties: { theme_path: np, control_path: nodePath },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "theme_ui.set_color",
    "theme_ui",
    "Set a theme color on a Theme resource or Control override.",
    {
      type: "object",
      required: ["target", "type", "name", "value"],
      properties: {
        target: {
          type: "object",
          properties: { theme_path: np, control_path: nodePath },
          additionalProperties: false,
        },
        type: { type: "string" },
        name: { type: "string" },
        value: {},
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["theme.target_missing"] },
  ),
  tool(
    "theme_ui.set_font",
    "theme_ui",
    "Set default or per-type font on a Theme or Control.",
    {
      type: "object",
      required: ["target", "font_path"],
      properties: {
        target: {
          type: "object",
          properties: { theme_path: np, control_path: nodePath },
          additionalProperties: false,
        },
        type: { type: "string" },
        name: { type: "string" },
        font_path: np,
        size: { type: "integer" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["theme.target_missing", "theme.font_load_failed"] },
  ),
  tool(
    "theme_ui.set_stylebox",
    "theme_ui",
    "Define or replace a StyleBox on a Theme or Control.",
    {
      type: "object",
      required: ["target", "type", "name", "stylebox"],
      properties: {
        target: {
          type: "object",
          properties: { theme_path: np, control_path: nodePath },
          additionalProperties: false,
        },
        type: { type: "string" },
        name: { type: "string" },
        stylebox: { type: "object" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["theme.target_missing", "theme.stylebox_invalid"] },
  ),
  tool(
    "theme_ui.preview",
    "theme_ui",
    "Generate a PNG preview of a theme on sample widgets.",
    {
      type: "object",
      required: ["theme_path"],
      properties: {
        theme_path: np,
        widgets: { type: "array" },
        size: { type: "object" },
      },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["theme.preview_failed"] },
  ),
  tool(
    "theme_ui.scaffold_screen",
    "theme_ui",
    "Scaffold a UI screen scene from a preset kind (title, settings, hud, pause, etc.).",
    {
      type: "object",
      required: ["output_path", "kind"],
      properties: {
        output_path: np,
        kind: { type: "string" },
        theme_path: np,
        options: { type: "object" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
];

const kept = existing.methods.filter(
  (m) => !String(m.method).startsWith("tilemap.") && !String(m.method).startsWith("theme_ui."),
);
const out = {
  catalog_version: "0.12.0",
  methods: [...kept, ...tilemapMethods, ...themeUiMethods],
};
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`Wrote ${out.methods.length} methods (catalog ${out.catalog_version})`);

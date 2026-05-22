#!/usr/bin/env node
/**
 * Build packages/shared/methods/registry.json entries for tasklist 19
 * (physics.* + particle.* + navigation.*).
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

const root = findTerravoltRepoRoot(import.meta.url);
const regPath = join(root, "packages", "shared", "methods", "registry.json");
const existing = JSON.parse(readFileSync(regPath, "utf8"));

const np = { type: "string", minLength: 1 };
const rp = { type: "string", minLength: 1, pattern: "^(res://|user://|/|[A-Za-z]:)" };

function tool(name, category, desc, inputSchema, opts = {}) {
  return {
    method: name,
    category,
    since: "0.11.0",
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

const physicsMethods = [
  tool(
    "physics.add_body",
    "physics",
    "Add a physics body node with optional collision shape under a parent.",
    {
      type: "object",
      required: ["parent_path", "kind", "dimension"],
      properties: {
        parent_path: np,
        kind: { type: "string" },
        dimension: { type: "string" },
        name: { type: "string" },
        transform: { type: "object" },
        shape: { type: "object" },
        mass: { type: "number" },
        gravity_scale: { type: "number" },
        layer: { type: "object" },
        mask: { type: "object" },
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      errorCodes: ["physics.shape_kind_unknown", "physics.dimension_mismatch"],
    },
  ),
  tool(
    "physics.set_layers",
    "physics",
    "Set collision layer and mask on a physics body.",
    {
      type: "object",
      required: ["path"],
      properties: { path: np, layer: {}, mask: {} },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["physics.dimension_mismatch"] },
  ),
  tool(
    "physics.list_layers",
    "physics",
    "List named physics layers from ProjectSettings.",
    {
      type: "object",
      properties: { dimension: { type: "string" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "physics.set_layer_name",
    "physics",
    "Name or rename a physics layer index (1..32).",
    {
      type: "object",
      required: ["dimension", "index", "name"],
      properties: {
        dimension: { type: "string" },
        index: { type: "integer" },
        name: { type: "string" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "physics.raycast",
    "physics",
    "Cast one or more rays against the live physics space.",
    {
      type: "object",
      required: ["dimension"],
      properties: {
        dimension: { type: "string" },
        from: { type: "object" },
        to: { type: "object" },
        mask: {},
        exclude: { type: "array" },
        hit_areas: { type: "boolean" },
        batch: { type: "array" },
      },
      additionalProperties: false,
    },
    { safe: true, requiresRuntime: true, errorCodes: ["physics.batch_too_large"] },
  ),
  tool(
    "physics.set_gravity",
    "physics",
    "Set global gravity vector and magnitude for 2D or 3D.",
    {
      type: "object",
      required: ["dimension"],
      properties: {
        dimension: { type: "string" },
        direction: { type: "object" },
        magnitude: { type: "number" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
];

const particleMethods = [
  tool(
    "particle.add_system",
    "particle",
    "Add a GPU or CPU particle system under a parent.",
    {
      type: "object",
      required: ["parent_path", "dimension"],
      properties: {
        parent_path: np,
        dimension: { type: "string" },
        use_gpu: { type: "boolean" },
        name: { type: "string" },
        transform: { type: "object" },
        amount: { type: "integer" },
        lifetime: { type: "number" },
        emitting: { type: "boolean" },
        material: { type: "object" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["particle.gpu_unsupported"] },
  ),
  tool(
    "particle.set_material",
    "particle",
    "Patch properties on a ParticleProcessMaterial resource.",
    {
      type: "object",
      required: ["material_path", "patch"],
      properties: { material_path: rp, patch: { type: "object" }, if_match: {} },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["protocol.idempotency_conflict", "resource.path_not_found"] },
  ),
  tool(
    "particle.preview",
    "particle",
    "Render a short preview of a particle system.",
    {
      type: "object",
      required: ["system_path"],
      properties: {
        system_path: np,
        duration_s: { type: "number" },
        fps: { type: "integer" },
        format: { type: "string" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "particle.set_emission",
    "particle",
    "Start, stop, restart, or one-shot emit a particle system.",
    {
      type: "object",
      required: ["system_path", "action"],
      properties: {
        system_path: np,
        action: { type: "string" },
        amount: { type: "integer" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "particle.list_presets",
    "particle",
    "Enumerate particle presets and optionally apply one.",
    {
      type: "object",
      properties: { apply_to: np, preset_name: { type: "string" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["asset.preset_unknown"] },
  ),
];

const navigationMethods = [
  tool(
    "navigation.add_region",
    "navigation",
    "Add a NavigationRegion2D/3D with navmesh resource.",
    {
      type: "object",
      required: ["parent_path", "dimension"],
      properties: {
        parent_path: np,
        dimension: { type: "string" },
        name: { type: "string" },
        transform: { type: "object" },
        navmesh: { type: "object" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "navigation.bake",
    "navigation",
    "Bake navigation mesh for a region or all regions in the scene.",
    {
      type: "object",
      properties: {
        region_path: np,
        scope: { type: "string" },
        cell_size: { type: "number" },
        agent_radius: { type: "number" },
        agent_height: { type: "number" },
        max_slope_deg: { type: "number" },
        edge_max_length: { type: "number" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["navigation.bake_timeout"] },
  ),
  tool(
    "navigation.add_agent",
    "navigation",
    "Add a NavigationAgent2D/3D child to a body.",
    {
      type: "object",
      required: ["parent_path", "dimension"],
      properties: {
        parent_path: np,
        dimension: { type: "string" },
        path_max_distance: { type: "number" },
        target_desired_distance: { type: "number" },
        radius: { type: "number" },
        navigation_layers: { type: "integer" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "navigation.set_layers",
    "navigation",
    "Rename navigation layers and assign navigation_layers on agents.",
    {
      type: "object",
      properties: {
        dimension: { type: "string" },
        layer_index: { type: "integer" },
        layer_name: { type: "string" },
        target_path: np,
        navigation_layers: { type: "integer" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "navigation.path",
    "navigation",
    "Compute a navigation path between two points.",
    {
      type: "object",
      required: ["dimension", "from", "to"],
      properties: {
        dimension: { type: "string" },
        from: { type: "object" },
        to: { type: "object" },
        layers: { type: "integer" },
        optimize: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { safe: true, requiresRuntime: true },
  ),
  tool(
    "navigation.debug_overlay",
    "navigation",
    "Toggle navigation debug overlay at runtime.",
    {
      type: "object",
      required: ["enabled"],
      properties: { enabled: { type: "boolean" }, scope: { type: "string" } },
      additionalProperties: false,
    },
    { mutates: true },
  ),
];

const kept = existing.methods.filter(
  (m) =>
    !String(m.method).startsWith("physics.") &&
    !String(m.method).startsWith("particle.") &&
    !String(m.method).startsWith("navigation."),
);
const out = {
  catalog_version: "0.11.0",
  methods: [...kept, ...physicsMethods, ...particleMethods, ...navigationMethods],
};
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`Wrote ${out.methods.length} methods (catalog ${out.catalog_version})`);

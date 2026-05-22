#!/usr/bin/env node
/**
 * Build packages/shared/methods/registry.json entries for tasklist 22 (scene_3d.*).
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
    since: "0.14.0",
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

const scene3dMethods = [
  tool(
    "scene_3d.add_mesh_instance",
    "scene_3d",
    "Add a MeshInstance3D with optional primitive or resource mesh and material.",
    {
      type: "object",
      required: ["parent_path"],
      properties: {
        parent_path: nodePath,
        name: { type: "string" },
        transform: { type: "object" },
        mesh: { type: "object" },
        material: { type: "object" },
        cast_shadow: { type: "string" },
        gi_mode: { type: "string" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["scene_3d.primitive_unknown"] },
  ),
  tool(
    "scene_3d.add_camera",
    "scene_3d",
    "Add a Camera3D with perspective/orthogonal/frustum projection and optional current toggle.",
    {
      type: "object",
      required: ["parent_path"],
      properties: {
        parent_path: nodePath,
        name: { type: "string" },
        transform: { type: "object" },
        fov: { type: "number" },
        near: { type: "number" },
        far: { type: "number" },
        projection: { type: "string" },
        current: { type: "boolean" },
        cull_mask: {},
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "scene_3d.add_light",
    "scene_3d",
    "Add a directional, omni, or spot light with shadow and bake configuration.",
    {
      type: "object",
      required: ["parent_path", "kind"],
      properties: {
        parent_path: nodePath,
        name: { type: "string" },
        transform: { type: "object" },
        kind: { type: "string" },
        color: {},
        energy: { type: "number" },
        shadow_enabled: { type: "boolean" },
        bake_mode: { type: "string" },
        range: { type: "number" },
        angle_deg: { type: "number" },
        inner_angle_deg: { type: "number" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "scene_3d.set_environment",
    "scene_3d",
    "Add or update a WorldEnvironment (sky, fog, ambient, tonemap, glow, SSAO, SSR).",
    {
      type: "object",
      required: ["spec"],
      properties: {
        scene_root_path: nodePath,
        spec: { type: "object" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "scene_3d.add_gridmap",
    "scene_3d",
    "Add a GridMap with a MeshLibrary and optionally seeded cells.",
    {
      type: "object",
      required: ["parent_path", "mesh_library_path"],
      properties: {
        parent_path: nodePath,
        name: { type: "string" },
        transform: { type: "object" },
        mesh_library_path: np,
        cell_size: { type: "object" },
        cells: { type: "array" },
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      errorCodes: ["scene_3d.mesh_library_unknown", "scene_3d.gridmap_cells_invalid"],
    },
  ),
  tool(
    "scene_3d.frame_subject",
    "scene_3d",
    "Position a camera to frame one or more subjects using their combined global AABB.",
    {
      type: "object",
      required: ["camera_path", "subjects"],
      properties: {
        camera_path: nodePath,
        subjects: { type: "array" },
        margin: { type: "number" },
        pitch_deg: { type: "number" },
        yaw_deg: { type: "number" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
];

const kept = existing.methods.filter((m) => !String(m.method).startsWith("scene_3d."));
const out = {
  catalog_version: "0.14.0",
  methods: [...kept, ...scene3dMethods],
};
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`Wrote ${out.methods.length} methods (catalog ${out.catalog_version})`);

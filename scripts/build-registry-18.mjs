#!/usr/bin/env node
/**
 * Build packages/shared/methods/registry.json entries for tasklist 18 (animation.* + animation_tree.*).
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

const root = findTerravoltRepoRoot(import.meta.url);
const regPath = join(root, "packages", "shared", "methods", "registry.json");
const existing = JSON.parse(readFileSync(regPath, "utf8"));

const np = { type: "string", minLength: 1 };

function tool(name, category, desc, inputSchema, opts = {}) {
  return {
    method: name,
    category,
    since: "0.10.0",
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

const animationMethods = [
  tool(
    "animation.list",
    "animation",
    "List AnimationPlayer nodes and their animations in a scene or project.",
    {
      type: "object",
      properties: { scope: { type: "string" }, scene_path: np },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "animation.create",
    "animation",
    "Create a new Animation in an AnimationPlayer library.",
    {
      type: "object",
      required: ["player_path", "name"],
      properties: {
        player_path: np,
        library: { type: "string" },
        name: { type: "string" },
        length: { type: "number" },
        step: { type: "number" },
        loop_mode: { type: "string" },
        scene_path: np,
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["animation.name_exists"] },
  ),
  tool(
    "animation.add_track",
    "animation",
    "Add a track to an animation on an AnimationPlayer.",
    {
      type: "object",
      required: ["player_path", "animation", "track"],
      properties: {
        player_path: np,
        animation: { type: "string" },
        library: { type: "string" },
        track: { type: "object" },
        index: { type: "integer" },
        scene_path: np,
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      errorCodes: ["animation.unknown", "animation.track_kind_unknown"],
    },
  ),
  tool(
    "animation.set_keyframes",
    "animation",
    "Insert or replace keyframes on an animation track.",
    {
      type: "object",
      required: ["player_path", "animation", "track_index", "keys"],
      properties: {
        player_path: np,
        animation: { type: "string" },
        library: { type: "string" },
        track_index: { type: "integer" },
        keys: { type: "array" },
        mode: { type: "string" },
        scene_path: np,
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["animation.unknown"] },
  ),
  tool(
    "animation.play",
    "animation",
    "Play, queue, pause, or stop an animation on an AnimationPlayer.",
    {
      type: "object",
      required: ["player_path"],
      properties: {
        player_path: np,
        name: { type: "string" },
        library: { type: "string" },
        action: { type: "string" },
        custom_blend: { type: "number" },
        from_end: { type: "boolean" },
        scene_path: np,
      },
      additionalProperties: false,
    },
    { mutates: true, requiresRuntime: true, errorCodes: ["animation.unknown"] },
  ),
  tool(
    "animation.preview_export",
    "animation",
    "Export an animation preview (GIF/MP4 best-effort; PNG sequence fallback).",
    {
      type: "object",
      required: ["player_path", "name"],
      properties: {
        player_path: np,
        name: { type: "string" },
        format: { type: "string" },
        fps: { type: "integer" },
        duration_s: { type: "number" },
        scene_path: np,
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      requiresEditor: true,
      headlessFallback: false,
      errorCodes: ["animation.exporter_missing", "animation.unknown"],
    },
  ),
];

const animationTreeMethods = [
  tool(
    "animation_tree.describe",
    "animation_tree",
    "Describe an AnimationTree root, states, transitions, and parameters.",
    {
      type: "object",
      required: ["tree_path"],
      properties: { tree_path: np, scene_path: np },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "animation_tree.set_active",
    "animation_tree",
    "Enable or disable AnimationTree processing.",
    {
      type: "object",
      required: ["tree_path", "active"],
      properties: { tree_path: np, active: { type: "boolean" }, scene_path: np },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "animation_tree.set_parameter",
    "animation_tree",
    "Set a blend parameter or travel/advance a state-machine playback.",
    {
      type: "object",
      required: ["tree_path", "parameter", "value"],
      properties: {
        tree_path: np,
        parameter: { type: "string" },
        value: {},
        mode: { type: "string" },
        scene_path: np,
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["animation_tree.parameter_unknown"] },
  ),
  tool(
    "animation_tree.add_state",
    "animation_tree",
    "Add a state to a StateMachine AnimationTree root.",
    {
      type: "object",
      required: ["tree_path", "state"],
      properties: { tree_path: np, state: { type: "object" }, scene_path: np },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["animation_tree.state_exists"] },
  ),
  tool(
    "animation_tree.remove_state",
    "animation_tree",
    "Remove a state from a StateMachine root.",
    {
      type: "object",
      required: ["tree_path", "name"],
      properties: { tree_path: np, name: { type: "string" }, scene_path: np },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["animation_tree.state_unknown"] },
  ),
  tool(
    "animation_tree.add_transition",
    "animation_tree",
    "Add a transition between two states in a StateMachine.",
    {
      type: "object",
      required: ["tree_path", "from", "to", "transition"],
      properties: {
        tree_path: np,
        from: { type: "string" },
        to: { type: "string" },
        transition: { type: "object" },
        scene_path: np,
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "animation_tree.remove_transition",
    "animation_tree",
    "Remove a transition between two states.",
    {
      type: "object",
      required: ["tree_path", "from", "to"],
      properties: {
        tree_path: np,
        from: { type: "string" },
        to: { type: "string" },
        scene_path: np,
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "animation_tree.blend_audit",
    "animation_tree",
    "Snapshot blend weights and active state-machine transition progress.",
    {
      type: "object",
      required: ["tree_path"],
      properties: { tree_path: np, scene_path: np },
      additionalProperties: false,
    },
    { safe: true, requiresRuntime: true },
  ),
];

const kept = existing.methods.filter(
  (m) =>
    !String(m.method).startsWith("animation.") && !String(m.method).startsWith("animation_tree."),
);
const out = {
  catalog_version: "0.10.0",
  methods: [...kept, ...animationMethods, ...animationTreeMethods],
};
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`Wrote ${out.methods.length} methods (catalog ${out.catalog_version})`);

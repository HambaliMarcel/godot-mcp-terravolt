#!/usr/bin/env node
/**
 * Build packages/shared/methods/registry.json entries for tasklist 21 (audio.* + input.*).
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
    since: "0.13.0",
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

const audioMethods = [
  tool(
    "audio.list_buses",
    "audio",
    "Describe the AudioServer bus layout.",
    { type: "object", properties: {}, additionalProperties: false },
    { safe: true },
  ),
  tool(
    "audio.add_bus",
    "audio",
    "Add an audio bus.",
    {
      type: "object",
      required: ["name"],
      properties: { name: np, send_to: { type: "string" }, index: { type: "integer" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["audio.bus_name_exists"] },
  ),
  tool(
    "audio.remove_bus",
    "audio",
    "Remove an audio bus and optionally reassign sends.",
    {
      type: "object",
      properties: { name: np, index: { type: "integer" }, reassign_sends_to: { type: "string" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["audio.bus_unknown", "audio.cannot_remove_master"] },
  ),
  tool(
    "audio.set_bus",
    "audio",
    "Patch bus volume, mute, solo, bypass, or send target.",
    {
      type: "object",
      required: ["bus", "patch"],
      properties: {
        bus: {},
        patch: { type: "object" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["audio.bus_unknown"] },
  ),
  tool(
    "audio.add_effect",
    "audio",
    "Add an AudioEffect to a bus.",
    {
      type: "object",
      required: ["bus", "kind"],
      properties: { bus: {}, kind: np, params: { type: "object" }, position: { type: "integer" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["audio.bus_unknown", "audio.effect_kind_unknown"] },
  ),
  tool(
    "audio.preview_play",
    "audio",
    "Play a stream on a bus for preview.",
    {
      type: "object",
      required: ["stream_path"],
      properties: {
        stream_path: np,
        bus: { type: "string" },
        volume_db: { type: "number" },
        pitch_scale: { type: "number" },
        duration_s: { type: "number" },
      },
      additionalProperties: false,
    },
    { mutates: false, errorCodes: ["audio.preview_unavailable", "resource.path_not_found"] },
  ),
];

const inputMethods = [
  tool(
    "input.list_actions",
    "input",
    "List InputMap actions and bound events.",
    {
      type: "object",
      properties: { include_builtin: { type: "boolean" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "input.add_action",
    "input",
    "Create an input action with optional events.",
    {
      type: "object",
      required: ["name"],
      properties: { name: np, deadzone: { type: "number" }, events: { type: "array" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["input.action_exists", "input.action_name_invalid"] },
  ),
  tool(
    "input.remove_action",
    "input",
    "Remove an input action.",
    {
      type: "object",
      required: ["name"],
      properties: { name: np },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["input.action_unknown"] },
  ),
  tool(
    "input.set_action_events",
    "input",
    "Replace all events bound to an action.",
    {
      type: "object",
      required: ["name", "events"],
      properties: { name: np, events: { type: "array" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["input.action_unknown"] },
  ),
  tool(
    "input.rename_action",
    "input",
    "Rename an input action and optionally rewrite script references.",
    {
      type: "object",
      required: ["from", "to"],
      properties: {
        from: np,
        to: np,
        update_references: { type: "boolean" },
        dry_run: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["input.action_unknown", "input.action_exists"] },
  ),
  tool(
    "input.simulate_action",
    "input",
    "Simulate pressing and releasing an action.",
    {
      type: "object",
      required: ["action"],
      properties: {
        action: np,
        strength: { type: "number" },
        hold_ms: { type: "integer" },
        then_release: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["input.action_unknown"] },
  ),
  tool(
    "input.describe_event",
    "input",
    "Describe an input event and matching actions.",
    {
      type: "object",
      required: ["event"],
      properties: { event: { type: "object" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
];

const kept = existing.methods.filter(
  (m) => !String(m.method).startsWith("audio.") && !String(m.method).startsWith("input."),
);
const out = {
  catalog_version: "0.13.0",
  methods: [...kept, ...audioMethods, ...inputMethods],
};
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
process.stdout.write(`build-registry-21: ${out.methods.length} methods @ ${out.catalog_version}\n`);

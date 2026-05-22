#!/usr/bin/env node
/**
 * Build packages/shared/methods/registry.json entries for tasklist 16 (editor.* + analysis.*).
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

const root = findTerravoltRepoRoot(import.meta.url);
const regPath = join(root, "packages", "shared", "methods", "registry.json");
const existing = JSON.parse(readFileSync(regPath, "utf8"));

const rp = { type: "string", minLength: 1, pattern: "^(res://|user://|/|[A-Za-z]:)" };

function tool(name, category, desc, inputSchema, opts = {}) {
  return {
    method: name,
    category,
    since: "0.8.0",
    description: desc,
    inputSchema,
    outputSchema: { type: "object" },
    mcpTool: { name, title: name, description: desc },
    requiresEditor: opts.requiresEditor ?? false,
    requiresRuntime: false,
    safe: opts.safe ?? false,
    mutates: opts.mutates ?? false,
    errorCodes: opts.errorCodes ?? [],
    examples: opts.examples ?? [],
    headlessFallback: opts.headlessFallback ?? true,
  };
}

const editorMethods = [
  tool(
    "editor.screenshot",
    "editor",
    "Capture a PNG of the editor or a named viewport.",
    {
      type: "object",
      properties: {
        target: { type: "string" },
        size: { type: "object" },
        quality: { type: "integer" },
      },
      additionalProperties: false,
    },
    {
      safe: true,
      requiresEditor: true,
      headlessFallback: false,
      errorCodes: ["editor.screenshot_too_large"],
    },
  ),
  tool(
    "editor.focus_node",
    "editor",
    "Select and frame a node in the scene tree dock.",
    {
      type: "object",
      required: ["path"],
      properties: { path: { type: "string" }, frame_in_viewport: { type: "boolean" } },
      additionalProperties: false,
    },
    { safe: true, requiresEditor: true, headlessFallback: false },
  ),
  tool(
    "editor.open_script",
    "editor",
    "Open a script in the script editor at an optional line.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp, line: { type: "integer" }, column: { type: "integer" } },
      additionalProperties: false,
    },
    { safe: true, requiresEditor: true, headlessFallback: false },
  ),
  tool(
    "editor.run_undo",
    "editor",
    "Trigger editor undo steps.",
    {
      type: "object",
      properties: { steps: { type: "integer" } },
      additionalProperties: false,
    },
    { mutates: true, requiresEditor: true, headlessFallback: false },
  ),
  tool(
    "editor.run_redo",
    "editor",
    "Trigger editor redo steps.",
    {
      type: "object",
      properties: { steps: { type: "integer" } },
      additionalProperties: false,
    },
    { mutates: true, requiresEditor: true, headlessFallback: false },
  ),
  tool(
    "editor.execute_script",
    "editor",
    "Run a one-off @tool script inside the editor with deny-list gating.",
    {
      type: "object",
      required: ["source"],
      properties: {
        source: { type: "string" },
        args: { type: "object" },
        timeout_ms: { type: "integer" },
        allow_filesystem: { type: "boolean" },
        allow_net: { type: "boolean" },
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      requiresEditor: true,
      headlessFallback: false,
      errorCodes: ["editor.script_timeout", "editor.script_forbidden_api"],
    },
  ),
  tool(
    "editor.error_log_tail",
    "editor",
    "Return recent editor errors and warnings.",
    {
      type: "object",
      properties: {
        lines: { type: "integer" },
        level: { type: "string" },
        since_ts: { type: "string" },
      },
      additionalProperties: false,
    },
    { safe: true, headlessFallback: true },
  ),
  tool(
    "editor.reload_scripts",
    "editor",
    "Reload scripts in the editor.",
    {
      type: "object",
      properties: { scope: { type: "string" } },
      additionalProperties: false,
    },
    { mutates: true, requiresEditor: true, headlessFallback: false },
  ),
  tool(
    "editor.layout",
    "editor",
    "Save, load, list, or delete named editor dock layouts.",
    {
      type: "object",
      required: ["action"],
      properties: { action: { type: "string" }, name: { type: "string" } },
      additionalProperties: false,
    },
    {
      mutates: true,
      requiresEditor: true,
      headlessFallback: false,
      errorCodes: ["editor.unsupported_in_version"],
    },
  ),
];

const analysisMethods = [
  tool(
    "analysis.scene_complexity",
    "analysis",
    "Measure scene complexity (node count, depth, offenders).",
    {
      type: "object",
      properties: {
        scope: { type: "string" },
        scene_path: rp,
        thresholds: { type: "object" },
      },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "analysis.signal_flow",
    "analysis",
    "Audit project signal declarations and flag orphan listeners.",
    {
      type: "object",
      properties: { scope: { type: "string" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "analysis.unused_resources",
    "analysis",
    "Find unused assets and resources across the project.",
    {
      type: "object",
      properties: {
        kinds: { type: "array" },
        exclude: { type: "array" },
      },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "analysis.metrics",
    "analysis",
    "Rolled-up LOC, scene, script, and resource metrics.",
    {
      type: "object",
      properties: { kinds: { type: "array" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
];

const kept = existing.methods.filter(
  (m) => !String(m.method).startsWith("editor.") && !String(m.method).startsWith("analysis."),
);
const out = {
  catalog_version: "0.8.0",
  methods: [...kept, ...editorMethods, ...analysisMethods],
};
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`Wrote ${out.methods.length} methods (catalog ${out.catalog_version})`);

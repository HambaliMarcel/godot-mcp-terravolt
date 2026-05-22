#!/usr/bin/env node
/** Tasklist 23 — testing.* + profile.* + export.* */
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
    since: "0.15.0",
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

const methods = [
  tool(
    "testing.list_suites",
    "testing",
    "Enumerate detected test suites.",
    {
      type: "object",
      properties: { framework: { type: "string" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "testing.run",
    "testing",
    "Run tests headless.",
    {
      type: "object",
      properties: {
        framework: { type: "string" },
        suites: { type: "array" },
        tags: { type: "array" },
        parallel: { type: "boolean" },
        timeout_ms: { type: "integer" },
        fail_fast: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["testing.framework_unknown", "testing.timeout"] },
  ),
  tool(
    "testing.assert_state",
    "testing",
    "Assert runtime/editor state conditions.",
    {
      type: "object",
      required: ["assertions"],
      properties: { assertions: { type: "array" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "testing.screenshot_compare",
    "testing",
    "Compare a screenshot against a golden image.",
    {
      type: "object",
      required: ["source", "golden_path"],
      properties: {
        source: { type: "object" },
        golden_path: rp,
        tolerance: { type: "number" },
        save_diff_to: rp,
      },
      additionalProperties: false,
    },
    { errorCodes: ["testing.golden_not_found"] },
  ),
  tool(
    "testing.list_reports",
    "testing",
    "List saved test reports.",
    {
      type: "object",
      properties: { limit: { type: "integer" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "testing.get_report",
    "testing",
    "Fetch a saved test report by id.",
    {
      type: "object",
      required: ["id"],
      properties: { id: { type: "string", minLength: 1 } },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "profile.monitor",
    "profile",
    "Sample Godot performance monitors.",
    {
      type: "object",
      properties: {
        keys: { type: "array" },
        window_ms: { type: "integer" },
        samples: { type: "integer" },
      },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "profile.flamegraph",
    "profile",
    "Capture a profiling flamegraph snapshot.",
    {
      type: "object",
      properties: {
        duration_s: { type: "number" },
        kind: { type: "string" },
        include_native: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { errorCodes: ["profile.flamegraph_unavailable"] },
  ),
  tool(
    "export.list_presets",
    "export",
    "List export presets configured for the project.",
    {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "export.build",
    "export",
    "Run an export preset build.",
    {
      type: "object",
      required: ["preset"],
      properties: {
        preset: { type: "string", minLength: 1 },
        debug: { type: "boolean" },
        output_path: rp,
        with_pck_only: { type: "boolean" },
        platform_args: { type: "object" },
        timeout_ms: { type: "integer" },
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      errorCodes: ["export.preset_unknown", "export.template_missing", "export.timeout"],
    },
  ),
  tool(
    "export.template_info",
    "export",
    "Report installed export template status.",
    {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
    { safe: true },
  ),
];

const prefixes = ["testing.", "profile.", "export."];
const kept = existing.methods.filter((m) => !prefixes.some((p) => String(m.method).startsWith(p)));
const out = { catalog_version: "0.15.0", methods: [...kept, ...methods] };
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`build-registry-23: ${out.methods.length} methods @ ${out.catalog_version}`);

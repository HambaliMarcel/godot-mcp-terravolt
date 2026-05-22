#!/usr/bin/env node
/**
 * Tasklist 26 — android.* deploy/inspection + testing.run_scenario orchestration.
 * Closes the only meaningful gap vs godot-mcp-pro (Android deploy chain) and
 * adds the multi-step scenario runner. Pushes catalog to the 222-tool target
 * declared by docs/tasklist/25-catalog-completion-gate.md.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

const root = findTerravoltRepoRoot(import.meta.url);
const regPath = join(root, "packages", "shared", "methods", "registry.json");
const existing = JSON.parse(readFileSync(regPath, "utf8"));

function tool(name, category, since, desc, inputSchema, opts = {}) {
  return {
    method: name,
    category,
    since,
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
    "android.list_devices",
    "android",
    "0.17.0",
    "List Android devices visible to adb (parses `adb devices -l`).",
    { type: "object", properties: {}, additionalProperties: false },
    { safe: true, errorCodes: ["android.adb_not_found"] },
  ),
  tool(
    "android.preset_info",
    "android",
    "0.17.0",
    "Inspect an Android export preset (export_path, package_name, runnable).",
    {
      type: "object",
      properties: {
        preset_name: { type: "string" },
        preset_index: { type: "integer", minimum: -1 },
      },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["android.preset_not_found"] },
  ),
  tool(
    "android.deploy",
    "android",
    "0.17.0",
    "Export APK + adb install -r + optional launch. Skip the export step with skip_export=true.",
    {
      type: "object",
      properties: {
        preset_name: { type: "string" },
        preset_index: { type: "integer", minimum: -1 },
        device_serial: { type: "string" },
        debug: { type: "boolean" },
        launch: { type: "boolean" },
        skip_export: { type: "boolean" },
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      errorCodes: [
        "android.preset_not_found",
        "android.export_failed",
        "android.install_failed",
        "android.adb_not_found",
      ],
    },
  ),
  tool(
    "testing.run_scenario",
    "testing",
    "0.17.0",
    "Run a scripted scenario: ordered [input|wait|assert|screenshot] steps with per-step results.",
    {
      type: "object",
      required: ["steps"],
      properties: {
        steps: { type: "array" },
        stop_on_fail: { type: "boolean" },
        step_timeout_ms: { type: "integer", minimum: 1 },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["testing.scenario_failed"] },
  ),
];

const newMethodNames = new Set(methods.map((m) => m.method));
const kept = existing.methods.filter((m) => !newMethodNames.has(m.method));
const out = { catalog_version: "0.17.0", methods: [...kept, ...methods] };
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`build-registry-26: ${out.methods.length} methods @ ${out.catalog_version}`);

#!/usr/bin/env node
/**
 * Build packages/shared/methods/registry.json entries for tasklist 13 (script.* + signal.*).
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

const root = findTerravoltRepoRoot(import.meta.url);
const regPath = join(root, "packages", "shared", "methods", "registry.json");
const existing = JSON.parse(readFileSync(regPath, "utf8"));

const rp = { type: "string", minLength: 1, pattern: "^(res://|user://|/|[A-Za-z]:)" };
const np = { type: "string", minLength: 1 };

function tool(name, category, desc, inputSchema, opts = {}) {
  return {
    method: name,
    category,
    since: "0.5.0",
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

const scriptMethods = [
  tool(
    "script.list",
    "script",
    "Enumerate script files under res://.",
    {
      type: "object",
      properties: { pattern: { type: "string" }, include_addon: { type: "boolean" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "script.read",
    "script",
    "Read script contents (envelope-aware).",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp, range: { type: "object" }, format: { type: "string" } },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["script.path_not_found"] },
  ),
  tool(
    "script.write",
    "script",
    "Create or overwrite a script file.",
    {
      type: "object",
      required: ["path", "content"],
      properties: { path: rp, content: { type: "string" }, mode: { type: "string" }, if_match: {} },
      additionalProperties: false,
    },
    {
      mutates: true,
      errorCodes: ["script.path_not_found", "script.path_exists", "protocol.idempotency_conflict"],
    },
  ),
  tool(
    "script.patch",
    "script",
    "Apply line-range hunks to a script.",
    {
      type: "object",
      required: ["path", "hunks"],
      properties: { path: rp, hunks: { type: "array" }, if_match: {} },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["script.path_not_found", "script.patch_conflict"] },
  ),
  tool(
    "script.validate",
    "script",
    "Compile-check a script.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp, mode: { type: "string" } },
      additionalProperties: false,
    },
    {
      safe: true,
      errorCodes: ["script.path_not_found", "script.dotnet_unavailable", "script.validate_timeout"],
    },
  ),
  tool(
    "script.find_usages",
    "script",
    "Find symbol references across the project.",
    {
      type: "object",
      required: ["symbol"],
      properties: {
        symbol: { type: "string" },
        kind: { type: "string" },
        case_sensitive: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "script.rename_symbol",
    "script",
    "Rename a symbol project-wide.",
    {
      type: "object",
      required: ["from", "to", "kind"],
      properties: {
        scope: {},
        from: { type: "string" },
        to: { type: "string" },
        kind: { type: "string" },
        dry_run: { type: "boolean" },
        exclude: { type: "array" },
      },
      additionalProperties: false,
    },
    { mutates: true, headlessFallback: false, errorCodes: ["script.rename_conflict"] },
  ),
  tool(
    "script.format",
    "script",
    "Format a script file.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp, in_place: { type: "boolean" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["script.path_not_found", "script.formatter_missing"] },
  ),
];

const signalMethods = [
  tool(
    "signal.list_declared",
    "signal",
    "List user-declared signals on a node's script.",
    { type: "object", required: ["path"], properties: { path: np }, additionalProperties: false },
    { safe: true },
  ),
  tool(
    "signal.add_declaration",
    "signal",
    "Add a signal declaration to a script.",
    {
      type: "object",
      required: ["script_path", "signal_name"],
      properties: {
        script_path: rp,
        signal_name: { type: "string" },
        args: { type: "array" },
        doc_comment: { type: "string" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["script.path_not_found", "signal.name_exists"] },
  ),
  tool(
    "signal.remove_declaration",
    "signal",
    "Remove a signal declaration from a script.",
    {
      type: "object",
      required: ["script_path", "signal_name"],
      properties: { script_path: rp, signal_name: { type: "string" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["script.path_not_found", "signal.unknown"] },
  ),
  tool(
    "signal.connect",
    "signal",
    "Connect a signal to a target method.",
    {
      type: "object",
      required: ["from_path", "signal_name", "to_path", "method"],
      properties: {
        from_path: np,
        signal_name: { type: "string" },
        to_path: np,
        method: { type: "string" },
        flags: { type: "integer" },
        binds: { type: "array" },
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      requiresEditor: true,
      headlessFallback: false,
      errorCodes: ["signal.unknown", "signal.target_unknown", "signal.method_unknown"],
    },
  ),
  tool(
    "signal.disconnect",
    "signal",
    "Disconnect a signal connection.",
    {
      type: "object",
      required: ["from_path", "signal_name", "to_path", "method"],
      properties: {
        from_path: np,
        signal_name: { type: "string" },
        to_path: np,
        method: { type: "string" },
      },
      additionalProperties: false,
    },
    { mutates: true, requiresEditor: true, headlessFallback: false },
  ),
  tool(
    "signal.list_connections",
    "signal",
    "List outgoing signal connections on a node.",
    {
      type: "object",
      required: ["path"],
      properties: { path: np, signal_name: { type: "string" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "signal.find_listeners",
    "signal",
    "Reverse lookup for signal listeners.",
    {
      type: "object",
      required: ["from_path", "signal_name"],
      properties: { from_path: np, signal_name: { type: "string" }, scope: { type: "string" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "signal.bulk_connect",
    "signal",
    "Connect many signal pairs atomically.",
    {
      type: "object",
      required: ["connections"],
      properties: { connections: { type: "array" }, if_match: {} },
      additionalProperties: false,
    },
    { mutates: true, requiresEditor: true, headlessFallback: false },
  ),
  tool(
    "signal.bulk_disconnect",
    "signal",
    "Disconnect many signal pairs.",
    {
      type: "object",
      required: ["connections"],
      properties: { connections: { type: "array" } },
      additionalProperties: false,
    },
    { mutates: true, requiresEditor: true, headlessFallback: false },
  ),
  tool(
    "signal.graph",
    "signal",
    "Export the signal graph as JSON/Mermaid/DOT.",
    {
      type: "object",
      properties: {
        scope: { type: "string" },
        format: { type: "string" },
        include_engine_signals: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { safe: true },
  ),
];

const kept = existing.methods.filter(
  (m) => !String(m.method).startsWith("script.") && !String(m.method).startsWith("signal."),
);
const out = { catalog_version: "0.5.0", methods: [...kept, ...scriptMethods, ...signalMethods] };
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`Wrote ${out.methods.length} methods (catalog ${out.catalog_version})`);

#!/usr/bin/env node
/**
 * Build packages/shared/methods/registry.json entries for tasklist 17 (runtime.*).
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

const root = findTerravoltRepoRoot(import.meta.url);
const regPath = join(root, "packages", "shared", "methods", "registry.json");
const existing = JSON.parse(readFileSync(regPath, "utf8"));

const np = { type: "string", minLength: 1 };
const rp = { type: "string", minLength: 1, pattern: "^(res://|user://|/|[A-Za-z]:)" };

function tool(name, desc, inputSchema, opts = {}) {
  return {
    method: name,
    category: "runtime",
    since: "0.9.0",
    description: desc,
    inputSchema,
    outputSchema: { type: "object" },
    mcpTool: { name, title: name, description: desc },
    requiresEditor: opts.requiresEditor ?? false,
    requiresRuntime: opts.requiresRuntime ?? true,
    safe: opts.safe ?? false,
    mutates: opts.mutates ?? false,
    errorCodes: opts.errorCodes ?? [],
    examples: opts.examples ?? [],
    headlessFallback: opts.headlessFallback ?? true,
  };
}

const runtimeMethods = [
  tool(
    "runtime.play",
    "Start the game in the editor (play main, current, or custom scene).",
    {
      type: "object",
      properties: { mode: { type: "string" }, scene: rp, args: { type: "array" } },
      additionalProperties: false,
    },
    { mutates: true, requiresEditor: true, requiresRuntime: false, headlessFallback: false },
  ),
  tool(
    "runtime.stop",
    "Stop the running game session.",
    {
      type: "object",
      properties: { force: { type: "boolean" } },
      additionalProperties: false,
    },
    { mutates: true, requiresRuntime: false },
  ),
  tool(
    "runtime.start_headless",
    "Spawn the project headless with the runtime bridge autoload.",
    {
      type: "object",
      properties: {
        scene: rp,
        args: { type: "array" },
        wait_handshake_ms: { type: "integer" },
      },
      additionalProperties: false,
    },
    { mutates: true, requiresRuntime: false },
  ),
  tool(
    "runtime.status",
    "Check whether a runtime session is alive.",
    { type: "object", properties: {}, additionalProperties: false },
    { safe: true, requiresRuntime: false },
  ),
  tool(
    "runtime.list_nodes",
    "Scene tree envelope for the running game.",
    {
      type: "object",
      properties: {
        envelope: { type: "string" },
        max_depth: { type: "integer" },
        root: np,
      },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["runtime.no_session", "runtime.bridge_unavailable"] },
  ),
  tool(
    "runtime.inspect_node",
    "Read properties on a live node.",
    {
      type: "object",
      required: ["path"],
      properties: {
        path: np,
        properties: {},
        include_signals: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["runtime.no_session", "scene.node_path_not_found"] },
  ),
  tool(
    "runtime.evaluate",
    "Sandboxed expression evaluation against a live node.",
    {
      type: "object",
      required: ["path", "expression"],
      properties: { path: np, expression: { type: "string" }, inputs: { type: "object" } },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["runtime.no_session", "expression.forbidden_identifier"] },
  ),
  tool(
    "runtime.set_property",
    "Set a property on a live node.",
    {
      type: "object",
      required: ["path", "key"],
      properties: { path: np, key: { type: "string" }, value: {} },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["runtime.no_session", "node.property_unknown"] },
  ),
  tool(
    "runtime.call_method",
    "Call a method on a live node.",
    {
      type: "object",
      required: ["path", "method"],
      properties: { path: np, method: { type: "string" }, args: { type: "array" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["runtime.no_session", "node.method_unknown"] },
  ),
  tool(
    "runtime.emit_signal",
    "Emit a signal on a live node.",
    {
      type: "object",
      required: ["path", "signal"],
      properties: { path: np, signal: { type: "string" }, args: { type: "array" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["runtime.no_session", "signal.unknown"] },
  ),
  tool(
    "runtime.send_input",
    "Synthesize input events into the running game.",
    {
      type: "object",
      required: ["events"],
      properties: {
        events: { type: "array" },
        delay_between_ms: { type: "integer" },
        force: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["runtime.no_session"] },
  ),
  tool(
    "runtime.simulate_sequence",
    "Higher-level input macro built from named actions.",
    {
      type: "object",
      required: ["sequence"],
      properties: { sequence: { type: "array" }, pace_ms: { type: "integer" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["runtime.no_session"] },
  ),
  tool(
    "runtime.click_ui",
    "Click a UI control by path or visible text.",
    {
      type: "object",
      required: ["selector"],
      properties: {
        selector: { type: "object" },
        scroll_into_view: { type: "boolean" },
        wait_animation_ms: { type: "integer" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["runtime.no_session", "runtime.ui_not_found"] },
  ),
  tool(
    "runtime.navigate",
    "Drive a navigation agent or CharacterBody toward a target.",
    {
      type: "object",
      required: ["agent_path", "target"],
      properties: {
        agent_path: np,
        target: { type: "object" },
        speed: { type: "number" },
        timeout_ms: { type: "integer" },
        arrival_radius: { type: "number" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["runtime.no_session", "runtime.navigate_timeout"] },
  ),
  tool(
    "runtime.record_inputs",
    "Start or stop recording live inputs.",
    {
      type: "object",
      required: ["action"],
      properties: { action: { type: "string" }, buffer_id: { type: "string" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["runtime.no_session"] },
  ),
  tool(
    "runtime.replay_inputs",
    "Replay a recorded input buffer.",
    {
      type: "object",
      required: ["buffer_id"],
      properties: {
        buffer_id: { type: "string" },
        speed: { type: "number" },
        loop: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["runtime.no_session", "runtime.buffer_not_found"] },
  ),
  tool(
    "runtime.log_tail",
    "Tail the running game log ring buffer.",
    {
      type: "object",
      properties: {
        lines: { type: "integer" },
        level: { type: "string" },
        since_ts: { type: "string" },
      },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["runtime.no_session"] },
  ),
  tool(
    "runtime.screenshot",
    "Capture the live game viewport as PNG base64.",
    {
      type: "object",
      properties: { size: { type: "object" }, quality: { type: "integer" } },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["runtime.no_session", "runtime.bridge_unavailable"] },
  ),
  tool(
    "runtime.set_engine_param",
    "Mutate engine-wide runtime params (time scale, physics ticks, debug flags).",
    {
      type: "object",
      required: ["params"],
      properties: { params: { type: "object" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["runtime.no_session"] },
  ),
];

const kept = existing.methods.filter((m) => !String(m.method).startsWith("runtime."));
const prevVer = String(existing.catalog_version || "0.8.0");
const nextVer = prevVer === "0.8.0" ? "0.9.0" : prevVer.startsWith("0.1") ? "0.12.0" : "0.9.0";
const out = {
  catalog_version: nextVer,
  methods: [...kept, ...runtimeMethods],
};
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(
  `Wrote ${out.methods.length} methods (catalog ${out.catalog_version}, +${runtimeMethods.length} runtime)`,
);

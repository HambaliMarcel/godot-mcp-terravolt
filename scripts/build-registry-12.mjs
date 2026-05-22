#!/usr/bin/env node
/**
 * Build packages/shared/methods/registry.json entries for tasklist 12 (node.*).
 */
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

const root = findTerravoltRepoRoot(import.meta.url);
const regPath = join(root, "packages", "shared", "methods", "registry.json");
const existing = JSON.parse(readFileSync(regPath, "utf8"));

const scenePathSchema = { type: "string", minLength: 1, pattern: "^(res://|user://|/|[A-Za-z]:)" };
const nodePathSchema = { type: "string", minLength: 1 };

function tool(name, category, desc, inputSchema, opts = {}) {
  return {
    method: name,
    category,
    since: "0.4.0",
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

const nodeMethods = [
  tool(
    "node.add",
    "node",
    "Add a new node under a parent in the active scene.",
    {
      type: "object",
      required: ["parent_path", "type"],
      properties: {
        parent_path: nodePathSchema,
        type: { type: "string" },
        name: { type: "string" },
        properties: { type: "object" },
        groups: { type: "array", items: { type: "string" } },
        index: { type: "integer" },
        unique_name: { type: "boolean" },
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      errorCodes: ["node.type_unknown", "scene.node_path_not_found", "node.name_collision"],
    },
  ),
  tool(
    "node.delete",
    "node",
    "Remove a node and its subtree from the active scene.",
    {
      type: "object",
      required: ["path"],
      properties: {
        path: nodePathSchema,
        defer: { type: "boolean" },
        free_resources: { type: "boolean" },
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["scene.node_path_not_found"] },
  ),
  tool(
    "node.duplicate",
    "node",
    "Clone a node under a target parent.",
    {
      type: "object",
      required: ["source_path"],
      properties: {
        source_path: nodePathSchema,
        target_parent_path: nodePathSchema,
        new_name: { type: "string" },
        flags: { type: "object" },
        shallow: { type: "boolean" },
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["scene.node_path_not_found"] },
  ),
  tool(
    "node.move",
    "node",
    "Reparent a node and/or change sibling order.",
    {
      type: "object",
      required: ["source_path", "target_parent_path"],
      properties: {
        source_path: nodePathSchema,
        target_parent_path: nodePathSchema,
        index: { type: "integer" },
        keep_global_transform: { type: "boolean" },
        new_name: { type: "string" },
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["scene.node_path_not_found", "node.cycle_detected"] },
  ),
  tool(
    "node.rename",
    "node",
    "Rename a node and optionally rewrite NodePath references.",
    {
      type: "object",
      required: ["path", "new_name"],
      properties: {
        path: nodePathSchema,
        new_name: { type: "string" },
        update_references: { type: "boolean" },
        dry_run: { type: "boolean" },
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["scene.node_path_not_found", "node.name_collision"] },
  ),
  tool(
    "node.get",
    "node",
    "Read node identity and serializable properties.",
    {
      type: "object",
      required: ["path"],
      properties: {
        path: nodePathSchema,
        properties: {},
        include_hint: { type: "boolean" },
        include_export: { type: "boolean" },
        envelope: { type: "string", enum: ["summary", "raw"] },
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["scene.node_path_not_found"] },
  ),
  tool(
    "node.modify",
    "node",
    "Polymorphic mutator: property writes, groups, meta, signal connect/disconnect in one call.",
    {
      type: "object",
      required: ["path", "ops"],
      properties: {
        path: nodePathSchema,
        ops: { type: "array" },
        dry_run: { type: "boolean" },
        if_match: {},
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      errorCodes: [
        "node.property_unknown",
        "node.value_type_mismatch",
        "scene.node_path_not_found",
        "protocol.invalid_params",
      ],
    },
  ),
  tool(
    "node.list_groups",
    "node",
    "List groups for a node or recursively for the scene.",
    {
      type: "object",
      properties: {
        path: nodePathSchema,
        recursive: { type: "boolean" },
        scope: { type: "string", enum: ["scene", "active"] },
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "node.list_signals",
    "node",
    "Enumerate declared signals and connections on a node.",
    {
      type: "object",
      required: ["path"],
      properties: {
        path: nodePathSchema,
        include_inherited: { type: "boolean" },
        include_connections: { type: "boolean" },
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["scene.node_path_not_found"] },
  ),
  tool(
    "node.find_path",
    "node",
    "Resolve a Selector to concrete NodePaths.",
    {
      type: "object",
      required: ["selector"],
      properties: {
        selector: { type: "object" },
        expect: { type: "string", enum: ["single", "many"] },
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["selector.no_match"] },
  ),
  tool(
    "node.is_a",
    "node",
    "Type query: class or script inheritance check.",
    {
      type: "object",
      required: ["path", "type"],
      properties: {
        path: nodePathSchema,
        type: { type: "string" },
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["scene.node_path_not_found"] },
  ),
  tool(
    "node.attach_script",
    "node",
    "Attach a script resource to a node.",
    {
      type: "object",
      required: ["path", "script_path"],
      properties: {
        path: nodePathSchema,
        script_path: scenePathSchema,
        replace_existing: { type: "boolean" },
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      errorCodes: [
        "node.script_already_attached",
        "script.path_not_found",
        "scene.node_path_not_found",
      ],
    },
  ),
  tool(
    "node.detach_script",
    "node",
    "Remove the script from a node.",
    {
      type: "object",
      required: ["path"],
      properties: { path: nodePathSchema, scene_path: scenePathSchema },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["scene.node_path_not_found"] },
  ),
  tool(
    "node.evaluate_expression",
    "node",
    "Evaluate a sandboxed Godot Expression against a node.",
    {
      type: "object",
      required: ["path", "expression"],
      properties: {
        path: nodePathSchema,
        expression: { type: "string" },
        inputs: { type: "object" },
        scene_path: scenePathSchema,
      },
      additionalProperties: false,
    },
    {
      safe: true,
      errorCodes: [
        "expression.parse_error",
        "expression.execute_error",
        "expression.forbidden_identifier",
        "scene.node_path_not_found",
      ],
    },
  ),
];

const kept = existing.methods.filter((m) => !String(m.method).startsWith("node."));
const out = {
  catalog_version: "0.4.0",
  methods: [...kept, ...nodeMethods],
};

writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`Wrote ${out.methods.length} methods (catalog ${out.catalog_version}) to ${regPath}`);

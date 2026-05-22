#!/usr/bin/env node
/**
 * Build packages/shared/methods/registry.json entries for tasklist 11.
 * Run once: node scripts/build-registry-11.mjs > packages/shared/methods/registry.json
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
    since: "0.3.0",
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
    headlessFallback: opts.headlessFallback ?? false,
  };
}

const sceneMethods = [
  tool(
    "scene.list",
    "scene",
    "Enumerate .tscn/.scn files under res://.",
    {
      type: "object",
      properties: { pattern: { type: "string" }, include_imported: { type: "boolean" } },
      additionalProperties: false,
    },
    { safe: true, headlessFallback: true },
  ),
  tool(
    "scene.get",
    "scene",
    "Scene metadata without instantiating.",
    {
      type: "object",
      required: ["path"],
      properties: { path: scenePathSchema },
      additionalProperties: false,
    },
    { safe: true, headlessFallback: true, errorCodes: ["scene.path_not_found"] },
  ),
  tool(
    "scene.open",
    "scene",
    "Open a scene tab in the editor.",
    {
      type: "object",
      required: ["path"],
      properties: { path: scenePathSchema, focus: { type: "boolean" } },
      additionalProperties: false,
    },
    {
      requiresEditor: true,
      safe: true,
      errorCodes: ["scene.path_not_found", "editor.not_available"],
    },
  ),
  tool(
    "scene.close",
    "scene",
    "Close the current or named scene tab.",
    {
      type: "object",
      properties: { path: scenePathSchema, save_first: { type: "boolean" } },
      additionalProperties: false,
    },
    {
      requiresEditor: true,
      mutates: true,
      errorCodes: ["editor.no_active_scene", "editor.not_available"],
    },
  ),
  tool(
    "scene.save",
    "scene",
    "Save the currently-edited scene.",
    {
      type: "object",
      properties: { path: scenePathSchema },
      additionalProperties: false,
    },
    {
      requiresEditor: true,
      mutates: true,
      errorCodes: ["scene.save_failed", "editor.no_active_scene"],
    },
  ),
  tool(
    "scene.save_as",
    "scene",
    "Save the current scene under a new path.",
    {
      type: "object",
      required: ["new_path"],
      properties: { new_path: scenePathSchema, overwrite: { type: "boolean" } },
      additionalProperties: false,
    },
    { requiresEditor: true, mutates: true, errorCodes: ["scene.save_failed"] },
  ),
  tool(
    "scene.create",
    "scene",
    "Create a new scene file with a typed root node.",
    {
      type: "object",
      required: ["path"],
      properties: {
        path: scenePathSchema,
        root_type: { type: "string" },
        root_name: { type: "string" },
        children: { type: "array" },
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      headlessFallback: true,
      errorCodes: ["scene.create_failed", "node.type_unknown"],
    },
  ),
  tool(
    "scene.delete",
    "scene",
    "Delete a scene file with optional dependency guard.",
    {
      type: "object",
      required: ["path"],
      properties: { path: scenePathSchema, force: { type: "boolean" } },
      additionalProperties: false,
    },
    {
      mutates: true,
      headlessFallback: true,
      errorCodes: ["scene.path_not_found", "resource.dependency_block"],
    },
  ),
  tool(
    "scene.instantiate",
    "scene",
    "Instantiate a PackedScene under a parent node.",
    {
      type: "object",
      required: ["source_path", "parent_path"],
      properties: {
        source_path: scenePathSchema,
        parent_path: nodePathSchema,
        name: { type: "string" },
        properties: { type: "object" },
        edit_state: { type: "string", enum: ["instance", "disabled", "main"] },
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      headlessFallback: true,
      errorCodes: ["scene.path_not_found", "scene.node_path_not_found"],
    },
  ),
  tool(
    "scene.pack",
    "scene",
    "Pack a subtree into a new .tscn file.",
    {
      type: "object",
      required: ["root_path", "output_path"],
      properties: {
        root_path: nodePathSchema,
        output_path: scenePathSchema,
        recursive_owner: { type: "boolean" },
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      headlessFallback: true,
      errorCodes: ["scene.create_failed", "editor.no_active_scene"],
    },
  ),
  tool(
    "scene.get_tree",
    "scene",
    "Return the active scene tree (envelope-aware).",
    {
      type: "object",
      properties: {
        envelope: { type: "string", enum: ["summary", "raw"] },
        max_depth: { type: "integer", minimum: 0 },
        max_children_per_node: { type: "integer", minimum: 1 },
      },
      additionalProperties: false,
    },
    { safe: true, headlessFallback: true, errorCodes: ["editor.no_active_scene"] },
  ),
  tool(
    "scene.get_subtree",
    "scene",
    "Return a subtree from a NodePath.",
    {
      type: "object",
      required: ["root_path"],
      properties: {
        root_path: nodePathSchema,
        envelope: { type: "string", enum: ["summary", "raw"] },
        max_depth: { type: "integer", minimum: 0 },
        max_children_per_node: { type: "integer", minimum: 1 },
      },
      additionalProperties: false,
    },
    { safe: true, headlessFallback: true, errorCodes: ["scene.node_path_not_found"] },
  ),
  tool(
    "scene.find_in_tree",
    "scene",
    "Search the active scene for nodes matching a selector.",
    {
      type: "object",
      required: ["selector"],
      properties: {
        selector: { type: "object" },
        limit: { type: "integer", minimum: 1, maximum: 500 },
        include_props: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { safe: true, headlessFallback: true },
  ),
  tool(
    "scene.validate",
    "scene",
    "Static integrity check for a scene or the active tree.",
    {
      type: "object",
      properties: { scope: { type: "string" }, depth: { type: "integer", minimum: 0 } },
      additionalProperties: false,
    },
    { safe: true, headlessFallback: true, errorCodes: ["scene.path_not_found"] },
  ),
  tool(
    "scene.replace",
    "scene",
    "Replace a subtree with another scene or synthesized node.",
    {
      type: "object",
      required: ["at_path", "with"],
      properties: {
        at_path: nodePathSchema,
        with: { type: "object" },
        keep_groups: { type: "boolean" },
        keep_owner: { type: "boolean" },
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      headlessFallback: true,
      errorCodes: ["scene.node_path_not_found", "scene.path_not_found"],
    },
  ),
];

const projectMethods = [
  tool(
    "project.info",
    "project",
    "Consolidated project metadata.",
    { type: "object", additionalProperties: false },
    { safe: true, headlessFallback: true },
  ),
  tool(
    "project.get_settings",
    "project",
    "Read one or many project settings.",
    {
      type: "object",
      properties: {
        keys: { type: "array", items: { type: "string" } },
        group: { type: "string" },
        include_defaults: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { safe: true, headlessFallback: true },
  ),
  tool(
    "project.set_settings",
    "project",
    "Patch project settings.",
    {
      type: "object",
      required: ["patch"],
      properties: {
        patch: { type: "object" },
        save: { type: "boolean" },
        dry_run: { type: "boolean" },
        confirm_high_risk: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, headlessFallback: true, errorCodes: ["project.setting_locked"] },
  ),
  tool(
    "project.list_autoloads",
    "project",
    "List every autoload entry.",
    { type: "object", additionalProperties: false },
    { safe: true, headlessFallback: true },
  ),
  tool(
    "project.add_autoload",
    "project",
    "Register an autoload singleton.",
    {
      type: "object",
      required: ["name", "path"],
      properties: {
        name: { type: "string", minLength: 1 },
        path: scenePathSchema,
        singleton: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, headlessFallback: true, errorCodes: ["node.type_unknown"] },
  ),
  tool(
    "project.remove_autoload",
    "project",
    "Unregister an autoload.",
    {
      type: "object",
      required: ["name"],
      properties: { name: { type: "string", minLength: 1 } },
      additionalProperties: false,
    },
    { mutates: true, headlessFallback: true },
  ),
  tool(
    "project.set_main_scene",
    "project",
    "Set application/run/main_scene.",
    {
      type: "object",
      required: ["path"],
      properties: { path: scenePathSchema, validate: { type: "boolean" } },
      additionalProperties: false,
    },
    { mutates: true, headlessFallback: true, errorCodes: ["scene.path_not_found"] },
  ),
];

const out = {
  catalog_version: "0.3.0",
  methods: [...existing.methods, ...sceneMethods, ...projectMethods],
};

writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`Wrote ${out.methods.length} methods (catalog ${out.catalog_version}) to ${regPath}`);

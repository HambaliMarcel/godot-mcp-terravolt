#!/usr/bin/env node
/**
 * Build packages/shared/methods/registry.json entries for tasklist 14 (resource.* + shader.*).
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
    since: "0.6.0",
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

const resourceMethods = [
  tool(
    "resource.list",
    "resource",
    "List resource files by class or glob.",
    {
      type: "object",
      properties: {
        class: { type: "string" },
        pattern: { type: "string" },
        include_imported: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "resource.get",
    "resource",
    "Read resource properties (envelope-aware for large blobs).",
    {
      type: "object",
      required: ["path"],
      properties: {
        path: rp,
        include_subresources: { type: "boolean" },
        max_depth: { type: "integer" },
      },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["resource.path_not_found"] },
  ),
  tool(
    "resource.create",
    "resource",
    "Create a new resource and save it.",
    {
      type: "object",
      required: ["path", "class"],
      properties: {
        path: rp,
        class: { type: "string" },
        properties: { type: "object" },
        take_over_path: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["resource.class_unknown", "resource.path_exists"] },
  ),
  tool(
    "resource.update",
    "resource",
    "Patch properties on an existing resource.",
    {
      type: "object",
      required: ["path", "patch"],
      properties: {
        path: rp,
        patch: { type: "object" },
        if_match: {},
        dry_run: { type: "boolean" },
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      errorCodes: [
        "resource.path_not_found",
        "resource.property_unknown",
        "resource.value_type_mismatch",
        "protocol.idempotency_conflict",
      ],
    },
  ),
  tool(
    "resource.duplicate",
    "resource",
    "Duplicate a resource to a new path.",
    {
      type: "object",
      required: ["source_path", "target_path"],
      properties: {
        source_path: rp,
        target_path: rp,
        deep: { type: "boolean" },
        overwrite: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["resource.path_not_found", "resource.path_exists"] },
  ),
  tool(
    "resource.delete",
    "resource",
    "Delete a resource file.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp, force: { type: "boolean" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["resource.path_not_found", "resource.dependency_block"] },
  ),
  tool(
    "resource.rename",
    "resource",
    "Rename or move a resource with optional reference rewrites.",
    {
      type: "object",
      required: ["from", "to"],
      properties: {
        from: rp,
        to: rp,
        update_references: { type: "boolean" },
        dry_run: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["resource.path_not_found", "resource.path_exists"] },
  ),
  tool(
    "resource.get_dependencies",
    "resource",
    "List outbound dependencies of a resource.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp, deep: { type: "boolean" } },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["resource.path_not_found"] },
  ),
  tool(
    "resource.get_dependents",
    "resource",
    "Reverse-lookup dependents of a resource.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp, scope: { type: "string" }, folder: rp },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "resource.replace_references",
    "resource",
    "Rewrite project-wide references from one path to another.",
    {
      type: "object",
      required: ["from_path", "to_path"],
      properties: {
        from_path: rp,
        to_path: rp,
        dry_run: { type: "boolean" },
        exclude: { type: "array" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "resource.export_json",
    "resource",
    "Export a resource as deterministic JSON.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp, include_subresources: { type: "boolean" } },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["resource.path_not_found"] },
  ),
  tool(
    "resource.import_json",
    "resource",
    "Import a resource from export JSON.",
    {
      type: "object",
      required: ["target_path", "json_string"],
      properties: {
        target_path: rp,
        json_string: { type: "string" },
        overwrite: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["resource.json_schema_mismatch", "resource.path_exists"] },
  ),
  tool(
    "resource.set_uid",
    "resource",
    "Assign or rotate a resource UID.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp, uid: { type: "string" }, force: { type: "boolean" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["resource.path_not_found"] },
  ),
  tool(
    "resource.validate",
    "resource",
    "Validate a resource file loads cleanly.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "resource.diff",
    "resource",
    "Structured diff between two resources or JSON.",
    {
      type: "object",
      required: ["a", "b"],
      properties: { a: rp, b: {} },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["resource.path_not_found"] },
  ),
];

const shaderMethods = [
  tool(
    "shader.list",
    "shader",
    "List shader code files and ShaderMaterial resources.",
    {
      type: "object",
      properties: { kind: { type: "string" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "shader.read",
    "shader",
    "Read shader source from a .gdshader file.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp, range: { type: "object" } },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["resource.path_not_found"] },
  ),
  tool(
    "shader.write",
    "shader",
    "Create or overwrite a .gdshader file.",
    {
      type: "object",
      required: ["path", "content"],
      properties: {
        path: rp,
        content: { type: "string" },
        mode: { type: "string" },
        if_match: {},
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["resource.path_exists", "protocol.idempotency_conflict"] },
  ),
  tool(
    "shader.compile_check",
    "shader",
    "Validate a shader compiles.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["resource.path_not_found", "shader.compile_timeout"] },
  ),
  tool(
    "shader.list_params",
    "shader",
    "Enumerate shader uniform parameters.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["resource.path_not_found"] },
  ),
  tool(
    "shader.set_material_params",
    "shader",
    "Set shader parameters on a ShaderMaterial.",
    {
      type: "object",
      required: ["material_path", "params"],
      properties: {
        material_path: rp,
        params: { type: "object" },
        if_match: {},
      },
      additionalProperties: false,
    },
    {
      mutates: true,
      errorCodes: [
        "resource.path_not_found",
        "shader.param_unknown",
        "shader.param_type_mismatch",
        "protocol.idempotency_conflict",
      ],
    },
  ),
];

const kept = existing.methods.filter(
  (m) => !String(m.method).startsWith("resource.") && !String(m.method).startsWith("shader."),
);
const out = {
  catalog_version: "0.6.0",
  methods: [...kept, ...resourceMethods, ...shaderMethods],
};
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`Wrote ${out.methods.length} methods (catalog ${out.catalog_version})`);

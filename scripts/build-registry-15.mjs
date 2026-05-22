#!/usr/bin/env node
/**
 * Build packages/shared/methods/registry.json entries for tasklist 15 (asset.* + batch_refactor.*).
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
    since: "0.7.0",
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

const assetMethods = [
  tool(
    "asset.list",
    "asset",
    "List source asset files under res://.",
    {
      type: "object",
      properties: {
        kind: { type: "string" },
        pattern: { type: "string" },
        include_imports: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "asset.import_status",
    "asset",
    "Report import status for assets.",
    {
      type: "object",
      properties: { path: rp, scope: { type: "string" }, folder: rp },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "asset.reimport",
    "asset",
    "Trigger reimport for asset(s).",
    {
      type: "object",
      properties: { path: rp, scope: { type: "string" }, folder: rp },
      additionalProperties: false,
    },
    { mutates: true, requiresEditor: true, errorCodes: ["asset.import_timeout"] },
  ),
  tool(
    "asset.get_import_settings",
    "asset",
    "Read import settings from .import sidecar.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["resource.path_not_found"] },
  ),
  tool(
    "asset.set_import_settings",
    "asset",
    "Patch import settings and optionally reimport.",
    {
      type: "object",
      required: ["path", "patch"],
      properties: { path: rp, patch: { type: "object" }, reimport_after: { type: "boolean" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["asset.unknown_setting", "resource.path_not_found"] },
  ),
  tool(
    "asset.add",
    "asset",
    "Add a new asset from base64 or file URL.",
    {
      type: "object",
      required: ["path"],
      properties: {
        path: rp,
        content_base64: { type: "string" },
        source_url: { type: "string" },
        overwrite: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["asset.too_large", "asset.path_exists"] },
  ),
  tool(
    "asset.delete",
    "asset",
    "Delete an asset and its import sidecar.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp, force: { type: "boolean" } },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["resource.path_not_found", "resource.dependency_block"] },
  ),
  tool(
    "asset.rename",
    "asset",
    "Rename/move an asset with optional reference rewrites.",
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
    { mutates: true, errorCodes: ["resource.path_not_found", "asset.path_exists"] },
  ),
  tool(
    "asset.preview",
    "asset",
    "Generate a preview thumbnail for an asset.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp, size: { type: "object" } },
      additionalProperties: false,
    },
    {
      safe: true,
      requiresEditor: true,
      headlessFallback: false,
      errorCodes: ["resource.path_not_found"],
    },
  ),
  tool(
    "asset.metadata",
    "asset",
    "Read intrinsic metadata for an asset.",
    {
      type: "object",
      required: ["path"],
      properties: { path: rp },
      additionalProperties: false,
    },
    { safe: true, errorCodes: ["resource.path_not_found"] },
  ),
  tool(
    "asset.batch_import_presets",
    "asset",
    "Apply import preset settings to many assets.",
    {
      type: "object",
      required: ["preset"],
      properties: {
        preset: { type: "string" },
        paths: { type: "array" },
        pattern: { type: "string" },
        dry_run: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["asset.preset_unknown"] },
  ),
  tool(
    "asset.find_unused",
    "asset",
    "Find assets with no inbound references.",
    {
      type: "object",
      properties: { kind: { type: "string" }, exclude: { type: "array" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
];

const batchMethods = [
  tool(
    "batch_refactor.preview",
    "batch_refactor",
    "Preview a batch refactor plan without applying.",
    {
      type: "object",
      required: ["plan"],
      properties: { plan: { type: "object" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
  tool(
    "batch_refactor.apply",
    "batch_refactor",
    "Apply a previewed batch refactor plan.",
    {
      type: "object",
      required: ["plan"],
      properties: { plan: { type: "object" }, confirm_token: { type: "string" }, if_match: {} },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["batch.confirm_mismatch", "batch.partial_failure"] },
  ),
  tool(
    "batch_refactor.rename_class",
    "batch_refactor",
    "Rename a GDScript class_name project-wide.",
    {
      type: "object",
      required: ["from", "to"],
      properties: {
        from: { type: "string" },
        to: { type: "string" },
        also_rename_file: { type: "boolean" },
        dry_run: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "batch_refactor.move_folder",
    "batch_refactor",
    "Move a folder and rewrite references.",
    {
      type: "object",
      required: ["from", "to"],
      properties: { from: rp, to: rp, dry_run: { type: "boolean" } },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "batch_refactor.replace_in_files",
    "batch_refactor",
    "Project-wide find-and-replace in text files.",
    {
      type: "object",
      required: ["pattern", "replacement"],
      properties: {
        pattern: {},
        replacement: { type: "string" },
        files: { type: "array" },
        dry_run: { type: "boolean" },
        max_edits: { type: "integer" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["batch.too_many_edits"] },
  ),
  tool(
    "batch_refactor.normalize_names",
    "batch_refactor",
    "Normalize file names to a casing convention.",
    {
      type: "object",
      required: ["target", "selector"],
      properties: {
        target: { type: "string" },
        selector: { type: "object" },
        dry_run: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true },
  ),
  tool(
    "batch_refactor.change_class",
    "batch_refactor",
    "Swap node/resource classes where compatible.",
    {
      type: "object",
      required: ["selector", "target_class"],
      properties: {
        selector: { type: "object" },
        target_class: { type: "string" },
        preserve_props: { type: "boolean" },
        dry_run: { type: "boolean" },
      },
      additionalProperties: false,
    },
    { mutates: true, errorCodes: ["batch.incompatible_classes"] },
  ),
  tool(
    "batch_refactor.history",
    "batch_refactor",
    "List recent batch_refactor.apply calls.",
    {
      type: "object",
      properties: { limit: { type: "integer" } },
      additionalProperties: false,
    },
    { safe: true },
  ),
];

const kept = existing.methods.filter(
  (m) => !String(m.method).startsWith("asset.") && !String(m.method).startsWith("batch_refactor."),
);
const out = {
  catalog_version: "0.7.0",
  methods: [...kept, ...assetMethods, ...batchMethods],
};
writeFileSync(regPath, `${JSON.stringify(out, null, 2)}\n`, "utf8");
console.log(`Wrote ${out.methods.length} methods (catalog ${out.catalog_version})`);

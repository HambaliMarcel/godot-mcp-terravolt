#!/usr/bin/env node
/**
 * Task 25 gate validator — registry integrity, headless dispatch, handler wiring.
 */
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";

import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

const root = findTerravoltRepoRoot(import.meta.url);
const regPath = join(root, "packages", "shared", "methods", "registry.json");
const errPath = join(root, "packages", "shared", "errors", "registry.json");
const opsPath = join(root, "packages", "godot-mcp-addon", "headless", "catalog_ops.gd");
const driverPath = join(root, "packages", "godot-mcp-addon", "headless", "headless_driver.gd");
const mainPath = join(root, "packages", "godot-mcp-addon", "main.gd");
const errGdPath = join(root, "packages", "godot-mcp-addon", "error_codes.gd");
const handlersDir = join(root, "packages", "godot-mcp-addon", "handlers");

const MIN_TOOLS = Number.parseInt(process.env.TERRAVOLT_MIN_CATALOG_TOOLS ?? "200", 10);

const reg = JSON.parse(readFileSync(regPath, "utf8"));
const errReg = JSON.parse(readFileSync(errPath, "utf8"));
const ops = readFileSync(opsPath, "utf8") + readFileSync(driverPath, "utf8");
const main = readFileSync(mainPath, "utf8");
const errGd = readFileSync(errGdPath, "utf8");

const methods = reg.methods ?? [];
const failures = [];

if (methods.length < MIN_TOOLS) {
  failures.push(`tool count ${methods.length} < ${MIN_TOOLS}`);
}

const missingHeadless = [];
for (const m of methods) {
  const quoted = `"${m.method}"`;
  if (m.headlessFallback && !ops.includes(quoted)) {
    missingHeadless.push(m.method);
  }
}
if (missingHeadless.length) {
  failures.push(`headlessFallback without catalog_ops dispatch: ${missingHeadless.join(", ")}`);
}

const handlerFiles = readdirSync(handlersDir).filter(
  (f) =>
    f.endsWith(".gd") &&
    !f.includes("_helpers") &&
    !f.includes("runner") &&
    f !== "handler_utils.gd",
);
const categories = new Set(methods.map((m) => m.category ?? m.method.split(".")[0]));
for (const cat of categories) {
  if (["server", "log"].includes(cat)) continue;
  const handlerFile = join(handlersDir, `${cat}.gd`);
  if (!existsSync(handlerFile) && !["ping", "server"].includes(cat)) {
    failures.push(`missing handler file for category ${cat}`);
  }
  const preload = `./handlers/${cat}.gd`;
  if (existsSync(handlerFile) && !main.includes(preload)) {
    failures.push(`handler ${cat}.gd not wired in main.gd`);
  }
}

const appCodes = (errReg.codes ?? errReg.errors ?? []).filter((c) => c.code < 0);
const gdMatches = [...errGd.matchAll(/:=\s*(-\d+)/g)];
const gdCodes = new Set(gdMatches.map((m) => Number.parseInt(m[1], 10)));
for (const c of appCodes) {
  if (!errGd.includes(String(c.code))) {
    failures.push(`error code ${c.code} (${c.symbol ?? c.id}) missing in error_codes.gd`);
  }
}

const missingSchema = methods.filter((m) => !m.inputSchema || !m.outputSchema);
if (missingSchema.length) {
  failures.push(`${missingSchema.length} methods missing input/output schema`);
}

const headlessCount = methods.filter((m) => m.headlessFallback).length;

process.stdout.write(
  JSON.stringify(
    {
      ok: failures.length === 0,
      catalog_version: reg.catalog_version,
      total_methods: methods.length,
      headlessFallback: headlessCount,
      requiresEditor: methods.filter((m) => m.requiresEditor).length,
      handler_files: handlerFiles.length,
      app_error_codes: appCodes.length,
      failures,
    },
    null,
    2,
  ) + "\n",
);

if (failures.length) process.exit(1);

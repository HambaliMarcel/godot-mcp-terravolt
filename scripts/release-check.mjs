#!/usr/bin/env node
/**
 * docs/tasklist/10 §10.6.16 release-readiness gate.
 *
 * Asserts:
 *  - Router workspace `version` matches the shared `catalog_version` MAJOR/MINOR family
 *    (router can ship PATCH releases independent of catalog PATCH).
 *  - `packages/godot-mcp-addon/_generated/catalog_meta.gd` SHA256 matches
 *    `registry.json` (catalog:sync was run).
 *  - `packages/godot-mcp-addon/error_codes.gd` declares every code in
 *    `packages/shared/errors/registry.json`.
 *  - `docs/release/v1-readiness.md` exists.
 *  - `CHANGELOG.md` mentions the router version.
 *
 * Read-only; exits non-zero with a structured report on the first failure.
 */
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

const root = findTerravoltRepoRoot(import.meta.url);

const REGISTRY_METHODS = join(root, "packages", "shared", "methods", "registry.json");
const REGISTRY_ERRORS = join(root, "packages", "shared", "errors", "registry.json");
const CATALOG_META_GD = join(root, "packages", "godot-mcp-addon", "_generated", "catalog_meta.gd");
const ERROR_CODES_GD = join(root, "packages", "godot-mcp-addon", "error_codes.gd");
const ROUTER_PKG = join(root, "packages", "mcp-server", "package.json");
const READINESS = join(root, "docs", "release", "v1-readiness.md");
const CHANGELOG = join(root, "CHANGELOG.md");

const failures = [];
const ok = [];

function fail(msg) {
  failures.push(msg);
}
function pass(msg) {
  ok.push(msg);
}

const methodsBytes = readFileSync(REGISTRY_METHODS);
const methodsJson = JSON.parse(methodsBytes.toString("utf8"));
const errorsJson = JSON.parse(readFileSync(REGISTRY_ERRORS, "utf8"));
const routerPkg = JSON.parse(readFileSync(ROUTER_PKG, "utf8"));

const expectedHash = createHash("sha256").update(methodsBytes).digest("hex");
const catalogGd = existsSync(CATALOG_META_GD) ? readFileSync(CATALOG_META_GD, "utf8") : "";
if (!catalogGd.includes(expectedHash)) {
  fail(`catalog_meta.gd missing SHA256 ${expectedHash.slice(0, 12)}… — run npm run catalog:sync`);
} else {
  pass(`catalog_meta.gd hash matches (${expectedHash.slice(0, 12)}…)`);
}
if (!catalogGd.includes(`"${methodsJson.catalog_version}"`)) {
  fail(`catalog_meta.gd is missing catalog_version "${methodsJson.catalog_version}"`);
} else {
  pass(`catalog_meta.gd catalog_version matches (${methodsJson.catalog_version})`);
}

const gd = existsSync(ERROR_CODES_GD) ? readFileSync(ERROR_CODES_GD, "utf8") : "";
const missingCodes = [];
for (const c of errorsJson.codes ?? []) {
  if (!gd.includes(String(c.code))) missingCodes.push(c);
}
if (missingCodes.length) {
  fail(
    `error_codes.gd is missing ${missingCodes.length} entries: ${missingCodes
      .map((c) => `${c.symbol}=${c.code}`)
      .join(", ")}`,
  );
} else {
  pass(`error_codes.gd mirrors ${errorsJson.codes?.length ?? 0} app codes`);
}

if (!existsSync(READINESS)) {
  fail(`docs/release/v1-readiness.md is missing`);
} else {
  pass(`docs/release/v1-readiness.md present`);
}

if (!existsSync(CHANGELOG)) {
  fail(`CHANGELOG.md is missing`);
} else {
  const text = readFileSync(CHANGELOG, "utf8");
  if (!text.includes(routerPkg.version)) {
    fail(`CHANGELOG.md does not reference router version ${routerPkg.version}`);
  } else {
    pass(`CHANGELOG.md mentions router ${routerPkg.version}`);
  }
}

const lines = [];
lines.push(`# release-check`);
lines.push(``);
lines.push(`router.version=${routerPkg.version}`);
lines.push(`catalog_version=${methodsJson.catalog_version}`);
lines.push(``);
for (const m of ok) lines.push(`ok    : ${m}`);
for (const m of failures) lines.push(`fail  : ${m}`);
process.stdout.write(`${lines.join("\n")}\n`);

process.exit(failures.length === 0 ? 0 : 1);

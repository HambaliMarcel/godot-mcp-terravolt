/**
 * Locate the Terravolt monorepo root by probing `packages/shared/methods/registry.json`,
 * compatible with callers under `scripts/`, routers under `packages/mcp-server/dist/`, etc.
 */
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REGISTRY_TAIL = ["packages", "shared", "methods", "registry.json"];

function ancestorDirs(seed) {
  const out = [];
  let d = resolve(seed);
  for (let i = 0; i < 22; i++) {
    out.push(d);
    const p = dirname(d);
    if (p === d) break;
    d = p;
  }
  return out;
}

/**
 * @param {string | URL} importMetaUrl `import.meta.url` of caller
 */
export function findTerravoltRepoRoot(importMetaUrl = import.meta.url) {
  const fromModule = dirname(fileURLToPath(importMetaUrl));

  /** Prefer cwd-first (IDE / `npm run` from repo root), then ancestor walk from this file. */
  const orderedRoots = [...ancestorDirs(process.cwd()), ...ancestorDirs(fromModule)];
  const seen = new Set();
  for (const root of orderedRoots) {
    if (seen.has(root)) continue;
    seen.add(root);
    const probe = join(root, ...REGISTRY_TAIL);
    if (existsSync(probe)) return root;
  }
  throw new Error(
    `[terravolt] Could not locate packages/shared/methods/registry.json. Run from repo root or set cwd to the monorepo.`,
  );
}

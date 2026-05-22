import { existsSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REGISTRY_TAIL = ["packages", "shared", "methods", "registry.json"] as const;

function ancestorDirs(seed: string): string[] {
  const out: string[] = [];
  let d = resolve(seed);
  for (let i = 0; i < 22; i++) {
    out.push(d);
    const p = dirname(d);
    if (p === d) break;
    d = p;
  }
  return out;
}

function toFsPath(urlOrPath: string): string {
  if (urlOrPath.startsWith("file://")) return fileURLToPath(urlOrPath);
  if (isAbsolute(urlOrPath)) return urlOrPath;
  throw new Error(
    `[terravolt] Expected a file:// URL or absolute path, got: ${urlOrPath}`,
  );
}

/** Locate monorepo root by `packages/shared/methods/registry.json`. */
export function resolveTerravoltRepoRoot(importMetaUrl: string): string {
  const fromModule = dirname(toFsPath(importMetaUrl));
  const roots = [...ancestorDirs(process.cwd()), ...ancestorDirs(fromModule)];
  const seen = new Set<string>();
  for (const root of roots) {
    if (seen.has(root)) continue;
    seen.add(root);
    const p = join(root, ...REGISTRY_TAIL);
    if (existsSync(p)) return root;
  }
  throw new Error(
    "[terravolt] Could not locate repo root for headless addon path resolution. Run from terra-volt monorepo or set TERRAVOLT_HEADLESS_DRIVER_GD.",
  );
}

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

/**
 * Accept either a `file://` URL (preferred — `import.meta.url`) or an
 * already-decoded absolute filesystem path. Windows paths look like URLs
 * (`H:\...`) so we can't always re-decode; tolerate both shapes.
 */
function toFsPath(urlOrPath: string): string {
  if (urlOrPath.startsWith("file://")) return fileURLToPath(urlOrPath);
  if (isAbsolute(urlOrPath)) return urlOrPath;
  throw new Error(`[terravolt] Expected a file:// URL or absolute path, got: ${urlOrPath}`);
}

/**
 * Find `packages/shared/methods/registry.json` —
 * honours `process.env.TERRAVOLT_METHOD_REGISTRY_JSON` override;
 * otherwise probes `cwd` then ancestors of `import.meta.url` (bundled/dist-safe).
 */
export function resolveMethodRegistryJsonPath(importMetaUrl: string): string {
  const envPath = process.env.TERRAVOLT_METHOD_REGISTRY_JSON;
  if (envPath) {
    if (!existsSync(envPath)) {
      throw new Error(
        `[terravolt] TERRAVOLT_METHOD_REGISTRY_JSON points to missing file: ${envPath}`,
      );
    }
    return envPath;
  }

  const fromModule = dirname(toFsPath(importMetaUrl));
  const roots = [...ancestorDirs(process.cwd()), ...ancestorDirs(fromModule)];
  const seen = new Set<string>();
  for (const root of roots) {
    if (seen.has(root)) continue;
    seen.add(root);
    const p = join(root, ...REGISTRY_TAIL);
    if (existsSync(p)) return p;
  }

  throw new Error(
    `[terravolt] Method registry JSON not found under cwd or ancestors of compiled module.\nSet TERRAVOLT_METHOD_REGISTRY_JSON to an absolute path, or run from the monorepo root.`,
  );
}

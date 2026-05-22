import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

import type { MethodRegistryFile } from "./methodRegistry.types.js";
import { resolveMethodRegistryJsonPath } from "./repoRoot.js";

export type {
  MethodRegistryEntry,
  MethodRegistryFile,
  McpToolOverlay,
} from "./methodRegistry.types.js";

let cachedPath: string | undefined;

// `resolveMethodRegistryJsonPath` expects a `file://` URL (it runs
// `fileURLToPath` internally). On Windows, double-decoding the path
// raises ERR_INVALID_URL_SCHEME ("H:\..." is parsed with scheme `h:`).
function registryAbsolutePath(): string {
  cachedPath ??= resolveMethodRegistryJsonPath(import.meta.url);
  return cachedPath;
}

export function registryPath(): string {
  return registryAbsolutePath();
}

export function loadMethodRegistry(): MethodRegistryFile {
  const path = registryAbsolutePath();
  const raw = readFileSync(path, "utf8");
  return JSON.parse(raw) as MethodRegistryFile;
}

export function registryContentSha256(): string {
  const path = registryAbsolutePath();
  const raw = readFileSync(path, "utf8");
  return createHash("sha256").update(raw, "utf8").digest("hex");
}

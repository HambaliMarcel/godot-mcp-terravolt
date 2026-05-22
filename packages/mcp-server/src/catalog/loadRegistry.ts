import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export type McpToolOverlay = {
  name: string;
  title?: string;
  description?: string;
};

export type MethodRegistryEntry = {
  method: string;
  category: string;
  since: string;
  description: string;
  inputSchema: Record<string, unknown>;
  outputSchema?: Record<string, unknown>;
  mcpTool?: McpToolOverlay;
  requiresEditor: boolean;
  requiresRuntime: boolean;
  safe: boolean;
  mutates: boolean;
  errorCodes: unknown[];
  examples: unknown[];
};

export type MethodRegistryFile = {
  catalog_version: string;
  methods: MethodRegistryEntry[];
};

export function registryPath(): string {
  const here = dirname(fileURLToPath(import.meta.url));
  /** dist/catalog → workspace root (`packages/mcp-server/dist/catalog`) */
  const repoRoot = join(here, "..", "..", "..", "..");
  return join(repoRoot, "packages", "shared", "methods", "registry.json");
}

export function loadMethodRegistry(): MethodRegistryFile {
  const path = registryPath();
  const raw = readFileSync(path, "utf8");
  return JSON.parse(raw) as MethodRegistryFile;
}

export function registryContentSha256(): string {
  const raw = readFileSync(registryPath(), "utf8");
  return createHash("sha256").update(raw, "utf8").digest("hex");
}

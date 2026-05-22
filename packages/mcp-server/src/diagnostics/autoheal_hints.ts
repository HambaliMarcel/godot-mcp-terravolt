import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";

import { registryPath } from "../catalog/loadRegistry.js";

export type AutoHealBlock = Readonly<{ hint?: string; steps?: readonly string[] }>;

type BundleFile = Readonly<{
  bySymbol: Record<string, AutoHealBlock>;
  byCode: Record<string, AutoHealBlock>;
}>;

let cached: BundleFile | undefined;

/** Load sibling `packages/shared/diagnostics/autoheal.json`; empty maps on failure. */
export function loadAutoHealHintsBundle(): BundleFile {
  if (cached) return cached;
  const registry = registryPath();
  const candidate = join(dirname(dirname(registry)), "diagnostics", "autoheal.json");
  try {
    const raw = readFileSync(candidate, "utf8");
    cached = JSON.parse(raw) as BundleFile;
    return cached;
  } catch {
    cached = { bySymbol: {}, byCode: {} };
    return cached;
  }
}

/** Map daemon-normalized `{ code, message, data }` JSON-RPC errors to recovery guidance. */
export function resolveAutoHeal(daemonErr: Record<string, unknown>): AutoHealBlock | undefined {
  const bundle = loadAutoHealHintsBundle();
  const data =
    typeof daemonErr["data"] === "object" && daemonErr["data"] !== null
      ? (daemonErr["data"] as Record<string, unknown>)
      : {};
  const symbol = typeof data["symbol"] === "string" ? data["symbol"] : undefined;
  if (symbol !== undefined && bundle.bySymbol[symbol] !== undefined) {
    return bundle.bySymbol[symbol];
  }

  const codeRaw = daemonErr["code"];
  const codeNum =
    typeof codeRaw === "number" ? codeRaw : Number.parseInt(String(codeRaw ?? ""), 10);
  if (Number.isFinite(codeNum)) {
    const fromCode = bundle.byCode[String(codeNum)];
    if (fromCode !== undefined) return fromCode;
  }

  return undefined;
}

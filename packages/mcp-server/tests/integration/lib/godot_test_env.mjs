import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
export const repoRoot = resolve(here, "..", "..", "..", "..", "..");
const envFile = join(repoRoot, ".terravolt", "godot-env.json");

export function loadGodotBinary() {
  const fromEnv = process.env.TERRAVOLT_GODOT_BINARY;
  if (fromEnv && !/\.(cmd|bat)$/i.test(fromEnv) && existsSync(fromEnv)) {
    return fromEnv;
  }
  if (existsSync(envFile)) {
    try {
      const profile = JSON.parse(readFileSync(envFile, "utf8"));
      if (profile?.godotBinary && existsSync(profile.godotBinary)) return profile.godotBinary;
    } catch {
      /* ignore */
    }
  }
  return undefined;
}

export function headlessConfig(godotBinary, projectPath) {
  return {
    godotHost: "127.0.0.1",
    godotPort: 6505,
    connectTimeoutMs: 5000,
    heartbeatIntervalMs: 15_000,
    heartbeatTimeoutMs: 45_000,
    reconnectBaseMs: 500,
    reconnectMaxMs: 30_000,
    logLevel: "warn",
    requestTimeoutMs: 30_000,
    maxPayloadBytes: 4 * 1024 * 1024,
    token: undefined,
    notificationFilter: "all",
    packageVersion: "0.0.0-test",
    godotBinaryPath: godotBinary,
    godotBinaryEnv: undefined,
    projectPath,
    headlessBootTimeoutMs: 25_000,
    headlessOpTimeoutMs: 15_000,
    metricsWindowSec: 60,
    includeAutoHealHints: false,
  };
}

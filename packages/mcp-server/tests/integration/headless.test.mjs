/**
 * docs/tasklist/10 §10.6.2 integration smoke for headless §07.
 *
 * Skipped when TERRAVOLT_GODOT_BINARY is not set (CI without Godot installed).
 * Locally: `npm run env:godot` writes `.terravolt/godot-env.json`; set the env
 * var from that file before running `npm run test:server`.
 */
import { strict as assert } from "node:assert";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import test from "node:test";

import { HeadlessCoordinator } from "../../dist/headless/headlessCoordinator.js";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..", "..", "..", "..");
const envFile = join(repoRoot, ".terravolt", "godot-env.json");

function loadGodotBinary() {
  if (process.env.TERRAVOLT_GODOT_BINARY && existsSync(process.env.TERRAVOLT_GODOT_BINARY)) {
    return process.env.TERRAVOLT_GODOT_BINARY;
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

const godotBinary = loadGodotBinary();
const fixture = join(repoRoot, "tests", "_fixtures", "empty");

const skip = !godotBinary || !existsSync(fixture);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set / .terravolt/godot-env.json missing"
  : `fixture missing: ${fixture}`;

test("headless: drive `ping` + `server.info` over TCP", { skip: skip && skipReason }, async () => {
  const cfg = {
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
    projectPath: fixture,
    headlessBootTimeoutMs: 25_000,
    headlessOpTimeoutMs: 15_000,
    metricsWindowSec: 60,
    includeAutoHealHints: false,
  };

  const importMetaUrl = import.meta.url;
  const log = () => {};
  const coordinator = new HeadlessCoordinator(cfg, log, importMetaUrl);
  try {
    await coordinator.ensureSession(fixture);
    const status = coordinator.status();
    assert.equal(status.alive, true);

    const ping = await coordinator.rpc("ping", {});
    assert.equal(typeof ping, "object");
    assert.equal(ping.ok, true);
    assert.equal(typeof ping.ts, "number");

    const info = await coordinator.rpc("server.info", {});
    assert.equal(info.name, "terravolt-godot-headless");
    assert.equal(info.build_mode, "headless_tcp");
    assert.ok(String(info.godot_version).startsWith("4."), `godot_version: ${info.godot_version}`);
  } finally {
    await coordinator.stop(true);
  }
});

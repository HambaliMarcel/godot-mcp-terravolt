/**
 * docs/tasklist/10 §10.6.4 — real MCP stdio end-to-end smoke.
 *
 * Spawns `node dist/index.js` as a true MCP server and drives it with the
 * official `@modelcontextprotocol/sdk` Client over stdio. Confirms:
 *   1. `tools/list` exposes the §07 headless tools + daemon-bridged `ping`.
 *   2. `headless.start_project` boots the real Godot binary against the
 *      empty fixture and reports a live PID/port.
 *   3. `headless.validate_script` round-trips JSON-RPC to Godot and
 *      compiles a tiny .gd snippet under the same headless session.
 *   4. `headless.stop` cleanly terminates the spawned process.
 *
 * Skipped when no Godot binary can be located (CI without Godot installed).
 */
import { strict as assert } from "node:assert";
import { existsSync, readFileSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import test from "node:test";

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..", "..", "..", "..");
const envFile = join(repoRoot, ".terravolt", "godot-env.json");
const fixture = join(repoRoot, "tests", "_fixtures", "empty");
const routerEntry = join(repoRoot, "packages", "mcp-server", "dist", "index.js");

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
const skip = !godotBinary || !existsSync(fixture) || !existsSync(routerEntry);

const skipReason = !godotBinary
  ? "Godot binary unavailable (`npm run env:godot` first)"
  : !existsSync(routerEntry)
    ? "router dist missing (`npm run build:server` first)"
    : !existsSync(fixture)
      ? `fixture missing: ${fixture}`
      : "skipped";

test(
  "MCP stdio: tools/list + headless.* round-trip via real Godot",
  { skip: skip && skipReason },
  async () => {
    const env = {
      ...process.env,
      TERRAVOLT_GODOT_BINARY: godotBinary,
      TERRAVOLT_PROJECT_PATH: fixture,
      TERRAVOLT_LOG_LEVEL: "warn",
      TERRAVOLT_CONNECT_TIMEOUT_MS: "750",
      TERRAVOLT_HEADLESS_BOOT_TIMEOUT_MS: "30000",
      TERRAVOLT_HEADLESS_OP_TIMEOUT_MS: "15000",
    };

    const transport = new StdioClientTransport({
      command: process.execPath,
      args: [routerEntry, "--godot-port", "1", "--connect-timeout-ms", "300"],
      env,
      stderr: "pipe",
    });
    const stderrChunks = [];
    const client = new Client(
      { name: "terravolt-e2e", version: "0.0.0-test" },
      { capabilities: { tools: {} } },
    );

    try {
      await client.connect(transport);
    } catch (e) {
      const stderr = transport.stderr;
      if (stderr) {
        try {
          for await (const c of stderr) stderrChunks.push(c.toString());
        } catch {
          /* ignore */
        }
      }
      e.message = `${e.message}\nROUTER STDERR:\n${stderrChunks.join("")}`;
      throw e;
    }
    transport.stderr?.on?.("data", (c) => stderrChunks.push(c.toString()));

    try {
      const tools = await client.listTools();
      const names = new Set(tools.tools.map((t) => t.name));
      for (const want of [
        "ping",
        "server_info",
        "tools_list",
        "tools_describe",
        "tools_metrics",
        "tools_bottlenecks",
        "tools_health",
        "context_fetch_raw",
        "headless_start_project",
        "headless_status",
        "headless_stop",
        "headless_validate_script",
      ]) {
        assert.ok(names.has(want), `missing tool: ${want}`);
      }

      const unwrap = (res) => res.structuredContent ?? JSON.parse(res.content?.[0]?.text ?? "{}");

      const startRes = await client.callTool({
        name: "headless_start_project",
        arguments: { projectPath: fixture },
      });
      assert.ok(!startRes.isError, `start failed: ${JSON.stringify(startRes)}`);
      const startEnv = unwrap(startRes);
      assert.equal(startEnv.ok, true);
      assert.equal(startEnv.tool, "headless_start_project");
      assert.equal(startEnv.result?.ready, true);
      assert.equal(typeof startEnv.result?.pid, "number");
      assert.equal(typeof startEnv.result?.port, "number");
      assert.ok(startEnv.result.port > 0);

      const statusRes = await client.callTool({ name: "headless_status", arguments: {} });
      const statusEnv = unwrap(statusRes);
      assert.equal(statusEnv.ok, true);
      assert.equal(statusEnv.result?.alive, true);

      const scratchDir = join(fixture, ".tv-scratch");
      mkdirSync(scratchDir, { recursive: true });
      const scratch = join(scratchDir, "noop.gd");
      writeFileSync(scratch, "extends Node\nfunc do_thing() -> int:\n\treturn 42\n", "utf8");

      try {
        const valRes = await client.callTool({
          name: "headless_validate_script",
          arguments: { path: scratch, projectPath: fixture },
        });
        const valEnv = unwrap(valRes);
        assert.ok(!valRes.isError, `validate isError: ${JSON.stringify(valEnv)}`);
        assert.equal(valEnv.ok, true);
        assert.equal(
          valEnv.result?.ok,
          true,
          `validate result not ok: ${JSON.stringify(valEnv.result)}`,
        );
      } finally {
        rmSync(scratchDir, { recursive: true, force: true });
      }

      const pingRes = await client.callTool({ name: "ping", arguments: {} });
      const pingEnv = unwrap(pingRes);
      assert.equal(pingEnv.ok, true, `ping failed: ${JSON.stringify(pingEnv)}`);
      assert.equal(
        pingEnv.method,
        "ping@headless",
        `expected headless fallback route, got: ${pingEnv.method}`,
      );
      assert.equal(pingEnv.result?.ok, true);

      const stopRes = await client.callTool({ name: "headless_stop", arguments: { force: true } });
      const stopEnv = unwrap(stopRes);
      assert.equal(stopEnv.ok, true);
    } finally {
      await client.close().catch(() => {});
    }
  },
);

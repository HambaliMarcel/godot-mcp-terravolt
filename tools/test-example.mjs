#!/usr/bin/env node
/**
 * End-to-end smoke against examples/playable-demo via the live MCP headless
 * coordinator. Confirms:
 *
 *   - scene.list returns >= 1 scene under res://
 *   - scene.get on res://main.tscn returns a parsed envelope (root_type, deps)
 *   - headless.validate_script on res://scripts/Player.gd reports no errors
 *   - project.settings_get returns config/name and run/main_scene
 *
 * Prints a single PASS or FAIL line for each check.
 */
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { HeadlessCoordinator } from "../packages/mcp-server/dist/headless/headlessCoordinator.js";
import {
  headlessConfig,
  loadGodotBinary,
} from "../packages/mcp-server/tests/integration/lib/godot_test_env.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..");
const demoPath = join(repoRoot, "examples", "playable-demo");

const godotBinary = loadGodotBinary();
if (!godotBinary) {
  console.error("FAIL setup: TERRAVOLT_GODOT_BINARY not set and .terravolt/godot-env.json missing");
  process.exit(2);
}
if (!existsSync(demoPath)) {
  console.error(`FAIL setup: demo missing at ${demoPath}`);
  process.exit(2);
}

const coordinator = new HeadlessCoordinator(
  headlessConfig(godotBinary, demoPath),
  () => {},
  import.meta.url,
);

const results = [];
function record(name, ok, detail = "") {
  results.push({ name, ok, detail });
  const line = ok ? `PASS ${name}` : `FAIL ${name}`;
  console.log(detail ? `${line} :: ${detail}` : line);
}

try {
  await coordinator.ensureSession(demoPath);

  const info = await coordinator.rpc("server.info", {});
  record("server.info", !!info?.godot_version, `godot=${info?.godot_version}`);

  const list = await coordinator.rpc("scene.list", {});
  record(
    "scene.list >=1 scene",
    Array.isArray(list?.scenes) && list.scenes.length >= 1,
    `total=${list?.total}, scenes=${(list?.scenes || []).map((s) => s.path).join(",")}`,
  );

  const main = await coordinator.rpc("scene.get", { path: "res://main.tscn" });
  record(
    "scene.get main.tscn parses",
    main?.root_type === "Node2D" && Array.isArray(main?.dependencies),
    `root_type=${main?.root_type}, node_count=${main?.node_count}, deps=${(main?.dependencies || []).length}`,
  );

  const script = await coordinator.rpc("script.validate", {
    path: "res://scripts/Player.gd",
  });
  record(
    "script.validate Player.gd",
    script?.ok === true && (script?.errors?.length ?? 0) === 0,
    `errors=${JSON.stringify(script?.errors ?? null)}`,
  );

  const scriptList = await coordinator.rpc("script.list", {});
  record(
    "script.list finds Player.gd",
    Array.isArray(scriptList?.scripts) &&
      scriptList.scripts.some((s) => String(s.path).endsWith("Player.gd")),
    `total=${scriptList?.total}`,
  );

  const projInfo = await coordinator.rpc("project.info", {});
  record(
    "project.info reports playable-demo + main.tscn",
    String(projInfo?.name ?? "").includes("playable-demo") &&
      String(projInfo?.main_scene ?? "").endsWith("main.tscn"),
    `name=${projInfo?.name}, main_scene=${projInfo?.main_scene}, autoloads=${projInfo?.autoload_count}`,
  );

  const settings = await coordinator.rpc("project.get_settings", { group: "application" });
  const cfg = settings?.settings || {};
  const mainSceneRow = cfg["application/run/main_scene"];
  const mainScene = mainSceneRow?.value ?? mainSceneRow;
  record(
    "project.get_settings run/main_scene wired",
    String(mainScene ?? "").endsWith("main.tscn"),
    `main_scene=${JSON.stringify(mainScene)}`,
  );
} catch (e) {
  console.error("FATAL", e?.message || e, e?.rpc || "");
  process.exitCode = 1;
} finally {
  await coordinator.stop(true);
}

const failed = results.filter((r) => !r.ok);
console.log("");
console.log(`summary: ${results.length - failed.length}/${results.length} checks passed`);
if (failed.length > 0) {
  process.exitCode = 1;
}

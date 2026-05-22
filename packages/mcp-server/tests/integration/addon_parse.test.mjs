/**
 * docs/tasklist/10 §10.6.5 — parse-check every TerraVolt addon `.gd` file
 * inside a real Godot project that mounts the addon, so `class_name`
 * siblings resolve (mirrors what a developer with `addon:link` would see).
 *
 * Implementation: `godot --headless --import --path <fixture>` boots the
 * editor in headless mode and runs the full project compile pass, which
 * populates `script_class_cache.cfg` and surfaces every GDScript parse
 * error as exit code != 0 or `SCRIPT ERROR:` stderr line.
 *
 * Skipped when no Godot binary is available.
 */
import { strict as assert } from "node:assert";
import { spawnSync } from "node:child_process";
import { cpSync, existsSync, readFileSync, rmSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import test from "node:test";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "..", "..", "..", "..");
const envFile = join(repoRoot, ".terravolt", "godot-env.json");
const fixture = join(repoRoot, "tests", "_fixtures", "with-addon");
const addonSrc = join(repoRoot, "packages", "godot-mcp-addon");
const addonDst = join(fixture, "addons", "terravolt_mcp");

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
const skip = !godotBinary || !existsSync(addonSrc) || !existsSync(fixture);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set / .terravolt/godot-env.json missing"
  : !existsSync(addonSrc)
    ? `addon missing: ${addonSrc}`
    : `fixture missing: ${fixture}`;

test("addon parse-check: every .gd compiles under real Godot 4", { skip: skip && skipReason }, () => {
  try {
    rmSync(addonDst, { recursive: true, force: true });
    cpSync(addonSrc, addonDst, { recursive: true });

    const res = spawnSync(
      godotBinary,
      ["--headless", "--import", "--path", fixture],
      { encoding: "utf8", windowsHide: true, timeout: 90_000 },
    );

    const stderr = (res.stderr ?? "") + "\n" + (res.stdout ?? "");
    const parseErrors = stderr
      .split(/\r?\n/)
      .filter((line) => /SCRIPT ERROR:\s+Parse Error:/.test(line))
      .slice(0, 40);

    assert.equal(
      parseErrors.length,
      0,
      `Godot --import reported ${parseErrors.length} GDScript parse error(s):\n  ${parseErrors.join("\n  ")}`,
    );
    assert.equal(
      res.status,
      0,
      `Godot --import exited ${res.status}\nstderr:\n${stderr.slice(0, 2000)}`,
    );
  } finally {
    rmSync(addonDst, { recursive: true, force: true });
    const godotMeta = join(fixture, ".godot");
    if (existsSync(godotMeta)) {
      try {
        const s = statSync(godotMeta);
        if (s.isDirectory()) rmSync(godotMeta, { recursive: true, force: true });
      } catch {
        /* ignore */
      }
    }
  }
});

#!/usr/bin/env node
/**
 * docs/tasklist/10 §A.1 helper.
 *
 * Locate a Godot 4.x exe (Mono or vanilla) at the canonical user-local install
 * directory and write a small JSON profile under `<repo>/.terravolt/godot-env.json`
 * so subsequent tools (router, CI smoke, contributors) can find it without
 * persisting machine-level `PATH` changes.
 *
 * Resolution order:
 *  1. `--godot-binary` flag (passed through).
 *  2. `TERRAVOLT_GODOT_BINARY` env var.
 *  3. PATH scan (`godot`, `godot4`, `Godot_v4*`).
 *  4. Per-platform canonical install dirs:
 *       Windows: `%LOCALAPPDATA%\Programs\Godot\**`, `%USERPROFILE%\Tools\Godot\**`,
 *                `C:\Program Files\Godot`, `C:\Tools\Godot`
 *       macOS:   `/Applications/Godot.app/Contents/MacOS/Godot`,
 *                `/Applications/Godot 4.app/Contents/MacOS/Godot`
 *       Linux:   `~/.local/share/godot`, `/usr/local/bin/godot4`, `/usr/bin/godot4`
 *
 * Outputs to stdout the variables a shell can `eval` (POSIX) or set (PowerShell),
 * and writes JSON to `<repo>/.terravolt/godot-env.json` for the router's
 * `--print-config` to consume.
 */
import { existsSync, mkdirSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { platform } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

function parseArgv(argv) {
  const out = { godotBinary: undefined, quiet: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--godot-binary" && argv[i + 1]) {
      out.godotBinary = argv[++i];
    } else if (a.startsWith("--godot-binary=")) {
      out.godotBinary = a.slice("--godot-binary=".length);
    } else if (a === "--quiet") {
      out.quiet = true;
    }
  }
  return out;
}

function pickWindowsExe(dir) {
  let entries;
  try {
    entries = readdirSync(dir);
  } catch {
    return undefined;
  }
  const exes = entries.filter(
    (n) => n.toLowerCase().startsWith("godot") && n.toLowerCase().endsWith(".exe"),
  );
  if (exes.length === 0) return undefined;
  const consoleExe = exes.find((n) => /_console\.exe$/i.test(n));
  return path.join(dir, consoleExe ?? exes[0]);
}

function scanWindowsRoot(root) {
  if (!existsSync(root)) return undefined;
  const direct = pickWindowsExe(root);
  if (direct) return direct;
  let subs;
  try {
    subs = readdirSync(root);
  } catch {
    return undefined;
  }
  for (const sub of subs) {
    const child = path.join(root, sub);
    try {
      if (!statSync(child).isDirectory()) continue;
    } catch {
      continue;
    }
    const hit = pickWindowsExe(child);
    if (hit) return hit;
  }
  return undefined;
}

function scanFromPath() {
  const env = process.env.PATH ?? "";
  const dirs = env.split(path.delimiter).filter(Boolean);
  const names =
    platform() === "win32" ? ["godot.exe", "godot4.exe", "Godot.exe"] : ["godot", "godot4"];
  for (const d of dirs) {
    for (const n of names) {
      const attempt = path.join(d, n);
      if (existsSync(attempt)) return attempt;
    }
  }
  return undefined;
}

function resolveGodotBinary(opts) {
  if (opts.godotBinary && existsSync(opts.godotBinary)) return path.resolve(opts.godotBinary);
  const env = process.env.TERRAVOLT_GODOT_BINARY;
  if (env && existsSync(env)) return path.resolve(env);

  const fromPath = scanFromPath();
  if (fromPath) return fromPath;

  if (platform() === "win32") {
    const roots = [];
    if (process.env.LOCALAPPDATA)
      roots.push(path.join(process.env.LOCALAPPDATA, "Programs", "Godot"));
    if (process.env.USERPROFILE) roots.push(path.join(process.env.USERPROFILE, "Tools", "Godot"));
    roots.push(String.raw`C:\Program Files\Godot`, String.raw`C:\Tools\Godot`);
    for (const r of roots) {
      const hit = scanWindowsRoot(r);
      if (hit) return hit;
    }
  } else if (platform() === "darwin") {
    const macCandidates = [
      "/Applications/Godot.app/Contents/MacOS/Godot",
      "/Applications/Godot 4.app/Contents/MacOS/Godot",
    ];
    for (const c of macCandidates) if (existsSync(c)) return c;
  } else {
    const linuxCandidates = [
      "/usr/local/bin/godot4",
      "/usr/bin/godot4",
      "/usr/local/bin/godot",
      "/usr/bin/godot",
    ];
    if (process.env.HOME)
      linuxCandidates.push(path.join(process.env.HOME, ".local", "share", "godot", "godot"));
    for (const c of linuxCandidates) if (existsSync(c)) return c;
  }

  return undefined;
}

function detectVersion(godotBinary) {
  const r = spawnSync(godotBinary, ["--version"], { encoding: "utf8" });
  if (r.status !== 0) return undefined;
  return (r.stdout ?? "").trim() || undefined;
}

function main() {
  const opts = parseArgv(process.argv.slice(2));
  const root = findTerravoltRepoRoot(import.meta.url);

  const binary = resolveGodotBinary(opts);
  if (!binary) {
    process.stderr.write(
      "[setup-godot-env] No Godot 4 executable found. Pass --godot-binary <abs path>, set TERRAVOLT_GODOT_BINARY, or install Godot under %LOCALAPPDATA%\\Programs\\Godot\\.\n",
    );
    process.exit(2);
  }

  const version = detectVersion(binary);
  const outDir = path.join(root, ".terravolt");
  mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, "godot-env.json");
  const profile = {
    godotBinary: binary,
    detectedVersion: version ?? null,
    detectedAt: new Date().toISOString(),
    platform: platform(),
  };
  writeFileSync(outPath, `${JSON.stringify(profile, null, 2)}\n`, "utf8");

  if (!opts.quiet) {
    process.stdout.write(`# TerraVolt Godot env -> ${outPath}\n`);
    if (platform() === "win32") {
      process.stdout.write(`$env:TERRAVOLT_GODOT_BINARY = "${binary}"\n`);
    } else {
      process.stdout.write(`export TERRAVOLT_GODOT_BINARY="${binary}"\n`);
    }
    if (version) process.stdout.write(`# version: ${version}\n`);
  }
}

main();

import { existsSync, readdirSync, statSync } from "node:fs";
import { platform } from "node:os";
import path from "node:path";

const COMMON_DARWIN = [
  "/Applications/Godot.app/Contents/MacOS/Godot",
  "/Applications/Godot 4.app/Contents/MacOS/Godot",
];

/** Top-level Windows directories scanned for an unpacked Godot tree. */
function windowsScanRoots(): string[] {
  const roots: string[] = [];
  const localAppData = process.env.LOCALAPPDATA;
  if (localAppData) {
    roots.push(path.join(localAppData, "Programs", "Godot"));
  }
  const userProfile = process.env.USERPROFILE;
  if (userProfile) {
    roots.push(path.join(userProfile, "Tools", "Godot"));
  }
  roots.push(String.raw`C:\Program Files\Godot`, String.raw`C:\Tools\Godot`);
  return roots;
}

/** Return the first `Godot*.exe` (preferring `_console` for stable stderr capture). */
function pickWindowsExe(dir: string): string | undefined {
  let entries: string[];
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
  return path.join(dir, consoleExe ?? exes[0]!);
}

/** Walk one level of subdirectories under `root` and return the first `Godot*.exe` found. */
function scanWindowsRoot(root: string): string | undefined {
  if (!existsSync(root)) return undefined;
  const direct = pickWindowsExe(root);
  if (direct !== undefined) return direct;
  let subs: string[];
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
    if (hit !== undefined) return hit;
  }
  return undefined;
}

/** Resolution order mirrors docs/tasklist/07 §7.6.2 and docs/guides/quick-start.md. */
export function resolveGodotBinary(opts: {
  readonly argvFlag?: string;
  readonly envBinary?: string;
}): string | undefined {
  if (opts.argvFlag && opts.argvFlag.length > 0 && existsSync(opts.argvFlag))
    return path.resolve(opts.argvFlag);
  if (opts.envBinary && opts.envBinary.length > 0 && existsSync(opts.envBinary))
    return path.resolve(opts.envBinary);

  const pathEnv = process.env.PATH ?? "";
  const dirs = pathEnv.split(path.delimiter).filter(Boolean);
  const names = ["godot", "Godot_v4_stable", "godot4"];

  for (const d of dirs) {
    for (const n of names) {
      const attempt = path.join(d, platform() === "win32" ? `${n}.exe` : n);
      if (existsSync(attempt)) return attempt;
    }
  }

  if (platform() === "darwin") {
    for (const pth of COMMON_DARWIN) {
      if (existsSync(pth)) return pth;
    }
  }
  if (platform() === "win32") {
    for (const root of windowsScanRoots()) {
      const hit = scanWindowsRoot(root);
      if (hit !== undefined) return hit;
    }
  }

  return undefined;
}

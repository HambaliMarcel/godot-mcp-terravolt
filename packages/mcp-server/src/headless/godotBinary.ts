import { existsSync } from "node:fs";
import { platform } from "node:os";
import path from "node:path";

const COMMON_WIN = [String.raw`C:\Program Files\Godot\Godot.exe`, String.raw`C:\Program Files\Godot\bin\godot_console.exe`];
const COMMON_DARWIN = [
  "/Applications/Godot.app/Contents/MacOS/Godot",
  "/Applications/Godot 4.app/Contents/MacOS/Godot",
];

/** Resolution order mirrors docs/tasklist/07 §7.6.2 (approx). */
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
    for (const pth of COMMON_WIN) {
      if (existsSync(pth)) return pth;
    }
  }

  return undefined;
}

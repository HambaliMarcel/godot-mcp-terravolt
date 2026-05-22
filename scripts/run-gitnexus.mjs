/**
 * Runs local `gitnexus analyze` with GITNEXUS_NO_GITIGNORE=1 so `references/`
 * (ignored in .gitignore) is indexed; suppressions stay in `.gitnexusignore`.
 *
 * Invokes `node node_modules/gitnexus/dist/cli/index.js analyze` so paths with
 * spaces work (avoids spawning `.cmd` shims via `spawnSync`).
 */
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");

const cli = join(repoRoot, "node_modules", "gitnexus", "dist", "cli", "index.js");

const env = {
  ...process.env,
  GITNEXUS_NO_GITIGNORE: "1",
};

if (!existsSync(cli)) {
  console.error(
    "[intel:gitnexus] missing `node_modules/gitnexus` — run `npm install` in the repo root."
  );
  process.exit(1);
}

const result = spawnSync(process.execPath, [cli, "analyze"], {
  cwd: repoRoot,
  stdio: "inherit",
  env,
  shell: false,
});

if (result.error) {
  console.error("[intel:gitnexus]", result.error.message ?? result.error);
  process.exit(1);
}

process.exit(result.status === null ? 1 : result.status);

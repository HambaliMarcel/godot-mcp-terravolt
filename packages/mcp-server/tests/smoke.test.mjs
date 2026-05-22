import { strict as assert } from "node:assert";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import test from "node:test";

const pkgRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const entry = join(pkgRoot, "dist", "index.js");

test("CLI --version prints package name and semver", () => {
  const r = spawnSync(process.execPath, [entry, "--version"], {
    encoding: "utf8",
  });
  assert.equal(r.status, 0, r.stderr || r.stdout);
  assert.match((r.stderr ?? "").trim(), /^terravolt-godot-mcp\s+\d+\.\d+\.\d+/);
});

test("CLI --print-config exits 0 with JSON on stderr", () => {
  const r = spawnSync(process.execPath, [entry, "--print-config"], {
    encoding: "utf8",
  });
  assert.equal(r.status, 0, r.stderr);
  const cfg = JSON.parse(r.stderr.trim());
  assert.equal(typeof cfg.godotPort, "number");
  assert.equal(cfg.godotPort, 6505);
});

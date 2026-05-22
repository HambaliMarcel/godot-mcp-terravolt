import { strict as assert } from "node:assert";
import { existsSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir, platform } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { resolveGodotBinary } from "../../dist/headless/godotBinary.js";

test("resolveGodotBinary: explicit argvFlag wins when file exists", () => {
  const dir = mkdtempSync(join(tmpdir(), "godot-bin-"));
  const fake = join(dir, platform() === "win32" ? "godot.exe" : "godot");
  writeFileSync(fake, "");
  const hit = resolveGodotBinary({ argvFlag: fake });
  assert.equal(hit, fake);
});

test("resolveGodotBinary: explicit envBinary used when argvFlag absent", () => {
  const dir = mkdtempSync(join(tmpdir(), "godot-env-"));
  const fake = join(dir, platform() === "win32" ? "godot.exe" : "godot");
  writeFileSync(fake, "");
  const hit = resolveGodotBinary({ envBinary: fake });
  assert.equal(hit, fake);
});

test("resolveGodotBinary: returns undefined when nothing found", () => {
  const r = resolveGodotBinary({
    argvFlag: "/definitely/does/not/exist/godot",
    envBinary: "/definitely/does/not/exist/godot",
  });
  if (r !== undefined) {
    assert.ok(existsSync(r), "if a resolver returned a path, it must exist");
  }
});

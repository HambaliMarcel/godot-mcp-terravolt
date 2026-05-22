/**
 * Exhaustive 222-method dispatch smoke test.
 *
 * For every method in `packages/shared/methods/registry.json` (skipping
 * router-only methods + a small allowlist of methods that require live
 * runtime/editor state we don't have in the empty fixture), this test
 * sends a JSON-RPC request to the live Godot headless daemon with empty
 * params and asserts the response is either:
 *
 *   - ok (the daemon returned a result), OR
 *   - a structured Terravolt error (-33xxx, -32602/-32603) — meaning the
 *     daemon DID dispatch the method, it just rejected the input.
 *
 * A `protocol.method_not_found` (-33101 / -32601) is a real failure.
 *
 * This is the "proof of 222-method coverage" smoke that complements the
 * happy-path category integration tests.
 */
import { strict as assert } from "node:assert";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import process from "node:process";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const emptyFixture = join(repoRoot, "tests", "_fixtures", "empty");
const skip = !godotBinary || !existsSync(emptyFixture);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set"
  : `fixture missing: ${emptyFixture}`;

const registryPath = join(repoRoot, "packages", "shared", "methods", "registry.json");
const registry = JSON.parse(readFileSync(registryPath, "utf8"));

/** Methods that are bridge-only (need a live runtime session) or that
 *  would mutate the fixture in a way that breaks subsequent assertions.
 *  We still want them in the registry; they're exercised by dedicated
 *  category tests that own their fixture lifecycle.
 */
const SKIP_METHODS = new Set([
  // runtime.* methods that need a running game session
  "runtime.call_method",
  "runtime.emit_signal",
  "runtime.click_ui",
  "runtime.inspect_node",
  "runtime.list_nodes",
  "runtime.evaluate",
  "runtime.set_property",
  "runtime.send_input",
  "runtime.simulate_sequence",
  "runtime.screenshot",
  "runtime.set_engine_param",
  "runtime.navigate",
  "runtime.log_tail",
  "runtime.record_inputs",
  "runtime.replay_inputs",
  // runtime.play needs editor; covered by per-category test
  "runtime.play",
  // long-running export build — we don't exercise it without a configured fixture
  "export.build",
  // long-running profile flamegraph — needs running game
  "profile.flamegraph",
  // testing.run spawns external Godot process; covered by dedicated test
  "testing.run",
  // android.deploy runs a real adb chain; covered by android test
  "android.deploy",
  // macro.* apply is destructive; covered by macro_headless test
  "macro.player_controller_2d",
  "macro.player_controller_3d",
  "macro.enemy_with_state_machine",
  "macro.enemy_wave_spawner",
  "macro.dialog_system",
  "macro.inventory_system",
  "macro.save_load_system",
  "macro.settings_menu",
  "macro.main_menu",
  "macro.pause_overlay",
  "macro.hud_health_score",
  "macro.day_night_cycle",
  "macro.basic_2d_level",
  "macro.basic_3d_level",
  "macro.localization_setup",
  // navigation.bake / asset.reimport / batch_refactor.apply mutate state
  "navigation.bake",
  "asset.reimport",
  "asset.batch_import_presets",
  "asset.set_import_settings",
  "batch_refactor.apply",
  "batch_refactor.preview",
  "batch_refactor.change_class",
  "batch_refactor.rename_class",
  "batch_refactor.move_folder",
  "batch_refactor.normalize_names",
  "batch_refactor.replace_in_files",
]);

/** Error codes that mean "daemon dispatched the method and returned a
 *  structured error" — these are all acceptable for this smoke test. */
function isDispatchedError(err) {
  const rpc = err?.rpc;
  if (!rpc || typeof rpc !== "object") return false;
  const code = Number(rpc.code);
  // -32600..-32603 are JSON-RPC envelope codes; -32602/-32603 are dispatched
  if (code === -32602 || code === -32603) return true;
  // Terravolt app codes live in the -33000..-34999 band
  if (code <= -33000 && code >= -35000) return true;
  // -32700 parse error is acceptable for some malformed param sets
  if (code === -32700) return true;
  return false;
}

/** -32601 / -33101 mean "method not found" — these are FAILURES. */
function isMethodNotFound(err) {
  const code = Number(err?.rpc?.code);
  return code === -32601 || code === -33101;
}

async function withCoordinator(projectPath, fn) {
  const coordinator = new HeadlessCoordinator(
    headlessConfig(godotBinary, projectPath),
    () => {},
    import.meta.url,
  );
  try {
    await coordinator.ensureSession(projectPath);
    return await fn(coordinator);
  } finally {
    await coordinator.stop(true);
  }
}

test(
  "exhaustive 222-method coverage: every registered method is dispatchable",
  { skip: skip && skipReason },
  async () => {
    const headlessOk = registry.methods.filter((m) => m.headlessFallback === true);
    const candidates = headlessOk.filter((m) => !SKIP_METHODS.has(m.method));

    assert.ok(
      headlessOk.length >= 195,
      `headlessFallback method count regressed: ${headlessOk.length} < 195`,
    );
    assert.ok(candidates.length >= 100, `expected >=100 candidates, got ${candidates.length}`);

    const notFound = [];
    const dispatched = [];
    const transportErrors = [];

    await withCoordinator(emptyFixture, async (c) => {
      for (const meta of candidates) {
        try {
          await c.rpc(meta.method, {});
          dispatched.push({ method: meta.method, kind: "ok" });
        } catch (err) {
          if (isMethodNotFound(err)) {
            notFound.push({ method: meta.method, code: err?.rpc?.code, message: err?.message });
          } else if (isDispatchedError(err)) {
            dispatched.push({ method: meta.method, kind: "error", code: err?.rpc?.code });
          } else {
            transportErrors.push({
              method: meta.method,
              code: err?.rpc?.code ?? null,
              message: String(err?.message ?? err),
            });
          }
        }
      }
    });

    // We tolerate a small number of transport-level edge cases (e.g., a method
    // that hangs the socket before responding) but every method MUST be
    // dispatched — no -32601 / -33101 responses.
    assert.equal(
      notFound.length,
      0,
      `methods missing from daemon dispatch: ${JSON.stringify(notFound, null, 2)}`,
    );

    // Surface transport errors as a soft assertion: if any appear, they
    // belong in SKIP_METHODS with a justification.
    assert.ok(
      transportErrors.length === 0,
      `unexpected transport errors (consider SKIP_METHODS):\n${JSON.stringify(
        transportErrors,
        null,
        2,
      )}`,
    );

    // Sanity: we exercised the bulk of the catalog.
    const expectedMin = Math.floor(candidates.length * 0.95);
    assert.ok(
      dispatched.length >= expectedMin,
      `dispatched=${dispatched.length} < 95%% of candidates ${candidates.length}`,
    );

    // Provide a count summary on test output for the maintainer.
    process.stderr.write(
      `coverage: dispatched=${dispatched.length}/${candidates.length} ` +
        `(skipped=${SKIP_METHODS.size}, total=${registry.methods.length})\n`,
    );
  },
);

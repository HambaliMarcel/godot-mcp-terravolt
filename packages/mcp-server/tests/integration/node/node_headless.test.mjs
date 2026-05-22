/**
 * Tasklist 12 — headless integration for node.* (docs/tasklist/12 §12.9).
 */
import { strict as assert } from "node:assert";
import { existsSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { HeadlessCoordinator } from "../../../dist/headless/headlessCoordinator.js";
import { headlessConfig, loadGodotBinary, repoRoot } from "../lib/godot_test_env.mjs";

const godotBinary = loadGodotBinary();
const minimal3dFixture = join(repoRoot, "tests", "_fixtures", "minimal_3d");
const skip = !godotBinary || !existsSync(minimal3dFixture);
const skipReason = !godotBinary
  ? "TERRAVOLT_GODOT_BINARY not set"
  : `fixture missing: ${minimal3dFixture}`;

test("node.* headless round-trips", { skip: skip && skipReason }, async () => {
  const coordinator = new HeadlessCoordinator(
    headlessConfig(godotBinary, minimal3dFixture),
    () => {},
    import.meta.url,
  );
  try {
    await coordinator.ensureSession(minimal3dFixture);

    const rootGet = await coordinator.rpc("node.get", { path: "." });
    assert.equal(rootGet.type, "Node3D");
    assert.equal(rootGet.name, "Main");

    const is3d = await coordinator.rpc("node.is_a", { path: ".", type: "Node3D" });
    assert.equal(is3d.match, true);

    const added = await coordinator.rpc("node.add", {
      parent_path: ".",
      type: "Node3D",
      name: "ChildProbe",
    });
    assert.ok(String(added.added_path).includes("ChildProbe"));

    const modified = await coordinator.rpc("node.modify", {
      path: added.added_path,
      ops: [
        { kind: "add_to_group", group: "probe" },
        { kind: "set", key: "position", value: { x: 1, y: 2, z: 3 } },
      ],
    });
    assert.ok(modified.applied.length >= 1);

    const groups = await coordinator.rpc("node.list_groups", { path: added.added_path });
    assert.ok(groups.groups.includes("probe"));

    const evalOk = await coordinator.rpc("node.evaluate_expression", {
      path: ".",
      expression: "1 + 2",
    });
    assert.equal(evalOk.value, 3);

    await assert.rejects(
      () => coordinator.rpc("node.evaluate_expression", { path: ".", expression: "OS.get_name()" }),
      (err) => {
        assert.match(String(err), /expression\.forbidden_identifier|33529/i);
        return true;
      },
    );

    const deleted = await coordinator.rpc("node.delete", { path: added.added_path });
    assert.equal(deleted.deleted_path, added.added_path);
  } finally {
    await coordinator.stop(true);
  }
});

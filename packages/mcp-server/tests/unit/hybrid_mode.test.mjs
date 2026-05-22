// Unit tests for hybrid-mode plumbing: route_mode in the success envelope and
// the per-call `_mode` override resolution. Drives the router-internal helpers
// from `dist/` so we don't need a live Godot session.

import { strict as assert } from "node:assert";
import test from "node:test";

import { successEnvelope } from "../../dist/mcp/tool_result_envelopes.js";

test("successEnvelope: explicit routeMode wins", () => {
  const env = successEnvelope("ping", "ping@editor", 12, { ok: true }, "editor");
  assert.equal(env.route_mode, "editor");
  assert.equal(env.method, "ping@editor");
  assert.equal(env.tool, "ping");
});

test("successEnvelope: infers headless from @headless suffix", () => {
  const env = successEnvelope("scene_list", "scene.list@headless", 5, {});
  assert.equal(env.route_mode, "headless");
});

test("successEnvelope: infers editor from @editor suffix", () => {
  const env = successEnvelope("scene_list", "scene.list@editor", 5, {});
  assert.equal(env.route_mode, "editor");
});

test("successEnvelope: infers router for local.* methods", () => {
  const env = successEnvelope("tools_list", "local", 1, []);
  assert.equal(env.route_mode, "router");
  const env2 = successEnvelope("mode_status", "local.mode_status", 1, {});
  assert.equal(env2.route_mode, "router");
});

test("successEnvelope: defaults to editor for unknown daemon methods", () => {
  const env = successEnvelope("scene_list", "scene.list", 5, {});
  assert.equal(env.route_mode, "editor");
});

test("successEnvelope: shape includes ok/tool/method/latencyMs/result", () => {
  const env = successEnvelope("t", "m@editor", 7, { a: 1 });
  assert.equal(env.ok, true);
  assert.equal(env.tool, "t");
  assert.equal(env.method, "m@editor");
  assert.equal(env.latencyMs, 7);
  assert.deepEqual(env.result, { a: 1 });
  assert.equal(env.route_mode, "editor");
});

// Unit tests for the WebSocket transport resilience fixes (hello-readiness,
// peer_busy backoff, transport diagnostics). Drives the router against a
// stub Godot daemon implemented with the `ws` library — no real Godot needed.

import { strict as assert } from "node:assert";
import test from "node:test";
import { setTimeout as delay } from "node:timers/promises";
import { WebSocketServer } from "ws";

import { GodotWsClient } from "../../dist/transport/godot_ws_client.js";

const HELLO_FRAME = JSON.stringify({ note: "terravolt_mcp_server_hello_opaque" });

function silentLogger() {
  return () => {};
}

function baseConfig(port) {
  return {
    godotHost: "127.0.0.1",
    godotPort: port,
    connectTimeoutMs: 2000,
    requestTimeoutMs: 1500,
    reconnectBaseMs: 100,
    reconnectMaxMs: 2000,
    heartbeatIntervalMs: 60000,
    heartbeatTimeoutMs: 60000,
    maxPayloadBytes: 1_000_000,
    notificationFilter: "all",
  };
}

async function freePort() {
  const { createServer } = await import("node:net");
  return await new Promise((resolve, reject) => {
    const srv = createServer();
    srv.unref();
    srv.on("error", reject);
    srv.listen(0, "127.0.0.1", () => {
      const addr = srv.address();
      const p = typeof addr === "object" && addr ? addr.port : 0;
      srv.close(() => resolve(p));
    });
  });
}

test("transport: hello frame flips isReady and resets peerBusyCount", async () => {
  const port = await freePort();
  const wss = new WebSocketServer({ host: "127.0.0.1", port });
  wss.on("connection", (sock) => {
    sock.send(HELLO_FRAME);
  });

  const client = new GodotWsClient(baseConfig(port), silentLogger());
  client.start();
  try {
    const deadline = Date.now() + 3000;
    while (!client.isReady() && Date.now() < deadline) {
      await delay(25);
    }
    assert.equal(client.isReady(), true, "expected client to reach ready");
    const diag = client.getTransportDiagnostics();
    assert.equal(diag.helloReceived, true);
    assert.equal(diag.peerBusyCount, 0);
    assert.equal(diag.connectInFlight, false);
    assert.equal(typeof diag.url, "string");
  } finally {
    client.dispose();
    wss.close();
  }
});

test("transport: peer_busy close (1008) increments counter and surfaces diagnostics", async () => {
  const port = await freePort();
  const wss = new WebSocketServer({ host: "127.0.0.1", port });
  let connectionCount = 0;
  wss.on("connection", (sock) => {
    connectionCount += 1;
    // Immediately reject with the same close code the Godot addon uses.
    sock.close(1008, "policy violation: server busy");
  });

  const cfg = baseConfig(port);
  cfg.reconnectBaseMs = 50;
  cfg.reconnectMaxMs = 200;
  const client = new GodotWsClient(cfg, silentLogger());
  client.start();
  try {
    // Wait for at least two reject cycles so the counter ticks past one.
    const deadline = Date.now() + 4000;
    while (client.getTransportDiagnostics().peerBusyCount < 2 && Date.now() < deadline) {
      await delay(50);
    }
    const diag = client.getTransportDiagnostics();
    assert.ok(diag.peerBusyCount >= 1, `peerBusyCount should be >= 1, got ${diag.peerBusyCount}`);
    assert.equal(diag.lastCloseCode, 1008);
    assert.match(diag.lastCloseReason ?? "", /busy/i);
    assert.equal(diag.helloReceived, false);
    assert.ok(connectionCount >= 1);
  } finally {
    client.dispose();
    wss.close();
  }
});

test("transport: request() rejects with transport.not_connected when daemon down", async () => {
  const port = await freePort();
  const cfg = baseConfig(port);
  cfg.connectTimeoutMs = 250;
  cfg.requestTimeoutMs = 250;
  const client = new GodotWsClient(cfg, silentLogger());
  client.start();
  try {
    await assert.rejects(
      () => client.request("server.info", {}),
      (err) => {
        const code = err?.code ?? err?.message ?? "";
        return /transport\.not_connected/.test(String(code));
      },
    );
  } finally {
    client.dispose();
  }
});

test("transport: sustained peer_busy trips circuit breaker and resetPeerBusyCircuit clears it", async () => {
  const port = await freePort();
  const wss = new WebSocketServer({ host: "127.0.0.1", port });
  wss.on("connection", (sock) => {
    sock.close(1008, "policy violation: server busy");
  });

  const cfg = baseConfig(port);
  cfg.reconnectBaseMs = 25;
  cfg.reconnectMaxMs = 100;
  const client = new GodotWsClient(cfg, silentLogger());
  client.start();
  try {
    const deadline = Date.now() + 6000;
    while (!client.getTransportDiagnostics().circuitBroken && Date.now() < deadline) {
      await delay(40);
    }
    const tripped = client.getTransportDiagnostics();
    assert.equal(tripped.circuitBroken, true, "circuit should trip after sustained peer_busy");
    assert.ok(
      tripped.peerBusyCount >= 10,
      `peerBusyCount should be >= 10 when circuit trips, got ${tripped.peerBusyCount}`,
    );

    client.resetPeerBusyCircuit();
    const after = client.getTransportDiagnostics();
    assert.equal(after.circuitBroken, false, "resetPeerBusyCircuit should clear the flag");
    assert.equal(after.peerBusyCount, 0, "resetPeerBusyCircuit should zero the busy counter");
    assert.equal(after.backoffAttempt, 0, "resetPeerBusyCircuit should zero the backoff");
  } finally {
    client.dispose();
    wss.close();
  }
});

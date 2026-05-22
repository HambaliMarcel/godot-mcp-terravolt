#!/usr/bin/env node
/**
 * Improve Laminer via Terravolt Godot daemon JSON-RPC (same backend as MCP tools).
 * Uses one WebSocket client because max_peers=1 and Cursor's router may hold the slot stale.
 */
import { spawn } from "node:child_process";
import WebSocket from "../node_modules/ws/index.js";
import { setTimeout as sleep } from "node:timers/promises";

const laminer = "H:/Laminer/laminer";
const godotGui =
  "C:/Users/marce/AppData/Local/Programs/Godot/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64.exe";

let nextId = 1;

function makeCoinWavBase64() {
  const sr = 22050;
  const d = 0.14;
  const n = Math.floor(sr * d);
  const buf = Buffer.alloc(44 + n * 2);
  buf.write("RIFF", 0);
  buf.writeUInt32LE(36 + n * 2, 4);
  buf.write("WAVE", 8);
  buf.write("fmt ", 12);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20);
  buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(sr, 24);
  buf.writeUInt32LE(sr * 2, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write("data", 36);
  buf.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) {
    const t = i / sr;
    const e = Math.max(0, 1 - t / d);
    const s = (Math.sin(2 * Math.PI * 880 * t) + Math.sin(2 * Math.PI * 1320 * t) * 0.5) * e * 0.28;
    buf.writeInt16LE(Math.max(-32767, Math.min(32767, Math.floor(s * 32767))), 44 + i * 2);
  }
  return buf.toString("base64");
}

async function waitForPort(port, ms = 45000) {
  const net = await import("node:net");
  const start = Date.now();
  while (Date.now() - start < ms) {
    const ok = await new Promise((resolve) => {
      const s = net.createConnection({ host: "127.0.0.1", port }, () => {
        s.end();
        resolve(true);
      });
      s.on("error", () => resolve(false));
    });
    if (ok) return;
    await sleep(400);
  }
  throw new Error(`port ${port} not ready`);
}

class DaemonClient {
  constructor(url) {
    this.url = url;
    this.ws = null;
    this.pending = new Map();
  }

  async connect() {
    this.ws = new WebSocket(this.url);
    await new Promise((resolve, reject) => {
      const t = setTimeout(() => reject(new Error("ws connect timeout")), 12000);
      this.ws.once("open", () => {
        clearTimeout(t);
        resolve();
      });
      this.ws.once("error", (e) => {
        clearTimeout(t);
        reject(e);
      });
    });
    this.ws.on("message", (raw) => {
      let msg;
      try {
        msg = JSON.parse(raw.toString());
      } catch {
        return;
      }
      if (msg.id == null) return;
      const p = this.pending.get(msg.id);
      if (!p) return;
      this.pending.delete(msg.id);
      if (msg.error) p.reject(new Error(JSON.stringify(msg.error)));
      else p.resolve(msg.result);
    });
  }

  request(method, params = {}, timeoutMs = 90000) {
    const id = nextId++;
    const body = JSON.stringify({ jsonrpc: "2.0", id, method, params });
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`timeout ${method}`));
      }, timeoutMs);
      this.pending.set(id, {
        resolve: (r) => {
          clearTimeout(timer);
          resolve(r);
        },
        reject: (e) => {
          clearTimeout(timer);
          reject(e);
        },
      });
      this.ws.send(body);
    });
  }

  close() {
    this.ws?.close();
  }
}

function readScript(result) {
  return result?.content ?? result?.text ?? "";
}

async function main() {
  // Fresh editor session = free peer slot
  spawn("taskkill", ["/F", "/IM", "Godot_v4.6.3-stable_mono_win64.exe"], { shell: true });
  spawn("taskkill", ["/F", "/IM", "Godot_v4.6.3-stable_mono_win64_console.exe"], { shell: true });
  await sleep(2000);

  const editor = spawn(godotGui, ["--path", laminer, "--editor"], {
    detached: true,
    stdio: "ignore",
  });
  editor.unref();

  await waitForPort(6505);
  await sleep(1500);

  const rpc = new DaemonClient("ws://127.0.0.1:6505");
  await rpc.connect();
  await rpc.request("ping");
  console.log("daemon connected");

  await rpc.request("scene.open", { path: "res://scenes/mario_level.tscn" });

  await rpc.request("asset.add", {
    path: "res://assets/game/items/coinGold.png",
    source_url: "H:/Laminer/laminer/assets/kenney_platformer/PNG/Items/coinGold.png",
    overwrite: true,
  });

  await rpc.request("asset.add", {
    path: "res://assets/game/audio/sfx_coin.wav",
    content_base64: makeCoinWavBase64(),
    overwrite: true,
  });

  await rpc.request("script.write", {
    path: "res://scripts/coin_pickup.gd",
    content: `extends Area2D

@export var score_value := 10

func _ready() -> void:
\tmonitoring = true
\tbody_entered.connect(_on_body_entered)
\tvar sprite := Sprite2D.new()
\tsprite.texture = preload("res://assets/game/items/coinGold.png")
\tsprite.centered = true
\tsprite.position = Vector2(0, -12)
\tadd_child(sprite)
\tvar shape := CollisionShape2D.new()
\tvar circle := CircleShape2D.new()
\tcircle.radius = 14.0
\tshape.shape = circle
\tshape.position = Vector2(0, -12)
\tadd_child(shape)


func _on_body_entered(body: Node2D) -> void:
\tif body.is_in_group("player") and GameManager.state == "playing":
\t\tGameManager.collect_coin(score_value)
\t\tqueue_free()
`,
  });

  let gmText = readScript(
    await rpc.request("script.read", { path: "res://scripts/game_manager.gd" }),
  );
  if (!gmText.includes("score_changed")) {
    gmText = gmText
      .replace(
        "signal hp_changed(current: int, maximum: int)\n",
        "signal hp_changed(current: int, maximum: int)\nsignal score_changed(score: int)\n",
      )
      .replace("var hp: int = MAX_HP\n", "var hp: int = MAX_HP\nvar score: int = 0\n")
      .replace(
        '\t"win": preload("res://assets/game/audio/sfx_win.ogg"),\n}',
        '\t"coin": preload("res://assets/game/audio/sfx_coin.wav"),\n\t"win": preload("res://assets/game/audio/sfx_win.ogg"),\n}',
      )
      .replace(
        "\thp = MAX_HP\n\ttime_left = LEVEL_TIME\n",
        "\thp = MAX_HP\n\tscore = 0\n\ttime_left = LEVEL_TIME\n",
      )
      .replace(
        "\thp_changed.emit(hp, MAX_HP)\n\ttime_changed.emit(ceili(time_left))",
        "\thp_changed.emit(hp, MAX_HP)\n\tscore_changed.emit(score)\n\ttime_changed.emit(ceili(time_left))",
      )
      .replace(
        "func win() -> void:",
        `func collect_coin(value: int) -> void:
\tif state != "playing":
\t\treturn
\tscore += value
\tscore_changed.emit(score)
\tplay_sfx("coin")


func win() -> void:`,
      );
    await rpc.request("script.write", { path: "res://scripts/game_manager.gd", content: gmText });
  }

  let lbText = readScript(
    await rpc.request("script.read", { path: "res://scripts/level_builder.gd" }),
  );
  if (!lbText.includes("COINS")) {
    lbText = lbText
      .replace(
        "# [x, y, patrol]\nconst ENEMIES:",
        `# [x, y]
const COINS: Array = [
\t[260, 545],
\t[520, 475],
\t[850, 405],
\t[1250, 475],
\t[1680, 405],
\t[2450, 475],
\t[3050, 405],
\t[3500, 545],
]

# [x, y, patrol]
const ENEMIES:`,
      )
      .replace(
        "\tfor spec in ENEMIES:\n\t\t_spawn_enemy(parent, spec[0], spec[1], spec[2])\n\tgoal.global_position",
        "\tfor spec in ENEMIES:\n\t\t_spawn_enemy(parent, spec[0], spec[1], spec[2])\n\tfor pos in COINS:\n\t\t_spawn_coin(parent, pos[0], pos[1])\n\tgoal.global_position",
      );
    if (!lbText.includes("_spawn_coin")) {
      lbText += `

static func _spawn_coin(parent: Node2D, x: int, y: int) -> void:
\tvar coin := Area2D.new()
\tcoin.position = Vector2(x, y)
\tcoin.set_script(preload("res://scripts/coin_pickup.gd"))
\tparent.add_child(coin)
`;
    }
    await rpc.request("script.write", { path: "res://scripts/level_builder.gd", content: lbText });
  }

  let mlText = readScript(
    await rpc.request("script.read", { path: "res://scripts/mario_level.gd" }),
  );
  if (!mlText.includes("_score_label")) {
    mlText = mlText
      .replace(
        "@onready var _hp_display: HBoxContainer = $HUD/HpBars\n",
        "@onready var _hp_display: HBoxContainer = $HUD/HpBars\n@onready var _score_label: Label = $HUD/ScoreLabel\n",
      )
      .replace(
        "\tGameManager.game_lost.connect(_on_game_lost)\n",
        "\tGameManager.game_lost.connect(_on_game_lost)\n\tGameManager.score_changed.connect(_on_score_changed)\n",
      )
      .replace(
        "\t_on_hp_changed(GameManager.hp, GameManager.MAX_HP)\n",
        "\t_on_hp_changed(GameManager.hp, GameManager.MAX_HP)\n\t_on_score_changed(GameManager.score)\n",
      )
      .replace(
        "func _on_hp_changed(current: int, maximum: int) -> void:",
        `func _on_score_changed(value: int) -> void:
\t_score_label.text = "Score: %d" % value


func _on_hp_changed(current: int, maximum: int) -> void:`,
      );
    await rpc.request("script.write", { path: "res://scripts/mario_level.gd", content: mlText });

    await rpc.request("node.add", {
      scene_path: "res://scenes/mario_level.tscn",
      parent_path: "HUD",
      type: "Label",
      name: "ScoreLabel",
      properties: {
        offset_left: 280,
        offset_top: 42,
        offset_right: 420,
        offset_bottom: 68,
        text: "Score: 0",
      },
    });
  }

  await rpc.request("scene.save", { path: "res://scenes/mario_level.tscn" });
  for (const p of [
    "res://scripts/coin_pickup.gd",
    "res://scripts/game_manager.gd",
    "res://scripts/level_builder.gd",
    "res://scripts/mario_level.gd",
  ]) {
    await rpc.request("script.validate", { path: p });
  }

  rpc.close();
  console.log("OK: MCP daemon applied coin collectibles + score HUD");
}

main().catch((e) => {
  console.error("FAILED:", e.message ?? e);
  process.exit(1);
});

#!/usr/bin/env node
/**
 * Improve Laminer platformer exclusively via Terravolt MCP tools (stdio router).
 */
import { Client } from "../node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js";
import { StdioClientTransport } from "../node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const laminer = "H:/Laminer/laminer";
const routerEntry = join(repoRoot, "packages", "mcp-server", "dist", "index.js");

const env = {
  ...process.env,
  TERRAVOLT_GODOT_BINARY:
    "C:/Users/marce/AppData/Local/Programs/Godot/Godot_v4.6.3-stable_mono_win64/Godot_v4.6.3-stable_mono_win64_console.exe",
  TERRAVOLT_PROJECT_PATH: laminer,
  TERRAVOLT_CONNECT_TIMEOUT_MS: "10000",
  TERRAVOLT_REQUEST_TIMEOUT_MS: "90000",
  TERRAVOLT_LOG_LEVEL: "warn",
};

function unwrap(res) {
  if (res.isError) throw new Error(JSON.stringify(res));
  return res.structuredContent ?? JSON.parse(res.content?.[0]?.text ?? "{}");
}

async function call(client, name, args = {}) {
  const res = await client.callTool({ name, arguments: args });
  const body = unwrap(res);
  if (body.ok === false) throw new Error(`${name}: ${body.message ?? JSON.stringify(body)}`);
  return body;
}

function readText(body) {
  return body.result?.content ?? body.result?.text ?? "";
}

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

async function main() {
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [routerEntry],
    env,
    stderr: "pipe",
  });
  const client = new Client(
    { name: "laminer-improver", version: "1.0.0" },
    { capabilities: { tools: {} } },
  );
  await client.connect(transport);

  try {
    const ping = await call(client, "ping");
    console.log("connected via", ping.method, "latencyMs=", ping.latencyMs);

    await call(client, "scene_open", { path: "res://scenes/mario_level.tscn" });

    await call(client, "asset_add", {
      path: "res://assets/game/items/coinGold.png",
      source_url: "H:/Laminer/laminer/assets/kenney_platformer/PNG/Items/coinGold.png",
      overwrite: true,
    });

    await call(client, "asset_add", {
      path: "res://assets/game/audio/sfx_coin.wav",
      content_base64: makeCoinWavBase64(),
      overwrite: true,
    });

    await call(client, "script_write", {
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

    let gmText = readText(
      await call(client, "script_read", { path: "res://scripts/game_manager.gd" }),
    );
    if (!gmText.includes("score_changed")) {
      gmText = gmText.replace(
        "signal hp_changed(current: int, maximum: int)\n",
        "signal hp_changed(current: int, maximum: int)\nsignal score_changed(score: int)\n",
      );
      gmText = gmText.replace(
        "var hp: int = MAX_HP\n",
        "var hp: int = MAX_HP\nvar score: int = 0\n",
      );
      if (!gmText.includes('"coin"')) {
        gmText = gmText.replace(
          '\t"win": preload("res://assets/game/audio/sfx_win.ogg"),\n}',
          '\t"coin": preload("res://assets/game/audio/sfx_coin.wav"),\n\t"win": preload("res://assets/game/audio/sfx_win.ogg"),\n}',
        );
      }
      gmText = gmText.replace(
        "\thp = MAX_HP\n\ttime_left = LEVEL_TIME\n",
        "\thp = MAX_HP\n\tscore = 0\n\ttime_left = LEVEL_TIME\n",
      );
      gmText = gmText.replace(
        "\thp_changed.emit(hp, MAX_HP)\n\ttime_changed.emit(ceili(time_left))",
        "\thp_changed.emit(hp, MAX_HP)\n\tscore_changed.emit(score)\n\ttime_changed.emit(ceili(time_left))",
      );
      if (!gmText.includes("func collect_coin")) {
        gmText = gmText.replace(
          "func win() -> void:",
          `func collect_coin(value: int) -> void:
\tif state != "playing":
\t\treturn
\tscore += value
\tscore_changed.emit(score)
\tplay_sfx("coin")


func win() -> void:`,
        );
      }
      await call(client, "script_write", {
        path: "res://scripts/game_manager.gd",
        content: gmText,
      });
    }

    let lbText = readText(
      await call(client, "script_read", { path: "res://scripts/level_builder.gd" }),
    );
    if (!lbText.includes("COINS")) {
      lbText = lbText.replace(
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
      );
      lbText = lbText.replace(
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
      await call(client, "script_write", {
        path: "res://scripts/level_builder.gd",
        content: lbText,
      });
    }

    let mlText = readText(
      await call(client, "script_read", { path: "res://scripts/mario_level.gd" }),
    );
    if (!mlText.includes("_score_label")) {
      mlText = mlText.replace(
        "@onready var _hp_display: HBoxContainer = $HUD/HpBars\n",
        "@onready var _hp_display: HBoxContainer = $HUD/HpBars\n@onready var _score_label: Label = $HUD/ScoreLabel\n",
      );
      mlText = mlText.replace(
        "\tGameManager.game_lost.connect(_on_game_lost)\n",
        "\tGameManager.game_lost.connect(_on_game_lost)\n\tGameManager.score_changed.connect(_on_score_changed)\n",
      );
      mlText = mlText.replace(
        "\t_on_hp_changed(GameManager.hp, GameManager.MAX_HP)\n",
        "\t_on_hp_changed(GameManager.hp, GameManager.MAX_HP)\n\t_on_score_changed(GameManager.score)\n",
      );
      if (!mlText.includes("_on_score_changed")) {
        mlText = mlText.replace(
          "func _on_hp_changed(current: int, maximum: int) -> void:",
          `func _on_score_changed(value: int) -> void:
\t_score_label.text = "Score: %d" % value


func _on_hp_changed(current: int, maximum: int) -> void:`,
        );
      }
      await call(client, "script_write", { path: "res://scripts/mario_level.gd", content: mlText });

      await call(client, "node_add", {
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

    await call(client, "scene_save", { path: "res://scenes/mario_level.tscn" });
    for (const p of [
      "res://scripts/coin_pickup.gd",
      "res://scripts/game_manager.gd",
      "res://scripts/level_builder.gd",
      "res://scripts/mario_level.gd",
    ]) {
      await call(client, "script_validate", { path: p });
    }

    console.log("OK: coins + score HUD added via Terravolt MCP");
  } finally {
    await client.close().catch(() => {});
  }
}

main().catch((err) => {
  console.error("FAILED:", err.message ?? err);
  process.exit(1);
});

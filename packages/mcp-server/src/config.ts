import { parseArgs } from "node:util";

export type LogLevel = "debug" | "info" | "warn" | "error";

export type Config = {
  readonly godotHost: string;
  readonly godotPort: number;
  readonly connectTimeoutMs: number;
  readonly heartbeatIntervalMs: number;
  readonly heartbeatTimeoutMs: number;
  readonly reconnectBaseMs: number;
  readonly reconnectMaxMs: number;
  readonly logLevel: LogLevel;
  readonly requestTimeoutMs: number;
  readonly maxPayloadBytes: number;
  readonly token: string | undefined;
  readonly notificationFilter: "all" | "events";
  readonly packageVersion: string;
  readonly godotBinaryPath: string | undefined;
  readonly godotBinaryEnv: string | undefined;
  readonly projectPath: string | undefined;
  readonly headlessBootTimeoutMs: number;
  readonly headlessOpTimeoutMs: number;
  readonly metricsWindowSec: number;
  readonly includeAutoHealHints: boolean;
};

function envString(name: string): string | undefined {
  const v = process.env[name];
  return v === undefined || v === "" ? undefined : v;
}

function envInt(name: string, def: number): number {
  const v = envString(name);
  if (v === undefined) return def;
  const n = Number.parseInt(v, 10);
  return Number.isFinite(n) ? n : def;
}

function parseLogLevel(s: string | undefined): LogLevel {
  if (s === "debug" || s === "info" || s === "warn" || s === "error") return s;
  return "info";
}

function parseIntOpt(s: string | undefined, def: number): number {
  if (s === undefined) return def;
  const n = Number.parseInt(s, 10);
  return Number.isFinite(n) ? n : def;
}

export type ParseResult =
  | { ok: true; config: Config }
  | { ok: false; message: string; fields?: Record<string, unknown> };

export function loadConfig(argv: string[], packageVersion: string): ParseResult {
  const parsed = parseArgs({
    args: argv,
    allowPositionals: false,
    options: {
      "print-config": { type: "boolean" },
      "godot-host": { type: "string" },
      "godot-port": { type: "string" },
      "connect-timeout-ms": { type: "string" },
      "heartbeat-interval-ms": { type: "string" },
      "heartbeat-timeout-ms": { type: "string" },
      "reconnect-base-ms": { type: "string" },
      "reconnect-max-ms": { type: "string" },
      "log-level": { type: "string" },
      "request-timeout-ms": { type: "string" },
      "max-payload-bytes": { type: "string" },
      token: { type: "string" },
      notifications: { type: "string" },
      "godot-binary": { type: "string" },
      project: { type: "string" },
      "headless-boot-timeout-ms": { type: "string" },
      "headless-op-timeout-ms": { type: "string" },
      "metrics-window-sec": { type: "string" },
      "disable-auto-heal": { type: "boolean" },
    },
  });

  const v = parsed.values;
  const godotHost = v["godot-host"] ?? envString("TERRAVOLT_GODOT_HOST") ?? "127.0.0.1";
  const godotPort = parseIntOpt(v["godot-port"] ?? envString("TERRAVOLT_GODOT_PORT"), 6505);

  const notifRaw = v["notifications"] ?? "all";
  const notificationFilter = notifRaw === "events" ? "events" : "all";

  const cfg: Config = {
    godotHost,
    godotPort,
    connectTimeoutMs: parseIntOpt(v["connect-timeout-ms"], 5000),
    heartbeatIntervalMs: parseIntOpt(
      v["heartbeat-interval-ms"] ?? envString("TERRAVOLT_HEARTBEAT_INTERVAL_MS"),
      envInt("TERRAVOLT_HEARTBEAT_INTERVAL_MS", 15_000),
    ),
    heartbeatTimeoutMs: parseIntOpt(
      v["heartbeat-timeout-ms"] ?? envString("TERRAVOLT_HEARTBEAT_TIMEOUT_MS"),
      envInt("TERRAVOLT_HEARTBEAT_TIMEOUT_MS", 45_000),
    ),
    reconnectBaseMs: parseIntOpt(v["reconnect-base-ms"], 500),
    reconnectMaxMs: parseIntOpt(v["reconnect-max-ms"], 30_000),
    logLevel: parseLogLevel(v["log-level"] ?? envString("TERRAVOLT_LOG_LEVEL") ?? "info"),
    requestTimeoutMs: parseIntOpt(v["request-timeout-ms"], 30_000),
    maxPayloadBytes: parseIntOpt(v["max-payload-bytes"], 4 * 1024 * 1024),
    token: v["token"] ?? envString("TERRAVOLT_TOKEN"),
    notificationFilter,
    packageVersion,
    godotBinaryPath: v["godot-binary"],
    godotBinaryEnv: envString("TERRAVOLT_GODOT_BINARY"),
    projectPath: v.project ?? envString("TERRAVOLT_PROJECT_PATH"),
    headlessBootTimeoutMs: parseIntOpt(
      v["headless-boot-timeout-ms"] ?? envString("TERRAVOLT_HEADLESS_BOOT_TIMEOUT_MS"),
      envInt("TERRAVOLT_HEADLESS_BOOT_TIMEOUT_MS", 30_000),
    ),
    headlessOpTimeoutMs: parseIntOpt(
      v["headless-op-timeout-ms"] ?? envString("TERRAVOLT_HEADLESS_OP_TIMEOUT_MS"),
      envInt("TERRAVOLT_HEADLESS_OP_TIMEOUT_MS", 60_000),
    ),
    metricsWindowSec: parseIntOpt(
      v["metrics-window-sec"] ?? envString("TERRAVOLT_METRICS_WINDOW_SEC"),
      envInt("TERRAVOLT_METRICS_WINDOW_SEC", 300),
    ),
    includeAutoHealHints: v["disable-auto-heal"] !== true,
  };

  if (godotPort < 1 || godotPort > 65535) {
    return { ok: false, message: "Invalid --godot-port" };
  }

  return { ok: true, config: cfg };
}

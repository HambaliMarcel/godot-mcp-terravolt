import { spawn, type ChildProcess } from "node:child_process";
import path from "node:path";

import type { Logger } from "../logger.js";

/** Launch Godot `--headless` with `headless_driver.gd`; parse bound TCP port from stderr. */
export async function launchHeadlessDriver(opts: {
  readonly godotBinary: string;
  readonly projectPath: string;
  readonly driverGdPath: string;
  readonly bootTimeoutMs: number;
  readonly log: Logger;
  readonly catalogVersion?: string;
  readonly registrySha256?: string;
}): Promise<{ proc: ChildProcess; port: number; host: string }> {
  const proj = path.resolve(opts.projectPath);
  const drv = path.resolve(opts.driverGdPath);
  const args = ["--headless", "--path", proj, "--script", drv];
  opts.log("info", "headless", "spawn", {
    exe: opts.godotBinary,
    argv: args.slice(0, 12),
    driver: drv,
  });

  const proc = spawn(opts.godotBinary, args, {
    windowsHide: true,
    stdio: ["ignore", "ignore", "pipe"],
    env: {
      ...process.env,
      TERRAVOLT_GODOT_BINARY: opts.godotBinary,
      TERRAVOLT_CATALOG_VERSION: opts.catalogVersion ?? "unknown",
      TERRAVOLT_REGISTRY_SHA256: opts.registrySha256 ?? "unknown",
    },
  });

  return await new Promise<{ proc: ChildProcess; port: number; host: string }>(
    (promiseResolve, promiseReject) => {
      let buf = "";
      const timer = setTimeout(() => {
        try {
          proc.kill("SIGKILL");
        } catch {
          /* ignore */
        }
        promiseReject(new Error("headless.driver_handshake_failed"));
      }, opts.bootTimeoutMs);

      proc.stderr?.setEncoding("utf8");

      proc.stderr?.on("data", (chk: string) => {
        buf += chk;

        while (buf.length > 0) {
          const nl = buf.indexOf("\n");
          if (nl < 0) break;
          const line = buf.slice(0, nl).trimEnd();
          buf = buf.slice(nl + 1);
          const m = /^TERRAVOLT_HEADLESS_PORT=(\d+)$/.exec(line);
          if (m && m[1]) {
            clearTimeout(timer);
            const portNum = Number.parseInt(m[1], 10);
            if (!Number.isFinite(portNum) || portNum <= 0) {
              proc.kill();
              promiseReject(new Error("headless.driver_handshake_failed"));
              return;
            }
            promiseResolve({ proc, port: portNum, host: "127.0.0.1" });
            return;
          }
        }
      });

      proc.on("error", (e: Error) => {
        clearTimeout(timer);
        promiseReject(e);
      });

      proc.on("exit", (code) => {
        if (buf.length > 1000 || code !== 0) {
          opts.log("warn", "headless", "exit_before_handshake", { code });
        }
      });
    },
  );
}

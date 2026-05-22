import path from "node:path";

import { loadMethodRegistry, registryContentSha256 } from "../catalog/loadRegistry.js";
import type { Config } from "../config.js";
import type { Logger } from "../logger.js";
import { resolveGodotBinary } from "./godotBinary.js";
import { launchHeadlessDriver } from "./headlessSession.js";
import { tcpJsonRpcRequest } from "./headlessTcpClient.js";
import { resolveTerravoltRepoRoot } from "./resolveTerravoltRoot.js";

export class HeadlessCoordinator {
  private session?:
    | {
        pid: number;
        port: number;
        host: string;
        proc: import("node:child_process").ChildProcess;
        projectPath: string;
        startedAtMs: number;
      }
    | undefined;

  constructor(
    private readonly cfg: Config,
    private readonly log: Logger,
    private readonly importMetaUrlForRoot: string,
  ) {}

  status(): Record<string, unknown> {
    if (!this.session) return { alive: false };
    const s = this.session;
    const alive = s.proc.exitCode === null;
    return {
      alive,
      pid: s.pid,
      host: s.host,
      port: s.port,
      projectPath: s.projectPath,
      uptimeMs: Date.now() - s.startedAtMs,
    };
  }

  async stop(force?: boolean): Promise<void> {
    if (!this.session) return;
    const proc = this.session.proc;
    this.session = undefined;
    try {
      proc.kill(force ? "SIGKILL" : "SIGTERM");
    } catch {
      /* ignore */
    }
  }

  godotExeOrThrow(): string {
    const b = resolveGodotBinary({
      argvFlag: this.cfg.godotBinaryPath,
      envBinary: this.cfg.godotBinaryEnv,
    });
    if (!b) throw new Error("headless.binary_missing");
    return b;
  }

  resolveDriverPath(): string {
    const envGd = process.env.TERRAVOLT_HEADLESS_DRIVER_GD;
    if (envGd?.length && path.isAbsolute(envGd)) return envGd;
    const root = resolveTerravoltRepoRoot(this.importMetaUrlForRoot);
    return path.join(root, "packages", "godot-mcp-addon", "headless", "headless_driver.gd");
  }

  resolvedProjectOrThrow(): string {
    const p = this.cfg.projectPath ?? process.env.TERRAVOLT_PROJECT_PATH ?? "";
    if (!p.length) throw new Error("headless.no_project");
    return path.resolve(p);
  }

  async ensureSession(projectPathAbsolute: string): Promise<void> {
    if (
      this.session &&
      path.resolve(projectPathAbsolute) === this.session.projectPath &&
      this.session.proc.exitCode === null
    ) {
      return;
    }
    await this.stop(false);
    const exe = this.godotExeOrThrow();
    const drv = this.resolveDriverPath();
    let catalogVersion: string | undefined;
    let registrySha256: string | undefined;
    try {
      catalogVersion = loadMethodRegistry().catalog_version;
      registrySha256 = registryContentSha256();
    } catch {
      catalogVersion = undefined;
      registrySha256 = undefined;
    }
    const { proc, port, host } = await launchHeadlessDriver({
      godotBinary: exe,
      projectPath: path.resolve(projectPathAbsolute),
      driverGdPath: drv,
      bootTimeoutMs: this.cfg.headlessBootTimeoutMs,
      log: this.log,
      catalogVersion,
      registrySha256,
    });

    await tcpJsonRpcRequest({
      host,
      port,
      method: "ping",
      params: {},
      timeoutMs: this.cfg.headlessOpTimeoutMs,
      log: this.log,
    });

    this.session = {
      pid: proc.pid ?? -1,
      port,
      host,
      proc,
      projectPath: path.resolve(projectPathAbsolute),
      startedAtMs: Date.now(),
    };
  }

  async rpc(method: string, params: Record<string, unknown>): Promise<unknown> {
    if (!this.session) throw new Error("headless.session_missing");
    if (typeof this.session.proc.exitCode === "number") throw new Error("headless.crashed");
    return await tcpJsonRpcRequest({
      host: this.session.host,
      port: this.session.port,
      method,
      params,
      timeoutMs: this.cfg.headlessOpTimeoutMs,
      log: this.log,
    });
  }

  /** Start if needed using cfg project / override path argument. */
  async ensureDefaultSession(projectOpt?: string): Promise<void> {
    const proj = projectOpt?.length ? path.resolve(projectOpt) : this.resolvedProjectOrThrow();
    await this.ensureSession(proj);
  }
}

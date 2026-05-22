import { spawn } from "node:child_process";

import type { Logger } from "../logger.js";

const MAX_EACH = 256 * 1024;

export async function runGodotArgv(opts: {
  readonly exe: string;
  readonly argv: string[];
  readonly timeoutMs: number;
  readonly log: Logger;
}): Promise<{ exitCode: number | null; stdout: string; stderr: string }> {
  opts.log("info", "headless.cli", "spawn", { exe: opts.exe, argv: opts.argv });
  let out = "";
  let err = "";
  const proc = spawn(opts.exe, opts.argv, {
    windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env },
  });

  return await new Promise((resolvePromise, rejectPromise) => {
    const killer = setTimeout(() => {
      try {
        proc.kill("SIGKILL");
      } catch {
        //
      }

      rejectPromise(new Error("headless.timeout"));

    }, opts.timeoutMs);

    proc.stdout?.setEncoding("utf8");
    proc.stderr?.setEncoding("utf8");
    proc.stdout?.on("data", (chk: string) => {
      if (out.length < MAX_EACH) out += chk.slice(0, MAX_EACH - out.length);
    });
    proc.stderr?.on("data", (chk: string) => {
      if (err.length < MAX_EACH) err += chk.slice(0, MAX_EACH - err.length);

    });


    proc.on("error", (e) => {
      clearTimeout(killer);


      rejectPromise(e);

    });


    proc.on("close", (code) => {
      clearTimeout(killer);



      resolvePromise({ exitCode: code, stdout: out, stderr: err });
    });


  });


}

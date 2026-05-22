import { createConnection } from "node:net";

import type { Logger } from "../logger.js";

function parseJson(line: string): unknown {
  try {
    return JSON.parse(line) as unknown;
  } catch {
    return null;
  }
}

export async function tcpJsonRpcRequest(opts: {
  readonly host: string;
  readonly port: number;
  readonly method: string;
  readonly params: Record<string, unknown>;
  readonly timeoutMs: number;
  readonly log?: Logger;
}): Promise<unknown> {
  const id = Math.floor(Math.random() * 1e9);
  const payload =
    JSON.stringify({
      jsonrpc: "2.0",
      id,
      method: opts.method,
      params: opts.params ?? {},
    }) + "\n";

  return await new Promise<unknown>((promiseResolve, promiseReject) => {
    let buf = "";

    const socket = createConnection({ host: opts.host, port: opts.port }, () => {
      socket.setEncoding("utf8");
      socket.write(payload, "utf8");
    });

    const tearDown = (): void => {
      try {
        socket.destroy();
      } catch {
        //
      }
    };

    const timer = setTimeout(() => {
      opts.log?.("warn", "headless", "tcp_timeout", { method: opts.method, id });
      tearDown();
      promiseReject(new Error("headless.timeout"));
    }, opts.timeoutMs);

    socket.on("data", (chunk: string) => {
      buf += chunk;

      while (true) {
        const nl = buf.indexOf("\n");
        if (nl < 0) break;

        const line = buf.slice(0, nl).trim();
        buf = buf.slice(nl + 1);
        if (line.length === 0) continue;

        const msg = parseJson(line);
        if (typeof msg !== "object" || msg === null) continue;

        const wire = msg as { id?: unknown; result?: unknown; error?: unknown };
        if (wire.id !== id) continue;

        clearTimeout(timer);
        tearDown();

        if ("error" in wire && wire.error != null) {
          const er = wire.error as { message?: unknown };
          promiseReject(
            Object.assign(new Error(typeof er.message === "string" ? er.message : "daemon_error"), {
              rpc: wire.error,
            }),
          );
          return;
        }

        promiseResolve(wire.result);
        return;
      }
    });

    socket.on("error", (e) => {
      clearTimeout(timer);
      tearDown();
      promiseReject(e);
    });
  });
}

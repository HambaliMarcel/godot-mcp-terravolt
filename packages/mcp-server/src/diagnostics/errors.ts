/** Router-side symbolic transport errors (mirror docs/tasklist/05). */

export const TRANSPORT_NOT_CONNECTED = "transport.not_connected";
export const DISPATCH_TIMEOUT = "dispatch.timeout";

export function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

export class DaemonJsonRpcError extends Error {
  readonly daemon: Record<string, unknown>;

  constructor(daemon: Record<string, unknown>) {
    super("daemon_jsonrpc_error");
    this.name = "DaemonJsonRpcError";
    this.daemon = daemon;
  }
}

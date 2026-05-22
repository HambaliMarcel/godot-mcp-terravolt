import { isRecord } from "./errors.js";

/** Normalize daemon JSON-RPC error for MCP tool `content` payload. */
export function mapGodotJsonRpcError(err: unknown): Record<string, unknown> {
  if (!isRecord(err)) {
    return { message: String(err), code: -32603, data: {} };
  }
  const code =
    typeof err["code"] === "number"
      ? err["code"]
      : Number.parseInt(String(err["code"] ?? "-32603"), 10);
  const message = typeof err["message"] === "string" ? err["message"] : "Daemon error";
  const data = isRecord(err["data"]) ? err["data"] : {};
  return { code, message, data };
}

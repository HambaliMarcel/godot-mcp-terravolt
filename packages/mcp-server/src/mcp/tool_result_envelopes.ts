import { TRANSPORT_NOT_CONNECTED } from "../diagnostics/errors.js";
import type { RegisteredRouterTool } from "../tools/registry.js";

export function okStructured(envelope: Record<string, unknown>) {
  return {
    structuredContent: envelope,
    content: [{ type: "text" as const, text: JSON.stringify(envelope) }],
  };
}

export function errStructured(message: string, data?: Record<string, unknown>) {
  const payload = { ok: false as const, message, ...data };
  return {
    structuredContent: payload,
    content: [{ type: "text" as const, text: JSON.stringify(payload) }],
    isError: true as const,
  };
}

/**
 * Routing mode that served the call. Useful when running the router in hybrid
 * mode where editor and headless can both serve a request.
 */
export type RouteMode = "editor" | "headless" | "router";

export function successEnvelope(
  tool: string,
  method: string,
  latencyMs: number,
  result: unknown,
  routeMode?: RouteMode,
): Record<string, unknown> {
  const mode: RouteMode = routeMode ?? inferRouteMode(method);
  return { ok: true, tool, method, route_mode: mode, latencyMs, result };
}

function inferRouteMode(method: string): RouteMode {
  if (method.endsWith("@headless")) return "headless";
  if (method.endsWith("@editor")) return "editor";
  if (
    method === "local" ||
    method.startsWith("local.") ||
    method.startsWith("tools.") ||
    method.startsWith("context.")
  )
    return "router";
  return "editor";
}

export function disconnectedHint(): Record<string, unknown> {
  return {
    app_code: TRANSPORT_NOT_CONNECTED,
    hint: "Ensure Terravolt MCP addon is listening on :6505 (Phase 1); see docs/tasklist/05 §5.6.12 smoke.",
  };
}

export function describeToolMeta(t: RegisteredRouterTool): Record<string, unknown> {
  return {
    kind: t.kind,
    name: t.name,
    title: t.title,
    description: t.description,
    category: t.category,
    safe: t.safe,
    mutates: t.mutates,
    requiresEditor: t.requiresEditor,
    requiresRuntime: t.requiresRuntime,
    daemonMethod: t.daemonMethod ?? null,
    inputSchemaJson: t.inputSchemaJson,
    outputSchemaJson: t.outputSchemaJson ?? null,
  };
}

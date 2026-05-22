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

export function successEnvelope(
  tool: string,
  method: string,
  latencyMs: number,
  result: unknown,
): Record<string, unknown> {
  return { ok: true, tool, method, latencyMs, result };
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

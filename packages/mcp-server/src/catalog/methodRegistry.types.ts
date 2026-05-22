/** Shared typings for packages/shared/methods/registry.json (router + codegen). */

export type McpToolOverlay = {
  name: string;
  title?: string;
  description?: string;
};

export type MethodRegistryEntry = {
  method: string;
  category: string;
  since: string;
  description: string;
  inputSchema: Record<string, unknown>;
  outputSchema?: Record<string, unknown>;
  mcpTool?: McpToolOverlay;
  requiresEditor: boolean;
  requiresRuntime: boolean;
  safe: boolean;
  mutates: boolean;
  errorCodes: unknown[];
  examples: unknown[];
};

export type MethodRegistryFile = {
  catalog_version: string;
  methods: MethodRegistryEntry[];
};

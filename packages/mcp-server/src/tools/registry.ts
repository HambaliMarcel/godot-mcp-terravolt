import type { MethodRegistryEntry } from "../catalog/loadRegistry.js";

export type RegisteredRouterTool = {
  readonly kind: "daemon" | "local";
  readonly name: string;
  readonly title: string;
  readonly description: string;
  readonly category: string;
  readonly safe: boolean;
  readonly mutates: boolean;
  readonly requiresEditor: boolean;
  readonly requiresRuntime: boolean;
  readonly inputSchemaJson: Record<string, unknown>;
  readonly outputSchemaJson: Record<string, unknown> | undefined;
  /** Present for daemon-bridged tools; omitted for fully local MCP tools (e.g. headless.*, tools.list). */
  readonly daemonMethod?: string | undefined;
  /** When daemon WS is offline, optionally route this tool over the §07 headless TCP session (ping/server.info parity). */
  readonly headlessFallback?: boolean;
};

export class RouterToolCatalog {
  private readonly byName = new Map<string, RegisteredRouterTool>();

  add(entry: RegisteredRouterTool): void {
    this.byName.set(entry.name, entry);
  }

  entries(): IterableIterator<[string, RegisteredRouterTool]> {
    return this.byName.entries();
  }

  describe(name: string): RegisteredRouterTool | undefined {
    return this.byName.get(name);
  }

  filter(opts: { category?: string; safe?: boolean }): RegisteredRouterTool[] {
    let out = [...this.byName.values()];
    if (opts.category !== undefined && opts.category.length > 0) {
      out = out.filter((t) => t.category === opts.category);
    }
    if (opts.safe !== undefined) {
      out = out.filter((t) => t.safe === opts.safe);
    }
    out.sort((a, b) => a.name.localeCompare(b.name));
    return out;
  }

  mergeFromDaemonRegistry(entries: MethodRegistryEntry[]): void {
    for (const m of entries) {
      const o = m.mcpTool;
      if (!o?.name) continue;
      const title = o.title ?? m.method;
      const desc = o.description !== undefined ? o.description : m.description;
      const name = o.name;
      const input = m.inputSchema as Record<string, unknown>;
      const output = m.outputSchema as Record<string, unknown> | undefined;
      this.add({
        kind: "daemon",
        name,
        title,
        description: desc,
        category: m.category,
        safe: m.safe,
        mutates: m.mutates,
        requiresEditor: m.requiresEditor,
        requiresRuntime: m.requiresRuntime,
        inputSchemaJson: input,
        outputSchemaJson: output,
        daemonMethod: m.method,
        headlessFallback: m.headlessFallback === true,
      } satisfies RegisteredRouterTool);
    }
  }

  snapshotNames(): string[] {
    return [...this.byName.keys()].sort((a, b) => a.localeCompare(b));
  }
}

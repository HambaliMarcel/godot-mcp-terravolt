import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const routerEntry = join(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "packages",
  "mcp-server",
  "dist",
  "index.js",
);
const transport = new StdioClientTransport({
  command: process.execPath,
  args: [routerEntry],
  env: { ...process.env, TERRAVOLT_LOG_LEVEL: "warn" },
  stderr: "pipe",
});
const client = new Client({ name: "health", version: "0" }, { capabilities: { tools: {} } });
await client.connect(transport);
await new Promise((r) => setTimeout(r, 4000));
const pingRes = await client.callTool({ name: "ping", arguments: {} });
const pingPayload =
  pingRes.structuredContent ??
  (() => {
    try {
      return JSON.parse(pingRes.content?.[0]?.text ?? "{}");
    } catch {
      return {};
    }
  })();
if (!pingPayload?.ok) {
  console.error("ping failed:", JSON.stringify(pingPayload));
}
const res = await client.callTool({ name: "tools_health", arguments: {} });
const payload =
  res.structuredContent ??
  (() => {
    try {
      return JSON.parse(res.content?.[0]?.text ?? "{}");
    } catch {
      return { raw: res };
    }
  })();
console.log(JSON.stringify(payload, null, 2));
await client.close();
process.exit(payload?.result?.checks?.pass ? 0 : 1);

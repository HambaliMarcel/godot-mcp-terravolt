import fs from "node:fs";

const path = "h:/Godot MCP Marcel/packages/mcp-server/src/mcp/register_router_only_tools.ts";
let s = fs.readFileSync(path, "utf8");
if (!s.includes("headless?: HeadlessCoordinator")) {
  s = s.replace(
    'import type { MethodRegistryFile } from "../catalog/methodRegistry.types.js";\n',
    'import type { MethodRegistryFile } from "../catalog/methodRegistry.types.js";\nimport type { HeadlessCoordinator } from "../headless/headlessCoordinator.js";\n',
  );
  s = s.replace(
    "ajvCompileSmoke: ValidateFn | null;",
    "ajvCompileSmoke: ValidateFn | null;\n  headless?: HeadlessCoordinator;",
  );
  s = s.replace(
    "const { mcp, routeCatalog, jsonRegistry, routerRegistrySha, godot, ajvCompileSmoke } = args;",
    "const { mcp, routeCatalog, jsonRegistry, routerRegistrySha, godot, ajvCompileSmoke, headless } = args;",
  );

  const inj = `
      let headlessGodotResolvable = false;
      try {
        headless?.godotExeOrThrow();
        headlessGodotResolvable = true;
      } catch {
        headlessGodotResolvable = false;
      }
      let headlessDriverGd: string | null = null;
      try {
        headlessDriverGd = headless?.resolveDriverPath() ?? null;
      } catch {
        headlessDriverGd = null;
      }
      const headlessTcpAlive = Boolean((headless?.status() as Record<string, unknown> | undefined)?.alive);
`;
  s = s.replace("const hashMatch =", `${inj}\n      const hashMatch =`);
  s = s.replace(
    "protocol_catalog_mismatch_detected: mismatchFlag,",
    "protocol_catalog_mismatch_detected: mismatchFlag,\n            headless_godot_executable_resolvable: headlessGodotResolvable,\n            headless_driver_gd_absolute: headlessDriverGd,\n            headless_tcp_session_alive: headlessTcpAlive,",
  );
}
fs.writeFileSync(path, s);

const mcp = "h:/Godot MCP Marcel/packages/mcp-server/src/transport/mcp_stdio.ts";
let ms = fs.readFileSync(mcp, "utf8");
ms = ms.replace(
  /\s*instructions:\s*\n\s*["][^"]*["],\n/,
  `\n      instructions:\n        \"TerraVolt bridges Cursor MCP stdio to editor (:6505) and optional Godot headless TCP (task 07).\",\n`,
);
fs.writeFileSync(mcp, ms);

#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { loadConfig } from "./config.js";
import { createLogger } from "./logger.js";
import { bootstrapRouter } from "./transport/mcp_stdio.js";

function readPackageVersion(): string {
  try {
    const pkgPath = join(dirname(fileURLToPath(import.meta.url)), "../package.json");
    const pkg = JSON.parse(readFileSync(pkgPath, "utf8")) as { version?: string };
    return pkg.version ?? "0.1.0";
  } catch {
    return "0.1.0";
  }
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  const packageVersion = readPackageVersion();

  if (argv.includes("--version")) {
    process.stderr.write(`terravolt-godot-mcp ${packageVersion}\n`);
    process.exit(0);
  }

  const parsed = loadConfig(argv, packageVersion);

  if (!parsed.ok) {
    process.stderr.write(
      `${JSON.stringify({
        level: "error",
        subsystem: "router",
        event: "config_parse_failed",
        message: parsed.message,
      })}\n`,
    );
    process.exit(2);
  }

  if (argv.includes("--print-config")) {
    process.stderr.write(`${JSON.stringify(parsed.config, null, 2)}\n`);
    process.exit(0);
  }

  const log = createLogger(parsed.config);
  const bundle = bootstrapRouter({ config: parsed.config, log });

  const stop = async (): Promise<void> => {
    await bundle.shutdown();
    process.exit(0);
  };
  process.on("SIGINT", () => void stop());
  process.on("SIGTERM", () => void stop());

  await bundle.connectStdio();
}

void main().catch((err: unknown) => {
  process.stderr.write(`${err instanceof Error ? (err.stack ?? err.message) : String(err)}\n`);
  process.exit(1);
});

import { mkdirSync, writeFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
mkdirSync(join(root, "graphs"), { recursive: true });

writeFileSync(
  join(root, "graphs", "README.md"),
  `# Graph artifacts (Graphify layer)

Run \`npm run intel:graphs\`.

- **dependency-graph.json** — dependency-cruiser (module graph for JS/TS toolchains)
- **madge-graph.json** — madge (optional circular-dep / graph summary)

Third-party reference clones under \`references/\` are excluded from scans.

When the MCP server or Godot addon layout stabilizes, update the globs in this script and refresh \`architecture/SYSTEM_OVERVIEW.md\`.
`,
  "utf8"
);

try {
  execSync(
    "npx depcruise --config .dependency-cruiser.js -T json -f graphs/dependency-graph.json .",
    { cwd: root, stdio: "inherit", shell: true }
  );
} catch {
  console.warn(
    "[intel:graphs] dependency-cruiser reported issues or no matching files — see output above."
  );
}

try {
  const out = execSync(
    "npx madge . --extensions ts,tsx,js,jsx,mjs,cjs --exclude \"^(references|node_modules)\" --json",
    { cwd: root, encoding: "utf8", shell: true }
  );
  writeFileSync(join(root, "graphs", "madge-graph.json"), out, "utf8");
} catch {
  writeFileSync(
    join(root, "graphs", "madge-graph.json"),
    JSON.stringify(
      { info: "madge could not build graph (no JS/TS modules yet or parse issue)" },
      null,
      2
    ),
    "utf8"
  );
}

console.log("[intel:graphs] finished");

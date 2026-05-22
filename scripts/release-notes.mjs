#!/usr/bin/env node
/**
 * docs/tasklist/10 §10.6.8 / §10.7.1 helper.
 *
 * Build a release-notes draft from registry deltas between `--from <ref>`
 * (default: previous tag matching `v*.*.*`) and the current working tree.
 *
 * Outputs Markdown to stdout. Read-only — no git mutations.
 */
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { findTerravoltRepoRoot } from "./lib/repo_root.mjs";

function parseArgv(argv) {
  const out = { from: undefined, to: "HEAD" };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--from" && argv[i + 1]) out.from = argv[++i];
    else if (a === "--to" && argv[i + 1]) out.to = argv[++i];
  }
  return out;
}

function gitShow(repoRoot, ref, relPath) {
  try {
    const buf = execFileSync("git", ["show", `${ref}:${relPath.replace(/\\/g, "/")}`], {
      cwd: repoRoot,
      stdio: ["ignore", "pipe", "ignore"],
    });
    return buf.toString("utf8");
  } catch {
    return undefined;
  }
}

function previousTag(repoRoot) {
  try {
    const out = execFileSync(
      "git",
      ["describe", "--tags", "--abbrev=0", "--match", "v*.*.*", "HEAD^"],
      {
        cwd: repoRoot,
        stdio: ["ignore", "pipe", "ignore"],
      },
    );
    return out.toString("utf8").trim() || undefined;
  } catch {
    try {
      const out = execFileSync("git", ["describe", "--tags", "--abbrev=0", "--match", "v*.*.*"], {
        cwd: repoRoot,
        stdio: ["ignore", "pipe", "ignore"],
      });
      return out.toString("utf8").trim() || undefined;
    } catch {
      return undefined;
    }
  }
}

function safeJson(s) {
  if (s === undefined) return undefined;
  try {
    return JSON.parse(s);
  } catch {
    return undefined;
  }
}

function methodMap(reg) {
  const m = new Map();
  if (!reg || !Array.isArray(reg.methods)) return m;
  for (const r of reg.methods) if (r && typeof r.method === "string") m.set(r.method, r);
  return m;
}

function diffMethods(prev, curr) {
  const a = methodMap(prev);
  const b = methodMap(curr);
  const added = [];
  const removed = [];
  const changed = [];
  for (const k of b.keys()) {
    if (!a.has(k)) added.push(k);
    else {
      const before = a.get(k);
      const after = b.get(k);
      if (JSON.stringify(before) !== JSON.stringify(after)) changed.push(k);
    }
  }
  for (const k of a.keys()) if (!b.has(k)) removed.push(k);
  added.sort();
  removed.sort();
  changed.sort();
  return { added, removed, changed };
}

function diffErrors(prev, curr) {
  const a = new Map((prev?.codes ?? []).map((c) => [String(c.code), c]));
  const b = new Map((curr?.codes ?? []).map((c) => [String(c.code), c]));
  const added = [];
  const removed = [];
  for (const k of b.keys()) if (!a.has(k)) added.push(k);
  for (const k of a.keys()) if (!b.has(k)) removed.push(k);
  added.sort();
  removed.sort();
  return { added, removed };
}

function main() {
  const args = parseArgv(process.argv.slice(2));
  const root = findTerravoltRepoRoot(import.meta.url);
  const from = args.from ?? previousTag(root);
  const methodsPath = "packages/shared/methods/registry.json";
  const errorsPath = "packages/shared/errors/registry.json";

  const currMethods = safeJson(readFileSync(join(root, methodsPath), "utf8"));
  const currErrors = safeJson(readFileSync(join(root, errorsPath), "utf8"));
  const prevMethods = from ? safeJson(gitShow(root, from, methodsPath)) : undefined;
  const prevErrors = from ? safeJson(gitShow(root, from, errorsPath)) : undefined;

  const md = diffMethods(prevMethods, currMethods);
  const ed = diffErrors(prevErrors, currErrors);

  const lines = [];
  lines.push(`# Release notes draft`);
  lines.push("");
  lines.push(`- Base ref: \`${from ?? "<initial>"}\``);
  lines.push(`- Head ref: \`${args.to}\``);
  lines.push(`- Router \`catalog_version\`: \`${currMethods?.catalog_version ?? "?"}\``);
  if (prevMethods)
    lines.push(`- Previous \`catalog_version\`: \`${prevMethods.catalog_version ?? "?"}\``);
  lines.push("");

  lines.push("## Method registry");
  lines.push(
    `- **Added (${md.added.length}):** ${md.added.map((m) => `\`${m}\``).join(", ") || "_none_"}`,
  );
  lines.push(
    `- **Changed (${md.changed.length}):** ${md.changed.map((m) => `\`${m}\``).join(", ") || "_none_"}`,
  );
  lines.push(
    `- **Removed (${md.removed.length}):** ${md.removed.map((m) => `\`${m}\``).join(", ") || "_none_"}`,
  );
  lines.push("");

  lines.push("## Error registry");
  lines.push(
    `- **Added (${ed.added.length}):** ${ed.added.map((c) => `\`${c}\``).join(", ") || "_none_"}`,
  );
  lines.push(
    `- **Removed (${ed.removed.length}):** ${ed.removed.map((c) => `\`${c}\``).join(", ") || "_none_"}`,
  );
  lines.push("");

  const changelog = join(root, "CHANGELOG.md");
  if (existsSync(changelog)) {
    lines.push("## CHANGELOG excerpt");
    lines.push("");
    const text = readFileSync(changelog, "utf8");
    const top = text.split(/^## /m).slice(0, 2).join("## ").trim();
    lines.push(top || "_(empty)_");
    lines.push("");
  }

  process.stdout.write(`${lines.join("\n")}\n`);
}

main();

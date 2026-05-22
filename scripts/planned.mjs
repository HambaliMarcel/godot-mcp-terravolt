#!/usr/bin/env node
/**
 * Prints a single-line roadmap note for npm scripts slated in docs/tasklist/01 §1.6.6.
 * Usage: node scripts/planned.mjs <script-name>
 */
const name = process.argv[2] ?? "unknown";
console.log(`${name}: planned — see docs/tasklist/01-repository-and-tooling-setup.md`);
process.exit(0);

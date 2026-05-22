# Documentation index

Start here, then drill down. The root **[`README.md`](../README.md)** is the product-level entry;
this index is the navigator for everything in `docs/`.

## Guides (operator-facing)

| Path                                                         | Purpose                                                               |
| ------------------------------------------------------------ | --------------------------------------------------------------------- |
| [`guides/quick-start.md`](guides/quick-start.md)             | First install, smoke test, Cursor wiring (under 10 minutes).          |
| [`guides/use-cases.md`](guides/use-cases.md)                 | Rookie-friendly walkthrough of every feature with game-dev use cases. |
| [`guides/mcp-usage.md`](guides/mcp-usage.md)                 | Per-tool `tools/call` payloads + Node SDK example.                    |
| [`guides/tools-reference.md`](guides/tools-reference.md)     | Authoritative list of every MCP tool (inputs, results, errors).       |
| [`guides/godot-integration.md`](guides/godot-integration.md) | Editor mode vs headless mode connection flow + diagrams.              |
| [`guides/headless-only.md`](guides/headless-only.md)         | CI / agent workflow without the editor.                               |
| [`guides/troubleshooting.md`](guides/troubleshooting.md)     | Symptom → fix table + `autoHeal` walkthrough.                         |

## Status & release

| Path                                                                     | Purpose                                                        |
| ------------------------------------------------------------------------ | -------------------------------------------------------------- |
| [`validation/tv-00-10-checkpoint.md`](validation/tv-00-10-checkpoint.md) | Current truth: what's verified, what's backlog, with commands. |
| [`catalog/parity.md`](catalog/parity.md)                                 | Editor vs headless parity matrix per method.                   |
| [`release/v1-readiness.md`](release/v1-readiness.md)                     | v1 ship gate checklist.                                        |
| [`roadmap.md`](roadmap.md)                                               | Post-1.0 items.                                                |
| [`faq.md`](faq.md)                                                       | Strategic / scope answers.                                     |
| [`support-matrix.md`](support-matrix.md)                                 | Supported OS + Godot + Node combinations.                      |

## Architecture & SRS

| Path                                                                     | Purpose                                                                       |
| ------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| [`architecture/overview.md`](architecture/overview.md)                   | High-level purpose, SRS pointers, indexing policy.                            |
| [`srs/README.md`](srs/README.md)                                         | Software Requirements Spec bundle (system blueprint, tool registry, roadmap). |
| [`srs/00-fundamentals-contract.md`](srs/00-fundamentals-contract.md)     | Non-negotiable contracts before Phase 1 code.                                 |
| [`repo-layout.md`](repo-layout.md)                                       | Canonical directory tree.                                                     |
| [`references/reference-repos-map.md`](references/reference-repos-map.md) | Architecture map for reference clones under `references/`.                    |

## Execution checklists

| Path                                                       | Purpose                                                               |
| ---------------------------------------------------------- | --------------------------------------------------------------------- |
| [`tasklist/`](tasklist/)                                   | Numbered tasklists `00`–`10` (foundation → quality / release / docs). |
| [`linear-roadmap-tracking.md`](linear-roadmap-tracking.md) | Linear project + epic TER map + bulk import notes.                    |

## Context engineering

| Path                                               | Purpose                                |
| -------------------------------------------------- | -------------------------------------- |
| [`context/context-map.md`](context/context-map.md) | What context agents should load first. |

## Contributing

| Path                                                                               | Purpose                                     |
| ---------------------------------------------------------------------------------- | ------------------------------------------- |
| [`contributing/agent-guidelines.md`](contributing/agent-guidelines.md)             | Safety / branching for automation.          |
| [`contributing/git-hooks.md`](contributing/git-hooks.md)                           | Optional Cursor co-author strip hook.       |
| [`contributing/windows-godot-portable.md`](contributing/windows-godot-portable.md) | Windows portable Godot install + PATH shim. |

## Governance (root-level)

[`../LICENSE`](../LICENSE) · [`../CONTRIBUTING.md`](../CONTRIBUTING.md) ·
[`../CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) · [`../SECURITY.md`](../SECURITY.md) ·
[`../CHANGELOG.md`](../CHANGELOG.md)

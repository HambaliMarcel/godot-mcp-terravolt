# Contributing to godot-mcp-terravolt

Thanks for helping improve TerraVolt’s Godot ⇄ MCP work. This repo is early-stage; clarity and small, focused PRs are especially welcome.

## Quick links

| Doc | Topic |
|-----|-------|
| [Code of Conduct](CODE_OF_CONDUCT.md) | Expected behaviour |
| [Security policy](SECURITY.md) | Vulnerability disclosure |
| [Architecture](docs/architecture/overview.md) | Layers and layout |
| [Agent context priorities](docs/context/context-map.md) | What reviewers / agents load first |
| [Git hooks (optional)](docs/contributing/git-hooks.md) | Local commit-message cleanup |

## Development setup

1. **Clone** and install tooling:
   ```bash
   npm install
   ```
2. **Intel refresh** after meaningful layout or TS/JS changes (optional):
   ```bash
   npm run omni:intel
   ```
3. **Reference repos** (optional, gitignored paths): see [README § Reference repos](README.md#reference-repos-local).

Do not commit `.env`, API keys, or tokens. Add patterns to `.gitignore` instead.

## Repository layout expectations

| Area | Guidance |
|------|-----------|
| `packages/mcp-server/` | MCP server implementation (planned) |
| `packages/godot-mcp-addon/` | Godot 4 addon / plugin sources (planned) |
| `docs/` | Narrative specs and guides |
| `tools/intel/` | Scripts invoked via `npm run` |
| `artifacts/` | Regenerated analyzer output (commit only when intentional) |

`references/godot-mcp-*` are upstream MCP study clones (**indexed** by GitNexus/Graphify in this workspace). **`references/godot-docs/`** is the official Sphinx manual — **human reading / search only** (excluded from those indexes because of volume). TerraVolt product code lives under **`packages/`** plus first-party tooling, not inside `references/`.

## Pull requests

1. Prefer **small PRs** with a clear explanation of *why*.
2. Git commits should reflect **maintainers / contributors as authors** (`git`-visible identity). Automated tooling shouldn’t invent extra “contributor” personas for this repo; optional hook **[docs/contributing/git-hooks.md](docs/contributing/git-hooks.md)** strips one known tooling trailer once `core.hooksPath` is set.


3. Update **docs/architecture/overview.md** if you change notable boundaries between packages or tooling.
4. Run **`npm run intel:graphs`** (and **`npm run intel:gitnexus`** where relevant) if you touch JS/TS under `packages/` or `tools/`.

Use the [.github Pull Request template](.github/PULL_REQUEST_TEMPLATE.md).

## Issues

Use the [.github Issue templates](.github/ISSUE_TEMPLATE/) for bugs and features.

## License

By contributing, you agree your contributions are licensed under the **[MIT License](LICENSE)** that covers this repository.

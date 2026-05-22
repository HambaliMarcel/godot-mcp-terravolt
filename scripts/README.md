# Scripts

Executable Node entrypoints wired from **`package.json`** (`npm run intel:*`). Keep them small and deterministic; regenerate outputs only (no baked secrets).

| Script | Via |
|--------|-----|
| `regen-graphs.mjs` | `npm run intel:graphs` |
| `run-gitnexus.mjs` | `npm run intel:gitnexus` |

See **[`docs/repo-layout.md`](../docs/repo-layout.md)** for where outputs land (`artifacts/js-graphs/`, `.gitnexus/`, …).

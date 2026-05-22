# Scripts

Small Node/Python entrypoints declared from the root **`package.json`**. Scripts stay deterministic
and never bake secrets into the repo.

## Doctor checklist (`docs/tasklist/01` §1.6.10)

Before starting a roadmap phase (`02+`), verify:

| Check          | Expected                                                                                                                                                            |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Node runtime   | `node -v` → **v20+**                                                                                                                                                |
| npm deps       | `npm install` exits **0** at repo root                                                                                                                              |
| Godot CLI      | `godot --version` shows **Godot 4.x** — see [`docs/contributing/windows-godot-portable.md`](../docs/contributing/windows-godot-portable.md) for portable ZIP setups |
| Godot headless | `godot --headless --version` prints engine banner _(CI / driver smoke)_                                                                                             |
| Lint / format  | `npm run lint` + `npm run format:check` exit **0**                                                                                                                  |
| Router types   | `npm run typecheck` exits **0**                                                                                                                                     |
| Omni intel     | `npm run omni:intel` completes without errors _(Graphify + GitNexus + JS graphs)_                                                                                   |
| Git hooks      | Optionally `git config core.hooksPath .githooks` (see **`docs/contributing/git-hooks.md`**)                                                                         |

## Canonical automation

| NPM script       | File                                                    | Purpose                                                                               |
| ---------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `intel:graphs`   | `regen-graphs.mjs`                                      | dependency-cruiser + madge → `artifacts/js-graphs/`                                   |
| `intel:gitnexus` | `run-gitnexus.mjs`                                      | Runs GitNexus with `GITNEXUS_NO_GITIGNORE=1` so `references/godot-mcp-*` stay indexed |
| `intel:graphify` | _(Python `-m graphify`)_ declared in **`package.json`** | Emits Graphify artefacts under `graphify-out/`                                        |
| `planned.mjs`    | `planned.mjs`                                           | Echo helper for roadmap scripts reserved in task `01`                                 |

## Miscellaneous

| File                                      | Purpose                                                                        |
| ----------------------------------------- | ------------------------------------------------------------------------------ |
| `strip-cursoragent-coauthor-msgfilter.sh` | `git filter-branch --msg-filter` helper — **`docs/contributing/git-hooks.md`** |

📍 Layout reference: **`docs/repo-layout.md`**.

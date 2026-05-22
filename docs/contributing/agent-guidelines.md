# Agent guidelines (safety)

Short policy for automation and human contributors using agents in this workspace.

## Destructive operations

Require explicit human approval before:

- Dropping databases or deleting production volumes.
- Rewriting shared git history (`reset --hard`, `push --force` to mainline) unless the user
  explicitly asked for that workflow.
- Disabling security tooling or hooks someone relies on.

## Data handling

Do not paste secrets into commits, issues, or prompts that get logged upstream. Prefer environment
variables and local-only config kept out of Git.

## Branching

Default: feature branches; merge via PR when collaborating.

## Repo layout & intel

Prefer **[`docs/repo-layout.md`](../repo-layout.md)** and
**[`docs/context/context-map.md`](../context/context-map.md)** so agents load the canonical tree
order before editing `packages/` or `scripts/`.

After editing or formatting `packages/shared/methods/registry.json`, always run
`npm run catalog:sync` before commit — `release:check` asserts `catalog_meta.gd` SHA256 matches
registry bytes.

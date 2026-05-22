# Agent policies (safety)

## Destructive operations

Require explicit human approval before:

- dropping databases or deleting production volumes,
- rewriting shared git history (`reset --hard`, `push --force` to mainline),
- disabling security tooling or hooks the user relies on.

## Data handling

Do not paste secrets into commits, issues, or skills. Prefer env vars and local-only config.

## Branching

Default: feature branches; merge via PR when working with collaborators.

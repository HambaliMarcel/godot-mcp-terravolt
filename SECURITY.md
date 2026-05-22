# Security Policy

## Supported versions

There are no versioned releases yet. Treat `master` / default branch tip as supported for
coordinated disclosure.

Once tagged releases ship, supported versions will be listed here.

## Reporting a vulnerability

**Please do not** open a public issue for undisclosed security problems.

Prefer one of:

1. [GitHub Security Advisories — **Report a vulnerability**](https://github.com/HambaliMarcel/godot-mcp-terravolt/security/advisories/new)
   (recommended if available on this repo).

2. If you cannot use Advisories: contact the repository owner privately through their GitHub profile
   (e.g. **Security** expectations in `README`) with enough detail to reproduce and assess impact.

We aim to acknowledge reports within **5 business days** and share a rough timeline once triaged.

## Scope

Components in this repository (planned or present): MCP server tooling, Godot addon code, CI, and
bundled scripts. Issues in third‑party clones under **`references/`** (local-only) must be reported
to those upstream projects.

## Safe harbor

Responsible disclosure that avoids user harm or data destruction is appreciated. Researchers must
not exploit issues beyond verification.

---

## Threat model (per `docs/tasklist/10 §10.6.11` and `§A.10`)

- **Loopback by default.** The Godot addon binds `127.0.0.1:6505`; the router only connects to
  loopback unless explicitly reconfigured. Changing `bind_address` to `0.0.0.0` exposes the daemon
  to any process on the LAN — pair such deployments with `terravolt_mcp/security/require_token`.
- **Optional token auth.** When configured, the router must supply the token on every WebSocket
  open. Tokens are never logged.
- **Arbitrary script execution.** `headless.run_script` and equivalent primitives are **off by
  default**. Enable only via the explicit router flag `--allow-arbitrary-scripts` and document the
  intent in CI configuration.
- **Log redaction.** Daemon logs may include user-supplied content (script source from `script.set`,
  asset paths). Enable `terravolt_mcp/logging/redact = true` for shared environments.
- **Telemetry.** TerraVolt does **not** phone home. All metrics live in `tools.metrics` /
  `tools.bottlenecks` and never leave the host.
- **Supply chain.** npm dependencies are pinned in `packages/mcp-server/package.json`; release CI
  must run `npm audit --production` and fail on high/critical advisories.
- **Updates.** Release notes always list security-relevant changes; subscribe to the GitHub release
  feed for advisories.

## Reporting checklist

When reporting, include:

1. Affected component (`mcp-server` / `godot-mcp-addon` / scripts).
2. Versions: router `package.json#version`, `catalog_version`, `Godot --version`.
3. Reproducer with the smallest possible MCP tool call or daemon JSON-RPC frame.
4. Network exposure flags in use (`bind_address`, token, allow-arbitrary-scripts).

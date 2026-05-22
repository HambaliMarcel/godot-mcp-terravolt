#!/usr/bin/env python3
"""
Bulk-create Linear child issues under the TV roadmap epic row (TER-*) from
`linear_task_export.json`, using Linear's GraphQL API.

Why this exists:
  Importing hundreds of MCP `save_issue` calls is brittle in chat. A personal API
  key completes the backlog in seconds and supports safe resume via a shell
  TSV ledger.

Requirements:
  - Environment variable LINEAR_API_KEY (from https://linear.app/settings/api)
  - Writes go to Terravolt / project "Godot MCP Terravolt — build roadmap"

Defaults here match identifiers returned when the epics were created via MCP:

  TEAM_ID   : 04048631-f5d6-4d6f-b74e-1ea63fbfc883
  PROJECT_ID: 955eb29e-d215-463a-b33a-438da398885a

Parents (episode num -> epic issue identifier):
  00→TER-33, 01→TER-34, 02→TER-35, 03→TER-37, 04→TER-36,
  05→TER-38, 06→TER-39, 07→TER-40, 08→TER-41, 09→TER-43, 10→TER-42

Usage::
  py -3 tools\\push_linear_issue_children_api.py --dry-run
  set LINEAR_API_KEY=...
  py -3 tools\\push_linear_issue_children_api.py

Resume / idempotency:
  Successful creates append to `.linear_children_import_done.tsv` (gitignored).

If you started children via MCP, prime the ledger so the Topology issue is skipped::

  py -3 tools\\push_linear_issue_children_api.py --prime "TER-33\\t[TV-00] 0.2.1 Topology (locked)"
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

GRAPHQL_URL = os.environ.get("LINEAR_GRAPHQL_URL", "https://api.linear.app/graphql")

TEAM_DEFAULT = os.environ.get("LINEAR_TEAM_ID", "04048631-f5d6-4d6f-b74e-1ea63fbfc883")
PROJECT_DEFAULT = os.environ.get("LINEAR_PROJECT_ID", "955eb29e-d215-463a-b33a-438da398885a")

PARENT_IDS_BY_EPISODE_NUM = {
    "00": "TER-33",
    "01": "TER-34",
    "02": "TER-35",
    "03": "TER-37",
    "04": "TER-36",
    "05": "TER-38",
    "06": "TER-39",
    "07": "TER-40",
    "08": "TER-41",
    "09": "TER-43",
    "10": "TER-42",
}

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXPORT_JSON = ROOT / "tools" / "linear_task_export.json"
DONE_DEFAULT = ROOT / ".linear_children_import_done.tsv"

MUTATION = """
mutation IssueCreate($input: IssueCreateInput!) {
  issueCreate(input: $input) {
    success
    issue {
      id
      identifier
      url
      parent {
        identifier
      }
    }
    userErrors {
      message
      path
    }
  }
}
"""


def gql(api_key: str, query: str, variables: dict | None = None) -> dict:
    body = {"query": query.strip()}
    if variables is not None:
        body["variables"] = variables
    encoded = json.dumps(body).encode("utf-8")
    # Linear accepts Bearer or raw token; Bearer is safest / docs-accurate.
    auth = api_key.strip()
    if auth.lower().startswith("bearer "):
        bearer = auth
    else:
        bearer = f"Bearer {auth}"
    req = urllib.request.Request(
        GRAPHQL_URL,
        data=encoded,
        headers={
            "Content-Type": "application/json",
            "Authorization": bearer,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            payload = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8")
        raise SystemExit(f"HTTP {e.code} from Linear: {err}") from e

    decoded = json.loads(payload)
    if decoded.get("errors"):
        raise SystemExit(f"GraphQL errors: {decoded['errors']}")
    return decoded["data"]


def load_done(path: pathlib.Path) -> set[tuple[str, str]]:
    pairs: set[tuple[str, str]] = set()
    if not path.is_file():
        return pairs
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue
        pairs.add((parts[0].strip(), parts[1].strip()))
    return pairs


def append_done(path: pathlib.Path, parent: str, title: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as fh:
        fh.write(f"{parent}\t{title}\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Import tasklist children into Linear via GraphQL")
    parser.add_argument("--dry-run", action="store_true", help="No network; print counts only")
    parser.add_argument("--team-id", default=TEAM_DEFAULT, help="Terravolt team UUID")
    parser.add_argument("--project-id", default=PROJECT_DEFAULT, help="Project UUID")
    parser.add_argument(
        "--done-file",
        type=pathlib.Path,
        default=DONE_DEFAULT,
        help="TSV ledger: columns parent_issue_id TAB title",
    )
    parser.add_argument("--sleep-ms", type=int, default=120, help="Delay between mutations")
    parser.add_argument(
        "--prime",
        action="append",
        default=[],
        metavar="PARENT<TAB>TITLE",
        help="Seed an already-created row into the ledger (repeatable)",
    )
    args = parser.parse_args()

    if not EXPORT_JSON.is_file():
        sys.stderr.write(f"Missing export {EXPORT_JSON}; run python tools/export_linear_issues.py\n")
        return 2

    data = json.loads(EXPORT_JSON.read_text(encoding="utf-8"))

    pairs_done = load_done(args.done_file)
    for prime in args.prime:
        if "\t" not in prime:
            sys.stderr.write(f"--prime must contain a tab delimiter, got {prime!r}\n")
            return 2
        p, t = prime.split("\t", 1)
        pairs_done.add((p.strip(), t.strip()))

    planned: list[tuple[str, str, str, str]] = []
    for ep in sorted(data, key=lambda e: e["num"]):
        num = ep["num"]
        parent_id = PARENT_IDS_BY_EPISODE_NUM.get(num)
        if parent_id is None:
            sys.stderr.write(f"Unknown episode num {num}; update PARENT_IDS_BY_EPISODE_NUM.\n")
            return 2
        for child in ep["children"]:
            title = f"[TV-{num}] {child['title']}".strip()
            body = child.get("body") or ""
            if len(body) > 49000:
                body = body[:49000] + "\n\n_(truncated for Linear)_"
            planned.append((parent_id, title, body, ep["episode"]))

    will_run = [(p, t, b, ep) for p, t, b, ep in planned if (p, t) not in pairs_done]

    print(
        json.dumps(
            {
                "export_file": str(EXPORT_JSON.relative_to(ROOT)),
                "planned_total": len(planned),
                "already_imported_pairs": len(pairs_done),
                "to_create": len(will_run),
            },
            indent=2,
        )
    )

    if args.dry_run:
        return 0

    api_key = os.environ.get("LINEAR_API_KEY", "").strip()
    if not api_key:
        sys.stderr.write(
            "LINEAR_API_KEY is not set.\n\n"
            "Create a workspace API key under Linear → Settings → API, then rerun.\n\n"
            "Optional: LINEAR_TEAM_ID / LINEAR_PROJECT_ID override UUIDs,\n"
            "          LINEAR_GRAPHQL_URL overrides the endpoint.\n"
        )
        return 2

    for i, (parent_id, title, description, _) in enumerate(will_run, start=1):
        inp = {
            "teamId": args.team_id,
            "projectId": args.project_id,
            "parentId": parent_id,
            "title": title,
            "description": description or "(no subsection body exported)",
        }
        result = gql(api_key, MUTATION, {"input": inp})["issueCreate"]
        errs = result.get("userErrors") or []
        if not result.get("success") or not result.get("issue"):
            sys.stderr.write(
                json.dumps({"title": title, "parentId": parent_id, "errors": errs}, indent=2)
            )
            return 3
        iss = result["issue"]
        print(f"[{i}/{len(will_run)}] created {iss.get('identifier')} {iss.get('url')}")
        append_done(args.done_file, parent_id, title)
        pairs_done.add((parent_id, title))
        if args.sleep_ms:
            time.sleep(args.sleep_ms / 1000.0)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

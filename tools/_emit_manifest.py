#!/usr/bin/env python3
"""Emit one episode's children as manifest JSON for MCP / review."""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PARENTS = {
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

def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: _emit_manifest.py <episode-num e.g. 00>")
    num = sys.argv[1].zfill(2)
    data = json.loads((ROOT / "tools" / "linear_task_export.json").read_text(encoding="utf-8"))
    ep = next(e for e in data if e["num"] == num)
    parent = PARENTS[num]
    out = []
    for ch in ep["children"]:
        body = ch["body"]
        if len(body) > 49000:
            body = body[:49000] + "\n\n_(truncated for Linear)_"
        out.append({"title": f"[TV-{num}] {ch['title']}", "description": body, "parentId": parent})
    path = ROOT / "tools" / "_scratch_manifest.json"
    path.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"wrote {len(out)} rows to {path}")


if __name__ == "__main__":
    main()

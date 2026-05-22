"""One-off export: docs/tasklist/*.md → tools/linear_task_export.json."""
import pathlib
import json

ROOT = pathlib.Path(__file__).resolve().parents[1]
TASKLIST = ROOT / "docs" / "tasklist"
OUT = ROOT / "tools" / "linear_task_export.json"


def chunk_episode(text: str) -> tuple[str, list[dict]]:
    lines = text.splitlines()
    idx = None
    for i, line in enumerate(lines):
        if line.startswith("### "):
            idx = i
            break
    header = "\n".join(lines[: idx or min(150, len(lines))])
    header = header[:24000]
    children: list[dict] = []
    if idx is None:
        return header, children
    cur_title: str | None = None
    buf: list[str] = []
    for line in lines[idx:]:
        if line.startswith("### "):
            if cur_title is not None:
                body = "\n".join(buf).strip()
                children.append({"title": cur_title.strip()[:240], "body": body[:20000]})
            cur_title = line[4:]
            buf = []
        else:
            buf.append(line)
    if cur_title is not None:
        body = "\n".join(buf).strip()
        children.append({"title": cur_title.strip()[:240], "body": body[:20000]})
    return header, children


def main():
    items = []
    for p in sorted(TASKLIST.glob("[0-9][0-9]-*.md")):
        text = p.read_text(encoding="utf-8")
        header, children = chunk_episode(text)
        stem = p.stem
        num = stem[:2]
        items.append({
            "episode": stem,
            "num": num,
            "file": str(p.relative_to(ROOT)),
            "parentsHeader": header,
            "fullDocument": text[:120000],
            "children": children,
        })
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(items, ensure_ascii=False), encoding="utf-8")
    total = sum(len(i["children"]) for i in items)
    print(f"wrote {OUT} episodes={len(items)} children_total={total}")


if __name__ == "__main__":
    main()

# Roadmap

Captured per `docs/tasklist/10 §10.6.14`. These items are intentionally
post-1.0; tracked individually as GitHub issues once filed.

| Item | Notes |
| ---- | ----- |
| Multi-client daemon. | Relax single-peer policy in `mcp_server.gd` and add per-peer auth. |
| Visualizer port `6510` parity with `tomyud1`. | Bind a read-only WS/SSE feed for inspector overlays. |
| LLM-assisted refactors. | Server-side LLM hooks behind a flag; off by default. |
| Deeper C# (.NET) coverage. | Parity with GDScript for `script.*` / `runtime.*`. |
| Resource preview thumbnails in tool outputs. | Echo small base64 previews when the envelope mode allows. |
| Headless multi-session. | Allow multiple `--headless` drivers under a single coordinator. |
| Cloud-agent integration. | Cursor cloud-agent friendly headless config + auth profile. |

Out-of-scope items live as **Decisions Log** rejections in `docs/tasklist/00 §0.13`.

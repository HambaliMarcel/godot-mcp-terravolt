# Terravolt MCP — examples

Standalone Godot projects you can open and run to verify the engine half of the toolchain works on
your machine. None of these are used by the integration test suite; they exist purely for hands-on
exploration.

| Project              | Open with                                                 | What you get                                                                                          |
| -------------------- | --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| **`playable-demo/`** | `godot --path examples/playable-demo` _or_ open in editor | A 2D `CharacterBody2D` you can move with arrow keys / WASD and recolor with Enter. No addon required. |

## Quick start (playable-demo)

```powershell
# Editor: Project Manager > Import > pick examples/playable-demo/project.godot
# Or run directly from the CLI:
$env:GODOT="C:\Users\<you>\AppData\Local\Programs\Godot\Godot_v4.6.3-stable_mono_win64\Godot_v4.6.3-stable_mono_win64_console.exe"
& $env:GODOT --path examples/playable-demo
```

Press F5 in the editor or just run the CLI — the main scene `res://main.tscn` loads automatically
(set via `run/main_scene` in `project.godot`).

## Not test fixtures

If you're looking for projects used by `npm run test:server`, those live under `tests/_fixtures/`.
They are intentionally minimal (no main scene) because they exist to be project roots for
`godot --headless`, not for interactive play. Don't open them in the editor expecting Play to work.

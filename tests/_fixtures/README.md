# Test fixtures

Per `docs/tasklist/10 §10.6.2`. Each subdirectory is a tiny Godot project the integration harness
can copy to a temp directory.

| Fixture              | Purpose                                                                                                                     |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `empty/`             | Smallest valid project; powers headless `ping` + `script.validate_syntax`.                                                  |
| `with-addon/`        | Project the addon-parse smoke stages into; verifies `class_name`s under real Godot.                                         |
| `minimal_3d/`        | Minimal 3D project with `main.tscn`; powers task 11 `scene.*` / `project.*` headless tests.                                 |
| `resource_zoo/`      | Sample `.tres` + `.gdshader` files; powers task 14 `resource.*` / `shader.*` headless tests.                                |
| `asset_zoo/`         | Texture + script sample; powers task 15 `asset.*` / `batch_refactor.*` and task 16 `analysis.*` headless tests.             |
| `minimal_game/`      | CharacterBody2D + runtime bridge autoload; powers task 17 `runtime.*` headless E2E (bridge staged from addon at test time). |
| `physics_zoo/`       | 3D world root; powers task 19 `physics.*` headless tests.                                                                   |
| `particle_zoo/`      | Effects root; powers task 19 `particle.*` headless tests.                                                                   |
| `nav_zoo/`           | Floor + nav region; powers task 19 `navigation.*` headless tests.                                                           |
| `tilemap_zoo/`       | TileMapLayer + tileset; powers task 20 `tilemap.*` headless tests.                                                          |
| `theme_zoo/`         | Theme + Control sample; powers task 20 `theme_ui.*` headless tests.                                                         |
| `audio_zoo/`         | Multi-bus `AudioBusLayout`; powers task 21 `audio.*` headless tests.                                                        |
| `input_zoo/`         | Custom `dash` action + script reference; powers task 21 `input.*` headless tests.                                           |
| `dialogue_demo/`     | _(planned)_ Macro showcase.                                                                                                 |
| `stress_tree_10000/` | _(planned)_ Stress tree for envelope/SLA tests.                                                                             |

Add fixtures alongside this README; for the headless driver you do **not** need to import the addon
(it loads via `--script`). The `with-addon/` fixture is the exception: the parse-check test stages
the addon as `addons/terravolt_mcp/` at runtime (and `.gitignore`d) so that `class_name` siblings
resolve.

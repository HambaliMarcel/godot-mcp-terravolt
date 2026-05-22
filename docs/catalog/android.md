# Catalog: `android.*`

Task 26 — 3 daemon methods (`catalog_version` **0.17.0**).

| Method                 | Safe | Mutates | Headless |
| ---------------------- | ---- | ------- | -------- |
| `android.list_devices` | yes  | no      | yes      |
| `android.preset_info`  | yes  | no      | yes      |
| `android.deploy`       | no   | yes     | yes      |

Handlers: `packages/godot-mcp-addon/handlers/android.gd`  
Helpers: `packages/godot-mcp-addon/handlers/android_helpers.gd`

These methods are all headless-safe — they shell out to `adb` (resolved via the
`TERRAVOLT_ANDROID_ADB` env var, Editor Settings → Export → Android → Adb, or `$PATH`) and to
`godot --headless --export-debug/release …` for the export step. No editor session is required.

`android.deploy` executes the full chain unless `skip_export=true`:

1. `godot --headless --path <project> --export-debug <preset> <export_path>`
2. `adb [-s <serial>] install -r <apk>`
3. `adb [-s <serial>] shell monkey -p <package> -c android.intent.category.LAUNCHER 1` (when
   `launch=true` and `package_name` is configured in the preset).

Every step is recorded in `result.steps[]` so failures surface the exact command + exit code +
captured stdout.

Error band: `-33998` (`android.adb_not_found`), `-33999` (`android.preset_not_found`), `-34010`
(`android.install_failed`), `-34011` (`android.export_failed`).

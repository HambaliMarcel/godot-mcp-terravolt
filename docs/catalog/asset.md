# Catalog: `asset.*`

Phase 3 work-unit #5 — 12 daemon methods (`catalog_version` **0.7.0**).

| Method                       | Safe | Mutates | Headless       |
| ---------------------------- | ---- | ------- | -------------- |
| `asset.list`                 | yes  | no      | yes            |
| `asset.import_status`        | yes  | no      | yes            |
| `asset.reimport`             | no   | yes     | partial (note) |
| `asset.get_import_settings`  | yes  | no      | yes            |
| `asset.set_import_settings`  | no   | yes     | yes            |
| `asset.add`                  | no   | yes     | yes            |
| `asset.delete`               | no   | yes     | yes            |
| `asset.rename`               | no   | yes     | yes            |
| `asset.preview`              | yes  | no      | no (editor)    |
| `asset.metadata`             | yes  | no      | yes            |
| `asset.batch_import_presets` | no   | yes     | partial        |
| `asset.find_unused`          | yes  | no      | yes            |

Handler: `packages/godot-mcp-addon/handlers/asset.gd`  
Helpers: `packages/godot-mcp-addon/handlers/asset_helpers.gd`  
Extensions allow-list: `packages/shared/asset/extensions.json`

Error band: `-33900` … `-33904` (+ shared `resource.dependency_block`).

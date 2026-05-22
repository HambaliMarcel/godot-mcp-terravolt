# Windows — portable Godot (ZIP, not MSI)

Godot distributes a **standalone `.exe`** (plus sidecar DLLs/PCK in the same folder). There is
nothing wrong with skipping the itch.io “installer” workflow—just keep the unzip layout intact.

## 1. Keep the unzip folder stable

Prefer a path **without spaces** once you settle on one, for example:

- `D:\sdk\godot-mono\4.6.3\` (recommended long-term)

Your Downloads folder works for learning, but **avoid moving files** referenced by shim scripts
unless you update the shim paths.

## 2. Smoke-test the binary

In PowerShell (replace `<folder>`):

```powershell
& "D:\sdk\godot-mono\4.6.3\Godot_v4.6.3-stable_mono_win64.exe" --version
& "D:\sdk\godot-mono\4.6.3\Godot_v4.6.3-stable_mono_win64.exe" --headless --version
```

You should see a `4.x` banner for both commands.

## 3. Put `godot` on `--version`/`PATH`

Windows resolves **`godot.exe`** OR **`godot.cmd`** names. A tiny shim keeps your PATH tidy:

```bat
@echo off
"C:\FULL\PATH\TO\Godot_v4.6.3-stable_mono_win64.exe" %*
```

Save as **`%USERPROFILE%\bin\godot.cmd`** (creates itself if you `mkdir bin`).

Then **append `%USERPROFILE%\bin` to your user `PATH`** (Settings → Environment variables → Path →
User), or append once via PowerShell:

```powershell
$bindir = Join-Path $env:USERPROFILE "bin"
New-Item -ItemType Directory -Force -Path $bindir | Out-Null

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*${bindir}*") {
  $new =
    ($(if ([string]::IsNullOrEmpty($userPath)) { "" } else { "$($userPath.TrimEnd(";"));" }) +
    $bindir)
  [Environment]::SetEnvironmentVariable("Path", $new, "User")
}
```

Close and reopen terminals (or reboot) so **`where.exe godot`** returns your shim:

```powershell
where.exe godot
godot --version
```

This satisfies **`docs/tasklist/01-repository-and-tooling-setup.md` §A.1** doctor checks tied to
**`godot --version`**.

## 4. Sandbox project outside `godot-mcp-terravolt`

Mirror **`01` §A.3 / §1.6.4**: clone/symlink TerraVolt’s **`packages/godot-mcp-addon/`** later into
`addons/terravolt_mcp/` (task **`02`**). Until then, bootstrap a disposable project **outside** the
MCP monorepo, e.g. `%USERPROFILE%\Documents\TerravoltMcpDev\`:

- Minimal **`project.godot`** pinned to **`4.6`** via `config/features`,
- **`run/main_scene`** set to **`res://Main.tscn`** alongside a trivial `Main.tscn`,
- Prefer saving **`project.godot` / `.tscn`** as UTF-8 **without BOM** (avoid rare parser issues on
  Windows).

After creating those files manually, **bootstrap the `.godot` cache once** — this prevents the GUI
from opening a half-initialised project and then failing **Play** with “no main scene”:

```powershell
godot --path "$env:USERPROFILE\Documents\TerravoltMcpDev" --headless --import --quit-after 120
godot --path "$env:USERPROFILE\Documents\TerravoltMcpDev" --headless --quit
```

If the alert still appears, assign the scene explicitly:

**Project → Project Settings → Application → Run → Main Scene → choose `Main.tscn`** (then save).

## Related

- **Task list gates:** **`docs/tasklist/01-repository-and-tooling-setup.md`** §§1.6.10 · 1.12 ·
  Appendix A
- **Omni tooling:** **`scripts/README.md`** doctor checklist

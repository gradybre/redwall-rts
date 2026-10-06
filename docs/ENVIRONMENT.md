# Environment and toolchain

Verified on macOS (Apple Silicon), 2026-09-05/06. Update this file when
something here stops being true.

**No secret values appear in this file or anywhere in this repository.** Only
the locations they live in are recorded.

## Installed tools

| Tool | Version | Installed via | Notes |
|---|---|---|---|
| Godot | **4.7.2 stable** | `brew install --cask godot` | `project.godot` targets 4.7. Docs say "4.3+"; 4.7 is the only version anything has been run against. |
| Blender | **5.2.1 LTS** | `brew install --cask blender` | On PATH as `blender` |
| Git LFS | 3.8.0 | `brew install git-lfs` | See `.gitattributes` and decision 0005 |
| uv / uvx | Homebrew | | Runs the Blender MCP server |
| Node / npx | v26 | | Runs the Meshy MCP server |

## Commands that work

Run these from the repository root unless stated.

```bash
# Test suite — prefer the script: it asserts the runner actually ran (see below)
./tools/run_tests.sh

# The same thing without the guard
godot --headless --path godot --script test/run_tests.gd

# Import assets / refresh the Godot project
godot --headless --path godot --editor --quit

# Boot the game headlessly
godot --headless --path godot --quit-after 120

# Balance harness (decision 0911): a game year of the real village per run, then the report.
# --fixed-fps 30 is required (the run checks it); success is the log's "BALANCE-RUN ok" line, not exit 0.
python3 tools/run_balance_matrix.py --out-dir <dir> --seeds 1 2 3 --days 48 --jobs 3
python3 tools/balance_report.py --out docs/balance/<name>.md --svg-dir docs/balance/<name> <dir>/*.json

# Normalise a Meshy GLB into a Godot-ready asset
blender --background --python .claude/skills/asset-pipeline/scripts/prep_unit.py -- \
  assets/source/<name>.glb godot/assets/units/<name>.glb --height 1.00
```

**`--path godot` is mandatory.** Running `godot` from the repository root finds
no `project.godot`, silently opens the project manager, imports nothing, and
**exits 0** — so it looks like success. This has already caused one wrong
conclusion. The exception is running from inside `godot/`, where bare `godot`
works.

**Because of that trap, an exit status of 0 is not evidence that anything ran.**
`tools/run_tests.sh` therefore asserts on the runner's own summary line: it must
be present, report a non-zero test count, and report zero failures. CI runs that
script (`.github/workflows/tests.yml`), so a run that executes nothing fails
rather than reporting success. Prefer the script over the bare command; a count
is deliberately not quoted here, because a hardcoded one goes stale the next
time a test is added.

## Reading the test log

`./tools/run_tests.sh` ends with three lines (decision 0501):

```text
7085 test(s), 562012 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 50 expected, 290 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

The numbers above are from 2026-10-01; read your own. In CI, where the demo's assets are not staged, the tolerated
count is higher (the sound cues that warn they play silent). **The run fails if any unexpected count or leak count is above
zero**, even with 0 failures.

- **A line that starts `ERROR:` or `WARNING:` is a finding.** Nothing declared it.
- **`EXPECTED ERROR: ...` / `EXPECTED WARNING: ...`** is a negative test's refusal, declared with
  `expect_diagnostic("fragment")` (test/framework/test_case.gd). If the declared line never appears, the test fails.
  So when you add a test that provokes `push_error`/`push_warning` on purpose, declare it first.
- **`TOLERATED ...`** is one of two kinds of line, and none is required:
  - One of the engine's two notices for a node outside the scene tree: a `!is_inside_tree()` global-transform read
    (a particle emitter restarting does one too) and `Camera is not inside scene.`. The worker runs every suite
    before the root is in the tree (see "Real input in a headless run"), so a suite that builds node fixtures sees
    them. Only suites that override `tolerates_outside_tree()` tolerate them, and only when the next `at:` line names
    the 3D `get_global_transform` or the camera. The same message from anything else is a finding.
  - A line that depends on the machine, not the code, declared by its test with `tolerate_diagnostic("fragment")`.
    For example, the real sound cues warn that they play silent where the demo's assets are not staged, as in CI.
- **`leaked at exit`** counts the worker's own shutdown report: objects and resources nothing freed. The usual
  cause is a reference cycle, which GDScript never collects. A lambda that uses a member or `self` holds the object
  it was made in. A lambda that captures a local holds that local. A plain method Callable (`obj.method`) holds only
  an id. Break the cycle in `after_each`, or in production code when the cycle is the game's own (the tunnel router
  and the resident brain each had one).
- **Find which suite leaks** with a focus runner that extends `res://test/run_tests.gd` and overrides
  `_discover_suites()`; run each suite in its own process and read its `leaked at exit` line. Add `--verbose` to a
  bare worker run (`... --script <focus>.gd -- --run-suites`) to list every leaked instance by class.
- **GDScript warnings never reach this log.** A headless run prints nothing for an integer division or a shadowed
  variable. `python3 tools/gdscript_warnings.py` lists them through the editor's language server (about 2.5 minutes),
  and CI fails on any. An integer division that is meant goes in as
  `@warning_ignore("integer_division") var half: int = n / 2`, on the statement itself. `int(a / b)` does not silence
  the warning, an annotation on the `func` line does not cover its body, and an `elif` condition needs
  `@warning_ignore_start`/`@warning_ignore_restore` around it.

## The Windows demo build

One command, run on the Mac from the repository root, builds the standalone Windows live demo
(decision 0196): it imports, VRAM-compresses the staged textures, reimports, exports, boots the pack
to check it and zips it.

```bash
python3 tools/stage_demo_assets.py                          # once: the demo's assets (gitignored)
python3 tools/build_demo_windows.py --out <folder>          # -> <folder>/redwall-demo-windows.zip (debug: a playtest build)
python3 tools/build_demo_windows.py --out <folder> --release  # on the release template (a final build; decision 0562)
python3 tools/build_demo_windows.py --out <folder> --pack-only   # no Windows templates: just the .pck
python3 tools/demo_texture_imports.py --godot godot         # the compression step on its own
```

- **It needs Godot's Windows export templates.** Installed 2026-09-29 from the official
  `Godot_v4.7.2-stable_export_templates.tpz` (1,281,349,702 bytes, SHA-512 checked against the
  release's `SHA512-SUMS.txt`): the twelve `windows_*` templates now sit beside `macos.zip` in
  `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`. Without them the script stops
  and says so; `--pack-only` still exports and verifies the pack. The package carries **no** D3D12
  Agility SDK or ANGLE libraries, so the preset does not ask for them.
- **`godot/export_presets.cfg` stays gitignored and local.** The committed preset is
  `tools/demo_build/windows_export_preset.cfg`; the script merges it in by name and keeps every other
  preset there (the macOS benchmark one).
- **The export templates reject `--main-pack`** (verified in `tools/export_benchmark_build.py`), so
  the pack is verified with the *editor* binary:
  `godot --main-pack <pck> --script tools/godot/verify_demo_pack.gd -- <out.json>`.
- **`ProjectSettings.get_setting()` ignores feature overrides.** The engine reads settings with
  overrides applied; a script that checks `application/run/main_scene.demo_build` must call
  `get_setting_with_override()` (or `..._and_custom_features()` in a test), or it reports
  `scenes/main.tscn` from a correct pack.
- **Touch a GLB to make Godot re-check it.** `--import` skips files whose modification time is
  unchanged, even with their `.md5` deleted.
- **The release template hides script errors, and a null call kills it** (decision 0562). This was measured on the
  4.7.2 macOS release template, which runs the same GDScript VM as Windows'. An out-of-range index raises nothing.
  A method called on null ends the process with signal 11 and leaves no message, not even in `godot.log`, which a
  release export flushes only on error lines. The debug template reports both as SCRIPT ERROR and carries on. The
  demo's playtest log (`user://logs/playtest-*.log`, beside `godot.log`) flushes every line, for this reason. On
  Windows it is in `%APPDATA%\Godot\app_userdata\Redwall Demo\logs`.
- **A script `Logger` held in a static var aborts the process at exit** (`recursive_mutex lock failed`, status 134):
  remove it with `OS.remove_logger` and drop the last reference while the tree is still up.
- **A screenshot stalls the clock into a CRITICAL pause.** Reading back and PNG-encoding a HiDPI frame
  takes longer than the clock's overload limit (a quarter second of debt at 1x); nothing in the game HUD
  acknowledges an overload -- the demo's stall banner does (`demo/ui/demo_stall_banner.gd`). Harness
  scripts pause (as the player) around a screenshot; `verify_demo_pack.gd` forces one stall on purpose
  and presses Enter to check the banner.

## Real input in a headless run

- **The suite's worker cannot dispatch input.** `test/run_tests.gd` runs every suite inside `_initialize`,
  before the root Window is in the tree: `push_input`, `grab_focus` and `release_focus` there fail with
  `!is_inside_tree()`. A check that needs real Viewport input runs its own SceneTree script in a child process
  (`test/test_demo_input_live.gd` runs `test/live/demo_input_live.gd`; decision 0261).
- **The headless display server sizes the root to 64x64 on the first frame**, whatever `root.size` was set to
  in `_initialize`. GUI hit tests then miss every control past 64 px while unhandled world input still arrives,
  so a click "passes through" a panel for the wrong reason. Set `root.size` again each frame (the live harness
  does).

## MCP servers

Configured in `.mcp.json` (committed; contains no secrets).

| Server | Command | Requires |
|---|---|---|
| `meshy` | `npx -y @meshy-ai/meshy-mcp-server` | `MESHY_API_KEY` in the environment; a paid Meshy plan for API task creation |
| `blender` | `uvx blender-mcp` | Blender running with its socket server started |

**Meshy credits are real money.** Present the cost and get explicit
confirmation before any tool that spends. `meshy_check_balance` is free.
Roughly 38 credits for a full unit: generate 5–20, texture 10, rig 5, animate 3.

**Starting the Blender bridge** — the add-on is installed and enabled already,
so only the socket server needs starting:

```bash
blender --python-expr "import bpy; bpy.ops.blendermcp.start_server()"
```

Blender MCP executes model-generated Python in Blender **with no sandbox** —
Blender's own documentation recommends a VM or a machine without sensitive data.
Start the socket server only while actively using it. Telemetry (prompts, code,
screenshots, scene data) was **disabled** on 2026-09-05; only anonymous usage
counts remain. Re-enable is manual, in Blender's add-on preferences.

## Secret locations

`MESHY_API_KEY` lives in `~/.claude/settings.json` under `env`, and in
`~/.zshenv` and `~/.zshrc`. **The value is not in this repository and must never
be committed.**

Why three places: shell rc files reach terminals but **not** the macOS desktop
app, which launchd starts without sourcing any shell file. The
`~/.claude/settings.json` `env` block is what actually reaches MCP servers
spawned by the desktop app. `.zshrc` alone silently fails — `${MESHY_API_KEY}`
in `.mcp.json` then expands to the literal string and every call 401s.

Rotating the key means updating all three.

## External document generation

Prompts live in `chatgpt-prompts/`. Outputs go **into `docs/` in this
repository** — see decision 0007 for what happened when they did not.

## Test runs use a private `user://` (ADR 1204)

`./tools/run_tests.sh` points Godot's `user://` at a fresh temporary directory
for each run. It does this by setting `HOME` (macOS) or `XDG_DATA_HOME` (Linux)
for the Godot process only, and deletes the directory on exit. Do not run the
suite with a bare `godot --script`: every checkout shares one `user://`, so
concurrent runs overwrite each other's fixture files and fail at random.

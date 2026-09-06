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
# Test suite — 52 tests, 106 assertions
godot --headless --path godot --script test/run_tests.gd

# Import assets / refresh the Godot project
godot --headless --path godot --editor --quit

# Boot the game headlessly
godot --headless --path godot --quit-after 120

# Normalise a Meshy GLB into a Godot-ready asset
blender --background --python .claude/skills/asset-pipeline/scripts/prep_unit.py -- \
  assets/source/<name>.glb godot/assets/units/<name>.glb --height 1.00
```

**`--path godot` is mandatory.** Running `godot` from the repository root finds
no `project.godot`, silently opens the project manager, imports nothing, and
**exits 0** — so it looks like success. This has already caused one wrong
conclusion. The exception is running from inside `godot/`, where bare `godot`
works.

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

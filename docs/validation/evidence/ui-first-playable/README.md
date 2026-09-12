# UI first-playable evidence — task 04.4 bullets 1 and 2

Captured 2026-09-11 from the **native macOS game**, not a headless render and not a preview.

| Field | Value |
| --- | --- |
| Branch / base revision | `feat/ui-shell`, branched from `d997d07` (origin/master) |
| Working tree | **dirty** — this is uncommitted work in progress at capture time; the commit on `feat/ui-shell` carries the same tree |
| Engine | Godot 4.7.2 stable (official), Metal 4.0 Forward+, Apple M5 Pro |
| Launch command | `godot --path godot --script capture_ui_scratch.gd --resolution <W>x<H> -- <out.png> <mode> [user_scale]` |
| Mutation testing | 50 mutations, one Godot invocation each, restored and SHA-256 compared after every run. 48 killed on the first pass; the **2 survivors were real test gaps**, both closed with a new test, and both then killed on a re-run of their own. |
| Plain launch | `godot --path godot` was run first and opened the real window; the capture script exists only to write the PNG and print the layout facts, and instantiates the same `res://scenes/main.tscn` the project's `run/main_scene` names |
| Headless suite | `./tools/run_tests.sh` → `ok: 2274 tests, 61649 assertions, 0 failures.` |
| World seed | 20260905 (GDD §5.1's fixed tutorial seed; UI-SET-103's default) |
| Fixture | `main.tscn` boot: `SettlementSystem.create_initial_settlement()`'s **real 12-resident cohort**, plus GDD §5.1's starting inventory |
| Screen scale reported by the OS | 2.0 |

`capture_ui_scratch.gd` is a scratch file and is **deleted before the commit**; it is recorded
here because the exact command matters. Every flow it drives goes through the interface's own
entry points (`Button.pressed`, `UIManager.create_world()`, `UIManager._on_tile_picked()`), not
through a store.

## What each capture shows

All paths are relative to `screenshots/`.

| # | File | Window | Canvas / user scale / profile | Shows |
| --- | --- | --- | --- | --- |
| 01 | `01_paused_hud_1920x1080.png` | 1920×1080 | 1920×1080, 100%, WIDE | Boot HUD. **Paused: PLAYER** is visible and named; the pause toggle is selected; six counters with real values or a named reason; empty command queue |
| 02 | `02_resident_detail_1920x1080.png` | 1920×1080 | 1920×1080, 100%, WIDE | Roster of the **real 12-resident cohort** (Warden Rowan first), one row keyboard-focused with the GOLD outline, detail panel showing that resident's real hunger/rest/health/skill |
| 03 | `03_zone_pending_1920x1080.png` | 1920×1080 | 1920×1080, 100%, WIDE | Generated world, tile picked, zone stroke painted, Confirm pressed. Console: `PENDING COMMANDS: 1` |
| 04 | `04_refusal_focus_1920x1080.png` | 1920×1080 | 1920×1080, 100%, WIDE | Confirm pressed with nothing selected. Refusal panel with warning icon **and** words, focus still on the control that refused |
| 05 | `05_new_settlement_1920x1080.png` | 1920×1080 | 1920×1080, 100%, WIDE | UI-SET-103 New Settlement page with its Create action |
| 06 | `06_invalid_form_1920x1080.png` | 1920×1080 | 1920×1080, 100%, WIDE | The same form with `architecture = HOLT`. Console: `CREATE: false`; the refusal names the unauthored scenario |
| 07 | `07_generated_world_1920x1080.png` | 1920×1080 | 1920×1080, 100%, WIDE | After generation: 1695 nodes / 7 basins / 9 stocks reported, minimap shows `128 x 128 tiles, seed 20260905`, **Residents 0** |
| 08 | `08_paused_hud_1280x720.png` | 1280×720 | 1920×1080, 100%, WIDE | The same HUD in a 1280×720 window — see the stretch finding below |
| 09 | `09_zone_pending_1280x720.png` | 1280×720 | 1920×1080, 100%, WIDE | Zone flow in the small window. Console: `PENDING COMMANDS: 1` |
| 10 | `10_scale150_1280x720.png` | 1280×720 | 1920×1080, **150%**, STANDARD | 150% user scale: the standard composition, larger controls, scrolling roster, fixed footer |
| 11 | `11_highdpi_3840x2160.png` | requested 3840×2160, **granted 3456×1986** | 1920×1103, 100%, WIDE | High-DPI render. The OS refused the full 3840×2160 window on this display; backing image 3456×1986 |
| 12 | `12_specimen_1920x1080.png` | 1920×1080 | n/a | The **UI specimen** (`res://scenes/ui/ui_specimen.tscn`): every §2.2 profile in all five states, a field, a meter and a refusal. **Every value on it is synthetic and the scene says so in its banner.** |

`before/` holds three captures from the same branch **before** the shared theme, fonts and icons
landed, for the before/after comparison the brief asks for.

## Player Impact Report

**Before:** the game booted into an unpaused world with six empty placeholder panels, the engine
default theme, no icons, no font of the project's own, and no operable control except a Space
key that toggled pause. One UI-SET element out of 103 appeared anywhere in the code.

**After:** the world opens **paused for inspection**, and the player can read provisions, fuel,
wood, stone, population and beds — each either a real figure or a named missing owner; open the
roster and select a real resident; read that resident's hunger, rest, health and foraging level;
generate §5.1's authored world; pick a tile on the map and see its terrain, basin and danger
band; paint a zone and commit it as a **command** that sits pending while the world is paused;
cancel it; and read an exact refusal with a severity icon, plain words and the technical code.

**What still reads as unfinished, honestly:** 61 of the 103 registry elements are drawn
**disabled with the name of the missing owner** rather than hidden — building, saving, settings,
feasts, recipes, forecasts, the job matrix and world-list rows among them. The world itself is
still the prototype green plane; no terrain renderer exists, so the "open centre" the design
asks for is currently an empty field rather than a settlement.

## Findings

### F1 — `project.godot`'s stretch mode defeats §1.2's breakpoints (BLOCKED, not mine to fix)

`window/stretch/mode="canvas_items"` against a 1920×1080 base gives the HUD a 1920×1080 canvas
**whatever the window size is**. Measured: a 1280×720 window reports `canvas (1920, 1080)` and
the WIDE profile, where §1.2's equations give Lw 1280 and STANDARD. §1.2 explicitly says "Do not
scale the entire game through a low-resolution pixel viewport". Consequences:

* capture 08 is the wide composition scaled down, not §1.2's 1280×720 composition;
* the NARROW profile (Lw < 1120) is **unreachable at runtime**: even 150% user scale only
  reaches Lw 1280. It is exercised by `test_ui_layout.gd` and `test_ui_shell.gd`, not on screen.

`project.godot` belongs to the integration lead. `ui_shell.gd`'s `_apply_geometry()` records the
measurement and why laying out against the window size instead would be worse.

### F2 — high-DPI window size was granted at 3456×1986, not 3840×2160

Requested `--resolution 3840x2160`; the OS granted 3456×1986 on this display. The capture is
kept and labelled with both numbers. **3840×2160 itself is deferred**, not passed.

### F3 — the generated world has no residents, and the boot cohort is real

Both are true and they are different paths, which is worth stating precisely:

* `main.tscn` boot calls `SettlementSystem.create_initial_settlement()`, which creates a **real
  12-resident cohort**. Captures 01, 02 and 10 show it: `Residents 12`, Warden Rowan named.
* `UI-SET-103` Create runs `world_init.gd`, which refuses to publish over live rows it does not
  own, so the New Settlement flow **resets the settlement first**. The generated world therefore
  has terrain, 1695 resource nodes, 7 basins and 9 fish stocks and **nobody living in it**:
  capture 07 shows `Residents 0`, which is a true zero and not an unpopulated marker.
* Task 06 owns the starter building/container/gear fixture that would repopulate a generated
  world. **Neither capture completes FP-01.**

### F4 — states that are distinguished on screen

`--` is the unpopulated marker (no owning store: Fuel, Beds). `0` is a measured zero (Residents
in a generated world). "Unavailable: …" is an unsupported feature with its missing owner. These
are three different renderings, and no undefined value is drawn as a zero.

## Checks run, and checks not run

| Check | Result |
| --- | --- |
| Headless suite | PASS — `ok: 2274 tests, 61649 assertions, 0 failures.` |
| Paused start, PLAYER reason, empty initial orders | PASS — captures 01/08, `test_ui_manager.gd` |
| Paused designation leaves stores unchanged, command pending | PASS — capture 03/09 (`PENDING COMMANDS: 1`), `test_ui_command_bridge.gd` |
| Resume commits once, one source-linked job, then cancellation | PASS in the suite (`test_ui_command_bridge.gd`); **not** in a screenshot, because resuming needs real elapsed time |
| Refusal shows icon + words + code, focus retained | PASS — capture 04 |
| Decorative controls never consume a world click | PASS — `test_ui_hit_test.gd`, `test_ui_shell.gd` |
| Keyboard focus order | Partial — the order is tested headlessly and the focus outline is visible in captures 02/04; a full keyboard-only traversal of the running app is **not executed** |
| Screen reader (VoiceOver/NVDA) | **NOT EXECUTED.** Accessible names and descriptions are set and asserted; that is not a screen-reader pass |
| Narrow profile on screen | **BLOCKED** by F1 |
| 3840×2160 | **DEFERRED** by F2 |
| Reduced motion, trackpad alternatives, tooltip-on-hover timing | **NOT EXECUTED** |
| Windows qualification | Out of scope; this is Mac only |

## Reproduction

```sh
cd <worktree>
./tools/run_tests.sh
godot --path godot                       # the native game, paused at boot
godot --path godot --script capture_ui_scratch.gd --resolution 1920x1080 -- /tmp/a.png zone 100
```

The scratch capture script is deleted before commit; recreate it, or drive the same entry points
by hand: `UIManager.create_world()`, `UIManager._on_tile_picked(tile)`, the shell's
`paint_tile()` and the UI-SET-066 Confirm button.

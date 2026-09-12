# Task 04.5 native UI evidence

Captured 2026-09-11 from the **native macOS game**, not a headless render and not a preview.

| | |
|---|---|
| Branch | `feat/ui-shell-integration` |
| Suite at capture | `ok: 2711 tests, 98302 assertions, 0 failures.` |
| Launch | `godot --path godot --script capture_ui_scratch.gd --resolution <W>x<H> -- <out.png> <mode> [scale]` |
| Scene | the project's own `run/main_scene`, `res://scenes/main.tscn` |
| Harness | `capture_ui_scratch.gd`, a scratch file **deleted before commit**; recorded here because the exact command matters |

The harness fakes no state. It drives the interface's own public entry points —
`UIManager.create_world()` is UI-SET-103's Create — and every value on screen came from
the real stores through the real HUD.

## The responsive correction

All three profiles are reachable at runtime for the first time, matching the READY_07
save/UI addendum's table:

| Window | User scale | Logical | Profile |
|---|---:|---|---|
| 1920×1080 | 100% | 1920×1080 | WIDE |
| 1280×720 | 100% | 1280×720 | STANDARD |
| 1280×720 | 150% | 853×480 | NARROW |

Previously every window reported WIDE. It took both halves of the ruling: `project.godot`'s
base stretching disabled, **and** a UI-only scale transform on the shell. Applying only the
first drew the narrow layout correctly at 853×480 in the corner of a 1280×720 window, which
is how the missing half was found. The ruling says in terms: do not apply both.

## What each capture shows

| File | Window / scale | Shows |
|---|---|---|
| `01_paused_wide_1920x1080.png` | 1920×1080 / 100% | Boot HUD, **Paused: PLAYER** named, counters with real values or a named reason |
| `02_generated_wide_1920x1080.png` | 1920×1080 / 100% | After UI-SET-103 Create: 1695 nodes, 7 basins, 9 fish stocks, seed 20260905 — the full sentence, wrapped |
| `03_roster_wide_1920x1080.png` | 1920×1080 / 100% | Residents opens the ROSTER, not the unbuilt world-access panel |
| `04_newsettlement_wide_1920x1080.png` | 1920×1080 / 100% | The UI-SET-103 form |
| `05_standard_1280x720.png` | 1280×720 / 100% | STANDARD profile |
| `06_narrow_1280x720_150.png` | 1280×720 / 150% | NARROW: compact two-row resources, single-row time group, two command rows |

## Open defects, visible in these images

1. **The alert card overflows at NARROW.** The message now wraps rather than clipping
   (UXV-032), and a long generation sentence wraps to three lines and draws outside a card
   whose height `ui_layout.alert_card()` fixes, over the pause line. Growing it from the
   shell does nothing — `_place_local()` re-sets the rect from the layout every pass. The
   card must become content-sized in `ui_layout.gd`, which the component owner holds.
   Overlap is worse than the clipping it replaced; both are recorded rather than traded.
2. **Frame art is authored but not applied.** `godot/ui/frames/` holds five frames of four
   corners and four edges each. Two placement attempts put corners outside their panels and
   left the edge strips invisible. The pieces load and draw, so the fault is the placement
   contract, not the paths: `ui_art_manifest.json` declares each asset's actual bounds and
   stretch margins and its author owns what they mean. `_apply_frame_art()` is kept in
   `ui_shell.gd`, uncalled, with that reason at the function.
3. **`Residents 0` after generation.** The starter cohort is on an unpushed branch and is not
   in this stack, so no resident detail exists to capture and **ART-UI-09 cannot be judged**.
4. **Painted icons are applied; panels are not.** The bowl, logs, stone, population group and
   Zone stakes render from `godot/ui/painted/`, and NARROW uses the 16 px symbolic variants
   rather than shrinking painted detail. Panels remain flat green — see defect 2.

## What these images do not establish

No visual approval. No keyboard or screen-reader qualification — names and descriptions are
set and asserted, which is not a pass. No Windows or minimum-hardware claim. High-DPI is not
captured here. Brendan's verdict is ART-UI-12 and is recorded separately.

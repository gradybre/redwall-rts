# 0144 — The ordinary workspace was an unimplemented amendment, not a z-order gap
Date: 2026-09-14 · Status: Accepted

## Decision

UI-C3-R01 is implemented across `ui_layout.gd`, `ui_shell.gd`, `ui_registry.gd` and
`hud.gd`. Seven things were settled while doing it.

1. **The workspace occlusion is fixed at the RECTANGLE, not at the layer table.**
   `_place_zones()` placed `ID_WORKSPACE` at `_geometry.modal` for every page. At
   1280x720 that is `(160,16,960,688)`, which contains the whole alert zone, two of the
   three resource columns and part of the minimap — the cycle-01 captures measured zero
   differing pixels between two active alert cards and none at all. SET-UX-VIS-002 §4.2
   had already split UI-SET-051 into an ordinary WORKSPACE and a MODAL, and the ordinary
   variant was never built. `UiLayout.workspace_rect()` builds it: width `min(640,Lw-32)`,
   bottom `command_strip.top-8`, top at least `management_top`, centred on the command
   strip and clamped off an open detail column. **No HUD control was raised above any
   dialog**, and `MODAL_PAGES` — UI-SET-103 and the name editor — still take §1.2's
   centred rectangle and still occlude. `test_a_true_modal_page_still_occludes_from_the_centred_rectangle()`
   asserts that half, so a future "fix" that flattened the distinction fails.

2. **`management_top` is stored on the Geometry, not recomputed by each caller.**
   It is `max(128, bottom(resources), bottom(alerts), bottom(time)) + 8` and it is 152 at
   every supported profile and user scale. A refused `compute_into()` returns it to its
   own 128 floor rather than leaving the last one standing, for the same reason every
   other rectangle is reset.

3. **The counter cell is two Labels inside a Button, and the Button prints nothing.**
   A `Button` draws its own `icon` beside its own `text` on one line, which is exactly the
   composition UI-C3-R01 §2 replaces. The caption line (14 px) and the numeric line (18 px)
   are separate children at separate rectangles, with a 16 px `TextureRect` beside the
   caption. Consequently `set_counter_display()` no longer writes `button.text`; it records
   the exact value and repaints. `test_hud.gd` and `test_ui_shell.gd` follow the string into
   the line that draws it.

4. **The cell measures against the Theme RESOURCE, never through `get_theme_font()`.**
   `Control.add_theme_font_size_override()` only refreshes a control's theme cache while it
   is inside the tree, and this shell is built off-tree by the headless suite. A measurement
   taken through the control would therefore use Godot's default face in the suite and the
   vendored Noto face in the game — and that measurement is what decides whether a value is
   drawn or disclosed. `_variation_font()` reads the shell's own `Theme`, which is identical
   in both. This is also why the tests assert the ALLOCATED line boxes rather than the
   Labels' realised `size.y`.

5. **The See ledger disclosure is UI-SET-009, not a new surface.** Activating a cell opens
   the existing resource ledger, whose line carries every counter's complete value and which
   wraps and scrolls. The action is connected for every counter, not only overflowing ones,
   so the disclosure is operable rather than conditional. Nothing shortens a number anywhere:
   the exact string stays in `_counter_full` and in the accessible description whatever the
   cell draws.

6. **UI-SET-051's registry minimum is overridden at CONSTRUCTION.** §4's row publishes
   480x320 and UI-C3-R01 §4's compact body is 640x312. `Control.update_minimum_size()`
   returns immediately outside the tree, so clearing `custom_minimum_size` after
   `_new_panel()` has already sized the panel does not invalidate the cached minimum —
   the frame silently came back as 320 high. `_control_minimum_size()` applies the override
   before the size is ever assigned. §4's row is unchanged and still published, and
   `_workspace_content_height()` still reads its 320 as the content floor.

7. **The workspace content column is given the frame's interior, never the ScrollContainer's
   realised width.** With horizontal scrolling disabled a ScrollContainer takes its minimum
   width from its content, so assigning the realised width back into the content's minimum is
   a ratchet that can only grow. It had never been visible because the frame was always 960
   wide; at 640 the roster kept 936 px rows and `clip_contents` cut the last glyphs off every
   resident's health line. Found in a native capture, not in the suite.

## Why

The previous lane and the integration lead both recorded the occlusion as unfixable — that
§3's layer table made the workspace drawing over the alert zone "the specification working as
written". That was wrong, and the record is corrected here: §4.2 already distinguished the two
variants, and the shell had implemented only one of them. The cost of the mistake was a cycle
of evidence gathering that concluded a defect was a specification gap.

The resource cells are the same shape of error in the other direction. The cycle-01 evidence
measured a 77.33 px text budget against `Residents` at 86.00 px — a caption that could not fit
with no value in it at all — and the fix is not a smaller font or an ellipsis but a second line.
UXV-016 requires "a concise label, exact formatted value and explicit unit"; UXV-032 forbids
clipping. Both are satisfiable at 56 px and neither is satisfiable at 36.

## Consequences

- `UiLayout.COUNTER_HEIGHT` is gone. It was one constant doing two jobs: the resource cell is
  now `RESOURCE_CELL_HEIGHT` (56) and the time cluster's control row is `CONTROL_HEIGHT` (36),
  which is what kept "time keeps its existing geometry" from being an accident.
- Six registry rows moved: UI-SET-001 to 128 high, 002..007 to 56, UI-SET-010's maximum to 104
  and UI-SET-011's to 100. Their widths did not move.
- `test_ui_hit_test.gd` samples the world band from `y=120`, which the 128 px resource frame now
  covers at `y=120` and `y=136`. **That file is outside this lane's allowlist and was NOT
  changed**; the stale fixture is reported with the one-line fix.
- Two value formats UI-C3-R01 §2 requires are composed outside this lane's files and are NOT
  implemented: ready-food days has no ` days` unit (`EconomySystem.food_days_text()`) and the
  living population is not `N / 256` (`ui_manager.gd`). They are named in `hud.gd`'s header
  rather than invented in the renderer, which prints what it is given byte for byte.
- The workspace header prints the §4 NAME of the open page, so the roster's header currently
  reads `Resident row` — §4 catalogues UI-SET-069 as a row, not as a page. A page title is not
  invented here; it is a question for §4's owner.
- No 16 px symbolic variant exists for fuel, wood, stone or beds, so those captions take
  ART-UI-05's optical line glyph at 16 px while food and people take their `symbolic16` file.
  No asset was generated.

## Alternatives rejected

- **Raising the HUD above dialogs.** Astra ruled it out in terms, and it would have made a
  genuine modal non-modal to fix an ordinary workspace.
- **Abbreviating a long quantity to K/M, or clipping it.** The ruling forbids both by name. The
  cell either prints the exact figure or names an action that discloses it.
- **Shrinking the numeric face until a long value fits.** UXV-032 forbids reduced font size as a
  fitting strategy, and it would make two counters on one screen disagree about what a digit is.
- **Reducing UI-SET-051's published minimum to 312.** 312 is the answer at ONE viewport, derived
  from `Lh-16-management_top`. Writing it into §4's row would turn a derived number into an
  invented constant.

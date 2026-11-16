# 1891 — The compact Demo party panel and its sheet (PARTY-COMPACT)

Date: 2026-10-12 · Status: Accepted (engineering record of decision 1871 P-B8 (b), ruled by Brendan; its own PROPOSALS
P-PC1 to P-PC5 wait for his ruling)

Number range: 1891–1894, given to this lane by the coordinator; this lane uses 1891 only. It replaces BACKLOG's
"unnumbered" for PARTY-COMPACT.

## Decision

Since slice B the level bar (UI-BUILD-013) stands above the minimap, so the "Demo party" column at 1280x720 is 136
logical px (76 at 125 %; 1871 E12). Where the column is too short for the full panel, the panel now takes a
**compact form** and its inspector moves into a **party sheet** that an "Open" action lays over the world beside the
column:

- `godot/demo/control/demo_party_panel.gd`: the compact form, the choice of form (`fit`, `full_fits`, `compact_rows`)
  and the inspector's move between the column and the sheet.
- `godot/demo/control/party_sheet.gd` (new): the sheet. A CanvasLayer on layer 2 (the demo's modal layer) with a
  click-away catcher, a frame in the thin carving, a head (title, count, ×), the summary and a slot for the inspector.
- `godot/demo/demo_village.gd` registers the sheet as a modal of the demo's input gate.

The three checks slice B relaxed are restored (see "Checks restored").

## Brendan's ruling

Decision 1871, "Brendan's rulings (2026-10-12)", relayed by the coordinator. In chat, using AskUserQuestion, P-B8:
**"Compact panel, next"**. That is P-B8 (b): "give the party panel a compact form for a short column: its header,
summary and actions only, with an 'open' control that lays the inspector over the world beside the column while it
is used". It was to be the follow-up right after slice B merged (BACKLOG PARTY-COMPACT; RULINGS.md 2026-10-12).

### Brendan's rulings (2026-10-12)

In chat via AskUserQuestion, the coordinator asking; each the recommended option:

| Proposals | Ruling |
|---|---|
| P1 what the compact panel shows, P5 the thin frame | **"Approve both"**: as built |
| P2 Pantry-style shaded sheet, P3 its full height, P4 a row click keeps it open | **"Approve all three"**: as built |

## Rules used

- **1871 E12 and P-B8**: the column ends above the level bar; the checks to restore.
- **UI-BUILD-013** and its Geometry (`docs/ui_ux_controls.md`): the level bar's place, `y = Lh − 16 − Mh − 8 − Hb`.
  **UX-BUILD-T01**: no overlap with the level bar. The compact frame ends 8 px above it, and the sheet stands right of
  it.
- **0391**: the frame never hides; F20's count and actions always shown. The undocked state ("the summary and actions
  move to the inspector's top") is replaced wherever the compact form fits, which is every offered size and scale.
- **0801 P8**: "Follow (End)" beside Release (R) whenever anyone is selected. Both are always in view in either form.
- **0791** item 5: Select idle (n) under the party panel's actions, shown with or without a selection. It stays in the
  compact frame's actions.
- **0261 / the input gate** (`demo/ui/demo_input_gate.gd`): a watched modal gets the scrim; world key presses are
  swallowed; Esc closes it one step; focus is trapped, with its close button last; focus goes back on close. The F7
  regions are unchanged.
- **UI §3**: "Closing a modal does not also clear selection in the same key press". A click away, too, only folds.
- **UI §2.1 / UX-T03**: text at least 14 px and buttons at least 32 px, checked live on the frame and the sheet.

## Engineering choices

- **E1. When the compact form is used.** `fit(height)` keeps the full form where the column leaves the inspector
  MIN_INSPECTOR_H (72) or all its content (`full_fits`). This is the old dock rule. Otherwise the panel is compact.
  `full_room` measures the header, the summary line and the actions as the full form lays them out, even while the
  compact form hides some of them. The one part that differs between the forms is the actions' flow, which holds
  Open only in the compact form; Open can only add height. So once compact, the panel stays compact at a column the
  full form would only just fit: a small, stable bias toward compact, never a flip back and forth. At the demo's sizes
  both flows take the same two rows, so the bias never shows.
  - Compact: 1280x720 at 100 % and 125 %, 1920x1080 at 150 %, 2560x1440 at 150 % (logical 1280x720 each).
  - Full: 1920x1080 at 100 % and 125 %, 2560x1440 at 100 % and 125 %.
- **E2. The compact frame fills the column's carved extent.** The full frame's carving draws FRAME_EXPAND (10 px)
  outside its rectangle. The compact frame wears the thin carving (PIECE_PANEL_TIGHT, held inside its rectangle) on
  the column grown by FRAME_EXPAND. So it ends at the same place, 8 px above the level bar, but has 20 px more inside:
  156 px at 100 % and 96 at 125 %. COMPACT_MARGINS (24, 8, 24, 8) keep the content's left edge and width exactly as in
  the full form, so the actions flow wraps the same way in both forms.
- **E3. What the compact frame shows** (`compact_rows`):
  - the actions always;
  - the summary above them where it fits;
  - the title above that where it fits too. The title goes first, then the summary; both are in the sheet's head.
  - Measured: at 100 % on 1280x720 all three fit (138 of 140 px). At 125 % only the actions do (76 of 80).
  - The header's count is hidden in the compact form. It rides on the Open action instead, "Open · 6 selected"
    (`open_caption`), so it is in view at every scale (F20).
- **E4. The actions.** Release (R), Follow (End), the group panel's Select idle row (`add_top_row` now puts another
  owner's row before Open), then Open. They take two rows in 292 px, whether or not the camera follows. No button
  caption was changed.
- **E5. The sheet's place** (`party_sheet.gd placement`), in logical px drawn at S: 8 px right of the column's carved
  frame; 316 wide (the column's content width plus 12 px margins); from the management top to the level bar's foot.
  - At 1280x720: x 364–680, y 152–456 (304 px tall).
  - At 125 %: 208 px tall, and it ends 8 px short of the right column (x 688).
  - It is clear of the resources, time, alerts, minimap, right column, commands, the level bar and the column, at
    every size tested. As a modal it may cover the guide card, an incident card, the Map layer picker, the news strip
    or the ordinary workspace while it is open (P-PC3).
- **E6. The sheet is a modal of the input gate.** `demo_village.gd _left_column` adds the left-column region as before,
  then calls `watch_modal(sheet, sheet.frame(), party.fold_sheet)` and `set_modal_close(sheet, ×)`. While it shows:
  - the gate lays its scrim under it, and world keys wait (B, V, Space, Page Up/Down, checked live);
  - Tab and Shift+Tab stay inside it with × last;
  - Esc folds it and gives the focus back where it was (Open).
  - **A click away:** a clear full-view catcher sits above the gate's scrim and below the frame.
    - A left, right or middle press on it is taken, and its matching release folds the sheet.
    - Godot sends a press's release to the control that took the press, so neither reaches the world. Since the
      review, the fold no longer happens on the press, which let the release fall through to the world.
    - A release with no press, another button's release, the wheel and a move do nothing but stop.
  - The folded sheet hides its frame and catcher as well as its layer. Otherwise the gate's region walk, which does
    not look through a CanvasLayer's own visibility, would offer its × to F7 and Tab.
- **E7. The inspector moves, its focus kept.** `_set_compact` reparents the inspector into the sheet's slot (compact)
  or back to the end of the column (full).
  - A focused row moved where it is still shown keeps its focus, of the same kind: drawn (the keyboard's) or hidden
    (a click's). Both are checked live.
  - One moved into a folded sheet loses it, so no focus is left on a hidden row (checked live).
  - Going back to the full form moves the inspector out first and folds the sheet after. The other order let the
    gate's close take the focus off the row (review LOW c).
- **E8. Opening.** `open_sheet` does nothing in the full form. It does not place the sheet: every `_place` already
  places it, so a second placement on opening was redundant (removed in review, mutant U1).
  - Opened by a click, the inspector shows from its top. The gate's hidden focus on the first control would
    otherwise scroll it down.
  - Opened by the keyboard, the drawn focus on the first control stays in view.
  - The sheet's summary wraps to at most two lines, cut with an ellipsis and whole in its tooltip. For a group the
    whole tally is also in the group panel's "Doing:" line. Without the cap, a nine-resident tally left the inspector
    23 px at 125 %.
- **E9. Picking and Send to….**
  - A member row's pick keeps the sheet open, now on that resident.
  - "Send to…" arms the next world click, so `group_select.gd` also connects it to `fold_sheet`. With the sheet open,
    that click would only have folded it.

## PROPOSALS for Brendan

- **P-PC1. What the compact frame shows** (E3, E4). At 1280x720 it shows the title, the summary and the actions. The
  count is on "Open · 6 selected". At 125 % only the actions show; the title and summary are in the sheet. Options:
  (a) as built; (b) keep the count in the header and drop the summary first; (c) a plain "Open" with the count
  nowhere at 125 %. **Recommend (a)**: the count and Release/Follow stay in view at every scale.
- **P-PC2. The sheet is a full modal** (E6). It has the gate's scrim, world keys wait, and a click away only folds.
  Options: (a) as built; (b) a light pop-over with no scrim, where a click away folds the sheet and also acts on the
  world. **Recommend (a)**: the brief asks that world keys wait, and (b) would let one click both fold and clear the
  selection.
- **P-PC3. How tall the sheet is** (E5). It runs from the column's top to the level bar's foot (304 px at 1280x720,
  208 logical at 125 %). It covers the guide or incident card, the Map layer picker and, at 125 %, part of an open
  build panel while it shows. Options: (a) as built; (b) stop above the build panel's rectangle, which is 144 px at
  125 %. **Recommend (a)**: it is a modal used briefly, and (b) leaves too little at 125 %.
- **P-PC4. A member row's pick keeps the sheet open** (E9). Options: (a) as built, showing the picked resident in
  the sheet; (b) fold on a pick, so the eased camera shows unshaded. **Recommend (a)**.
- **P-PC5. The thin carving for the compact frame and the sheet** (E2). Options: (a) as built, which gains the 20 px
  that let the actions fit at 125 %; (b) the thick carving, where the actions would not fit at 125 % and would
  scroll as before. **Recommend (a)**.

## Checks restored (1871 E12)

- `demo_layout_live.gd`:
  - "at 100 % the actions are always in view" holds at 720 rows too (Release and Follow both). A new "Release and
    Follow always in view" holds at every scale and size.
  - The scroll-reveal checks run at 125 % with no `LIVE-SKIP`. The skip is now the asserted check "reveal: the
    inspector taller than a row", passing with 122 px at 125 %.
- `test_demo_command.gd`: the room check is back to 250 px at 720 rows. The party's room there is the sheet, 304 px.
- Every member row is reachable (in the open sheet where compact): checked at 1, 6 and 9 selected at every scale.

## Shared files touched, and the hook added

- `demo/demo_village.gd`: `_left_column(command)` replaces the one `add_region("left column", …)` line. It adds the
  region and registers the sheet with the gate (`watch_modal`, `set_modal_close`).
- `demo/control/group_select.gd`: one line, `panel.send_pressed.connect(party.fold_sheet)`, and its docstring.
- `demo/control/demo_party_panel.gd`: the form logic. The undocked state (`_dock`, `_docked`) is removed. `docked()`
  now means the full form, and `compact()` is new.
- Tests: `test_demo_command.gd`, `test_demo_group_select.gd`, `test/live/demo_layout_live.gd`,
  `test/live/demo_input_live.gd`; new `test_demo_party_sheet.gd`.
- Three more live harnesses read the inspector at 1280x720, so they open the sheet first through the shared
  `test/live/party_sheet_live.gd` (`SheetLive.open_for`, a real click on Open):
  - `test/live/demo_select_live.gd`: the group section, tiles, crews and Send to…;
  - `test/live/demo_people_live.gd`: the person section and a notable moment; it folds the sheet before the
    spotlight card;
  - `test/live/demo_care_live.gd` (slow tier): the injury and infirmary lines; it folds after reading them.
  The first `--fast` run found the first two; the third was found by searching the harnesses.
- Review round:
  - `scripts/ui/level_bar.gd`: the place order and trimmed labels;
  - `scripts/ui/ui_shell.gd`: `command_icon(id)`, additive;
  - `demo/build_panel/demo_build.gd`: one line in `unlock_build_command`;
  - new `test/live/party_sheet_live.gd`;
  - `test_level_bar.gd` and `test_demo_build_panel.gd`.
- No pinned file (ADR 1212) was touched (`underground_memory_budget.py --check` passes), and no file of the
  TEST-SPEED or ORCHARD-FLAKE lanes.

## Keys

None added. In the sheet:

- Esc folds it (the gate's modal close), as do × and a click away.
- Enter or Space on a keyboard-focused Open opens it.
- Tab and Shift+Tab cycle inside it.
- F7 order is unchanged: world → right column → left column (Open is a stop) → Map layer picker → guide card →
  level bar → world.

## Review round (2026-10-12)

The coordinator's independent review of 06a9d809..17fef19a found nothing CRITICAL or HIGH in this lane. Its full
sharded art-free run at 17fef19a was clean (491 suites, 12348 tests, 0 failures, 0 unexpected diagnostics, 0 leaks).
It asked for two fixes to slice B's leftovers in this column and HUD, and several in this lane. All were fixed on top
of 17fef19a.

- **HIGH (slice B), level bar re-place.**
  - The fault: `level_bar.gd place` set each button's size before its minimum. A re-place to smaller cells kept the
    old size. At 1280x720 from 100 % to 125 %, the buttons stayed 102x44 instead of 78x32; 11 of 15 pairs overlapped
    and the bottom row ran into the minimap.
  - The fix: the minimum is now set first, then the size. The buttons' labels are trimmed, so a word never adds width.
  - Tests: `test_level_bar.gd` places STANDARD, NARROW and STANDARD and requires each button to equal its
    `BuildLayout.level_button_rect`, with no two overlapping. `demo_layout_live.gd` checks at every scale, after each
    scale's re-place, that every level button is inside the bar's `screen_rect()` and none overlaps another. The
    swap-back mutant (L1) is killed live.
  - Frames: `party_check/review/` holds the bar at 1280x720 at 125 % after 100 %, and at 1920x1080 at 150 % after
    125 %.
- **MEDIUM (slice B), the enabled Build command wore the lock.**
  - The fix: `ui_shell.gd command_icon(id)` is a pure wrapper of `_icon_texture_for`. `demo_build.gd
    unlock_build_command` sets the button's icon from it.
  - `test_demo_build_panel.gd` asserts the game's shell keeps the lock and the demo's Build does not. This is
    recorded as a correction in decision 1871 (E21). `ui_shell.gd` is not pinned.
- **MEDIUM, the sheet frame's size reset was untested (U12).** `demo_layout_live.gd _sheet_follows_its_content`
  opens the sheet for the whole cast, one resident and nobody. It requires the frame to be as tall as its content,
  and shorter for nobody.
- **MEDIUM, the mutation record could not be checked.** It now lists every mutant above.
- **LOW a, a click away's release reached the world.** The catcher now takes the press and folds on its matching
  release (E6).
- **LOW b, drawn vs hidden focus across a form change was untested (U18).** It is now checked live, both kinds.
- **LOW c, going back to the full form with the sheet open dropped a keyboard focus.** The inspector now moves first
  and the sheet folds after (E7).
- **LOW d.** E1's "never feeds back" is reworded to what is true: a small, stable bias toward the compact form.
- **LOW e.** `test_demo_command.gd` keeps its column floor (150 px at 720 rows) beside the 250 px sheet check.
- **LOW f.** The three copies of the open-the-sheet helper are now one, `test/live/party_sheet_live.gd`. The select,
  people and care harnesses call `SheetLive.open_for(control, party)`. Their other code is as on master; an earlier
  edit that had left one blank line between functions is gone.

**Second review (ef6561c6): no CRITICAL or HIGH.** It confirmed every first-pass fix by running it: the three live
harnesses lost no function, a click away keeps both press and release from the world (engine probe), `command_icon`
changes nothing in the settlement shell, and the 125 % / 150 % frames are clean. Two LOW items are recorded, not fixed:
- `test_level_bar.gd`'s re-place test cannot see the line order outside the tree (Godot does not clamp `size` there);
  its docstring now says so, and mutant L1 is killed by the live check `_level_buttons_inside`, as the list credits.
- A lone release can still reach the world after a two-button chord over the catcher, or after Esc between a press
  and its release. Harmless today: world selection acts on a left release only after its own press, and placing tools
  act on a press. A future tool that acts on a bare release must swallow it.

## Gates

### Review round (on top of 17fef19a)

- **Focused suites:** test_demo_party_sheet, test_demo_command, test_demo_group_select, test_level_bar,
  test_build_layout, test_demo_build_panel, test_build_panel, test_ui_shell, test_demo_input_gate,
  test_demo_panels_fit, test_demo_camera_modes, and the live wrappers test_demo_layout_live (1280x720, 1920x1080,
  2560x1440), test_demo_input_live (1280x720, 1920x1080), test_demo_select_live, test_demo_people_live,
  test_demo_care_live, test_demo_camera_live and test_demo_guide_live.
  - staged: "421 test(s), 6073 assertion(s), 0 failure(s)";
  - art-free: "421 test(s), 6251 assertion(s), 0 failure(s)";
  - both: "diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0
    object(s), 0 resource(s)" and "log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s),
    0 resource(s)."
- **Live harness runs, staged:**
  - layout: 1280x720 238 0, 1920x1080 306 0;
  - input: 1280x720 290 0;
  - select: 1280x720 60 0;
  - people: 1280x720 36 0;
  - care: 1280x720 37 0.
- **Analyzer** (port 6391): "0 GDScript warning(s) in 0 of 1506 file(s)".
- **Contracts:** `underground_memory_budget.py --check` exit 0 (headroom_bytes 49749393); `ready07_arithmetic.py`
  "status": "PASS"; `decision_numbers.py` "decision_numbers: PASS -- 545 records, 0 problem(s)".
- `--fast` was not rerun in this round; the coordinator runs the full suite.

### Before the review

- **Focused suites, staged**: `./tools/run_tests.sh` with test_demo_party_sheet, test_demo_command,
  test_demo_group_select, test_demo_layout_live, test_demo_input_live, test_demo_input_gate, test_demo_panels_fit and
  test_demo_camera_modes printed:
  - "171 test(s), 2783 assertion(s), 0 failure(s)";
  - "diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0
    object(s), 0 resource(s)";
  - "log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s)."
- **The same, art-free** (godot/demo/assets moved aside): "171 test(s), 2949 assertion(s), 0 failure(s)", with the
  same diagnostics and log lines.
- **Live harnesses, staged** (`LIVE-SUMMARY checks failures`):
  - layout: 1280x720 226 0 (final); 1920x1080 287 0 and 2560x1440 283 0 (before the last mutation checks; the final
    `test_demo_layout_live.gd` run above covers all three sizes);
  - input: 1280x720 290 0, 1920x1080 295 0 (final).
- **Live harnesses, art-free**: layout 1280x720 233 0, 1920x1080 307 0, 2560x1440 307 0; input 1280x720 288 0,
  1920x1080 293 0. These are from the run before the last checks were added. The final art-free numbers are the suite
  line above.
- **Analyzer**: `python3 tools/gdscript_warnings.py --max 0 --port 6391` printed "0 GDScript warning(s) in 0 of 1505
  file(s)".
- **Memory and contracts**:
  - `underground_memory_budget.py --check` exited 0 with headroom_bytes 49749393;
  - `ready07_arithmetic.py` printed "status": "PASS";
  - `decision_numbers.py` printed "decision_numbers: PASS -- 545 records, 0 problem(s)".
- **Other live wrappers** (test_demo_select_live, test_demo_people_live, test_demo_care_live, test_demo_camera_live,
  test_demo_guide_live):
  - staged: "10 test(s), 516 assertion(s), 0 failure(s)";
  - art-free: "10 test(s), 508 assertion(s), 0 failure(s)";
  - both with 0 unexpected diagnostics and 0 leaks.
- **`--fast`**:
  - The first run, at 06a9d809, printed "12198 test(s), 1130651 assertion(s), 2 failure(s)". The failures were
    test_demo_people_live and test_demo_select_live at 1280x720, which read the inspector unopened; they are fixed
    above.
  - The final run, at 28c48f1d, printed:
    - "12198 test(s), 1130658 assertion(s), 0 failure(s)";
    - "diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 278 expected, 310 tolerated; leaked at exit: 0
      object(s), 0 resource(s)";
    - "log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s)."
- **Frames** in the lane's scratchpad `party_check/`:
  - folded `party_{1,6,9}_*` and open `party_open_{1,6,9}_*` at 1280x720 (100 %, 125 %) and 1920x1080 (150 %);
  - folded only at 1920x1080 (100 %, 125 %), where the full form is used;
  - a real click's sheet in `input/party_sheet_open_{1280x720,1920x1080}.png`.

## Mutation testing

Each mutant was run one at a time, and each file was restored with its SHA-256 checked.

- **Unit stage:** `./tools/run_tests.sh` with test_demo_party_sheet, test_demo_command, test_level_bar,
  test_demo_build_panel and test_demo_group_select.
- **Live stage:** survivors of the unit stage were run against `demo_layout_live.gd` and `demo_input_live.gd` at
  1280x720.

**Final list, on the reviewed code:** 63 mutants. The unit suites kill 49 and the live harnesses the other 14.
**SURVIVED_MUTANTS: none.** Line numbers are those of the code these were run on.

- M1 `demo/control/demo_party_panel.gd:769`: `return room >= MIN_INSPECTOR_H or room >= content` to `return room > MIN_INSPECTOR_H or room >= content`. Killed by by test_the_full_form_needs_min_inspector_h_or_all_its_content.
- M2 `demo/control/demo_party_panel.gd:769`: `return room >= MIN_INSPECTOR_H or room >= content` to `return room >= MIN_INSPECTOR_H and room >= content`. Killed by by test_the_full_form_needs_min_inspector_h_or_all_its_content.
- M3 `demo/control/demo_party_panel.gd:769`: `return room >= MIN_INSPECTOR_H or room >= content` to `return room >= MIN_INSPECTOR_H or room > content`. Killed by by test_the_full_form_needs_min_inspector_h_or_all_its_content.
- M4 `demo/control/demo_party_panel.gd:799`: `if inner < need: / return ROWS_ACTIONS` to `if inner <= need: / return ROWS_ACTIONS`. Killed by by test_the_compact_frame_drops_the_title_then_the_summary, test_the_compact_frame_shows_the_rows_its_height_holds.
- M5 `demo/control/demo_party_panel.gd:801`: `inner >= need + SEPARATION + header_h else` to `inner >= need + header_h else`. Killed by by test_the_compact_frame_drops_the_title_then_the_summary, test_the_compact_frame_shows_the_rows_its_height_holds.
- M6 `demo/control/demo_party_panel.gd:801`: `inner >= need + SEPARATION + header_h else` to `inner > need + SEPARATION + header_h else`. Killed by by test_the_compact_frame_drops_the_title_then_the_summary, test_the_compact_frame_shows_the_rows_its_height_holds.
- M7 `demo/control/demo_party_panel.gd:801`: `return ROWS_ALL if inner >= need + SEPARATION + header_h else ROWS_SU...` to `return ROWS_SUMMARY if inner >= need + SEPARATION + header_h else ROW...`. Killed by by test_the_compact_frame_drops_the_title_then_the_summary, test_the_compact_frame_shows_the_rows_its_height_holds.
- M8 `demo/control/demo_party_panel.gd:791`: `_summary_line.visible = rows != ROWS_ACTIONS` to `_summary_line.visible = rows == ROWS_ALL`. Killed by by test_the_compact_frame_shows_the_rows_its_height_holds.
- M9 `demo/control/demo_party_panel.gd:792`: `_header.visible = rows == ROWS_ALL` to `_header.visible = rows != ROWS_ACTIONS`. Killed by by test_the_compact_frame_shows_the_rows_its_height_holds.
- M10 `demo/control/demo_party_panel.gd:788`: `var inner: float = frame_h - COMPACT_MARGINS[1] - COMPACT_MARGINS[3]` to `var inner: float = frame_h - COMPACT_MARGINS[1]`. Killed by by test_the_compact_frame_shows_the_rows_its_height_holds.
- M11 `demo/control/demo_party_panel.gd:762`: `_fit_compact(height + 2.0 * FRAME_EXPAND)` to `_fit_compact(height)`. Killed by live demo_layout_live, "party 1: compact at 100 %, the title and the summary in view too".
- M12 `demo/control/demo_party_panel.gd:714`: `_draw_frame(rect if full else rect.grow(FRAME_EXPAND))` to `_draw_frame(rect)`. Killed by live demo_layout_live, "party 1: compact, the thin carving fills the column's carved extent".
- M13 `demo/control/demo_party_panel.gd:812`: `_count.visible = not on` to `_count.visible = on`. Killed by by test_the_compact_form_moves_the_inspector_to_the_sheet_and_back.
- M14 `demo/control/demo_party_panel.gd:813`: `_open.visible = on` to `_open.visible = true`. Killed by by test_the_compact_form_moves_the_inspector_to_the_sheet_and_back.
- M15 `demo/control/demo_party_panel.gd:818`: `_summary_line.visible = true / _sheet.fold()` to `_summary_line.visible = true`. Killed by by test_the_compact_form_moves_the_inspector_to_the_sheet_and_back.
- M16 `demo/control/demo_party_panel.gd:811`: `_compact_box if on else _full_box` to `_full_box if on else _compact_box`. Killed by by test_the_compact_form_moves_the_inspector_to_the_sheet_and_back.
- M17 `demo/control/demo_party_panel.gd:816`: `if not on: / _header.visible = true` to `if not on:`. Killed by by test_the_compact_form_moves_the_inspector_to_the_sheet_and_back.
- M19 `demo/control/demo_party_panel.gd:830`: `if mine and focused.is_visible_in_tree():` to `if mine:`. Killed by live demo_layout_live, "compact: no focus left on a row in the folded sheet".
- M20 `demo/control/demo_party_panel.gd:847`: `if not _compact: / return / _sheet.open()` to `_sheet.open()`. Killed by by test_only_the_compact_form_opens_the_sheet.
- M21 `demo/control/demo_party_panel.gd:852`: `_inspector.scroll_vertical = 0 /  /  / func fold_sheet` to `pass /  /  / func fold_sheet`. Killed by by test_only_the_compact_form_opens_the_sheet.
- M22 `demo/control/demo_party_panel.gd:851`: `if focused == null or not focused.has_focus(true):` to `if focused == null:`. Killed by live demo_input_live, "and its inspector shown from the top".
- M22b `demo/control/demo_party_panel.gd:851`: `if focused == null or not focused.has_focus(true):` to `if true:`. Killed by live demo_input_live, "the keyboard's focus in view".
- M23 `demo/control/demo_party_panel.gd:437`: `return OPEN_BUTTON if selected == 0 else` to `return OPEN_BUTTON if selected <= 1 else`. Killed by by test_open_carries_the_count.
- M24 `demo/control/demo_party_panel.gd:350`: `_actions.move_child(row, _open.get_index())` to `(removed)`. Killed by by test_the_party_panel_hosts_the_section_after_its_notice_and_the_row_in_its_top.
- M25 `demo/control/demo_party_panel.gd:432`: `_actions.visible = _release.visible or not _extra_rows.is_empty() or ...` to `_actions.visible = _release.visible or not _extra_rows.is_empty()`. Killed by by test_the_actions_show_with_open_alone.
- M27 `demo/control/demo_party_panel.gd:872`: `if _compact: / return _open / return _count` to `return _count`. Killed by by test_the_compact_form_moves_the_inspector_to_the_sheet_and_back.
- M28 `demo/control/demo_party_panel.gd:738`: `return UiLayout.SAFE_INSET + 2.0 * FRAME_EXPAND + WIDTH` to `return UiLayout.SAFE_INSET + FRAME_EXPAND + WIDTH`. Killed by by test_at_125_percent_on_1280x720_the_sheet_keeps_clear_of_the_right_column, test_the_sheet_stands_beside_the_column_down_to_the_level_bar_s_foot.
- M29 `demo/control/demo_party_panel.gd:732`: `_inspector.custom_minimum_size.y = clampf(_inspector_content(), 0.0, ...` to `pass`. Killed by live demo_layout_live, "reveal: the inspector taller than a row".
- M29b `demo/control/demo_party_panel.gd:732`: `_inspector.custom_minimum_size.y = clampf(_inspector_content(), 0.0, ...` to `_inspector.custom_minimum_size.y = _inspector_content()`. Killed by live demo_layout_live, "party 1: Open lays the sheet over the world".
- M30 `demo/control/demo_party_panel.gd:419`: `_sheet.show_words(_count.text, _summary.text)` to `(removed)`. Killed by by test_the_sheet_says_the_count_and_the_whole_summary.
- M31 `demo/control/demo_party_panel.gd:879`: `return -full_room(0.0) - SEPARATION` to `return -full_room(0.0) + SEPARATION`. Killed by by test_fixed_height_is_the_full_form_s_fixed_part.
- M32 `demo/control/demo_party_panel.gd:815`: `_move_inspector(_sheet.slot() if on else _column)` to `_move_inspector(_column)`. Killed by by test_the_compact_form_moves_the_inspector_to_the_sheet_and_back.
- M34 `demo/control/demo_party_panel.gd:776`: `(actions_h + SEPARATION if actions_h > 0.0 else 0.0)` to `(actions_h + SEPARATION)`. Killed by by test_fixed_height_is_the_full_form_s_fixed_part.
- M35 `demo/control/demo_party_panel.gd:831`: `focused.grab_focus(not keyboard)` to `focused.grab_focus()`. Killed by live demo_layout_live, "the full form keeps a hidden row focus".
- M36 `demo/control/demo_party_panel.gd:815`: `_move_inspector(_sheet.slot() if on else _column) / if not on: / _hea...` to `if not on: / _sheet.fold() / _header.visible = true / _summary_line.v...`. Killed by live demo_layout_live, "the full form keeps a hidden row focus".
- S1 `demo/control/party_sheet.gd:182`: `or button == MOUSE_BUTTON_MIDDLE` to `(removed)`. Killed by by test_a_click_away_folds_the_sheet_on_its_release.
- S2 `demo/control/party_sheet.gd:174`: `if click.pressed: / _pressed_away = click.button_index` to `if click.pressed: / fold()`. Killed by by test_a_click_away_folds_the_sheet_on_its_release.
- S3 `demo/control/party_sheet.gd:163`: `_frame.visible = on / visible = on` to `visible = on`. Killed by by test_the_compact_form_moves_the_inspector_to_the_sheet_and_back, test_the_sheet_is_built_folded_on_its_layer.
- S4 `demo/control/party_sheet.gd:162`: `_catcher.visible = on` to `(removed)`. Killed by by test_the_sheet_is_built_folded_on_its_layer.
- S5 `demo/control/party_sheet.gd:238`: `Rect2(column_right + GAP, top,` to `Rect2(column_right, top,`. Killed by by test_the_sheet_stands_beside_the_column_down_to_the_level_bar_s_foot.
- S6 `demo/control/party_sheet.gd:238`: `maxf(bar.end.y - top, 0.0)` to `maxf(bar.position.y - top, 0.0)`. Killed by by test_at_125_percent_on_1280x720_the_sheet_keeps_clear_of_the_right_column, test_panel_placement_keeps_clear_of_the_hud_at_every_size.
- S7 `demo/control/party_sheet.gd:237`: `var top: float = geometry.management_top` to `var top: float = geometry.management_top + 10.0`. Killed by by test_the_sheet_stands_beside_the_column_down_to_the_level_bar_s_foot.
- S8 `demo/control/party_sheet.gd:245`: `+ _summary.get_combined_minimum_size().y + 2.0 * SEPARATION` to `+ _summary.get_combined_minimum_size().y + SEPARATION`. Killed by by test_the_slot_gets_what_the_head_leaves.
- S9 `demo/control/party_sheet.gd:246`: `return maxf(height - used, 0.0)` to `return height - used`. Killed by by test_the_slot_gets_what_the_head_leaves.
- S10 `demo/control/party_sheet.gd:230`: `return inner_width + MARGINS[0] + MARGINS[2]` to `return inner_width + MARGINS[0]`. Killed by by test_the_sheet_stands_beside_the_column_down_to_the_level_bar_s_foot.
- S11 `demo/control/party_sheet.gd:97`: `_close.pressed.connect(fold)` to `(removed)`. Killed by by test_the_sheet_is_built_folded_on_its_layer.
- S12 `demo/control/party_sheet.gd:29`: `const LAYER: int = 2` to `const LAYER: int = 0`. Killed by by test_the_sheet_is_built_folded_on_its_layer.
- S13 `demo/control/party_sheet.gd:193`: `_summary.tooltip_text = summary` to `(removed)`. Killed by by test_the_sheet_says_the_count_and_the_whole_summary.
- S14 `demo/control/party_sheet.gd:102`: `_summary.max_lines_visible = SUMMARY_LINES` to `(removed)`. Killed by by test_the_sheet_says_the_count_and_the_whole_summary.
- S16 `demo/control/party_sheet.gd:68`: `_catcher.mouse_filter = Control.MOUSE_FILTER_STOP` to `_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE`. Killed by by test_a_click_away_folds_the_sheet_on_its_release.
- S17 `demo/control/party_sheet.gd:189`: `if _count.text != count: / _count.text = count` to `(removed)`. Killed by by test_the_sheet_says_the_count_and_the_whole_summary.
- S18 `demo/control/party_sheet.gd:254`: `_frame.size = Vector2(rect.size.x, 0.0)` to `pass`. Killed by live demo_layout_live, "the sheet as tall as its content".
- S19 `demo/control/party_sheet.gd:176`: `elif click.button_index == _pressed_away:` to `elif true:`. Killed by by test_a_click_away_folds_the_sheet_on_its_release.
- S20 `demo/control/party_sheet.gd:150`: `_pressed_away = MOUSE_BUTTON_NONE / _set_shown(false)` to `_set_shown(false)`. Killed by by test_a_click_away_folds_the_sheet_on_its_release.
- S21 `demo/control/party_sheet.gd:172`: `if click == null or not folds_on(click.button_index): / return` to `if click == null: / return`. Killed by by test_a_click_away_folds_the_sheet_on_its_release.
- S22 `demo/control/party_sheet.gd:69`: `_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` to `(removed)`. Killed by live demo_input_live, "a click away folds it".
- V1 `demo/demo_village.gd:1874`: `_gate.watch_modal(party.sheet(), party.sheet().frame(), party.fold_sh...` to `(removed)`. Killed by live demo_layout_live, "party 1: the sheet is the gate's top modal".
- V2 `demo/demo_village.gd:1875`: `_gate.set_modal_close(party.sheet(), party.sheet().close_button())` to `(removed)`. Killed by live demo_input_live, "Close is last in the sheet's Tab order".
- G1 `demo/control/group_select.gd:142`: `panel.send_pressed.connect(party.fold_sheet)` to `(removed)`. Killed by by test_send_to_folds_the_party_sheet.
- L1 `scripts/ui/level_bar.gd:102`: `_buttons[level].custom_minimum_size = cell.size / _buttons[level].siz...` to `_buttons[level].size = cell.size / _buttons[level].custom_minimum_siz...`. Killed by live demo_layout_live, "every level button inside the bar".
- L2 `scripts/ui/level_bar.gd:70`: `button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS` to `(removed)`. Killed by by test_a_re_place_to_smaller_cells_resizes_every_button.
- B1 `demo/build_panel/demo_build.gd:134`: `button.icon = _shell.command_icon(UiShell.ID_BUILD)` to `(removed)`. Killed by by test_the_demo_build_command_opens_and_closes_the_panel.
- B2 `scripts/ui/ui_shell.gd:632`: `return _icon_texture_for(id) /  /  / func _icon_texture_for` to `return load(LOCK_ICON) as Texture2D /  /  / func _icon_texture_for`. Killed by by test_the_demo_build_command_opens_and_closes_the_panel.

**History.**

- **The first pass (06a9d809): 53 mutants.**
  - Four of its survivors were redundant code, which was removed: the `acting` guard in `full_room`, the same-parent
    guard in `_move_inspector`, an explicit `release_focus`, and the catcher's `accept_event`.
  - The other survivors were killed by checks added then.
- **The review's sample (U1–U26) had five survivors.**
  - U1, the redundant `_place_sheet()` in `open_sheet`: removed.
  - U2, the frame's minimum width set again on every place: removed, since the build sets it once.
  - U12, the frame's size reset: killed now by S18 ("the sheet as tall as its content").
  - U18, `grab_focus(not keyboard)`: killed now by M35 ("the full form keeps a hidden row focus").
  - U25, the summary's minimum width: removed. The VBox gives the label its width, and `max_lines_visible` bounds
    its height. `test_the_slot_gets_what_the_head_leaves` still checks a short summary measures one line.
- **The review round also found:**
  - `clip_text` on the level buttons was redundant beside their trimmed overrun, which already keeps the text out of
    the minimum width. It was removed; L2 removes the overrun and is killed.

## Not done here, and why

- The independent review is the coordinator's (brief).
- The full sharded CI-style suite is the coordinator's (brief); this lane ran `--fast`.

## Source

- Brendan's ruling P-B8, "Compact panel, next" (1871, "Brendan's rulings (2026-10-12)").
- BACKLOG PARTY-COMPACT.
- `docs/ui_ux_controls.md` UI-BUILD-013 Geometry and UX-BUILD-T01.
- Decisions 0391, 0791, 0801 and 0261.

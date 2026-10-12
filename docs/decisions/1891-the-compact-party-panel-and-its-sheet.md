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
  `full_room` measures every part as the full form shows it, whatever shows now, so the choice never feeds back on
  itself.
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
  - **A click away:** a clear full-view catcher sits above the gate's scrim and below the frame. A left, right or
    middle press on it folds the sheet. It stops the press (MOUSE_FILTER_STOP), so the click neither selects nor
    orders. The wheel and a move are only stopped.
  - The folded sheet hides its frame and catcher as well as its layer. Otherwise the gate's region walk, which does
    not look through a CanvasLayer's own visibility, would offer its × to F7 and Tab.
- **E7. The inspector moves, its focus kept.** `_set_compact` reparents the inspector into the sheet's slot (compact)
  or back to the end of the column (full).
  - A focused row moved where it is still shown keeps its focus.
  - One moved into a folded sheet loses it, so no focus is left on a hidden row (checked live).
  - Going back to the full form folds the sheet.
- **E8. Opening.** `open_sheet` does nothing in the full form.
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
- Three more live harnesses read the inspector at 1280x720, so each gained `_open_sheet_for(control)`. Their
  `_reveal`, and the steps that read a row first, click Open where the control is in the folded sheet:
  - `test/live/demo_select_live.gd`: the group section, tiles, crews and Send to…;
  - `test/live/demo_people_live.gd`: the person section and a notable moment; it folds the sheet before the
    spotlight card;
  - `test/live/demo_care_live.gd` (slow tier): the injury and infirmary lines; it folds after reading them.
  The first `--fast` run found the first two; the third was found by searching the harnesses.
- No pinned file (ADR 1212) was touched, and no file of the TEST-SPEED or ORCHARD-FLAKE lanes.

## Keys

None added. In the sheet:

- Esc folds it (the gate's modal close), as do × and a click away.
- Enter or Space on a keyboard-focused Open opens it.
- Tab and Shift+Tab cycle inside it.
- F7 order is unchanged: world → right column → left column (Open is a stop) → Map layer picker → guide card →
  level bar → world.

## Gates

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

Mutants were run one at a time and each file was restored (SHA-256 checked). They covered the form choice and its
bounds, the compact rows, the margins and carving, Open's visibility and words, the count's place, the inspector's move
and focus, the open-scroll rule, the sheet's placement, slot room, layer, folding, catcher and tooltip, the gate
registration and the Send-to hook.

- **First pass: 53 mutants.**
  - The unit suites killed 37; the live harnesses at 1280x720 killed 4 more (M19 focus, M29 slot clamp, V1
    watch_modal, V2 Close last).
  - 12 survived. Four were redundant code, which was removed: the `acting` guard in `full_room`, the same-parent guard
    in `_move_inspector`, an explicit `release_focus`, and the catcher's `accept_event` under MOUSE_FILTER_STOP.
  - The other eight were killed by checks added for them: the compact rows on the real nodes, Open hidden again in the
    full form, `fixed_height`, the thin carving filling the carved extent, the title and summary at 100 %, and a
    click-opened sheet starting at its top.
- **Final list: 50 mutants (one added, M34), all killed.**
- **SURVIVED_MUTANTS: none.**

## Not done here, and why

- The independent review is the coordinator's (brief).
- The full sharded CI-style suite is the coordinator's (brief); this lane ran `--fast`.

## Source

- Brendan's ruling P-B8, "Compact panel, next" (1871, "Brendan's rulings (2026-10-12)").
- BACKLOG PARTY-COMPACT.
- `docs/ui_ux_controls.md` UI-BUILD-013 Geometry and UX-BUILD-T01.
- Decisions 0391, 0791, 0801 and 0261.

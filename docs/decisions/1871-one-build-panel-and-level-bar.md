# 1871 — Slice B: one build panel and the level bar

Date: 2026-10-12 · Status: Accepted (engineering record of DEC-061's slice B; the PROPOSALS below await Brendan)

Number range: 1871–1879 was allocated to this lane by the coordinator. This lane uses 1871 only. It replaces no
BACKLOG range. A separate lane records the slice's memory budget (decision 1880).

## Decision

The game now has the build panel and the level bar that DEC-061 Q1 asks for. They are UI-BUILD-001–014 in
`docs/ui_ux_controls.md` and are written as game UI in `godot/scripts/ui/`:

- `build_panel.gd`: the panel;
- `level_bar.gd`: the level bar;
- `build_batch.gd`: the one pending batch;
- `build_ledger.gd`: the ledger's arithmetic;
- `build_validity.gd`: the validity glyphs and words;
- `build_catalog.gd`: the cards;
- `build_layout.gd`: the geometry.

The rows are registered in `ui_registry.gd` as their own family. The live demo mounts the panel and the bar
(`godot/demo/build_panel/`). B opens the panel, and it replaces the four old entry points. Room types are painted on the
1 m grid into one batch built on the modular planner's draft. Confirm all sends each room through the planner's
existing order route. PageUp and PageDown change level everywhere. Keyboard zoom is now on = and −.

## Brendan's rulings (2026-10-12)

Relayed by the coordinator. On 2026-10-12, in chat, using AskUserQuestion, Brendan chose the recommended option for
each of the four questions:

1. **Memory and catalog scope: "Budget now, rest later".** The memory budget is the other lane's (decision 1880).
   This slice adds no room types or items, changes no save format and edits no pinned file.
2. **Confirm all: "Order through planner".** In his words: "Room types are painted into the one pending batch on the 1 m grid,
   using the modular planner's draft and undo. Confirm all orders them through the planner's existing route, the same
   one 'Plan an underground room' uses today. The Passage, Burrow home and Root cellar cards open the old tunnel and
   template tools, with their own confirm, until slice C replaces them."
3. **Old buttons: "Replace with the panel".** In his words: "Remove all four buttons. B opens the build panel, and the old tools are
   reached only from its cards. H and C stop opening room templates (H keeps its game binding, Harvest). The demo's
   tests and live harnesses are updated to go through the panel."
4. **Where it lives: "Game UI, demo mounts it".** In his words: "The panel and level bar are game UI code (scripts/ui) registered as
   UI-BUILD-001–014 in ui_registry.gd. The demo mounts them. The settlement game's own Build button stays disabled
   until slice G gives it surface rooms to build."

Earlier, decision 1851 OPEN-09 was ruled (a): PageUp and PageDown change level, and keyboard zoom moves to = and −.

## Rules used

- **UI-BUILD-001–014.** The Registry, Geometry, "Input in build mode", "Validity in words" and Acceptance sections
  of `docs/ui_ux_controls.md` (UX-BUILD-T01, T02 as far as slice B goes, T03, T04, T05). Also §5's `level_up`,
  `level_down`, `camera_zoom_in/out` and `tool_redo` rows, and UI-MOVE-001's amended level selection.
- **SET-BUILD-001.**
  - BUILD-REQ-002: the 2 × 2 rule.
  - BUILD-REQ-004: a stroke grows the room it touches.
  - BUILD-REQ-005: no repainting over another type.
  - BUILD-REQ-013: the "No way in" words.
  - BUILD-REQ-019: Confirm all deducts nothing.
  - BUILD-REQ-020: Undo and Redo touch only pending operations.
  - BUILD-REQ-021: an invalid operation disables Confirm all.
  - §3 (the cell and the size label), §4 (least cells) and §7.2 (a cell's cost).
- **BAL-ROOM-001.** An underground cell costs wood 1000, stone 1000, work 16920 milli-WU and earth 8000 milli-U.
  These are read from `excavation_contract.gd` and the level's clear height, never restated.
- **ADRs 1052 and 1055.** The canonical footprint and the planner's 32-step draft history.
- **DEC-049.** Natural measures, through `goods_measures.gd`.
- **GDD §4.1.** One WU is one game minute.

## Engineering choices

- **E1. The registry rows are a family of their own.** `ELEMENT_COUNT` stays 103.
  - The shell, its availability table, its focus order and many suites size or loop by that count. A UI-BUILD row is
    not a UI-SET row.
  - The family has its own columns (`BUILD_*`), its own count, its own contract asserts and its own keys
    (`build_element_key` → "UI-BUILD-nnn").
  - Two rows have no fixed rectangle, and say so the way UI-SET-054 does. UI-BUILD-010 is "Painted cell set": the new
    size kind `SIZE_PAINTED_CELLS`. UI-BUILD-011 is "Footprint + access tiles": `SIZE_FOOTPRINT`.
  - UI-BUILD-005's expanded size and the UI-SET-066/067 instances of 008/009 are separate constants.
  - `test_ui_registry.gd` quotes all fourteen rows by hand.
- **E2. The batch is built on the planner's draft.**
  - **The draft accepts the 1 m grid.** Each operation is one `modular_draft.gd` session: one room type on one level,
    at pitch 1024 u. The draft accepts it, because 2048 % 1024 == 0.
  - **The rest of the planner accepts it too, checked against the actual owners.**
    - `modular_runtime.gd` pins whatever pitch the draft has.
    - `RoomOrders` takes the plan's `cell_size_u` from it.
    - `test_demo_build_orders.gd` sends a 6 × 4 Kitchen at 1024 u through the runtime to the admission fixture's real
      RoomOrders. It reached room preflight once and was refused for its missing approach (`REFUSE_ENTRY`). No owner
      changed.
    - The planner's own view still uses its 0.25 m grid (GRID_U 256), unchanged.
  - **How a stroke joins the batch.** A rectangle is previewed on a scratch draft. On release it is replayed onto the
    operation it touches, or onto a new one. "Touches" means the same type on the same level, overlapping or sharing
    an edge (BUILD-REQ-004).
  - **Undo and Redo.** The batch-wide history is a stack of operation indices, at most 32 (ADR 1055). An undo pops
    one index and undoes that operation's own draft.
  - **Emptied operations.** One stays in place while its history can reach it, and is then dropped.
- **E3. What happens to a stroke on release.**
  - A stroke that is never valid there ("X") is dropped, and its words are said. That covers a strip one cell wide, a
    stroke past the planning area, one over another type, and one joining two planned rooms.
  - A room that is valid there but not ready ("!") stays in the batch and holds Confirm all back. That covers "too
    small", a planner shape refusal, and the planner route's last refusal (until the room changes).
  - This follows the section's glyph semantics: ! is fixable, X is never valid here.
- **E4. Words.** `build_validity.gd` holds the fifteen canonical reasons word for word, each with its glyph and
  token. Four reasons were added: see PROPOSAL P-B2.
- **E5. The ledger reads the settlement's stores.** "Stores hold" reads `EconomySystem.stock_milli`, the stores that
  will pay. The planner's toolbar reads them too (decision 1801). It does not read the demo village's legacy stores.
- **E6. The order route** (`demo/build_panel/demo_build_orders.gd`).
  - For each valid operation it binds that operation's own draft to a fresh, off-tree planner editor and world tool on
    the actual level floor. It composes a `modular_runtime.gd` over the settlement's RoomOrders, room bindings and
    level catalog, exactly as `modular_room_mode.gd` does.
  - It calls the runtime's `check_request` and then `submit_request`. The temporary nodes are freed before it returns.
  - Nothing is deducted, and no access endpoint is invented.
  - Live, the route refused a room under the village with RoomOrders' own words: "This room would intersect
    protected water." With no passage it says "Connect a completed passage …". The room stays in the batch with that
    reason.
- **E7. The painting frame.**
  - Cells are world metres in the frame the planner and the entry worker already share. Cell (0, 0) is at the actual
    space domain's datum.
  - So the planning area is the level pack's 0..256 m square. Under the demo village (±20 m) that is only its
    south-east quadrant (see P-B5).
  - Picking and the ghosts use the legacy floor the U view shows. A cell is a column, so the order route places the
    same cells on the actual level's floor.
- **E8. The levels in the demo.**
  - **Surface** is the U view off. **Level 1 and Level 2** are the U view on that legacy level. The warren's 4 m
    spacing is the demo's; DEC-061's 5 m spacing is slices C and D's work.
  - **Levels 3 and 4** read "no way in yet". Selected, the U view draws nothing (`tunnel_view.gd set_unreached`), and
    the room cards say BUILD-REQ-013's words.
  - **Overview** is the surface view with painting off (see P-B4).
  - U still toggles the view, and the bar follows it. The selection is untouched by any of this (UX-BUILD-T05, tested).
- **E9. Level keys are read before the HUD, everywhere.** This is how the U view's level keys were already read,
  through demo_command's `_input` hook. They are never taken behind a modal or the stall banner. At an end the bar
  says the canonical "X Not possible: No level above the surface" or "No level below level 4".
- **E10. The arrow keys.** The section says "Arrows move the cell cursor" and also "WASD and arrows outside the card
  row still pan". Read together: the arrows move the cell cursor only while a room type is armed and the world has
  the keys. Otherwise they pan, and WASD always pans. Up is −Z, world-aligned (see P-B10).
- **E11. What the panel hides while it is open.**
  - The section names UI-SET-026 and the BR detail. In the demo the BR detail is the shell's UI-SET-036 together
    with the demo's right column (its four panels and the orchard's).
  - The Map layer picker and the news strip stand where the panel goes, so they are hidden too.
  - Each is recorded when the panel opens and given back when it closes, or while an old tool runs. The command keys
    of a hidden strip do nothing while it is hidden (`handle_command_key`'s own rule).
- **E12. The party panel's column ends above the level bar.** The bar is always shown above the minimap, and
  UX-BUILD-T01 forbids overlap.
  - At 1280×720 this shortens the "Demo party" column from about 284 to 156 logical px. At 125 % it is about 76 px.
  - At 1280×720 the summary and actions then sit at the inspector's top and are reached by scrolling. This is decision
    0391's undocked state, which before was reached only at 125 %. At 125 % the inspector is shorter than one member
    row.
  - The checks were changed to match:
    - `test_demo_command.gd`'s room check is 150 px at 720 rows and 250 px above that.
    - `demo_layout_live.gd`'s "at 100 % the actions are always in view" now applies above 720 rows.
    - Its scroll-reveal checks are skipped where the inspector is shorter than a row. Every member row is still
      checked reachable.
  - This is a real loss in the demo at 1280×720: see P-B8.
- **E13. The old tools are sub-modes of the panel.** A Passage, Burrow home or Root cellar card hides the panel. The
  demo's surfaces come back so the old tools' own panels show. The tool opens, and the panel returns when it closes.
  B in the tool still closes the tool (its own key).
- **E14. The top-centre level indicator is trimmed, not retired.** It now reads "Underground · Level 1 (floor 1.25 m
  down)". The "of 2" and the key hint are gone, because they contradicted the bar's four levels.
- **E15. The planner's separate view stays mounted, with no entry.** That is `modular_demo_mode.gd` with its
  GuardedRig. Its harness opens it directly; its check count is unchanged at 64 (see P-B7).
- **E16. Closing the panel.** Closing forgets the chosen card and the tab. The batch is kept or discarded by the
  question. Both questions ("Keep N pending changes?" and "Discard N pending changes?") stand in the footer's place,
  not in a modal.
- **E17. The build panel is a planning surface** for the "Pause while planning" setting, as the Dig tool is.
- **E18. The expanded ledger grows upward from the footer, over the panel's upper rows.** It is 320 × 160 at
  STANDARD and NARROW, and up to 640 wide at WIDE. Placed above the panel it would cover the guide card at 1280×720.
- **E19. The party panel's tool buttons and their action cards are gone.** Those cards said who would dig and what
  they would stop. The Dig tool's own readout and `tool_card_into` remain (test kept).
- **E20. A card's picture is a described placeholder** ("Picture (placeholder): …"). No room art exists (see P-B6).
- **E21. UI-SET-027 stays locked**, as ruling 4 says. Its demo tooltip now says "In the demo, B opens the build panel:
  …" (`demo_command_tips.gd`).
- **E22. The ghost's states.** Valid, blocked and impossible each tint the outline with their own §2.1 token, and
  each carries a tag with its glyph and type. The section's dashed (blocked) and hatched, numbered (impossible)
  outlines are not drawn yet. The words carry the state, so UX-BUILD-T03 holds.

## PROPOSALS for Brendan

- **P-B1. Locked cards for later slices.** These cards stay visible and inspectable, marked "! Blocked":
  - Furnish and Decor items: "Not yet: furnishing comes in a later update".
  - Outdoor, Clear ground, Earth and Remove: "Not yet: …".
  - Surface room types: "Not yet: rooms on the surface come in a later update".

  Options: (a) as built; (b) hide later-slice cards until their slice lands. **Recommend (a).** The section says
  locked cards stay inspectable, and the words say when.
- **P-B2. Reasons the section's table does not hold.** All are in `build_validity.gd`:
  - X "Outside the planning area: keep the whole room inside it";
  - ! "Shape: …", the planner's own shape refusals in plain words;
  - X "Joins two planned rooms: undo one of them first";
  - "Choose one level to paint on: Overview shows them all".

  Options: (a) adopt them as worded; (b) for the joining case, merge the two pending rooms in the batch instead,
  which is OPEN-06's merge applied before confirmation. **Recommend (a) now, and (b) with slice C**, where confirmed
  rooms merge.
- **P-B3. UI-SET-027 (Build) in the demo.** Options: (a) keep it locked, as ruling 4 is read (built); (b) enable it in
  the demo only, so a click opens the panel as the section says ("B or UI-SET-027"). **Recommend (b).** The settlement
  game's button stays locked either way.
- **P-B4. Overview.** The demo has no all-levels view. Options: (a) the surface view with painting off (built); (b) the
  U view of level 1 with painting off; (c) a real multi-level overview, later. **Recommend (a) now and (c) later.**
- **P-B5. The planning area under the demo village.** The actual underground is the level pack's 0..256 m square, and
  the village spans ±20 m, so only its south-east quadrant can be painted. Options: (a) keep the frame the planner
  and entry worker share (built); (b) offset the build panel's cells so the village's centre lands on the actual
  settlement's hall cell (116, 118). **Recommend (a)** until slice C moves the demo onto the actual World. (b) adds an
  offset no document states.
- **P-B6. Card pictures.** Options: (a) keep the described placeholders; (b) commission room and item art (paid
  generation needs an itemised, costed list first). **Recommend (a)** until slice G's surface rooms settle the set.
- **P-B7. The planner's separate view** (`modular_demo_mode.gd`, no entry now). Options: (a) retire it in slice C, when
  the panel paints the actual World; (b) keep it as an inspection view. **Recommend (a).**
- **P-B8. The shorter party column** (E12). At 1280×720 the actions scroll, and at 125 % the inspector is shorter
  than a row. Options:
  - (a) accept it, as built;
  - (b) give the party panel a compact form for a short column: its header, summary and actions only, with an "open"
    control that lays the inspector over the world beside the column while it is used;
  - (c) move the demo's party panel out of the left column, for example under the right column's tabs.

  **Recommend (b).** It keeps the level bar where the spec puts it, and keeps the party usable at 1280×720.
- **P-B9. The ghost's dashed and hatched outlines** (E22). Options: (a) add them in slice C with its per-cell validity;
  (b) now. **Recommend (a).**
- **P-B10. The keyboard cell cursor's directions** (E10). Options: (a) world-aligned, Up is −Z (built); (b) screen-relative,
  following the camera's yaw. **Recommend (b), in slice C.**

## Keys

- **Changed.**
  - `camera_zoom_in`: = and keypad +, plus the wheel. It was PageUp and the wheel.
  - `camera_zoom_out`: − and keypad −, plus the wheel. It was PageDown and the wheel.
  - `camera_pitch_up` and `camera_pitch_down` stay Alt+PageUp and Alt+PageDown.
- **Added.**
  - `level_up`: PageUp.
  - `level_down`: PageDown.
  - `tool_redo`: Ctrl+Shift+Z, Ctrl+Y and Cmd+Shift+Z. §5 names it, and `test_input_map.gd`'s SPEC_ACTIONS lacked it.
- **In the demo.**
  - B now opens the build panel; in the Dig tool, B still closes the tool.
  - H and C no longer open or switch room templates, outside the tool or in it. H stays the game's `open_harvest`.
  - The Dig tool's own keys are unchanged: Enter, Backspace, Esc, R, L and U.
  - With the panel open:
    - Esc steps back one layer;
    - Ctrl+Tab and Ctrl+Shift+Tab change tab;
    - Ctrl+Z undoes; Ctrl+Shift+Z or Ctrl+Y redoes;
    - the arrows move the cell cursor while a room type is armed (E10);
    - Enter sets the corners while the world has the keys.
- **Shadow pairs.** In `test_input_map.gd`, `camera_zoom_*|camera_pitch_*` became `level_*|camera_pitch_*`. Two pairs
  were added: `tool_undo|tool_redo` and `open_zones|tool_redo`.

## Shared files touched, and the hook added

- `godot/project.godot`: the input map, as above.
- `scripts/ui/ui_registry.gd`: the UI-BUILD family and `SIZE_PAINTED_CELLS`. Additive.
- `demo/control/demo_command.gd`: `set_build_hooks(before_gui, handle)`, asked first in `take_before_gui` and
  `handle_input`. The party panel's dig and room wiring and `_refresh_tool_cards` were removed.
- `demo/control/demo_party_panel.gd`: the dig and room buttons and signals removed. The column ends above the level
  bar.
- `demo/tunnel/tunnel_control.gd`: B outside the tool, and H and C everywhere, removed. The words were updated.
- `demo/tunnel/tunnel_view.gd`: `set_unreached` and the `unreached` flag; the indicator's words trimmed.
- `demo/tunnel/tunnel_panel.gd`: the "Plan an underground room" button and its action removed.
- `demo/demo_village.gd`:
  - `_build_build_panel` mounts the panel, the bar and the hooks, a "build panel" focus region and a planning surface;
  - `build()` returns it;
  - the help's Dig action opens the panel;
  - the planner's button wiring was removed.
- `demo/playtest/playtest_taps.gd`: build-panel probes replace the dig and room crumbs.
- `demo/camera/demo_camera.gd`: comment only.
- Words only:
  - `demo/ui/demo_command_tips.gd`;
  - `demo/guide/help_topics.gd`, `guide_text.gd` and `field_guide.gd`;
  - `demo/farm/farm_card.gd`;
  - `demo/control/resident_abilities.gd`.
- `demo/burrow/modular_demo_live.gd`: opens the planner's view directly.

No pinned file was touched. Neither `ui_manager.gd` nor any `scripts/core` file changed.

## Gates

Every line below is quoted from the run, never taken from an exit status.

- **`./tools/run_tests.sh --fast`.**
  - The run printed: `12146 test(s), 1129975 assertion(s), 2 failure(s)` and `diagnostics: 0 unexpected error(s), 0
    unexpected warning(s), 278 expected, 310 tolerated; leaked at exit: 0 object(s), 0 resource(s)`.
  - The two failures were this slice's own:
    - `test_demo_earth.gd` quoted the old "Dig tunnel (B)" fix words;
    - `test_demo_layout_live.gd` hit the shorter party column at 1280×720 (E12).
  - Both were fixed and re-run in the focused run below.
- **Focused run of every touched suite.** That is 28 suites, the live wrappers included (`test_demo_input_live`,
  `test_demo_layout_live`, `test_demo_guide_live`, `test_modular_demo_live`). It printed: `812 test(s), 69073
  assertion(s), 0 failure(s)`, `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 3 expected, 249
  tolerated; leaked at exit: 0 object(s), 0 resource(s)` and `log: 0 unexpected error(s), 0 unexpected warning(s);
  leaked at exit: 0 object(s), 0 resource(s).`
- **Live input harness.** `LIVE-SUMMARY 243 0` at 1280×720 and `LIVE-SUMMARY 251 0` at 1920×1080. Both include the
  build steps:
  - B, the Rooms tab, UX-BUILD-T01 rectangles with the minimap shown and hidden, PageDown to level 1;
  - the keyboard's F7, Tab and Enter onto a card, Enter, the arrows and Enter painting a room;
  - Ctrl+Z and Ctrl+Shift+Z, the expanded ledger, a Confirm all refused in words, Overview by click, and B → Keep.
- **`python3 tools/gdscript_warnings.py --max 0 --port 6383`.** It printed `0 GDScript warning(s) in 0 of 1503
  file(s)`.
- **Contract checks.**
  - `underground_memory_budget.py --check`: PASS.
  - `ready07_arithmetic.py`: `"status": "PASS"`.
  - `decision_numbers.py`: PASS.
  - `merge_gate.py`, `lane_notes.py --check`, `dispatch_plan.py --validate`, `astra_inbox.py --check`,
    `generate_canonical_state_table.py --check`, `state_registry_coverage.py`, `ui_refinement_contract.py` and
    `setting_contract.py`: all PASS.

## Mutation testing

There were 42 mutants, one per run (operator, constant or branch): each mutant was applied, its focused suite run,
and the source restored. They covered:
- the batch: 14;
- the ledger: 6;
- the validity words: 3;
- the level bar: 4;
- the geometry: 6;
- the catalog: 3;
- the panel: 3;
- the demo mount: 3.

**41 were killed and 1 survived.**
- The first pass left 4 survivors. 3 were real gaps, and each now has a test that kills it:
  - a 1-cell-wide stroke along x;
  - a stroke over its own room counting the union once;
  - the footer's minimum widths between 0 and 120 px of ledger.
- The one left is equivalent: SURVIVED_MUTANTS `D2`. Removing `_special >= 0` from `demo_build.gd armed_type()` changes
  nothing that can be observed:
  - on Overview the U view is off, which already disarms painting;
  - on Levels 3–4 the room cards are locked, so no type is armed.
  The guard is kept as a statement of the rule.

## Not done here, and why

- **The memory budget and ARCH-BUILD-001's obligations.** These belong to the other lane under ruling 1.
- **Furnishing, item ghosts (UI-BUILD-011), connectors and the connector card (UI-BUILD-012), Earth, Clear ground
  and Remove.** These are slices C–G. Their cards are locked, saying so.
- **Surface painting.** This is slice G.
- **Painting on the settlement's actual World.** The demo still shows the legacy warren (slice C).
- **"No way in" judged per cell before confirmation.** This is slice C. Today the planner route says it at Confirm
  all.

## Source

- DEC-061.
- SET-BUILD-001; decision 1851 with its OPEN-09 ruling.
- `docs/ui_ux_controls.md` UI-BUILD-001 and §5.
- ADRs 1052 and 1055.
- BAL-ROOM-001; `godot/scripts/core/excavation_contract.gd`.
- `godot/data/underground/initial_level_pack.json`.
- Brendan's rulings of 2026-10-12, as relayed above.

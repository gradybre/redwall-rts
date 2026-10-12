# 1871 — Slice B: one build panel and the level bar

Date: 2026-10-12 · Status: Accepted (engineering record of DEC-061's slice B; Brendan ruled on every PROPOSAL on
2026-10-12, recorded below)

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

**The PROPOSALS (P-B1 to P-B11).** Relayed by the coordinator. On 2026-10-12, in chat, using AskUserQuestion, Brendan
answered four questions, each as recommended:

| Question | His answer | What it rules |
|---|---|---|
| P-B1, P-B6, P-B11 | "Approve all three" | P-B1 (a): later slices' cards stay visible, locked, saying when. P-B6 (a): the described placeholder pictures stay. P-B11 (a): no room can be ordered from the panel until slices C/D add the way in |
| P-B3, P-B2, P-B4 | "Approve all three" | P-B3 (b): in the demo, the Build command (UI-SET-027) opens the panel, built here (E21); the settlement game keeps it locked. P-B2 (a): the added reasons as worded, with the merge of joined rooms in slice C. P-B4 (a): Overview is the surface view now, a real all-levels view later |
| P-B5, P-B7, P-B9, P-B10 | "Approve all four" | P-B5 (a): the paint area keeps the planner's frame until slice C. P-B7 (a): the old planner view retires in slice C. P-B9 (a): the dashed and hatched outlines come in slice C. P-B10 (b): a camera-relative cell cursor, in slice C |
| P-B8 | "Compact panel, next" | P-B8 (b): a compact Demo party panel with an "open" overlay, as the follow-up right after slice B merges (BACKLOG PARTY-COMPACT) |

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
    small" and a planner shape refusal (a hole or a pinch), judged on the room's whole union while the stroke is
    still drawn, so a closing stroke never reads ✓.
  - A stroke that adds no new cell to its room (painted wholly inside it) is dropped as X "Nothing to add: these cells
    are already planned for this room". It records no Undo step (review H1).
  - A stroke whose union with its room would pass the room's most cells is X, in the planner's capacity words, and is
    dropped the same way. A stroke the planner's draft refuses on finish is dropped with its words, never recorded.
  - The planner route's last refusal is kept on the room until it changes. See E6 for how it counts.
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
  - **Corrected (review H3).** The first version of this entry said the missing-approach refusal goes away once a
    passage is dug. It does not: RoomOrders asks for a prospective entry contact bound to the room, and nothing a
    player can do from the panel or the Dig tool makes one. So no room can be ordered from the panel in this slice.
    That is P-B11.
  - **The coordinator's resolution of review H3** (relayed 2026-10-12). The route is kept, and `classify` maps its
    answers into the panel's words and kinds:
    - `PROSPECTIVE_ENTRY_CONTACT_UNBOUND` (no approach) is "! Blocked: No way in: connect to a finished Passage or
      entrance; the way in from the build panel comes in a later update".
    - Protected water, a paid cut, protected ground above and required footing are X "Cannot dig here: water" /
      "occupied" / "protected ground". They can never succeed on that site, so they hold Confirm all back.
    - **Second review.** The terrain survey's protected resources, foundations and building sites, and ground that
      is not natural dry solid (`underground_terrain.gd` REFUSE_RESOURCE, REFUSE_FOUNDATION, REFUSE_BODY and
      REFUSE_DRY), are X "Cannot dig here: protected ground" too. The first round missed them: they fell to the
      runtime's catch-all "This site is not ready for that room …", read "!" and were retried for ever, and most
      sites under the demo village give one of them. `NEVER_HERE` names the owners' constants. A test walks every
      `underground_terrain.gd` REFUSE_* code through `classify`. The survey's binding, bounds, capacity and
      open-exterior codes are not the site's, so they keep the runtime's words as "!".
    - Any other refusal keeps the runtime's own words as "! Blocked".
  - A "!" route refusal does not count as invalid. It stays "! Blocked", the status line says "! Refused last time,
    Confirm all tries again: …", and the next Confirm all retries it. Shape, size and overlap judgements still disable
    Confirm all. `build_batch.gd retryable()` holds the rule: the room is unchanged since the refusal, and the
    refusal was "!".
  - Live, the route refused the harness's Kitchen under the village as X "Cannot dig here: water".
  - **Corrected (second review).** The first round's six live rooms at x 40–85, z 40–43 were refused
    TERRAIN_RESOURCE_PROTECTED. They read "! … not ready for that room" because of the gap above, not because the
    route judged them fixable. The live step now paints six rooms on open ground at x 100–145, z 100–103. Each is
    refused PROSPECTIVE_ENTRY_CONTACT_UNBOUND, and the harness checks every one reads the canonical "! Blocked: No
    way in: …; the way in from the build panel comes in a later update", with Confirm all still enabled.
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
  - **Review M1.** The Dig tool's own level-key branch read PgUp/PgDn before the gate while the U view was on, so
    they changed level behind the Pantry. It is removed from `tunnel_control.gd`. The build hook alone reads the
    keys. The live harness now checks PgUp/PgDn behind the Pantry with the U view on.
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
      checked reachable. The skip prints a `LIVE-SKIP` line and asserts nothing (review M6). The column measured
      156 logical px at 1280×720 against `test_demo_command.gd`'s 150 px threshold, which is kept.
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
- **E18. The expanded ledger stands inside the panel, from its top edge down to 8 px above the footer** (review H2
  and M3). It is 192 high, 320 wide at STANDARD and NARROW and 640 at WIDE, never wider than the footer.
  - Its words sit in a ScrollContainer, so any number of operations scroll inside it.
  - It never rises above the panel, so it is clear of the alerts at every profile.
  - **M3 choice: it covers the tab row whole.** The first version started it part-way down and cut the tabs in half.
    Covering keeps the panel's layout still.
  - **Corrected (second review).** Covering alone was not enough: the Decor tab's strip beside the ledger (x 332–388
    at 1280×720) was still clickable, and at WIDE the status words' tail showed beside it. While the ledger is
    expanded, the three tabs and the where/status words are now hidden. They come back when it folds, when an old
    tool's card suspends the panel, and when the panel closes (`build_panel.gd _show_ledger`).
  - Placed above the panel it would cover the guide card at 1280×720.
- **E19. The party panel's tool buttons and their action cards are gone.** Those cards said who would dig and what
  they would stop. That information now shows on the Passage, Burrow home and Root cellar cards (review M8): the
  panel's `card_note` hook asks `demo_build.gd`, which fills `tool_card_into` and the work interrupt words. It is
  added to the info card and the card's tooltip.
- **E20. A card's picture is a described placeholder** ("Picture (placeholder): …"). No room art exists (see P-B6).
- **E21. In the demo the Build command opens the panel** (P-B3, approved 2026-10-12).
  - `demo_build.gd unlock_build_command` enables the shell's UI-SET-027 in the demo only. It writes its own tip,
    "Build (B) — Open the build panel: paint rooms underground, or open the Passage and burrow tools", and connects
    its press to what B does: open the panel, ask before closing with changes, and in the Dig tool close the tool.
  - Enabled, Build's key is the shell's (its `_unhandled_key_input` runs before demo_command's), so B reaches the
    panel through the same press. While the panel shows, the command strip is hidden, and B reaches the panel through
    the build hook as before.
  - The settlement game's shell keeps Build locked (ruling 4). Neither `ui_shell.gd`, `ui_manager.gd` nor any pinned
    file changed. `test_ui_shell.gd`'s "Build is locked" covers the game's shell, so it stands.
  - `demo_command_tips.gd` no longer writes the old "In the demo, B opens …" line. Like the farm's Food, an enabled
    Build keeps the tip its owner wrote.
- **E23. Setup refusals are shown and disarm painting** (review M4). The refusal codes from `batch.configure` and
  `paint.configure` are kept. The first is pushed with `UIManager.push_refusal`, and `armed_type()` is then -1.
- **E24. The paint ghosts redraw only on a batch change** (review M5). A cursor move redraws only the stroke and
  cursor ghost. `demo_build_paint.gd` counts both kinds of draw, and a check holds the room ghosts still while the
  cursor moves.
- **E25. The level bar marks a level with no way in, beside colour** (review LOW). It shows "Level 3 !" ("L3 !" at
  NARROW), using the table's ! for "No way in". The spec's labels are otherwise unchanged, and the words "no way in
  yet" are in the tooltip and accessible name.
- **E26. Smaller review fixes.**
  - The paint label keeps a 16 px safe inset from the window's edges.
  - `quanta_per_cell` rounds up, so a part quantum is still costed.
  - Each room is priced at the clear height of the level it was painted on (`build_catalog.gd clear_height_of`).
  - A stroke alone no longer rebuilds the ledger or the status words.
  - The card pool grows to fit a row, never dropping a card.
- **E27. The second review's smaller fixes.**
  - Confirm all's notice names the first room the route refused when none is invalid: "Confirm all: 0 ordered, 6
    kept back -- Dormitory: No way in: …".
  - The old tools' card notes ("who would dig, what they would stop") are re-read every
    `demo_command.gd PANEL_REFRESH_S` (0.2 s), the old party panel's cadence, while the panel shows. Nothing is
    read on the frames between. A refresh creates no objects, but it does build the note strings each time and rewrites
    the info card's text even when it has not changed (third review, LOW 1); at 5 Hz for three legacy cards the cost
    is negligible, and these cards go when slice C retires the old tools.
  - A locked card's visible line gives its own reason's head: "! Choose one level to paint on" on Overview, "! No
    way in" on Levels 3–4, "! Not yet" for later slices' cards. The whole reason stays in the info card.
- **E28. The live harness puts the camera back** after the build steps. `_build_level_one` centres the camera on
  (9, 0, 8) so the keyboard cursor starts in the planning area. Left there, the later box-select step framed the
  residents from that point. In an art-free checkout (CI's) the placeholder residents' screen box then started under
  the top-left HUD, and the drag selected no one at either size. This happened in 46947083 and was found by the
  coordinator's CI-style run. The harness was wrong, not the game: it now saves the camera's target before the build
  steps, restores it after them, and checks the framing is restored.
- **E22. The ghost's states.** Valid, blocked and impossible each tint the outline with their own §2.1 token, and
  each carries a tag with its glyph and type. The section's dashed (blocked) and hatched, numbered (impossible)
  outlines are not drawn yet. The words carry the state, so UX-BUILD-T03 holds.

## PROPOSALS for Brendan

All eleven were ruled on 2026-10-12, each as recommended (see Brendan's rulings above).

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
  - "Choose one level to paint on: Overview shows them all";
  - X "Nothing to add: these cells are already planned for this room" (review H1).

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
- **P-B11. No room can be ordered from the panel until slices C/D add the way in** (E6, review H3). RoomOrders
  needs a prospective entry contact bound to the room, and no step in the panel or the Dig tool makes one. Every room
  is refused "No way in …; the way in from the build panel comes in a later update". Options:
  - (a) accept this for slice B (built, as the coordinator resolved);
  - (b) add a minimal way-in step now, binding a finished passage's contact to a painted room before Confirm all.

  **Recommend (a).** The way in is slices C/D's connector work (UI-BUILD-012). A minimal step now would be replaced,
  and it would need an entry rule no document states.

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
  In the review round its own PgUp/PgDn branch (`level_step`, `is_level_key`, `_level_key`) was removed too (E9, M1).
- `demo/tunnel/tunnel_view.gd`: `set_unreached` and the `unreached` flag; the indicator's words trimmed.
- `demo/tunnel/tunnel_panel.gd`: the "Plan an underground room" button and its action removed.
- `demo/demo_village.gd`:
  - `_build_build_panel` mounts the panel, the bar and the hooks, a "build panel" focus region and a planning surface;
  - `build()` returns it;
  - `set_interrupts` hands the panel the command's interrupt words for the old tools' cards (E19);
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

## Review round (2026-10-12)

The coordinator's review of 06aa9b08 found three high, eight medium and six low items. All were fixed in this
worktree on top of bbbb3207. Where each fix is recorded:

| Finding | Resolution |
|---|---|
| H1 phantom Undo step (a stroke inside its own room, or over capacity) | E3: "Nothing to add" and capacity judged on the union; the draft's revision compared before recording; a draft refusal dropped as X |
| H2 the expanded ledger overflowed the panel | E18: a ScrollContainer inside the panel, below the alerts; checked with 12 rooms at 1280×720 and NARROW, and live with six refused rooms |
| M3 the ledger cut the tab row in half | E18: it starts at the panel's top edge, covering the tabs whole |
| H3 REFUSE_ENTRY never satisfiable | E6 corrected; the coordinator's resolution (`classify`, retry); P-B11 |
| M1 PgUp/PgDn changed level behind a modal with U on | E9: the tunnel tool's own branch removed; a live check behind the Pantry |
| M2 surviving mutants | tests for Redo never naming a confirmed room, the ring hole while drawn, and the stroke guards in `confirm_all`, `redo()` and `demo_build.gd` |
| M4 setup refusals ignored | E23 |
| M5 every ghost redrawn on a cursor move | E24 |
| M6 a check that could not fail | a `LIVE-SKIP` line (E12) |
| M7 the EconomySystem stand-in | `test_demo_build_orders.gd`: inventory, reservations, jobs, sites and identities byte-for-byte across paint, undo, redo, a refused Confirm all and discard, on the actual owners |
| M8 `tool_card_into` had no caller | E19 |
| LOW (six) | E25 and E26 |

The live Kitchen the harness paints lies on protected water, so it now reads X and holds Confirm all back. The six
rooms the first round's new step painted read "!" only because of a gap in the mapping; the second review found it
(E6), and the step now paints on open ground.

**Third review (af9005c6, coordinator's independent reviewer): no CRITICAL or HIGH.** It confirmed the terrain
mapping on the real demo (protected resource/foundation → X, water → X, open ground → "! No way in", retried), the
Build command toggling once per B press through the shell or the build hook, the settlement shell staying locked, the
tab row hidden and restored on fold/suspend/close, the lock-line wording and the camera restore (E28). Three LOW items
are left as they are, recorded here:
- The 0.2 s note refresh builds strings and rewrites unchanged text (E27 corrected above). Not a per-frame cost.
- `test_the_demo_build_command_opens_and_closes_the_panel`'s "connects once" check cannot fail on its own: Godot
  refuses a duplicate `connect` itself, with an ERROR line that the runner's diagnostics gate would catch.
- Ctrl+Tab while the ledger is expanded switches the hidden tab, and a focused tab loses focus when hidden. Harmless.

## Gates

Every line below is quoted from the run, never taken from an exit status.

### Second review and the rulings (final batch)

The coordinator runs the full sharded suite after this commit; `--fast` was not rerun here.
- **Focused run** of 28 suites (the 26 above plus `test_demo_ui.gd` and `test_ui_shell.gd`), the live wrappers at both
  sizes included. It printed `865 test(s), 16289 assertion(s), 0 failure(s)`, `diagnostics: 0 unexpected error(s), 0
  unexpected warning(s), 0 expected, 206 tolerated; leaked at exit: 0 object(s), 0 resource(s)` and `log: 0
  unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).`
- **Art-free**, in the coordinator's checkout (no `godot/demo/assets`, CI's import) with this change applied:
  - `test_demo_input_live.gd`: `3 test(s), 672 assertion(s), 0 failure(s)`. At 46947083 it failed "the drag selected
    a group" at both sizes (E28).
  - `test_demo_layout_live`, `test_demo_guide_live`, `test_modular_demo_live`, `test_demo_build_panel`,
    `test_demo_build_orders` and `test_demo_ui`: `84 test(s), 1395 assertion(s), 0 failure(s)`.
- **Live input harness**, with frames: `LIVE-SUMMARY 256 0` at 1280×720 and `LIVE-SUMMARY 264 0` at 1920×1080.
- **Analyzer** on port 6383: `0 GDScript warning(s) in 0 of 1503 file(s)`.
- **Contract checks:** `underground_memory_budget.py --check` exit 0; `ready07_arithmetic.py` `"status": "PASS"`;
  `decision_numbers.py` `PASS -- 544 records, 0 problem(s)`; `merge_gate.py` and `lane_notes.py --check` PASS.

### Review round

- **`./tools/run_tests.sh --fast`**, twice.
  - First run: `12171 test(s), 1130168 assertion(s), 1 failure(s)`. The failure was `test_modular_demo_live.gd`, a
    child's `6 ObjectDB instances were leaked at exit`. It did not recur in 3 sequential runs of the suite, nor in 8
    parallel runs of its scene.
  - Final run: `12175 test(s), 1130192 assertion(s), 1 failure(s)` and `diagnostics: 0 unexpected error(s), 0
    unexpected warning(s), 278 expected, 310 tolerated; leaked at exit: 0 object(s), 0 resource(s)`. The failure was
    `test_demo_orchard_live.gd` "the apple is tended in game time: FAIL after 2400 frames".
  - **That failure is pre-existing on master.** The tend job loses its worker (`worker -1`) in some runs. It failed
    2 of 5 runs here, 2 of 8 on a copy at bbbb3207, and 1 of 8 on a copy at master 1cfe1e3c, before slice B. It is
    not this slice's, and it is left for its owner.
- **Focused run** of the 26 touched suites, the live wrappers included. It printed `644 test(s), 14117 assertion(s),
  0 failure(s)`, `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 206 tolerated; leaked at
  exit: 0 object(s), 0 resource(s)` and `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0
  object(s), 0 resource(s).`
- **Live input harness**, with frames. `LIVE-SUMMARY 250 0` at 1280×720 and `LIVE-SUMMARY 258 0` at 1920×1080.
  The new steps are the U view behind the Pantry, the X or ! refusal and Confirm all's state, and six refused rooms
  with the ledger expanded (`build_ledger_refused`).
- **Analyzer** on port 6383: `0 GDScript warning(s) in 0 of 1503 file(s)`.
- **Contract checks.**
  - `underground_memory_budget.py --check`: exit 0.
  - `ready07_arithmetic.py`: `"status": "PASS"`.
  - `decision_numbers.py`: `PASS -- 544 records, 0 problem(s)`.
  - `merge_gate.py`, `lane_notes.py --check`, `dispatch_plan.py --validate`, `astra_inbox.py --check`,
    `generate_canonical_state_table.py --check`, `state_registry_coverage.py` and `ui_refinement_contract.py`: PASS.
  - `setting_contract.py`: `PASS_STATIC_SPEC_AND_REFERENCE_ONLY`.

### First round (06aa9b08)

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

**Coordinator's final CI-style run** (af9005c6, art-free checkout, `godot/.godot` deleted and re-imported, the ten CI
shards run five at a time locally by Brendan's choice of 2026-10-12, then `ci_test_shards.py verify --count 10`):

```text
ok: 490 suite files executed exactly once across 10 shards
{"counts": {"assertions": 1245499, "expected": 278, "failures": 0, "leaked_objects": 0, "leaked_resources": 0,
 "tests": 12333, "tolerated": 373, "unexpected_errors": 0, "unexpected_warnings": 0}, "shard_count": 10, "suite_count": 490}
wall seconds: 1057
```

An earlier sharded run at 46947083 found the art-free drag-select failure fixed in E28.

## Mutation testing

### Second review and the rulings (final batch)

18 new mutants, each killed:
- the terrain mapping: 5 (each of the four new protected-ground codes dropped, and water's words);
- the Build command: 3 (left locked, its press unwired, the Dig tool ignored);
- Confirm all's notice without the refused room: 1;
- the notes' cadence: 2 (read every frame, never read);
- the ledger over the tab row: 4 (tabs and status left showing; a close or an old tool's turn leaving them hidden);
- the lock line's own reason: 1;
- the notes rewritten into the tooltips: 1;
- `demo_command_tips.gd` overwriting the demo's Build tip: 1.

With the earlier rounds that makes 99 mutants: 96 killed and 3 equivalent survivors (D2, R1, D6, above).

### Review round

There were 39 new mutants over the review's logic, and the first round's 42 were rerun (3 anchors re-pointed at the
changed code). That makes 81 in all.
- The new mutants covered:
  - the batch: 14 (the revision compare, "Nothing to add", capacity, the union shape, the history guards, the retry
    rule and the kept answer kind);
  - the ledger: 3;
  - the catalog: 2;
  - the panel: 6;
  - the geometry: 2;
  - the level bar's mark: 1;
  - `classify`: 4;
  - the demo mount: 5;
  - the painter: 2.
- **The first pass killed 72 and left 9.** Six were real gaps, and each now has a test that kills it:
  - Confirm all mid-stroke with a room pending (R7);
  - the retry rule's kind and staleness (R9, R10);
  - the dropped stroke's words (R14);
  - the ledger on a panel narrower than it (G8);
  - `classify` never writing the runtime's answer (O3).
- Two of the retry rule's conditions were redundant and were removed. A route refusal's room is judged with that
  refusal's kind, so it is retryable exactly when it is "! Blocked" at the refused revision.
- **Final: 78 killed and 3 survived, all equivalent.**
  - `D2`, as in the first round.
  - `R1`: finish_stroke's revision compare. The stroke judgement already measures the union against the draft's own
    cells, so the draft cannot record nothing for a stroke that reached it. The compare is kept as the backstop the
    review asked for.
  - `D6`: `demo_build.gd`'s redo guard during a keyboard stroke. `batch.redo()` refuses mid-stroke itself (R6,
    killed). The guard is kept as the review asked.

### First round (06aa9b08)

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
- **A way in made from the panel.** Slices C/D (P-B11). Until then no room can be ordered from the panel.

## Source

- DEC-061.
- SET-BUILD-001; decision 1851 with its OPEN-09 ruling.
- `docs/ui_ux_controls.md` UI-BUILD-001 and §5.
- ADRs 1052 and 1055.
- BAL-ROOM-001; `godot/scripts/core/excavation_contract.gd`.
- `godot/data/underground/initial_level_pack.json`.
- Brendan's rulings of 2026-10-12, as relayed above.

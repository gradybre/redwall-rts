# 1921 — The Furnish tab: place, fit and ready the dug rooms (proof of concept)

Date: 2026-10-13 · Status: Accepted (Brendan asked for it, "start the Furnish tab", and ruled its three questions the
same day, quoted below); the PROPOSALS at the end await his word

Number range: 1921–1929, allocated to this lane by the coordinator; checked with `decision_numbers.py` and over every
ref. This is the lane record. It replaces no BACKLOG range.

## Decision

The build panel's **Furnish** tab (and its **Decor** tab, which holds the decoration: UI-BUILD-002) now works in the
demo, as a proof of concept on top of decision 1912's painted-room loop:

- With a room type chosen, the tab lists only the furniture that type uses (room_catalog.gd's palette, GDD §5.9's
  table): bed, patient bed, seat, kitchen bench, hearth, shelf, partition, door; decoration on Decor. On levels 1–4 a
  card arms placing it; on the surface and on Overview the cards stay locked and say why.
- **Ghost placement**: the armed piece's footprint follows the cursor on the dug pits' floor, turned by **R / Shift+R**,
  judged ✓ or X with its reason in words (the label beside the pointer; the ghost's tag carries the glyph and name). A
  click places it in the one pending batch: one Undo step, Redo, Discard all, the ledger's own line and the bill.
- **After Confirm all**, each piece waits in a demo-side store; a resident walks in through the Entrance, stands on
  the piece for a short wait (the dig's 1.5 s) and the piece appears. Free, like the rooms.
- **Validity**: each dug room's line is drawn over its far wall and shown on the Furnish tab, updated as pieces are
  fitted ("! Kitchen: Needs 1 hearth and 1 kitchen bench" → "✓ Kitchen ready"); fitted beds count in the HUD's Beds.

All of it is in `godot/scripts/ui/` and `godot/demo/`. No core simulation owner is touched (room_catalog.gd and
building_definitions.gd are read, never changed). Nothing is saved (P-1912-4 (a)).

## Brendan's rulings (2026-10-13)

Relayed by the coordinator: Brendan asked, in chat, "start the Furnish tab", and answered its three questions:

1. **Installing: "A resident fits it".** After Confirm all, a resident walks to the spot and the piece appears after a
   short wait, like the mole digging. It is free, like the rooms: the ledger shows the bill, but nothing is deducted.
2. **Function: "Room becomes valid".** The room's line updates live, for example "Kitchen: needs a hearth" → "✓ Kitchen
   ready". Placed beds count in the HUD's Beds. No new resident behaviour yet: nobody sleeps or cooks there.
3. **Placement: "Footprint + rotation".** Each piece has a footprint and rotates with R / Shift+R. It must sit on dug
   cells of a room whose type uses it, and pieces can't overlap. No access tiles yet; those are slice E's full rule.

**What it bypasses, knowingly** (decision 1912's framing; slice E replaces all of it):

- ADR 1081's install crews and paid publication (`UndergroundFurnitureWork`, the Quote, Funding, Jobs, Work and Gear):
  one resident fits each piece after a fixed wait (ruling 1);
- payment: REQ-SET-124–126 and BUILD-REQ-019's hauled materials; the ledger shows the bill and nothing is deducted
  (ruling 1);
- SET-BUILD-001 §6 / BUILD-REQ-010's **access tiles** (ruling 3) and, with them, the **wall-behind** rule for the hearth
  and shelf (OPEN-05 (a)): both are slice E's (P-1921-6 asks whether to add wall-behind now);
- the room services: nobody sleeps, cooks or stores anything there (ruling 2); a fitted hearth counts as lit (no fuel);
- saving: the furniture is not saved (P-1912-4 (a)).

## What was built

| Piece | Files | Requirement |
|---|---|---|
| Pending pieces: footprints read from room_catalog.gd and turned, edge items, judgement in words, the bill | `scripts/ui/build_furniture.gd` (new) | ruling 3; SET-BUILD-001 §3, §6; BUILD-REQ-010, -011 |
| Place / Undo / Redo / Discard all / Confirm all for pieces | `scripts/ui/build_batch.gd` (`place_piece`, `PIECE_TAG`) | BUILD-REQ-019–021 |
| Cards unlocked on levels 1–4, the rooms that use each piece, free | `scripts/ui/build_catalog.gd` | UI-BUILD-002/003 |
| Arming a piece, the ledger's pieces and bill, the rooms' lines on the tab | `scripts/ui/build_panel.gd` | UI-BUILD-004, -005, -008 |
| New refusal words | `scripts/ui/build_validity.gd` | UI "Validity in words"; P-1921-1 |
| The confirmed furniture and the fitter's walk | `demo/build_panel/demo_build_fittings.gd` (new); `demo_build_works.gd path_to_any` | ruling 1 |
| A resident fits it | `demo/build_panel/demo_build_below_task.gd` (MODE_FIT) | ruling 1 |
| Each room's line in words, heat and enclosure | `demo/build_panel/demo_build_rooms.gd` (new) | ruling 2; SET-BUILD-001 §4; GDD §5.9 |
| Ghosts, fitted pieces, room lines drawn | `demo/build_panel/demo_build_furnish.gd` (new) | BUILD-REQ-011; ruling 2 |
| Input (click, Enter, R / Shift+R, right click), Confirm all, sending the fitter, Beds | `demo/build_panel/demo_build.gd` | rulings 1–3; UI "Input in build mode" |
| Fitted beds in the HUD's Beds | `demo/ui/demo_hud_model.gd` (`built_beds`); `demo/demo_village.gd` (one line) | ruling 2 |
| Live loop | `test/live/demo_build_furnish_live.gd`; `test/test_demo_build_furnish_live.gd` (slow tier); `test/live_harness_case.gd` (the runner, moved out of `test_demo_input_live.gd`) | the brief's gate |

**Shared files touched, and the hook added:** `build_batch.gd` (the piece section, `PIECE_TAG` in `_replay` /
`_step_words`, the pieces in `pending_count` / `invalid_count` / `discard_all` / `confirm_all`'s third route);
`build_panel.gd` (`piece_armed`, `armed_item`, `set_room_lines`, the ledger's piece lines, Confirm all's reason for a
piece); `build_catalog.gd` (`item_lock`, `users_of`, the item cards' words); `build_validity.gd` (five reasons);
`demo_build.gd` (the Furnish section); `demo_build_below_task.gd` (MODE_FIT); `demo_build_works.gd` (`path_to_any`,
`_search` takes a set of goals); `demo_hud_model.gd` (`built_beds`); `demo_village.gd` (binds `built_beds`);
`test_demo_input_live.gd` (now extends `live_harness_case.gd`); `slow_suites.json` and `ci_test_shard_weights.json`
(the new live suite, 102 s). **Keys:** R / Shift+R (`placement_rotate`, already bound and unhandled in the demo) turn the
armed piece; a right click with a piece armed puts its card down. No new key or action.

## Engineering choices

- **E1 — Footprints are the catalog's, not authored here.** room_catalog.gd `furniture` gives GDD §5.9's footprint in
  2 m tiles; × 2 is SET-BUILD-001 §6's cells: bed, patient bed, seat, shelf, decoration 2 × 2; kitchen bench and hearth
  4 × 2 (2 × 4 turned once or three times). Door and partition are "tile edge" pieces, 0 × 0 floor: SET-BUILD-001 §6's
  "2 cell edges". No footprint had to be proposed.
- **E2 — The cursor sits at the footprint's middle**, rounded north-west: a 2 × 2 piece's north-west cell is the cursor
  cell, a 4 × 2 piece reaches one cell west of it (`anchor_for`). Turning keeps the cursor inside the footprint.
- **E3 — Edge items stand on a side of the cursor cell, chosen by the turn**: 0 north, 1 east, 2 south, 3 west, two
  cells long (east from the cursor for north/south, south from it for east/west). Each cell edge needs dug floor on
  both sides and a room that uses the piece on at least one (the other may be a way's landing: SET-BUILD-001 §6 asks
  walk cells either side of a door, and a Bedroom against a landing must be closed off there, E9). They share no cell
  edge with another door or partition and never cut through one floor piece ("Cuts through a Bed: put it between
  pieces"); otherwise they take no floor (GDD: "no floor occupation"), so a piece beside them never blocks them.
  P-1921-3.
- **E4 — The order of a piece's judgement**: an unknown item; per footprint cell, not dug yet ("Not dug yet") or not a
  room (earth, a way's landing: "Not in a room"), then two rooms under one footprint ("Spans two rooms"); then the
  room type (the canonical "Wrong room: Kitchen bench belongs in Kitchen"); then a way down's cells ("On a way down:
  keep its stairs clear"); then any pending or confirmed piece ("Overlaps a Hearth"). Every refusal is X. A way
  down's cells -- where it stands below the surface and where it lands -- are no room floor even when dug into a room
  (the host reads confirmed ones as ROOM_BARE, `demo_build_works.gd on_way`; the batch hands in its pending ones,
  `bind_ways`), and a way down placed over furniture, or landing on it, is refused too (`judge_item`). A refused click joins nothing and keeps no step (as a way down's, 1912).
- **E5 — A pending piece is judged again whenever it is read**, so one whose floor a confirmed piece has taken since
  holds Confirm all back in its own words (BUILD-REQ-021). It is a handful of rows; no cache.
- **E6 — Steps.** A placement is one step `[VERB_PLACE, PIECE_TAG + row]`; `PIECE_TAG` is `2 << 24`, past the ways
  down's `ITEM_TAG` (`1 << 24`), so `_replay` reads it first and the operation renumbering (`_prune`, `_renumber`,
  `_reached_operations`), which skips every entry at or past `ITEM_TAG`, leaves it alone. Confirm all orders pieces
  last (after the ways down and rooms), and `_forget` drops every step up to the newest naming an ordered one (1912's
  review H1).
- **E7 — The bill.** The ledger's short line adds the pieces' wood, stone and work to the cells'; the expanded ledger
  lists each piece ("Level 1 · Kitchen bench, turned once (free for now): ✓ Can build") and the furniture's whole
  bill in its own goods ("Furniture needs 2 logs, 2 lengths of cloth; work about 20 minutes (free for now: nothing is
  taken from the stores)").
- **E8 — The fitter.** The first selected resident not below, else the first resident on no task who is not a mole
  (moles dig), else the first resident not below (P-1921-2). One fitter trip at a time, sent only when a waiting piece
  can be reached from the Entrance; while pieces wait and nobody fits, one is sent again every 2 s (the mole's rule);
  why nobody went ("Nobody can fit the furniture: it waits", "The waiting furniture cannot be reached from an
  Entrance: it waits") is said once, apart from the mole's words. Its walk is
  `demo_build_works.gd path_to_any`: breadth first through dug cells to the nearest cell of any waiting piece (a
  floor piece's own cells; a door's or partition's cells either side). The figure stands on the piece and lightens
  as it works, as the mole's does; the tag over the piece reads "Fitting". It never reads as digging
  (`digging_cell`, `dig_share`: dig trips only).
- **E9 — The rooms' lines** (`demo_build_rooms.gd`). A room is a 4-connected set of ordered or dug cells of one type
  (OPEN-06's merge: joined rooms of one type are one). The line names the first thing missing, in this order: still
  being dug; the fitted pieces short of room_catalog.gd's minimum counts (the canonical "Needs 1 hearth and 1 kitchen
  bench"); SET-BUILD-001 §4's area (the canonical "Too small: Dormitory needs at least 36 cells (has 24)", per piece
  where the type counts area per piece); a maximum ("Has 2 beds: a Bedroom takes at most 1"); the Bedroom's
  PARTITIONED_ENCLOSURE ("Needs walls, partitions or doors where it meets the Kitchen": every edge it shares with
  another room or a landing holds a fitted partition or door; earth is its generated wall); the Infirmary's
  HEATED_COMPONENT. Only FITTED pieces count. Every number is room_catalog.gd's `service_requirements`; the lines are
  counted again only when the works, the furniture or the level change. The Dormitory's "bed access connected to the
  exterior" is access, slice E's.
- **E10 — Heat without fuel** (SET-BUILD-001 §4): a fitted hearth heats the rooms joined to its room through open
  boundaries or doors (a fitted partition closes an edge), `HEARTH_HEATED_TILE_CAPACITY` (120 tiles, 480 cells) a
  hearth, allotted in room order (the scan order of their first cells), a room heated only if all of it fits. Rooms
  are allotted whether or not they are otherwise valid (the GDD allots to valid rooms; validity here waits on heat, so
  the circle is cut there). P-1921-5.
- **E11 — Drawing.** Ghosts are the build panel's own (`demo_build_ghost.gd`) on the dug pits' floor, 1 m below the
  paint plane (decision 1913 E2: a piece is picked there too). Fitted pieces use the demo's staged models where it has
  them, through `demo_props.gd`: bed and patient bed → `bed`, hearth → `hearth`, seat → `table_stools`, shelf →
  `pantry_shelf`, decoration → `rag_rug`; turned with the piece, laid along a 4 × 2 footprint's long side and shrunk
  (never grown) inside it. The kitchen bench, door and partition have no model: plain blocks (a doorway of two posts
  and a lintel for the door), named by a tag. With nothing staged (CI) every piece is a named block. Nothing was
  generated or downloaded; P-1921-7 prices real models.
- **E12 — Tags.** The rooms' lines stand over each room's far (north) wall, clear of the pieces; they, the waiting and
  fitting words and the blocks' names go to decision 1913's spacer with the dug view's tags. The cursor ghost's tag is
  short (glyph and name); its reason is the label beside the pointer, so the two never repeat each other.
- **E13 — Words on the tab.** On Furnish and Decor the info card ends with the dug rooms' lines of the level shown;
  with no piece chosen it reads "Choose a piece to place" and the lines.
- **E14 — Per-frame cost.** `furnish.refresh` writes nine integers into a kept array and compares it with the last
  (no allocation on a still frame), rebuilding only on a change; the label's words are rebuilt only when the cursor,
  the turn, the item or the batch moved; `panel.set_room_lines` compares the string before it writes.
- **E15 — The live suite is its own, in the slow tier.** The loop digs 70 cells and fits five pieces: 102 s. Its runner
  (`_run_harness`, `_assert_run`) moved from `test_demo_input_live.gd` to `test/live_harness_case.gd` so both suites
  share it without re-running each other's tests.

## PROPOSALS for Brendan

- **P-1921-1 — The refusal words.** "Not dug yet: furniture stands on a dug room's floor"; "Not in a room: place it on
  a dug room's floor"; "Spans two rooms: keep it inside one room"; "Overlaps a Hearth: place it clear of other
  furniture"; "Not between dug floors: a Door needs dug floor on both sides and a room on one"; "Cuts through a Bed:
  put it between pieces"; "On a way down: keep its stairs clear". All X. Options: (a) as worded;
  (b) other words. **Recommend (a).**
- **P-1921-2 — Who fits** (E8): (a) as built: the selected resident, else the first free one who is not a mole, else
  anyone; (b) only a free resident, waiting otherwise; (c) the mole, after digging. **Recommend (a)**: the loop never
  stalls, and the art-free run (no moles) works the same.
- **P-1921-3 — Doors and partitions** (E3): (a) as built: on the side of the cursor cell the turn names, dug floor on
  both sides and a room on one (a landing may be the other), never through one piece; (b) only between two different
  rooms. **Recommend (a)**: a partition may split one room, as
  the starter layout's does.
- **P-1921-4 — The rooms' extra words** (E9): "Being dug (N cells to go)", "Has 2 beds: a Bedroom takes at most 1",
  "Needs walls, partitions or doors where it meets the Kitchen", "Needs heat: a hearth in it or in a room joined to
  it". The canonical "Needs …" and "Too small: …" are the UI table's. Options: (a) as worded; (b) other words.
  **Recommend (a).**
- **P-1921-5 — Heat without fuel** (E10): (a) as built: a fitted hearth counts as lit and allots its 480 cells in room
  order to every joined room; (b) heat only valid rooms, solving the circle by first judging every room without heat.
  **Recommend (a)** for the proof of concept; slice E brings fuel.
- **P-1921-6 — Wall-behind now?** SET-BUILD-001 §6 (OPEN-05 (a)) wants the hearth and shelf against a wall or earth.
  Ruling 3 left access to slice E and did not mention wall-behind. Options: (a) leave it to slice E with access;
  (b) add it now (one more X reason, "Needs a wall behind it", already canonical). **Recommend (a)**, as ruling 3 drew
  the line; (b) is a small change if wanted.
- **P-1921-7 — Real models** (E11). Five of nine pieces use staged models. Itemised at Meshy's published rates (no model
  was run, nothing spent): kitchen bench, text-to-3D preview + 2K texture refine, 30 credits; interior door, none (the
  staged `burrow_door` could be fitted to a 2 m edge: engineering, no cost); partition, none (a plain wall reads as
  one). Options: (a) buy the kitchen bench (30 credits; the last recorded balance is 8, so it needs a top-up); (b) wire
  the staged burrow door for doors, nothing bought; (c) keep the blocks until slice E. **Recommend (c)** for the proof
  of concept, (b) when slice E draws the real rooms.
- **P-1921-8 — Right click puts the card down** (UI-BUILD's input table names no way to). Options: (a) as built;
  (b) Escape instead (its order is stroke → connector card → panel). **Recommend (a).**
- **P-1921-9 — What counts in Beds**: (a) as built: every fitted bed, in a valid room or not, and no patient bed (the
  HUD's Beds are homes' beds); (b) only beds in a valid Dormitory or Bedroom. **Recommend (a)**, the ruling's words
  ("Placed beds count").
- **P-1921-10 — Decoration on the Decor tab.** The brief listed decoration among the Furnish tab's pieces; UI-BUILD-002
  (and slice B) put it on its own Decor tab, which this follows, placed the same way. Options: (a) as built; (b) list it
  on Furnish too. **Recommend (a).**

## The review

An independent `code-reviewer` on `bd749c1d` found no CRITICAL. Its three HIGH and two MEDIUM defects are fixed in
`3422f55b`:

- **H1** the pointer's words went stale and could contradict the ghost (their key left out the level and the dig):
  the key now holds both, and `test_the_label_follows_the_dig_and_the_level` checks "Not dug yet" → ✓ → level 2.
- **H2** a Bedroom against a landing could never be closed off (a door needed a room on both sides): a door or
  partition now needs dug floor both sides and a room on one (E3), checked through the batch.
- **H3** two allocations every frame: the drawing's key is kept in place and the joined lines cached (E14).
- **M1** furniture could stand on a way down's stairs or landing, and a way down over furniture: both refused (E4).
- **M2** a partition or door could cut one piece in two: refused ("Cuts through a Bed").
- **M3** test gaps: added (the fitter's resend, its words said once, the Entrance and reach guards, the tie between
  waiting pieces, the label's X in the fast tier, the half-fitted piece is no dig).
- LOW, fixed: item numbers read from catalog.gd; the fitter is sent only when a waiting piece can be reached
  ("The waiting furniture cannot be reached from an Entrance: it waits"); its words are said apart from the mole's;
  one recount per room line. LOW, answered: the new REASON ids stay as the table's record of the proposed words (as
  1912's did); the ghost's tag keeps the glyph and name only, the reason in words being the label beside the pointer
  and the notice (E12); dead pending rows are not compacted (a handful a session, dropped by Discard all, as the ways
  down's are).

## Gates

At `3422f55b` (code), Godot 4.7.2, 2026-10-13/14.

- **Full CI-style run** (`godot/demo/assets` set aside, `godot/.godot` deleted, imported with no `handle_crash`;
  `./tools/run_tests_parallel.sh`, 10 shards, 4 jobs): every shard exit 0, each shard's `diagnostics:` and `log:` line 0
  unexpected errors or warnings and 0 leaked objects or resources; verify `ok: 503 suite files executed exactly once
  across 10 shards`; 12,493 tests, 1,229,784 assertions, 0 failures; 1,395 s. The art was put back and re-imported;
  `demo_texture_imports.py --check`: 0 files would change.
- **Suites touched** (with the art): test_build_furniture 20 tests, test_demo_build_furnish 25, test_build_panel 30,
  test_build_catalog 14, test_build_batch, test_build_validity, test_demo_build_panel, test_demo_build_dig,
  test_demo_build_works, test_demo_hud_truth: 0 failures, 0 leaks.
- **Analyzer** (`tools/gdscript_warnings.py --max 0 --port 6421`): 0 GDScript warnings in 0 of 1,537 files. Every new or
  changed function is 30 lines or fewer.
- **Decision numbers**: PASS, 551 records. Contracts: merge_gate, dispatch_plan, astra_inbox, canonical state table,
  ready07 arithmetic, the underground memory budget, setting_contract, ui_refinement_contract and
  test_ci_test_shards: all pass.
- **Live harness** `demo_build_furnish_live.gd`: 57 / 57 at 1280×720 and 1920×1080, windowed with the art and headless
  art-free (its suite in the full run); `demo_build_dig_live.gd` 25 / 25.
- **Mutation testing** (`scratchpad/furnish_check/mut/run.py`, one mutant a run against test_build_furniture,
  test_demo_build_furnish, test_build_panel and test_build_catalog): 100 mutants over the placement judgement, edges,
  ways, the batch's steps, the store, the fitter, the rooms' lines and heat, the drawing, the label and the HUD's Beds.
  The first pass killed 89 of 99 (one pattern was ambiguous); tests were added for the gaps, and the second pass
  killed 98 of 100. **SURVIVED_MUTANTS, both equivalent:** F19 (skipping the room check on an edge: every edge item is
  a shared fitting every room uses) and P01 (dropping `level >= 1` from `piece_armed`: a piece card is locked on the
  surface, so no piece is ever chosen there).
- **Frames looked at** (session scratchpad, not committed): `furnish_check/final_1280x720/` and
  `final_1920x1080/` -- the rooms dug, the hearth's ghost "✓ Hearth", three pieces placed, the bench refused over the
  Dormitory in words, a resident fitting ("Fitting", "Waiting to be fitted: 2 pieces"), "✓ Kitchen ready" with the
  staged hearth and two bench blocks, and two staged beds with "✓ Dormitory ready" and Beds 2 on the HUD.

## Source

Brendan's rulings of 2026-10-13 (above). SET-BUILD-001 §3, §4, §6, BUILD-REQ-010, -011, -019–021; GDD §5.9 (the
furniture table and room validity); `docs/ui_ux_controls.md` UI-BUILD-002–005, -008, "Input in build mode", "Validity
in words"; decisions 1081, 1851, 1871, 1912, 1913.

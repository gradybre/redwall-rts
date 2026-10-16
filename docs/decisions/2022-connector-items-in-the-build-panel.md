# 2022 — Connector items in the build panel: three families, the connector card, and refusing to cut anything off

Date: 2026-10-16 · Status: Accepted (Brendan's rulings on decision 2021, 2026-10-16; the PROPOSALS at the end are this
lane's own small calls, awaiting his word)

Number range: 2021–2039 (slice D1's); 2021 is the scoping record, this is the implementation record. It replaces no
BACKLOG range. Branch `feat/build-slice-d1`.

## Decision

Slice D1 is built as decision 2021 scoped it and Brendan ruled it (all twelve proposals (a); P-D1-2 "Use the table,
marked", P-D1-6 "Real check now", P-D1-11 "All three types"):

- **Three way items on every level** (P-D1-1): Burrow mouth (RAMP), Hatch with ladder (LADDER_HATCH) and Stair-head
  (EARTH_TIMBER), then Stone and Spiral stairs locked "Not yet: stone and spiral stairs come in a later update".
  Their shapes and bills are decision 2021's placeholder table, kept in one file
  (`scripts/ui/build_connector_families.gd`) with each number's source beside it, and labelled "placeholder" on every
  card, ghost note and ledger line (P-D1-2). Nothing goes into SET-BUILD-001 §9.
- **The Stair-head is decision 2041's F40 flight** (Brendan's approval of 2041 on 2026-10-16, noted in 2021):
  2 × 23 cells, every row an open slot to the land, 2041 §2.4's row depths (5 rows reach level 1 from row 5; 142
  cubes); its bill L0 + T0 + 38 treads, in all wood 78,500, stone 35,500 milli-U, 858,980 milli-WU, earth 284,000
  milli-U (2041 §2.5); placed at rotation 0 only (P-DF-6 (a)): turned, it reads "X Not possible: No qualified stair
  for this direction yet".
- **The connector card** (UI-BUILD-012, P-D1-3): a click pins the way's ghost and opens the card; Down / Up with the
  impossible one disabled and its reason (P-D1-4); "✓ Connects to "+level or why not; the placeholder's notes, "Climbers
  only" on a hatch (P-D1-8) and "Proof of concept: free; not yet a qualified descent" (P-D1-11); Add to plan and Cancel.
- **Below the Surface a way stands on a Passage** (P-D1-5), "<Item> needs a passage under it: paint one there first".
- **Removing the only way in is refused** (BUILD-REQ-017, P-D1-6): a click on a confirmed way asks for its removal; it
  and a Mound's front door's removal are judged by a real connectivity check over the proof of concept's space, and
  refused "Would cut off <names>: build another way in first".
- **The landings reader is bound in the demo** (P-D1-9); confirmed but unbuilt ways count as ways in (P-D1-7).
- **The mole digs all three families**, free (P-D1-11). `begin_underground_entry` is not wired (P-D1-10).

## What was built

| Piece | Files | Rule |
|---|---|---|
| Families: placeholder shapes, cells per level and turn, landings, runs, access pairs, quanta, fixture bills | `scripts/ui/build_connector_families.gd` (new) | 2021 table; P-D1-1, P-D1-2 |
| Pending ways per family and turn, removal rows, clashes by level | `scripts/ui/build_items.gd` | 2021 E2, E3 |
| Judging a way: levels, area, clashes (pending and confirmed), landing and run ground, furniture, Surface water / things / Mound floor, Passage under it; removal rows and the cut-off check; Mound door removals | `scripts/ui/build_batch.gd` | BUILD-REQ-013, -016, -017; BUILD-MOUND-021; P-D1-4–7 |
| The connectivity check | `scripts/ui/build_way_graph.gd` (new) | BUILD-REQ-017; P-D1-6 |
| The connector card | `scripts/ui/build_connector_card.gd` (new); `build_panel.gd` (pin, direction, Add to plan, Escape order, NARROW) | UI-BUILD-012; P-D1-3, P-D1-4 |
| Cards and ledger lines | `build_catalog.gd`, `build_panel.gd`, `build_ledger.gd` (`add_quanta_into`) | UI-BUILD-003, -005 |
| Words | `build_validity.gd` (`needs_passage`, `not_in_room`, `connects`); `docs/ui_ux_controls.md` table rows and follow-up | P-D1-12 |
| The works per family: runs (`TYPE_WAY`), landings, links, removal, directions | `demo/build_panel/demo_build_works.gd`, `demo_build_ground.gd` | 2021 E4; P-D1-11 |
| The demo's cut-off reader | `demo/build_panel/demo_build_way_host.gd` (new) | P-D1-6 |
| Drawing per family, turned | `demo_build_ways.gd` (ramp, hatch, ladder, stair-head meshes), `demo_build_dug.gd`, `demo_build_earth.gd`, `demo_build_mound_view.gd` (hatches only), `demo_build_paint.gd` (ghosts with access pairs) | 2021 E8 |
| Input: pin, add, rotate, remove; the pointer's words | `demo/build_panel/demo_build.gd` | P-D1-3 |
| Live harness | `test/live/demo_build_dig_live.gd` (the five cards, the card, two more entrances dug and drawn, the refused removal), `demo_build_furnish_live.gd`, `demo_build_mound_live.gd` | |

## Engineering choices (beyond decision 2021's)

- **E1 — A way's anchor is its bounding box's north-west cell**, so a hatch is exactly decision 1912's 2 × 2 and every
  earlier test and drawing of it holds. Turn 0 descends north; R turns the descent clockwise. Cells are listed
  canonically (by z, then x).
- **E2 — What clashes.** Two ways clash where both stand, or where either's run (solid earth only its way takes)
  shares a cell; a way may stand on a hatch's landing (open floor: a shaft of hatches). Confirmed ways clash the same
  way unless a pending removal takes them away.
- **E3 — A top cell links to the landing row** the same way across (a hatch: the same cell below), so the mole lands
  at a run's foot and digs the run back toward its top, along itself; a dug run is never entered from its side.
- **E4 — The cut-off check compares reach before and after.** Something already unreachable never holds a removal
  back; the removals pending together are judged together, once a batch revision; a window's removal never asks.
- **E5 — Way-host targets**: every room cell named "<Type> (<level>)" (de-duplicated) and every resident below by
  name; runs are not walkable cells (their way is the link).
- **E6 — The turn is kept from one way to the next** (as a piece's is, decision 1921); the card closes on Cancel,
  Escape, a level change or putting the card down.
- **E7 — A refusal stays beside the pointer** while the way's card is chosen, until another click; while pinned the
  pointer says "<Item>: choose Down or Up on its card, then Add to plan (Enter)".
- **E8 — A turned Stair-head is "X"**, not "!": no stair is qualified that way, and an "X" way never joins the batch
  (P-DF-6 (a)'s "greyed out" read as the ghost's hatched "X" with the ruled words).
- **E9 — From review (all HIGH fixed).** H1: Confirm all judges the removals afresh (the cut-off answer is cached
  only between batch revisions, and the residents below can move without one). H2: removals are ordered before
  placements, and a removed way's cells that another standing way takes are left alone. H3: a pending removal's
  dug cells below read occupied, not finished, so they are no way in. H4: a run is left only onto its own landing,
  never sideways, never onto another run. H5: choosing another card closes the connector card. MEDIUM: two ways
  never share a landing (`meets`); the works' searches and `on_way` no longer allocate per cell (owner maps built
  when the ways change); a resident on a run counts at its way's landing. Declined: caching each way's judgement
  per revision (a few pending ways, judged on a change, not a frame); the "shaft of hatches" test fakes a Passage
  under a landing, which the demo never reports (a landing is no Passage, P-D1-5), and stays as the batch's rule.
  Re-review of the delta: all five fixed; one new HIGH, N1 (with a removal pending, a new way could not come down on
  the removed one's dug landing), fixed: a way's own landing and run read the host's raw ground. Also: a refused
  Confirm all moves the revision so the row shows its new "X"; choosing the Stair-head resets a turn it cannot take.

- **E10 — One judgement over a built way** (the coordinator's defect on the removal frame, 2026-10-16). Hovering a
  built way with a way's card chosen showed two refusals at once: the placement ghost's "Overlaps another ..." on its
  3D tag, running off under the HUD, and the removal's "Would cut off ..." beside the pointer. Now a way's moving
  ghost carries no tag; its judgement is spelled out once, in the pointer's label, which `label_position` keeps inside
  the window and above the panel. Over a built way (a click removes it) the ghost draws that way, judged as its removal
  (`build_batch.gd removal_preview`: nothing asked, cached a revision), and the label says "✓ Remove <Item>: click to
  ask for its removal", "✓ Keep <Item>: click to withdraw its removal", or the X line with what it would cut off; off
  one, "Place <Item>: ..." and, when it cannot stand, the reason on a second line. Every ghost tag also wraps at
  about 40 characters (`demo_build_ghost.gd TAG_WRAP_PX`) rather than running across the screen. Checked by
  `test_demo_build_panel.gd` (one judgement, no ghost tag), `test_build_batch_ways.gd` (`removal_preview`) and the
  live harness's "only the removal's judgement shows" (47 checks at both sizes).

## PROPOSALS for Brendan

- **P-2022-1 — A way on the Surface over water or a placed thing** is refused "Cannot dig here: water" / "... a tree"
  (the Mound host's reader, decision 2002's). SET-BUILD-001 §9's ghost lists water among the "X" reasons; things are
  this lane's reading. (a) as built; (b) water only. **Recommend (a).**
- **P-2022-2 — New small words**: "no built way stands there now" (a pending removal whose way has gone); the ghost
  tags "<Item> comes down here", "Remove <Item>", "access"; level tags "<Item>: way down / way up / way up to the
  surface" (replacing "Entrance", "Way down", "Way up"); "Connects to Surface" for a way up from level 1. (a) as
  worded; (b) other words. **Recommend (a).**
- **P-2022-3 — The turn is kept between ways** (E6). (a) as built; (b) every new card starts at turn 0.
  **Recommend (a)**, as furniture does.
- **P-2022-5 — The pointer's words over a built way** (E10): "✓ Remove <Item>: click to ask for its removal" and
  "✓ Keep <Item>: click to withdraw its removal". (a) as worded; (b) other words. **Recommend (a).**
- **P-2022-4 — "Keep" for a withdrawn removal**: Undo after withdrawing a removal reads "Undo Keep Hatch with ladder"
  (review LOW). (a) as worded; (b) other words. **Recommend (a).**

## Memory and save

As decision 2021 said: no saved state. Each pending way row gains family, turn and removal (3 B8 columns); each
confirmed way in the works gains family, turn and a live flag (3 B8) and the works keep a links Dictionary rebuilt
when the ways change; `TYPE_WAY` reuses the type byte. The graph is built per removal judgement, at most once a batch
revision. ARCH-BUILD-001's 16,957,440 bytes are unchanged.

## Gates

Run on `36b784de` (2026-10-16, Godot 4.7.2); origin/master had not moved from `c11da82e`, so nothing was merged in.

- **Full CI-style run** (demo assets aside, `godot/.godot` deleted, imported with no crash; `./tools/run_tests_parallel.sh
  --jobs 4`): `ok: 538 suite files executed exactly once across 10 shards`; 12,877 tests, 1,435,414 assertions,
  0 failures, 0 unexpected errors or warnings, 0 leaked objects or resources; 1,463 s.
- **Analyzer** (`tools/gdscript_warnings.py --max 0 --port 6501`): `0 GDScript warning(s) in 0 of 1611 file(s)`.
  Functions ≤ 30 lines, a docstring on each.
- **Contracts**: `decision_numbers.py` PASS (566 records); `ready07_arithmetic.py` PASS; `merge_gate.py` PASS;
  `dispatch_plan.py --validate` PASS; `lane_notes.py --check` PASS; `state_registry_coverage.py` PASS;
  `ui_refinement_contract.py` PASS; `astra_inbox.py --check` PASS; `generate_canonical_state_table.py --check` PASS.
- **Live harness** `test/live/demo_build_dig_live.gd`, windowed with the art, at 1280×720 and 1920×1080:
  `LIVE-SUMMARY 46 0` at both (registered minimum 43 in `test_demo_input_live.gd`); the furnish and Mound harnesses
  pass with their new connector-card steps (60 and 46 checks). Frames looked at, in the session scratchpad
  `d1_check/1280x720/` and `d1_check/1920x1080/` (not committed): `ways_cards_*` (the five cards),
  `loop_connector_card_*`, `ways_connector_card_burrow_mouth_*`, `ways_connector_card_stair-head_*` (UI-BUILD-012),
  `ways_removal_refused_*` (the refusal in words beside the pointer), `ways_dug_below_*` (the dug ramp and stair-head
  on level 1), `loop_rooms_open_*` (the dug hatch's ladder), `ways_surface_*`, `loop_entrance_open_*`.
- **Mutation testing** (`scratchpad/mut/run*.py`, one mutant a run against the focused suites): 74 mutants of the new
  logic (the graph 9, the families 14, the items 7, the batch 22, the works 11, the cut-off host 5, the panel and card
  8 -- including every review fix); **73 killed**. The survivors of the first pass (G6, F5, I2, B1, W8, H4a, H6) were
  killed by new tests. **One equivalent survivor, I4**: `removed_landings` counting placement rows too changes
  nothing, because `_all_landings` adds the placements' own landings back (`placed ∪ (host − placed) = host ∪
  placed`). G3 (every neighbour walkable) was killed by the search never ending; G3b (`if false`) is killed by tests.
- **Independent review** (`code-reviewer`): no CRITICAL. HIGH H1–H5 fixed (E9); re-review of the delta found N1,
  fixed. MEDIUM fixed or answered in E9; LOW fixed.

## Source

Decision 2021 and Brendan's rulings on it (2026-10-16); SET-BUILD-001 §3, §9, BUILD-REQ-013, -015, -016, -017,
BUILD-MOUND-021; `docs/ui_ux_controls.md` UI-BUILD-003, -005, -011, -012; decisions 0212, 1202, 1209, 1880, 1912,
1913, 1921, 2002; DEC-039, DEC-059.

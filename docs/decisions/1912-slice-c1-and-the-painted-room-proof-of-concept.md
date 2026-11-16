# 1912 — Slice C1 and the painted-room proof of concept: paint, judge every cell, place an entrance, a mole digs

Date: 2026-10-12 · Status: Accepted (Brendan's rulings on decisions 1911 and 1931 and his proof-of-concept ruling of
2026-10-12, quoted below; the PROPOSALS at the end await his word)

Number range: 1911–1929 (this lane's); 1911 is the scoping record, this is the implementation record. It replaces no
BACKLOG range.

## Decision

The build panel now does, in the demo, what DEC-061's slice C asks a player to see -- and, by Brendan's ruling, a
proof of concept of the digging:

- **C1** (decision 1911 P-C1 (b) and P-C4–P-C9, all as recommended): Rect · Oval · Paint · Erase strokes on the 1 m
  grid; joined pending rooms merge, an Erase that cuts a room splits it; **every cell is judged before Confirm all**
  (ground the crew can dig, the 2 × 2 rule, the way in) and drawn so (✓ gold, ! dashed, X hatched and numbered); the
  cell cursor follows the camera; levels 1–4 show the **actual** World at 5 m in the demo's own camera; the old tool
  cards and the separate planner view are gone; the height a room is dug to and priced at is read in one place with
  the claw crew's identity.
- **The proof of concept** (Brendan, 2026-10-12): an **Entrance** placed on the surface (and a **Way down** on levels
  1–3) joins the pending batch; **Confirm all** hands the batch to a demo-side store of ordered cells, free; a **mole**
  walks to the Entrance and digs the cells one by one; the dug rooms are drawn open; residents can be sent into them.
  All in `godot/demo/` and `godot/scripts/ui/`; no core simulation owner is touched.

## Brendan's rulings (2026-10-12)

**The proof of concept.** Relayed by the coordinator: Brendan said, in chat, "Right now I want to build out the most
basic ability to build via this layout concept to prove a proof of concept, not focus on speed, timing, foreman, claw
mechanics, etc… we can revise from there." His answers to the coordinator's four questions:

1. How a confirmed room gets built: **"A simple mole digs."** A mole walks to each cell, and the cell opens after a
   short wait. Plain walking: no claw strokes, no foreman rules, none of the excavation-site, Work or Routes phase
   machinery.
2. Cost: **"Free for now."** The ledger still shows the per-cell bill as information; nothing is deducted. Costs
   return when the real economy is wired in.
3. Way in: **"Place a simple entrance."** The Surface tab gets a basic Entrance item; placed and confirmed, it opens a
   way down to level 1 that rooms and passages connect to (a lite slice D).
4. Scope: **"Paint rooms + passages."** The Rooms tab only: paint any room type or passage on levels 1–4, see
   validity, Confirm all, watch a mole dig it, residents can walk through it. Furnish and Decor come later.

**What it bypasses, knowingly** (each comes back with slice C3, after C2.1–C2.3 and slice D):

- DEC-059's pricing and payment, and REQ-SET-124–126's hauled materials (ruling 2);
- the claws' M1 / M3 strokes and DEC-052's crew rows (ruling 1; decision 1932's 1-quantum room is drawn, not dug);
- UG24's dispatcher and the excavation Sites, Work and Routes owners (ruling 1);
- BUILD-REQ-012's up-to-4 builders and parallel faces (one mole);
- a way in through a real, qualified connector (ruling 3; SET-BUILD-001 §9, OPEN-02, OPEN-10 stay slice D's);
- saving: the proof of concept's state is not saved (a reload loses it).

**UG24's "never show unpaid work as done" is knowingly waived** by "Free for now": dug rooms are drawn open without
anything paid. It holds again when C3 wires the real economy.

**Earlier the same day** (recorded in decision 1911 and `docs/handoff/RULINGS.md`): P-C1 (b), P-C2 (c), P-C3 (a) as
corrected by P-C2-3 (a), P-C4–P-C9 (a); P-C2-1 to P-C2-5 on decision 1931; and decision 1932's room height (1 quantum,
one claw front stroke M3). "Until M3 lands claws reach 0 quanta" there means the height a claw stroke can actually
CUT (decision 1931 F1: no published claw stroke reaches a room wall). `reachable_height_u` reads anchor heights only
and reports 1,024 u for the claw crew; the build panel prices with that function's result (E9), which is decision
1932's 1 quantum. The proof of concept digs regardless (ruling 1).

## What was built

| Piece | Files | Requirement |
|---|---|---|
| Tools: Rect, Oval, Paint (2 × 2 brush), Erase | `scripts/ui/build_stroke.gd` (new); `demo/burrow/modular_draft.gd` BLOCK and `apply_cells` | P-C7 (a); BUILD-REQ-002 |
| Merge on join, split on cut, one step each | `scripts/ui/build_batch.gd` | P-B2 (b); BUILD-REQ-003, -004 |
| Validity per cell | `scripts/ui/build_cell_validity.gd` (new); `build_batch.gd` | BUILD-REQ-002, -013, -021; ECON-003; P-C4 (a) |
| Ways down in the batch | `scripts/ui/build_items.gd` (new); `build_batch.gd`; `build_catalog.gd`; `build_panel.gd` | ruling 3; OPEN-07 (a) |
| Ghosts: dashed, hatched, numbered | `demo/build_panel/demo_build_ghost.gd`, `build_ghost.gdshader` (new) | UI-BUILD-010; P-B9 (a) |
| Camera-relative cursor | `demo/build_panel/demo_build.gd arrow_step` | P-B10 (b) |
| The actual World's levels in the demo camera | `demo_build_world.gd` (new); `tunnel_view.gd set_override_mask` | P-C6 (a); P-B5/P-C5 (a) |
| Ground under each cell | `demo_build_ground.gd` (new) | ECON-003; BUILD-REQ-013 |
| Dig height in one place, claw identity | `demo/burrow/modular_runtime.gd dug_height_u` | DEC-054; P-C3 (a) as corrected by P-C2-3 (a) |
| The proof of concept | `demo_build_works.gd`, `demo_build_below_task.gd`, `demo_build_figure.gd`, `demo_build_dug.gd` (new); `demo_build.gd` | rulings 1–4 |
| Old tool cards and planner view retired | `build_catalog.gd`, `build_panel.gd`; deleted `demo/burrow/modular_demo_mode.gd`, `modular_demo_live.gd/.tscn`, `test/test_modular_demo_live.gd` | P-C2 (c); P-B7 (a) |
| Honest words | `demo/guide/help_topics.gd`, `guide_text.gd`, `field_guide.gd`; `demo_build.gd` notices | P-C2 (c); rulings 1–4 |

## Engineering choices

- **E1 — Strokes are cell sets.** A stroke is the planner draft's own stamp (Rectangle, ELLIPSE, or a new BLOCK tool
  that grows each dragged cell to its 2 × 2 block, so the brush always keeps BUILD-REQ-002). Overlap, joining and
  narrowness are judged on the cells, not on a rectangle.
- **E2 — One release, one step.** A step is `[verb, entries…]`; a merge empties the younger rooms in the same step, a
  split makes new rooms in it, a way down is an entry at `ITEM_TAG` + its row. Each draft changes at most once per
  step, so Undo and Redo replay a step exactly. A step that changed nothing is not kept.
- **E3 — Merge keeps the oldest; a split keeps the piece with the room's first cell.** OPEN-06 (a)'s rule applied
  before confirmation; the split is BUILD-REQ-003 (each 4-connected set is one room).
- **E4 — Per-cell order of reasons.** Ground first ("Cannot dig here"), then 2 × 2, then the way in. A drafted cell
  over dug or ordered space is "occupied". Only diggable cells carry the way in; a one-cell strip is still diggable and
  carries it (its own cells read "Too narrow").
- **E5 — The way in.** Seeds are drafted cells beside finished space, or on or beside a landing (built, or a pending
  way down's). "No way in" holds Confirm all back (BUILD-REQ-013); this replaces slice B's "refused, retried" for that
  reason only. A stroke covering a cell the crew cannot dig is "X" and dropped; its words name it.
- **E6 — A host with no ground reader judges only shapes.** The off-tree suites and a run with no underground
  composed paint and confirm on shapes alone; nothing is claimed about ground there.
- **E7 — The actual World in the demo's camera.** The planner's `modular_world_view.gd` is built once, the first time
  an underground level is shown (about 72 ms on Brendan's Mac), on render layer 128, with its own light; the ghosts
  and dug rooms are on layer 256. While the panel shows an underground level the U view draws exactly those layers;
  U pressed meanwhile is read as a choice (off: Surface; on: Level 1). With the panel closed the bar follows the legacy
  U view as before.
- **E8 — The shared frame (P-C5 (a)).** Cell (0, 0) is the space domain's datum, so cells are world metres. Under the
  village, the terrain survey reads level 1 as **water for z 0–31 m**; it is dry from z 32. Cells there say "Cannot dig
  here: water" and an Entrance landing there is refused in those words.
- **E9 — Dig height.** `modular_runtime.gd dug_height_u` is the one place: the clear height capped by
  `reachable_height_u` with the claw crew's identity (`CLAW_DIG_ROWS[0]` of the mounted pins), never "any row". On
  master the claw rows reach 1,024 u, so a cell is priced at 1 quantum (wood 250, stone 250 milli-U, 4,230 milli-WU,
  earth 2,000), which is decision 1932's room. Fixtures whose crew is the content-6 pick name their own
  (`set_crew_identity`). `reachable_height_u` itself (core) is unchanged.
- **E10 — The proof of concept draws rooms 1 m high** (1 quantum: decision 1932's height, and the simplest to draw).
- **E11 — The works store** (`demo_build_works.gd`): one byte a cell per underground level for EARTH / ORDERED / OPEN
  and one for the room type (4 × 65,536 × 2 bytes), a box per level around its ordered and dug cells (scans stay
  inside it), and a short list of confirmed ways down. Every Entrance is joined to every other through the surface. Ordered and dug
  cells read as finished space for the next plan (`demo_build_ground.gd`), so new rooms connect to them.
- **E12 — The dig order.** Breadth first from where the mole stands, through dug cells and dug ways down: the nearest
  ordered cell beside open space (or the landing under a dug way down, or its own cell). Rooms therefore open outward
  from the Entrance (SET-BUILD-001 §8's shape, by the plainest rule). A short wait of 1.5 s of game time per cell.
- **E13 — The mole.** The first selected mole, else the first mole on no task, else the first mole not below on a
  visit (its routine task gives way, as any order's does); in a village with no mole at all (the art-free
  placeholders, as in CI) any resident digs, and the notice says so ("No mole lives in the village: X digs instead").
  A mole is sent only when an ordered cell can be reached from an Entrance; otherwise the reason is said once. It walks the surface to the Entrance as any task's resident does; underground its
  actor is indoors (not drawn) and a stand-in figure with its name is drawn in the World view. A trip lost on the
  surface goes back to its routine and the panel sends a mole again every 2 s while cells wait.
- **E14 — Visitors.** With residents selected, a right click on a dug cell (panel open on that level) sends them down;
  they walk through dug cells and stay until called away. That is "residents can walk through it".
- **E15 — Old tool code kept.** `tunnel_control.gd`, `room_tool.gd`, `underground_rooms.gd`, `tunnel_plan.gd` and the
  rest are kept: the village's existing warren is drawn and walked with them and many suites test them. Only the
  panel's entries were removed. Deleted: `modular_demo_mode.gd`, `modular_demo_live.gd/.tscn`,
  `test_modular_demo_live.gd` (nothing else used them). `modular_room_mode.gd` is kept (its own tests; C3 may reuse its
  access binding).
- **E16 — A placement puts the card down.** After a way down is placed the card is no longer armed (Shift keeps it),
  as UI-BUILD's input table says for items; otherwise its cursor ghost sat over the new placement and read "overlaps".
- **E17 — Flat colours for the proof of concept's drawing.** The U view's environment is dark by design; the dug floor,
  walls, blueprint cells and the figure are unshaded so they read.
- **E18 — The 1280×720 box-select step.** On this branch it failed 2 of 3 windowed runs; master passed 3 of 3, but only
  because a wandering resident put the residents' box corner off-screen. The harness now grows the box until a
  corner inside the window is clear of the HUD (`demo_input_live.gd _cast_box`). Fixed, not recorded as a flake.
- **E19 — A visit can be dropped on the surface.** A resident whose walk to the Entrance gets lost ends the trip and
  goes back to its routine (`resident_brain.gd`'s lost-trip rule; the below task does not hold when lost). It happened
  once in five windowed 1280×720 runs of the loop harness (and, art-free, the resident's next routine task was its
  sleep). The player clicks again; the harness does the same, at most twice, and reports how often
  (`demo_build_dig_live.gd _report_resends`; every later run: 0). A failed wait now names the visitor's task and cell.
- **E20 — The first import can crash.** One `godot --headless --path godot --editor --quit` after deleting
  `godot/.godot` ended in signal 11 while reimporting `NotoSans-SemiBold.ttf` (`propagate_notification()` called off
  the main thread). The shell chain went on, and the suite then failed across eight shards on a half-made import. Run
  again, the import finished cleanly and the suite passed. Check the import log for `handle_crash` before a run.

## PROPOSALS for Brendan

- **P-1912-1 — New words.** "Nothing to erase: no planned <type> cells here" (X); "Overlaps another <Entrance / Way
  down>: undo it first" (X); "<Way down> needs a passage or room under it: paint one there first" (!); the erase
  stroke's "✓ Takes out the planned cells under it". Options: (a) as worded; (b) other words. **Recommend (a).**
- **P-1912-2 — The Way down below level 1** stands on a planned or dug passage or room and lands on the same 2 × 2
  cells one level down. Options: (a) as built; (b) only on a Passage. **Recommend (a)** for the proof of concept.
- **P-1912-3 — Which mole digs** (E13): (a) as built, taking a mole from its routine when none is free, and any
  resident when the village has no mole (the art-free placeholders); (b) wait for a free mole, and nobody digs without
  one. **Recommend (a)**: the loop should never stall silently, and the art-free CI run can check it.
- **P-1912-4 — Nothing is saved** (E11): (a) accept for the proof of concept; (b) save the works. **Recommend (a)**;
  C3's real owners save.

**Brendan's ruling (2026-10-13, relayed by the coordinator): "Approve all four"**, i.e. P-1912-1 to P-1912-4 all (a)
as built: the words as worded; a Way down stands on a planned or dug passage or room; a mole is taken from its routine
when none is free, and any resident digs when the village has no mole; nothing about the works is saved for the
proof of concept.

## Gates

The full run is at `b17e7f03`; the gates commit changes only the loop harness (E19) and its registered minimum (20
checks), checked afterwards by test_demo_input_live and the windowed runs below (2026-10-12/13, Godot 4.7.2).

- **Full CI-style run** (demo assets aside, `godot/.godot` deleted, imported; `./tools/run_tests_parallel.sh`, 4 jobs):
  `ok: 500 suite files executed exactly once across 10 shards`; 12,427 tests, 1,229,226 assertions, 0 failures,
  0 unexpected errors or warnings, 0 leaked objects or resources; 1,397 s. (The run before it was void: E20.)
- **Suites touched** (with the art): test_build_batch 56 tests, test_build_cell_validity 12, test_demo_build_works 7,
  test_demo_build_dig 5, test_demo_build_panel 30, test_modular_runtime 17, test_modular_access 25,
  test_demo_input_live 4, test_demo_guide_live 2: all 0 failures.
- **Analyzer** (`tools/gdscript_warnings.py --port 6417`): 0 GDScript warnings in 0 of 1,524 files. Functions ≤ 30 lines.
- **Decision numbers** (`docs/validation/decision_numbers.py`): PASS, 549 records, 0 problems.
- **Independent review** (`code-reviewer`): no CRITICAL. HIGH, all fixed: H1 Undo after a partial Confirm all replayed
  confirmed pieces (history now keeps only steps after the newest one naming a confirmed piece); H2 each dig scanned
  all 65,536 cells of a level (now the ordered box only); H3 the 2 × 2 check was quadratic (one linear pass,
  `all_in_blocks`); H4 an unreachable order resent a mole forever and a second Entrance was never reached (every
  Entrance joins the surface node; a mole is sent only when an ordered cell is reachable; the reason is said once).
  MEDIUM: M1 tests added; M2 a crew whose rows reach nothing now digs 0 and the docs say so; M4 the marks mask falls
  back; M5 the level bar's marks follow confirmed ways down (`269d4ee3`); M6 notices said once. **M3 declined**
  (bind the ground reader only once it is `readable()`): with no settlement underground there is no World to judge,
  E6's shape-only judgement is the honest answer there, and H4's say-once covers the stall. LOW: binds now refresh;
  the waiting tag is in words; stale text fixed; `retryable`'s reason comparison kept (the reasons are plain strings).
- **Mutation testing** (new validity and batch logic, plus the review's fixes; `scratchpad/mut/run.py`): 51 mutants,
  46 killed. The 5 survivors are equivalent: B03 (the union already enforces capacity), B10 and B12 (defensive
  guards no caller reaches), S01 (an ellipse fills its own box's corners' rows), W01 (walking only proceeds through
  open cells). M2a survived the first pass and is killed by the empty-profiles case added to test_modular_runtime.
- **Frames looked at**, the whole loop, windowed (Entrance placed, rooms painted ✓, the mole digging with "Waiting for
  the mole: 34 cells", rooms open, a visitor inside), at 1280×720 and 1920×1080:
  `scratchpad/slicec_check/loop_v2_1280x720/` and `loop_v2_1920x1080/` (session scratchpad, not committed).
  Loop harness: 20 of 20 checks at both sizes, windowed and headless, with and without the art.
- **Windowed harnesses**: demo_input_live 296 / 301 checks, demo_room_blueprint_live 35 / 35, all passing at
  1280×720 / 1920×1080; the 1280×720 box-select step passes (E18).

## Source

Brendan's rulings of 2026-10-12 (above, and in decisions 1911, 1931, 1932); DEC-052, DEC-054, DEC-059, DEC-061;
SET-BUILD-001 BUILD-REQ-002–005, -012–014, -019–021, §3, §7.2, §8–§10; `docs/ui_ux_controls.md` UI-BUILD-001–014;
decisions 1851, 1871, 1880, 1911, 1931.

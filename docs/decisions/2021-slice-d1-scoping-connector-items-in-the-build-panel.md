# 2021 — Slice D1 scoping: entrances and ways down as per-family items in the build panel

Date: 2026-10-16 · Status: Accepted. Brendan ruled all twelve PROPOSALS (a) on 2026-10-16 (below); the build follows
in decision 2022.

Number range: 2021–2039 (slice D1's, given by the slice D coordinator, session `dbd322db`); 2021 is this scoping
record. It replaces no BACKLOG range. Branch `feat/build-slice-d1` from origin/master `c11da82e`.

## Decision

Slice D ("Entrance and connectors as items", study §5 D) is split, by Brendan's "Begin" of 2026-10-16 on the
coordinator's proposal, into **D1** (the build panel and the pending batch), **D-flight** (scoping the steeper
earth/timber flight, decision 2041) and **D2** (binding a finished connector to the room-dig runtime). This record
scopes D1. It finds what the code and documents already hold, lists the engineering choices D1 would make without a
ruling, and asks Brendan twelve questions (P-D1-1 to P-D1-12). No D1 code starts before he answers.

D1 is demo and `scripts/ui/` work. It never claims a real connector reaches level 1: the only qualified flight ends
about 1 m down (F2), and qualifying a full-level flight is D-flight's.

## What D1 must do (the brief)

1. Per-family **Entrance** items on the Surface (burrow mouth, hatch with ladder, stair-head) and **Way down** items on
   a passage on levels 1–3, replacing `build_items.gd`'s generic proof-of-concept items, subset to what the economy can
   price.
2. A ghost with ✓ / ! / X and the reason in words, and the connector card: Down; Up greyed on the Surface;
   "✓ Connects to Underground level N"; Cancel. The item joins the pending batch. Painting against a planned entrance
   in the same batch stays allowed (OPEN-07 (a)).
3. A host reader bound to `batch.bind_landings`, so built landings make the level below paintable.
4. BUILD-REQ-017: refuse removing the only way in, by a real connectivity check.
5. A way down on a Mound room's floor (decision 2001, BUILD-MOUND-021).
6. OPEN-02 (a): placeholder geometry, access cells and fixture bills for RAMP, LADDER_HATCH, STONE and SPIRAL, as
   **PROPOSED values for Brendan's review**, each number traced to its source.
7. What happens to the proof of concept's digging of ways down (decision 1912, "Free for now") until D2.

## Findings (origin/master `c11da82e`)

**F1. The proof of concept's way down is one generic 2 × 2 item.** `godot/scripts/ui/build_items.gd:12-16` holds
`SIDE = 2`, the names "Entrance" and "Way down" and `DEEPEST_TOP = 3`; a row is level, north-west cell and a live flag
(:18-21). Its landing is the same 2 × 2 cells one level down (`footprint` :29-31, `landings` :73-79). No family, turn,
direction or bill exists. `build_batch.gd` places and judges it (`place_item` :672-684, `judge_item` :687-714), and
Confirm all sends it first (`_confirm_items` :1607-1617). The catalog's one card per level is
`build_catalog.gd way_down_card` :308-320 (level 4 locked, "No level below level 4"); the ledger line says "free for
now" (`build_panel.gd ITEM_LINE` :74).

**F2. Nothing reaches level 1.** Five connector families exist as numbers only (`scripts/core/room_connectors.gd:7-13`).
The only qualified descent is the first-entry flight: 6 treads, rise 128 u, run 512 u
(`data/underground/mole-worker/qualified-claw-runtime-v2/tread_geometry.gd:15-21`), ending about 1 m down; level 1's
floor is 5,120 u down (SET-BUILD-001 §3). `SettlementSystem.begin_underground_entry`
(`scripts/systems/settlement_system.gd:1967-1979`) is called only by tests and benches, and its chain ends at
`ENTRY_KITCHEN_UNBUILT`.

**F3. `room_connectors.gd` cannot hold a placeholder family.** A `Definition` must carry profile-qualified approach and
reach contacts with work points and profile ids (`_content_error` :100-123, `CONNECTOR_CONTACT_MISSING`). A placeholder
would have to invent profile rows, which is forbidden; and `underground_connector_catalog.gd` belongs to the running
activation lane (LIVE_WORK_SLICE_D §3). So D1's family data must live on the planning side, as cells, never as
`Definition`s. Turning a family into a real `Definition` is D-flight's and D2's.

**F4. The game has no build panel to bind.** Slice B's ruling "Game UI, demo mounts it" (decision 1871; RULINGS
"Slice B, the build panel shell") keeps the settlement's Build button disabled until slice G. The only host of
`BuildBatch` is the demo (`demo/build_panel/demo_build.gd:221` `bind_ground`, :708 `confirm_all`). `bind_landings`
(`build_batch.gd:179-184`) is bound by no host; only `test_build_batch.gd:631-633` calls it. There is also nothing in
the game for a reader to read: no connector item rows exist, and no connector publishes a level-1 endpoint (F2). Item 3
of the brief cannot be done "in the game" in D1; see P-D1-9.

**F5. The demo already treats every ordered cell as a way in.** `demo_build_ground.gd ground` :115-118 returns
FINISHED for any cell the works store has ordered or dug, and `order_way_down` (`demo_build_works.gd:92-103`) orders
the 2 × 2 landing with the way. So a confirmed way gives the level below its way in today without `bind_landings`. For
a hatch that is right. For a sloped family it would be wrong: every cell of its run (F7) would become a way in for its
neighbours, though only its foot opens onto the level.

**F6. BUILD-REQ-017 exists only as words.** `build_validity.gd` has `FORMAT_CUT_OFF` (:86) and `cut_off()` (:224-226);
nothing calls it. The one removal of a built thing that exists today is decision 2002's removal of a confirmed Mound
door or window, and `build_mound_edges.gd row_judgement` (:230-235) judges a removal ✓ whenever its door still stands.
**So removing a Mound's only door is accepted today**, even when the Mound holds the hatch to level 1 and residents are
below: a live BUILD-REQ-017 gap. No removal of a confirmed way down or room exists (UI-BUILD-003's Remove tool and
UI-SET-034's review are slice F's). Undoing or erasing pending things already turns dependent pending cells
"! No way in" and holds Confirm all back (BUILD-REQ-013); that is not a removal and needs nothing new.

**F7. The geometry of a 5 m level.** SET-BUILD-001 §3: level 1's floor is at world y −4,608 u, its clear height 4,096 u,
so its ceiling is at −512 u and the land is at +512 u. Between them lies **one quantum** (1,024 u). Between level N's
floor and level N+1's ceiling there is also one quantum. ARCH-BUILD-001 already notes that connectors "cut roof-band,
footing and surface quanta between levels" (`docs/systems_architecture.md`, ARCH-BUILD-001 "Exact counts"). Three
consequences:

- A **hatch** cuts only 1 quantum per cell through earth. The rest of its 5,120 u drop is inside the level below's clear
  height, over its landing.
- A **sloped** connector at 1:2.5 is mostly an **open cut**: with 3 quanta of headroom, 9 of the ramp's 14 columns are
  open to the ground above (computed below). On level N ≥ 1 that cut is a trench in the passage floor.
- A sloped connector takes a **strip of cells on both levels**, not a 2 × 2 landing. The proof of concept's "lands on
  the same 2 × 2 one level down" (F1) fits only the hatch.

**F8. A hatch is not a route for every task.** `docs/design/underground-planning/levels-and-connections.md:63`: a
timber ladder and hatch is a "specialized climbing route; eligibility must consider grip, capability and load; not a
substitute for a usable route for every task". So in the real game a level reached only by hatches has no haul route
for spoil and materials. In the proof of concept nothing is hauled (decision 1912 ruling 2).

**F9. The connector card's rectangle exists.** `build_layout.gd connector_rect` (:100-105) places UI-BUILD-012 above
the panel's top-right edge, or inside its content row in NARROW, and `ui_registry.gd:408` registers "Connector card".
No widget draws it (`build_panel.gd:38`: "comes with slice D").

**F10. The Mound hatch is in place.** Decision 2002 E15: the Entrance card placed wholly on one Mound room's floor is
its hatch, "Way down, connects to Underground level 1" (`demo_build_paint.gd way_name` :211-222), reachable once its
cell is dug and its door fitted (`demo_build_mound_host.gd hatch_ready` :335). `build_batch.gd _way_clear_of`
(:898-909) refuses a 2 × 2 that is part on a room ("split") or on the berm ("on the hill"). It handles only 2 × 2.

**F11. Asset dimensions on hand** (no new art needed for three families):

| Asset | Measured | Source |
|---|---|---|
| Burrow-mouth prop | 1.87 × 0.90 × 1.90 m as delivered; drawn 3.0 m across; arch fits the 0.90 m mole | decision 1913 "Measured before use"; ART-BUILD-POC accepted (RULINGS 2026-10-13) |
| Stair flight | 1.90 × 0.48 × 1.69 m; stretched over a 2 × 2 m landing | decision 1913 |
| Mound hatch (procedural) | hole 1.70 m square, frame 1.96 m, lid 1.70 m, ladder rails 0.6 m apart, rungs about 0.33 m apart | `demo_build_mound_parts.gd add_hatch` :195-210 |
| Legacy ramp | grade 2:5 (1:2.5), eased over 896 u at both ends | `demo/tunnel/tunnel_rules.gd:102-104`; decision 0212 §2 |
| Legacy stairs | risers of 256 u (4,096 / 16), treads 320–512 u | `tunnel_rules.gd:826-829`; decision 0212 §2 |
| Wide bore | 2 quanta wide, 3 high: "the smallest lattice bore an otter … and the badger … fit" (badger 1.12 m across) | `tunnel_rules.gd:67-70` |

**F12. Prices that are already adopted.** Per quantum (DEC-059 on BAL-UG-001/ECON-002; SET-BUILD-001 §7.1): wood 250,
stone 250 milli-U, work 940 + 1,880 + 1,410 = 4,230 milli-WU, earth out 2,000 milli-U. Fixtures (ADR 1202, ADR 1209
D3, DEC-059 P3): L0 4,000 milli wood and 32,000 milli-WU; each tread T0's bill, 1,000 milli wood and 5,640 milli-WU
(12,000 before DEC-059). **DEC-059 P3 names brace, cut, finish and each tread's fastening; it does not name L0's
32,000.** Whether ×0.47 applies to L0 is unstated, so this record uses 32,000 and flags it. `build_ledger.gd` already
reads the per-quantum numbers from `excavation_contract.gd` (:1-13), never restating them.

**F13. Memory.** The pending batch is presentation-side and never saved (ARCH-BUILD-001 "Pending batch"; decision 1880
lists it outside obligation 1). Real connectors are item rows, which are the existing Furniture rows re-keyed to cells,
at no new allocation, **provided every item covers at least 2 × 2 cells on its level** (decision 1880 "[NEW
constraint]"; ARCH-BUILD-001 "Items").

**F14. Work that names slice D but belongs to D2.** Decision 1936 P-1936-4 (a): the game checkpoint recipe "when slice
D makes a room diggable". Decision 1937 S7: the host's restore-rebind fixture, deferred "until slice D". Decision 1971
§3: shafts and stairs by top-face digging (rows 56–62). Decision 1936 F2 and F5: a room dig needs a published access
endpoint, a travel row and a SUPPORTED_VOID seed within one cube of the floor (`ROOM_DIG_ORDER_NO_WAY_IN`). None of
these can be done without a real connector, so all are D2's.

**F15. No file collision.** D1's files (below) are none of LIVE_WORK_SLICE_D §3's. On 2026-10-16 neither running lane
(`feat/activate-content-11-12`, `perf/dig-tick-cost-2`) changes any `scripts/ui/build_*`, `demo/build_panel/*`,
`ui_ux_controls.md` or `building_model_amendment.md` file (`git diff --name-only c11da82e...<branch>`).

## The placeholder families (OPEN-02 (a)) — PROPOSED values for Brendan's review

Nothing here is adopted. Each number is derived; the derivation is beside it. Shared inputs:

- **Drop:** 5,120 u per level (SET-BUILD-001 §3; BUILD-REQ-018).
- **Width:** 2 cells (2,048 u): the Passage minimum (BUILD-REQ-014), wider than the badger's 1.12 m (F11 wide bore).
- **Headroom along a slope:** 3 quanta (3,072 u), the badger's 2,611 u (DEC-039) rounded up to whole quanta, and the
  legacy wide bore's height (F11). A connector is not a room, so the rooms' 4-quantum painted height (DEC-054 addendum)
  is not used; the 4-quantum figures are given too.
- **Access:** one front access pair (2 cells) at the top and one at the foot, OPEN-02 (a)'s "one front access pair".
- **Quanta:** every 1,024 u cube the connector's void touches, conservatively (computed by a script in the session
  scratchpad, `d1calc/quanta.py`; to be committed as a test in phase 2). A cube already open is never charged twice
  (SET-BUILD-001 §7.2), so each count is an upper bound.

| Family (card) | Footprint on the standing level | Cells taken on the level below | Quanta at most | Excavation bill at most (wood, stone milli-U; work milli-WU; earth milli-U) | Fixture bill (PROPOSED) |
|---|---|---|---|---|---|
| LADDER_HATCH (Hatch with ladder) | 2 × 2 (the hatch art's 1.96 m frame fits 2.048 m; GDD 1-tile item = 2 × 2 cells, SET-BUILD-001 §3) + front access pair | the same 2 × 2 (its landing) + access pair | 20: 4 through the band + 16 for the landing's 4-quantum clear height (4 if the landing is already dug) | 5,000; 5,000; 84,600; 40,000 | Frame and lid as L0 (4,000 wood, 32,000 work) + ladder as one tread (T0) per 1,024 u of drop, 5 a level (5,000 wood, 28,200 work): **9,000 wood, 60,200 work**. The "one T0 per quantum" ratio is this record's choice and the weakest number here |
| RAMP (Burrow mouth) | 2 × 11 (2 × 9 of it an open cut) + top access pair | 2 × 12 (the foot at its end) + foot access pair | 84 (2 × 42); 90 at 4 quanta headroom | 21,000; 21,000; 355,320; 168,000 | **None**: an earth ramp is all excavation (its bracing is in each quantum's brace phase). Run 12,800 u (5,120 × 2.5) + 896 u for the eased ends = 13,696 u = 14 cells |
| EARTH_TIMBER (Stair-head), the 20 m fallback | 2 × 16 (2 × 13 open) + access pair | 2 × 16 + foot pair | 112 (2 × 56); 120 at 4 quanta | 28,000; 28,000; 473,760; 224,000 | At least L0 + 40 treads at T0's bill: **44,000 wood, 257,600 work** (ADR 1209 rise 128 / run 512: 40 treads over 20,480 u, SET-BUILD-001 §9). The bottom sill and the steeper flight are D-flight's (decision 2041); this row is replaced when that is ruled |
| STONE (Stone stairs; not offered in D1) | 2 × 5 (2 × 4 open) + access pair | 2 × 6 + foot pair | 44 (2 × 22); 48 at 4 quanta | 11,000; 11,000; 186,120; 88,000 | **Not proposed**: no stone fixture recipe exists. Geometry from decision 0212's stairs: 20 risers of 256 u (the legacy rise) on 320 u treads = 6,400 u = 7 cells |
| SPIRAL (Spiral stair; not offered in D1) | 4 × 4 (OPEN-02's placeholder as is) + access pair | the same 4 × 4 + access pair | 80: 16 through the band + 64 for the well's 4 quanta | 20,000; 20,000; 338,400; 160,000 | **Not proposed**: no recipe. Its 20 steps of 256 u, about two-thirds of a turn at 1.5 m radius, are for the slice that offers it |

Every footprint is at least 2 × 2 cells on its standing level, so decision 1880's item bound holds (F13).

## Engineering choices (made without a ruling; each a small change if Brendan wants otherwise)

- **E1 — Family data is planning-side.** A new `scripts/ui/build_connector_families.gd` holds the table above as
  constants, each tagged PROPOSED with its source, plus pure functions: the cells a family takes on each level for a
  cell and a turn, its access and foot cells, and its quanta. No `room_connectors.Definition` is made (F3).
- **E2 — A pending row stores the standing level, the north-west cell, the family and the turn** (R / Shift+R, as
  UI-BUILD-011). Everything else is derived. An Up placement (P-D1-4) is stored as the same item standing on the level
  above, so there is no direction column.
- **E3 — Overlap and clearance cover both levels.** `clashes`, `_way_cells` (furniture keeps clear) and the Mound
  hill's `_way_clear_of` read a family's cells on both levels, not a fixed 2 × 2. "Wholly on one room's floor" (F10)
  becomes: every cell of the family's standing footprint on one Mound room.
- **E4 — Only the foot is a landing.** `Items.landings(level)` returns the foot cells and the foot access pair. The
  works store marks a sloped connector's run cells with a new type value (`TYPE_WAY`), and the ground reader reads them
  as occupied, not finished, so the run is never a way in (F5).
- **E5 — The removal check is a cold breadth-first search** over the proof of concept's graph: dug and ordered cells
  per level, joined 4-way; each way down joining its standing cells (or the surface node) to its foot; each Mound room
  joined to the surface only through a door. It runs once per removal judgement, never per frame, as a pure helper
  (`scripts/ui/build_way_graph.gd`) the demo feeds from `demo_build_works.gd` and the Mound host. Names come from the
  room types and levels cut off and from residents below (the dig trip, the fitter and visitors). Stored lots and
  reservations: none exist in the proof of concept, and the helper takes them as host readers that return none.
- **E6 — The ledger reads.** A connector's line is its quanta × `excavation_contract.gd`'s per-quantum numbers, plus the
  family's fixture bill from E1's table, with "free for now" kept in the demo (decision 1912 ruling 2).
- **E7 — The card uses `build_layout.connector_rect`** (F9) and the panel's existing tokens; no new key: Enter adds,
  Escape closes the card (UI-BUILD's Escape order: stroke → card → panel), R / Shift+R rotate.
- **E8 — The demo draws three families with art it has:** the burrow-mouth prop for the Burrow mouth, the stair flight
  stretched along a stair's run, and the Mound hatch (`add_hatch`) for a hatch anywhere. No paid generation.

## The file plan

New: `scripts/ui/build_connector_families.gd`, `scripts/ui/build_way_graph.gd`, `scripts/ui/build_connector_card.gd`
(the UI-BUILD-012 widget), and their suites (below).

Edited, `scripts/ui/`: `build_items.gd` (family, turn and removal columns; per-family cells), `build_batch.gd`
(`place_item`/`judge_item` per family and direction; the card's pending placement; removal rows for confirmed ways;
the cut-off check on door and way removals), `build_catalog.gd` (three cards per level, Stone and Spiral locked),
`build_panel.gd` (the card, ledger lines), `build_validity.gd` (new words, P-D1-12), `build_mound_edges.gd` (a door
removal asks the cut-off check), `build_ledger.gd` (connector lines), `build_cell_validity.gd` only if E4 needs it.

Edited, `demo/build_panel/`: `demo_build.gd` (card flow, the landings reader bound, way removal clicks),
`demo_build_works.gd` (family and turn per way; run, foot and `TYPE_WAY` cells; removal), `demo_build_ground.gd`
(`TYPE_WAY` read as occupied), `demo_build_ways.gd` and `demo_build_dug.gd` (per-family drawing), `demo_build_paint.gd`
(per-family ghosts with access cells), `demo_build_mound_host.gd` (hatch cells per family), `demo_build_below_task.gd`
(walking a run). Guide words: `demo/guide/help_topics.gd`, `guide_text.gd`, `field_guide.gd`.

Docs: this record; `godot/demo/README.md`'s build panel section; `docs/ui_ux_controls.md` (the new words, once ruled,
in "Validity in words", and a follow-up note under UI-BUILD); `docs/handoff/RULINGS.md` (Brendan's rulings).
**`building_model_amendment.md` §9 is not edited by D1**: its values stay "still to be authored" until Brendan rules
P-D1-2, and D-flight may need the same rows (see Risks).

Not touched: everything in LIVE_WORK_SLICE_D §3, `scripts/core/`, `scripts/systems/`, the save files and registry.

## The test plan

Following CLAUDE.md's QA rules and handoff README §3.4–3.5:

- **New suites.** `test_build_connector_families.gd`: every table value recomputed from its inputs (drop, grade, eased
  ends, headroom, width), quanta by an independent count, every footprint at least 2 × 2 (decision 1880's
  constraint), all four turns, a run off the planning area. `test_build_way_graph.gd`: the only way in refused with
  its names; a second way allows it; a Mound's only door refused, its second door allowed; residents below named;
  removing an unused way allowed; boundaries (one cell of a room cut off, a way whose foot is unused).
  `test_build_connector_card.gd`: Down / Up per level (Surface Up disabled "No level above the surface", level 4 Down
  disabled "No level below level 4"), Add to plan, Cancel, Escape order.
- **Updated suites.** `test_build_items.gd`, `test_build_batch.gd`, `test_build_batch_mound.gd`,
  `test_build_mound_edges.gd`, `test_build_catalog.gd`, `test_build_validity.gd`, `test_build_panel.gd`,
  `test_build_ledger.gd`, `test_build_layout.gd` (UX-BUILD-T01 rectangles for the card at the nine sizes),
  `test_demo_build_works.gd`, `test_demo_build_dig.gd`, `test_demo_build_panel.gd`, `test_demo_build_mound_host.gd`.
  Every public function tested; boundary tests at each family's table values; one allocation check that the ghost's
  per-frame path judges nothing when nothing moved (as `judgements` does today).
- **Live harnesses**, windowed and headless, with and without the art, at **1280×720 and 1920×1080**:
  `demo_build_dig_live.gd` (each offered family through the card: placed, confirmed, dug, walked),
  `demo_build_mound_live.gd` (a hatch in a Mound; its only door's removal refused), `demo_input_live.gd` (the card's
  keys and Escape order). Frames into `scratchpad/d1_check/`, every one looked at, including the NARROW card.
- **Mutation testing** of the new logic (families, item judgement, direction, the graph check, the works' run and foot
  cells): one mutant per run against the focused suites; every survivor explained; any left declared as
  `SURVIVED_MUTANTS`.
- **Gates.** Full CI-style run (`./tools/run_tests_parallel.sh`, demo assets aside, fresh import), the analyzer on port
  6501 (`0 GDScript warning(s)`), the contracts group (`decision_numbers.py` and the rest), and an independent
  `code-reviewer` pass, with every CRITICAL and HIGH fixed.

## Memory and save impact

- **No saved state is added.** The pending batch stays presentation-side and unsaved; the works store stays the
  proof of concept's unsaved store (P-1912-4 (a)).
- **Unsaved bytes:** each pending item row gains family (B8), turn (B8) and a removal flag (B8), 3 bytes on today's
  13 (three I32 and one B8); each confirmed way in the works store gains family and turn, 2 bytes; `TYPE_WAY` reuses
  the existing type byte (no new column); the family table is constant data, five rows of fewer than 32 integers; the
  graph search is transient, bounded by the works' existing `SEARCH_LIMIT` of 65,536 cells, on a cold path.
- **ARCH-BUILD-001's 16,957,440 bytes (decision 1880) do not change.** Real connector items, when D2 builds them, are
  Furniture rows at no new allocation, which holds because every proposed footprint is at least 2 × 2 cells (F13). D2
  must still give the families item definition ids, which touches the catalog fingerprint (decision 1880's obligation
  2, slice G's).

## Sequenced after: D2

D2 starts after D-flight's build and the activation lane (`feat/activate-content-11-12`) merge. It owns:
a qualified connector's `Definition` (profiles, contacts, work points); its bottom endpoint published in Locations, a
travel row in Profiles, staging and spoil containers, and a SUPPORTED_VOID seed within one cube of the floor (decision
1936 F2, F5); `begin_underground_entry` (or its successor) as the card's runtime trigger (SET-BUILD-001 §9 "Built");
the game's landings reader and the game's real BUILD-REQ-017 check over Routes (MOVE-REQ-008); saved connector item
rows; decision 1936's game checkpoint recipe and decision 1937's S7 restore-rebind fixture; top-face digging of shafts
(decision 1971 §3); retiring D1's free proof-of-concept digging of ways. C3 follows D2.

## Risks and collisions

- **D-flight overlap.** The Stair-head's numbers above are the 20 m fallback; D-flight's record 2041 may propose others.
  D1 keeps them in one table row so a ruling is a one-row change. Neither lane should edit SET-BUILD-001 §9 until
  Brendan rules, or the two will conflict.
- **Reading a placeholder as adopted.** The demo will show placeholder bills and footprints. The card and ledger must
  say "placeholder" and "free for now", and nothing goes into SET-BUILD-001 without P-D1-2's ruling.
- **The hatch as the only way in** (F8) works in the proof of concept, which hauls nothing, but not in the real game.
  P-D1-8 asks how to say so.
- **A longer `demo_build.gd`.** It is 1,340 lines and shared with the Mound and Furnish work; D1 keeps its edits to
  narrow hooks and puts new logic in new files.
- **F6's door gap is live on master.** Fixing it in D1 changes `build_mound_edges.gd`, decision 2002's file; that lane
  has merged (#267), so there is no running collision.

## PROPOSALS for Brendan

Each has a recommendation; one answer per line is enough.

- **P-D1-1 — Which items the panel offers.** (a) Three per level: Burrow mouth, Hatch with ladder and Stair-head, on
  the Surface and on passages on levels 1–3; Stone and Spiral shown locked ("Not yet: stone and spiral stairs come in
  a later update"), their geometry kept as PROPOSED data only; (b) all five; (c) the Hatch only, the other two locked.
  **Recommend (a)**: your study's three, and the three the economy can price (the ramp is all digging; the hatch and
  stair have timber bills from L0 and the treads).
- **P-D1-2 — The placeholder table (OPEN-02 (a)).** (a) Use the table above as placeholders in D1, marked
  "placeholder" on the card and ledger, and adopt nothing into SET-BUILD-001 yet; (b) use the geometry and the digging
  bills, but show fittings as "not yet priced" (no L0/T0 analogy for the hatch); (c) you set other numbers.
  **Recommend (a)**. The weakest number is the hatch ladder's "one tread's bill per metre of drop".
- **P-D1-3 — The connector card.** (a) As UI-BUILD-012 says: a click pins the ghost and opens the card (Down / Up,
  "✓ Connects to Underground level N", Add to plan, Cancel); Enter adds it; Shift keeps the item for another; Escape
  closes the card first; (b) keep today's one click to place, the card shown afterwards with Cancel as Undo.
  **Recommend (a)**: it is the adopted design.
- **P-D1-4 — Ways up (BUILD-REQ-016).** (a) Build Up now: on levels 2–4 "Up" places the same item standing on the
  level above with its foot here, and level 4 gets its card (Up only); on the Surface Up is disabled with "No level
  above the surface"; (b) Down only; Up always disabled with "Not yet: ways up come in a later update".
  **Recommend (a)**: it is adopted and costs little once a row stores its standing level.
- **P-D1-5 — Where a way down stands below the Surface.** (a) On a Passage only (SET-BUILD-001 §9, BUILD-REQ-016),
  with the words "<Item> needs a passage under it: paint one there first"; (b) on a passage or any room, as P-1912-2
  allowed for the proof of concept. **Recommend (a)**: P-1912-2 was ruled for the proof of concept only. Mound rooms on
  the Surface keep BUILD-MOUND-021.
- **P-D1-6 — Refusing removal of the only way in (BUILD-REQ-017).** (a) A real connectivity check over the proof of
  concept's dug space, ways, Mound doors and residents below, applied to removing a Mound door (allowed today even when
  it is the only one: F6) and to a new removal of a confirmed way down (clicked as doors are), refused with "Would cut
  off Kitchen (level 1), Basil: build another way in first"; an allowed way removal leaves its dug cells open and puts
  undug ordered cells back to earth (backfill stays slice F's); (b) the check on Mound door removal only now, way
  removal with slice F's Remove tool; (c) all of it in slice F. **Recommend (a)**.
- **P-D1-7 — A confirmed but unbuilt way counts as a way in.** (a) Yes: OPEN-07's "planned entrance" covers it, and the
  proof of concept already does it; digging waits for it; (b) no: only built ways and ways in the same batch, as
  BUILD-REQ-013 reads word for word. **Recommend (a)**, with a note in SET-BUILD-001 when it is next amended.
- **P-D1-8 — A hatch carries no loads (F8).** (a) In the proof of concept a hatch is a way in like the others, and its
  card says "Climbers only: loads need a stair or ramp"; the real rule is D2's; (b) a level reached only by hatches
  marks its rooms "! Blocked: a hatch carries no loads; add a stair or ramp". **Recommend (a)**.
- **P-D1-9 — The landings reader in the game.** (a) Bind it in the demo now; the game's reader comes with D2, when a
  connector first publishes its foot, and the game's panel with slice G (F4); (b) also write a game reader now that
  reads the settlement and, today, always returns nothing. **Recommend (a)**: (b) would test only an empty answer.
- **P-D1-10 — `begin_underground_entry`.** (a) Not wired in D1; D2 makes it the card's runtime trigger; (b) wire the
  Stair-head's Confirm all to it in the game now. **Recommend (a)**: its chain ends 1 m down, so it would start real
  work that cannot reach level 1.
- **P-D1-11 — The proof of concept's digging of ways until D2.** (a) The mole digs each offered family's cells (top,
  run, foot), free, drawn with the art the demo has; residents walk them as today; the card says "proof of concept:
  not yet a qualified descent"; (b) only the hatch is dug; the mouth and stair are planned and wait for D2; (c) no ways
  are dug until D2. **Recommend (a)**: it keeps decision 1912's loop whole for all three items.
- **P-D1-12 — New words.** (a) As worded: "<Item> does not fit in this room: it needs <w> × <l> cells" (X), "<Item>
  needs a passage under it: paint one there first" (!); BUILD-REQ-017's existing "Would cut off <names>: build another
  way in first" (X) used as written; on the card, "Climbers only: loads need a stair or ramp" and "Placeholder: sizes
  and costs await review"; (b) other words.
  **Recommend (a)**.

## Brendan's rulings (2026-10-16)

Relayed by the coordinator: on 2026-10-16, in chat, using the AskUserQuestion tool, Brendan chose the recommended
option on **all twelve** proposals. The nine routine ones were approved together; three were asked on their own.

| Item | Ruling |
|---|---|
| P-D1-1 | **(a)**: Burrow mouth, Hatch with ladder and Stair-head on every level that has them; Stone and Spiral locked |
| P-D1-2 | **(a)**, **"Use the table, marked"**: the placeholder table is used, every size and cost labelled "placeholder" on the card and ledger; nothing goes into SET-BUILD-001 §9 (D-flight's 2041 may still replace the Stair-head row) |
| P-D1-3 | **(a)**: the connector card as UI-BUILD-012 |
| P-D1-4 | **(a)**: ways Up now; level 4 gets an Up-only card |
| P-D1-5 | **(a)**: below the Surface, a way stands on a Passage only |
| P-D1-6 | **(a)**, **"Real check now"**: the connectivity check on Mound door removal and on a new removal of a confirmed way down |
| P-D1-7 | **(a)**: a confirmed but unbuilt way counts as a way in |
| P-D1-8 | **(a)**: a hatch is a way in in the proof of concept; its card says "Climbers only" |
| P-D1-9 | **(a)**: the landings reader bound in the demo; the game's with D2 and slice G |
| P-D1-10 | **(a)**: `begin_underground_entry` is not wired in D1 |
| P-D1-11 | **(a)**, **"All three types"**: the mole digs the Burrow mouth, Hatch and Stair-head, free |
| P-D1-12 | **(a)**: the new words as worded |

## Gates (this record)

Docs only: `python3 docs/validation/decision_numbers.py` run after writing (summary in the lane report). No GDScript
changed, so the suite and the analyzer were not run.

## Source

Brendan's "Begin" of 2026-10-16 on the slice D split (LIVE_WORK_SLICE_D §1); DEC-039, DEC-054 (and its 2026-10-15
addendum), DEC-059, DEC-061; SET-BUILD-001 §3, §7, §9, §10, §12, BUILD-REQ-013, -015, -016, -017, BUILD-MOUND-021;
`docs/ui_ux_controls.md` UI-BUILD-003, -011, -012 and "Validity in words"; ARCH-BUILD-001; decisions 0212, 1202, 1209,
1851 (OPEN-02, -07, -10, -11), 1871, 1880, 1911, 1912, 1913, 1936, 1937, 1971, 2001, 2002;
`docs/design/underground-planning/evil-genius-2-building-study.md` §5 D and its dependency table;
`docs/design/underground-planning/levels-and-connections.md` D04 table; `docs/handoff/RULINGS.md` building rows.

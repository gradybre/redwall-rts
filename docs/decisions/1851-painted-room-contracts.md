# 1851 — Painted-room contracts: how DEC-061 lands in the owning documents

Date: 2026-10-11 · Status: Accepted (contract slice A of the Evil Genius 2 study; docs only, no code). All OPEN items ruled 2026-10-11.

Number range: 1851–1869 was allocated to this lane by the coordinator; 1851 is the only record it uses. It replaces
no BACKLOG range.

## Decision

Brendan's [DEC-061](../setting_decisions.md#dec-061--building-matches-evil-genius-2-as-closely-as-possible) is
written into the owning documents as one new GDD amendment,
[SET-BUILD-001](../building_model_amendment.md) (`docs/building_model_amendment.md`), plus short pointers and
sections in the GDD, the UI contract (UI-BUILD-001–014), the balance document (BAL-ROOM-001), the architecture
(ARCH-BUILD-001), SET-MOVE-001 (level count closed) and SET-MOVE-ECON-001. The study's slice plan gains a re-planned
slice G and a dependency table. Where DEC-061 leaves a value open, the contract either derives it exactly from an
existing number or marks it PROPOSED with an `OPEN-nn` entry below.

## Why, and the engineering choices

Each choice below is this lane's, made so that later code slices can build without inventing anything.

- **E1 — An amendment document, not a GDD rewrite.** The GDD's §5.9 building and furniture tables, and balance
  §4.1–4.3, are parsed by `docs/validation/setting_contract.py` (it asserts 30 buildings and 9 furniture and resolves
  every material key). Rewriting them would break that contract check, and the tables remain the source of every
  bill. So they stay, with “amended by SET-BUILD-001” pointers, and new tables avoid the `id`/`footprint_x`/`floor_x`
  column names that check selects on.
- **E2 — New room types are appended** (`STORE=8` … `QUARRY_SHED=16`) and new key items take furniture IDs 9–17,
  so no existing ordinal moves. Activation goes through a versioned catalog fingerprint with refusal of older saves,
  as DEC-044 did.
- **E3 — Thirteen buildings become rooms, seventeen stay outdoor items** (SET-BUILD-001 §5.1). DEC-061 names well,
  fence, paths, weir and apiary as outdoor; the lane classified open-air or open-sided structures (stockpile, dryer,
  composter, nursery, saltpan, lookout, memorial garden, workbench shelter, fisher shelter) and boundary pieces (stone
  wall, gate) the same way. PROPOSED, OPEN-03.
- **E4 — One key item per black-box building**, carrying that building's whole service (slots, store, passive slots,
  unlock, upgrade). The kitchen is the exception: its two cooking slots already exist as two `kitchen_bench`
  furniture pieces, so a KITCHEN room uses two benches and a hearth rather than a new item.
- **E5 — Costs (OPEN-01).** Of the three derivations needing no new constant, (b) is recommended and written into
  BAL-ROOM-001 as PROPOSED: the key item carries its building's existing bill; surface cells pay one shell rate
  derived from the residence, the only GDD building whose bill is pure shell: `ceil_div(c × bill_residence, 192)`
  for `c` cells, exact at the residence's 8 × 6-tile floor. Option (a), cells carrying everything, was rejected as
  the recommendation because an underground room of the same type would get its machine free.
- **E6 — Underground cell price is derived, not proposed:** 4 quanta per cell from the level pack's 4096 u clear
  height, priced by DEC-059's active 4230 milli-WU and ECON-002's wood 250 / stone 250 per quantum.
- **E7 — Level planes.** Underground level k's floor is quantum y = −5k from the initial level pack's datum; the pack
  already holds `level_spacing_u` 5120, clear height 4096, roof band 1024 and footing 1024, and level 4's footing
  (quantum −21) fits its −32 minimum. The terrain-cover check over level 1 stays with the geometry owner.
- **E8 — Access tiles are the exact conversion of the GDD's “adjacent walk tile”**: any 2 × 2-cell block sharing
  an edge with the footprint (seats: above or below; bench and hearth: along either long side), with “at least one
  usable”. Access is deliberately **rotation-independent**: the first draft used a single −Z front tile, and the
  review found that `starter_structures.gd` writes rotation 0 for all 31 starter pieces (and refuses any other), so a
  front-only rule would have invalidated the row-0 beds, the bench, the hearth, the row-5 seats, seat (9,2) and the
  kitchen shelf. Wall-behind means “a footprint edge touches a generated wall or earth”, also rotation-independent.
  It is authored only where the starter layout is consistent (bed and seat: no, since starter beds and seats stand
  free); other wall-behind values are PROPOSED (OPEN-05). **Starter check:** beds on tile rows 0, 2 and 4 reach walk
  rows 1, 3 or 5; seats on rows 2, 4 and 5 reach rows 3, 3 and 6 (seat (9,2) by (9,3)); the bench reaches
  (6,1)–(7,1); the hearth reaches (8,1) while (9,1) holds the kitchen shelf, which is why “at least one” is required;
  the kitchen shelf reaches (8,1); all five shelves touch an outside wall. Every room still
  meets its minimum (dormitory 40 tiles for 12 beds, kitchen 10, common 25 with 12 seats, pantry 5).
- **E9 — Repainting another type over a room is refused**, not converted. DEC-061 Q8 allows growing and shrinking
  but not changing type in place, and ADR 1081 says a Kitchen cannot become a Bedroom by clearing its contents.
  Removal is a separate paint (Earth underground, Clear ground on the surface) that opens the demolition review.
- **E10 — Half partitions.** A painted room can be an odd number of cells long, so a partition may span one cell
  edge; it costs exactly half the GDD tile-edge partition (500 milli-U wood, 4000 milli-WU), both exact.
- **E11 — Doors.** A surface room group needs a walk path to a door item on its outside boundary (REQ-SET-122's
  “accessible door”, GDD's “connected to exterior door”). The door is the existing `interior_door` row; there is no
  separate exterior door catalog entry. This adds one door bill (wood 2000 milli-U, 12000 milli-WU) to every
  surface room group; it follows from REQ-SET-122 rather than a new price.
- **E12 — PageUp/PageDown change level, so keyboard zoom moves to = / −** (PROPOSED, OPEN-09). The GDD UI bound
  PageUp/PageDown to zoom, while the demo, the study and the brief use them for levels; = and − are unbound in
  `godot/project.godot` and the demo. Alt+PageUp/PageDown pitch is a different chord and stays.
- **E13 — UI rows are a new family (UI-BUILD-001–014) at the end of the UI document**, with pointers in UI-SET-027
  and 052–058, instead of new rows inside §4. §4 holds 103 rows that `godot/test/test_ui_registry.gd` and
  `ui_registry.gd` transcribe; the slice that builds the panel extends both.
- **E14 — The build panel hides the command strip and detail while open**, so it can take the full bottom interval
  (480–912 × 256). Rectangles were checked by the equations in UI-BUILD-001 “Geometry” at 1280×720, 1920×1080 and the
  narrowest 853.33 × 480 logical viewport; they are equations, not rendered evidence.
- **E15 — Manifests left unchanged.** `docs/planning/movement_profile_readiness.json` Q2-26 keeps `value: null`,
  because `tools/test_movement_profile_policy.py` forbids values in slots, and
  `docs/planning/underground_economy_hazard_values.json` keeps `depth.status = CANDIDATE_NOT_ADOPTED`, because its
  oracle asserts it. Both are authoring records; DEC-061 supersedes them for active content, the same way BAL-UG-001
  left the manifest's work values in place for DEC-059. The documents that read them now carry a pointer.
- **E16 — Memory not recomputed.** No column width or capacity is chosen for the 1 m grid, so no bytes are written
  into the ledger; ARCH-BUILD-001 states the exact counts (327680 cells; 1048576 room-cell quanta underground; 3145728 quanta in the
  whole pack domain, which bounds connectors) and lists
  the slice-B obligations.

## Consequences

- After Brendan's rulings no slice waits on a ruling. Slice D still needs the steeper flight qualified (OPEN-10 (a)),
  and slices D and G author OPEN-02's per-item geometry.
- DEC-031's “placed burrows” are read, under DEC-061, as painted rooms opened from a placed entrance (the H/C
  templates are retired). Brendan confirmed this reading (OPEN-11 (a), 2026-10-11).
- The demo's polyline tunnel tool, H/C templates and 4 m second level are superseded by contract; they stay playable
  until the slices replace them.
- `room_catalog.gd`'s refusal to author access offsets is overruled by DEC-061 Q7 for slice E; its height and
  clearance profile requirement stays.
- A future reader must not re-derive the balance §4.1 footprints as room sizes: for rooms they are only cost and
  capacity sources.

## OPEN list for Brendan

Each needs a ruling before the slice named. Recommendation in bold.

1. **OPEN-01 — Who pays on the surface: the room's cells or its machine?** (slice G)
   (a) Cells pay the whole old building bill, spread over its area; machines free.
   **(b) Machines carry their old building's bill; every surface room's cells pay one wall-and-roof rate taken from
   the residence (a 2 × 2 room: 1¼ logs, ½ block of stone, a little cloth, 25 work-minutes).** Surface buildings cost more
   than today: painted at the old footprint size (144 cells), a covered store goes from wood 35, stone 10,
   480 work-minutes to wood 80, stone 28, cloth 6, 1380 work-minutes, and every surface room now needs some cloth.
   A room painted tightly around its machine costs less. Balance probes are rerun.
   (c) Split each bill by a fixed fraction (needs a number from you).
   (a) would make an underground mill's millstone free, because underground rooms pay digging, not walls.
2. **OPEN-02 — Shapes for the new machines and the other stair families.** (slices D, G) The nine key items
   (store bay, cellar bay, craft bench, millstone, smoker, boat slip, brew vat, forester rack, quarry rack) and the
   ramp, stone stairs, spiral stairs and ladder/hatch have no measured footprint, access tiles or fixture bill.
   **(a) Author each from the asset dimensions in its slice, starting with 4 × 4 cells and one front access pair as a
   placeholder for review**; (b) give every machine the old building's footprint (much larger rooms).
3. **OPEN-03 — Which old buildings stay outside, and which levels rooms may use.** (slice G) **(a) As tabled in
   SET-BUILD-001 §5.1: eleven more structures (open-air, open-sided or boundary pieces) stay outdoor items; boathouse, forester lodge and
   quarry shed rooms are surface-only; other rooms any level**; (b) make the fisher shelter, workbench shelter and
   nursery rooms too.
4. **OPEN-04 — Services that belonged to a building with no machine.** (slice G) **(a) The hall's two Keeper places
   go with the central hall's hearth; each infirmary room has two Healer places; the kitchen's own 100 kg buffer goes
   away and kitchens draw from a nearby pantry or store, as the starter kitchen does**; (b) keep a kitchen buffer as
   an extra shelf requirement.
5. **OPEN-05 — Which pieces need a wall behind them.** (slice E) **(a) Hearth and shelf yes; patient bed and kitchen
   bench no** (beds and seats are already no, from the starter layout); (b) no wall-behind on anything.
6. **OPEN-06 — Painting a bridge between two rooms of the same type.** (slice F) **(a) They join into one room, the
   older one's identity surviving, as in EG2**; (b) refuse and ask the player to remove one first.
7. **OPEN-07 — Planning a deeper level before its stairs are built.** (slice C) DEC-061 says building the entrance
   opens level 1. **(a) Also allow painting level 1 against an entrance that is only planned in the same batch; the
   digging waits for it, as in EG2**; (b) level 1 is paintable only after the entrance is finished.
8. **OPEN-08 — Tier-2 upgrades.** (slice G) **(a) The store and workshop upgrades attach to their machines; the
   residence/hall upgrade becomes a per-room upgrade of living rooms, priced by area like the walls**; (b) drop
   upgrades for painted rooms.
9. **OPEN-09 — Zoom keys.** (slice B) PageUp/PageDown change level (as in the demo and EG2). **(a) Keyboard zoom
   moves to = and −**; (b) zoom keeps PageUp/PageDown and levels use another key.
10. **OPEN-10 — How the first entrance reaches level 1, 5 m down.** (slice D) The only qualified stair (the first
    entry's flight, ADR 1209) drops 128 u per 512 u tread, so 5 m needs 40 treads over 20 m. **(a) Qualify a steeper
    earth/timber flight for a full level (new motion work) and keep the 20 m flight as the fallback**; (b) accept the
    20 m flight as the entrance; (c) make the burrow-mouth ramp (1:2.5, 12.8 m) the first entrance once qualified.

11. **OPEN-11 — What DEC-031's “placed burrows” become.** (slice D) DEC-031 confirmed that placed burrows, planned
    tunnels and free digging work together. DEC-061 retires the burrow templates. **(a) A “placed burrow” is now a
    painted room reached from a placed entrance, with no separate template**; (b) keep the burrow home and root
    cellar as one-click room presets that paint a fixed shape into the same batch.

## Gates

Run in this worktree after the edits (summary lines in the lane report): `decision_numbers.py`,
`ready07_arithmetic.py`, `merge_gate.py`, `setting_contract.py`, `state_registry_coverage.py`,
`ui_refinement_contract.py`, `validate_underground_economy_hazards.py`, `ready07_addendum_checks.py`,
`dispatch_plan.py --validate`, `lane_notes.py --check`, `astra_inbox.py --check`,
`underground_memory_budget.py --check`, the three cycle handoff validators, the movement profile and envelope tests,
`validate_save_registry_handoff.py --source-root .` and `generate_canonical_state_table.py --check`. No GDScript
changed, so the Godot suite and analyzer were not run.

## Brendan's rulings (2026-10-11)

Relayed by the coordinator: on 2026-10-11, in chat, using the AskUserQuestion tool, Brendan chose the recommended
option on **all eleven** OPEN items above.

| Item | Ruling |
|---|---|
| OPEN-01 | **(b)**, machines carry their old building's bill, and room cells pay the residence-derived wall-and-roof rate |
| OPEN-02 | **(a)**, author each item's and connector family's geometry and bill in its slice, from a 4 × 4-cell placeholder |
| OPEN-03 | **(a)**, the outdoor/room split and level eligibility as tabled in SET-BUILD-001 §5.1 |
| OPEN-04 | **(a)**, the services move: hall Keepers to the central hearth, Healers to each infirmary room, kitchen buffer dropped |
| OPEN-05 | **(a)**, hearth and shelf need a wall behind; patient bed and kitchen bench do not |
| OPEN-06 | **(a)**, same-type rooms merge and the older one survives |
| OPEN-07 | **(a)**, paint against a planned entrance; the digging waits for it |
| OPEN-08 | **(a)**, upgrades move onto machines (store, workshop) and living rooms (residence/hall package by area) |
| OPEN-09 | **(a)**, PageUp/PageDown change level; keyboard zoom on = and − |
| OPEN-10 | **(a)**, qualify a steeper earth/timber flight for the first entrance, with the 20 m flight as fallback |
| OPEN-11 | **(a)**, a placed burrow is a painted room reached from a placed entrance |

Every PROPOSED tag these settle is now ADOPTED in SET-BUILD-001, BAL-ROOM-001, UI-BUILD, the GDD, SET-MOVE-001 and the
study. Still to be authored, not ruled away: OPEN-02's per-item values (each slice authors them for review) and
OPEN-10's steeper flight (new motion qualification work).

## Review

An independent `code-reviewer` read the first commit. It confirmed every link, anchor and ID, the one-to-one mapping
of 30 buildings and 9 furniture types, and all of the arithmetic. It raised 2 HIGH, 8 MEDIUM and 8 LOW findings, all
fixed in the second commit:
- HIGH: the front-only access rule failed the starter at rotation 0 (now rotation-independent, E8).
- HIGH: the connector card overlapped the narrow alert zone (it now sits inside the panel in NARROW).
- MEDIUM: PROPOSED items were stated as settled in the GDD, balance and UI (now tagged).
- MEDIUM: the kitchen's 2-bench wording was ambiguous.
- MEDIUM: “twelve” outdoor items should be eleven.
- MEDIUM: the quanta bound covered room cells only (connectors now bounded by the pack domain).
- MEDIUM: painted stores had no container owner (now slice-B obligation 4).
- MEDIUM: removal could not be reached by mouse in build mode (Remove tool card added).
- MEDIUM: DEC-031 was reinterpreted silently (now OPEN-11).
- MEDIUM: OPEN-01's cost increase was understated (worked totals added).
- LOW: removal now uses the paid ledger; digging uses priority order with parallel faces; the ramp run is stated as a
  minimum; the heat group is defined by one roof; “start, not finish” is explicit for slices B–F; Passage is offered
  on every level; REQ-SET-134 is re-read for kitchens; the door bill is noted.

## Source

DEC-061 (Brendan, 2026-10-11, in `docs/setting_decisions.md`); the Evil Genius 2 study; GDD §4.2, §4.3, §5.9;
balance §4.1–4.3 and BAL-UG-001; SET-MOVE-001; SET-MOVE-ECON-001 with DEC-052 and DEC-059;
`godot/data/underground/initial_level_pack.json`; `godot/scripts/core/room_connectors.gd` and `room_catalog.gd`;
ADRs 0212, 1081, 1202, 1209; DEMO-CONTAIN-R01.

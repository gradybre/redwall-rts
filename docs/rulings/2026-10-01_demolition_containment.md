<a id="DEMO-CONTAIN-R01"></a>
# DEMO-CONTAIN-R01 — Demolition containment, ground piles and furniture returns

**Status:** adopted, 2026-10-01. **Approved by Brendan on 2026-10-01** ([DEC-043](../setting_decisions.md));
recorded by the executor in [decision 0531](../decisions/0531-demolition-containment-is-adopted-and-containers-carry-an-anchor-tile.md).
The proposal was drafted against `origin/master` `df9aec3`; its line numbers refer to that commit.
The approved endpoint contract is summarised in
[`destructive_edit_endpoint_contract.md`](../planning/destructive_edit_endpoint_contract.md).

This closes the question decision 0145 and decision 0511 §1 left open: **who owns the
container-by-tile (container placement) binding** that stage 5 of
`settlement_system.gd::request_demolition()` refuses without (`MISSING_CONTAINMENT_CONTRACT`).
It does **not** close REQ-SET-127/128 or CONSTRUCTION-EVACUATION-INTEGRATION: those close only
on the composed runtime acceptance of steps D2–D9 below.

## Brendan's rulings, verbatim

- Answers 1-9: APPROVED as recommended (including the new ground-pile rules in #9).
- Furniture removal returns 50% of its materials (same rule as buildings), NOT the intact item.
- Scope: FULL PATH (~16-20 sessions), including INIT-C live apply, evacuation hauling, rooms/furniture teardown, tier-2 refunds (BUILD-C4-R01), dispatch/UI, movement invalidation.

## The approved answers, verbatim

The table and the two corrections that precede it are reproduced exactly as approved.
"Approved as recommended" means the **Recommendation** column is the rule. The **Alternative**
column is the rejected option, kept so a later reader can see what was weighed.

Two corrections to the brief before the table:
- **The tier-2 basis is already ruled.** BUILD-C4-R01 (`docs/rulings/2026-09-19_cycle04_resumption.md:32-56`; `open_items.json` "answered 2026-09-19, implementation_complete false") says the return is computed from the recorded base package plus each completed upgrade, floored once per item. Only the implementation is missing.
- **Furniture refunds are handled separately.** The same ruling says furnishings "remain a separately owned item/instance" and are not refunded through building costs.

Line numbers below are from origin/master. GDD = `docs/game_gdd.md`, ARCH = `docs/systems_architecture.md`.

| # | Recommendation | Alternative | Why (citations) | Cost |
|---|---|---|---|---|
| 1 Owner | Add an `_c_anchor_tile` I32 column to `inventory.gd`, next to `_c_owner_*` (:399). Inventory writes it in `create_container` and in a new `set_container_anchor`. Stage 5 does a bounded cold scan over all containers to collect those whose anchor is in the affected tile set, the same shape as `containers_by_owner_into` (:2853). | A `container_slot`/`container_generation` WorldTileMaps column in `buildings.gd` (:298). | R-BUILD-DOM-004 (`2026-09-11_building_room_domains.md:178`) says Inventory owns containers and forbids a parallel store. A tile map in `buildings.gd` would hold refs from the Inventory namespace that Buildings cannot check (the same problem as `construction.gd` :1068). INV-GOODS-R01 permits a bounded scan on a cold path and forbids an unbudgeted index. | 101376×4 = **405,504 B**. The alternative is 16384×8 = 131,072 B. Work: about 1 session. |
| 2 Shape | One anchor tile per container (container→tile). A tile may hold several containers: a building store, a project container and **at most one** ground pile. "Unplaced" is `-1` (satchels and expedition packs). | A tile→container map. It holds only one container per tile, so a store, a project and a pile on one tile cannot all be recorded. | ARCH-MEM-002 (:31) counts 1024 building + 512 satchel + 82944 project + 512 expedition + 16384 ground-pile containers, which allows one pile per tile. Interiors use the same 128×128 grid (`buildings.gd` `_is_interior_tile` :883). Pile spill rule: GDD :668. | Included in #1. The one-pile-per-tile rule is enforced where piles are created (#9). |
| 3a Main store | **Anchored explicitly** at the building's origin tile. The gate requires the owner scan and the tile scan to agree; a building-owned container whose anchor is off the footprint is a refusal. | Treat the store as implicitly located by its footprint, with no anchor. | Decision 0145 says owner equality proves ownership but not physical containment. Two independent proofs are more honest than one inferred one. | No extra memory. |
| 3b Pantry shelves | **Not containers.** A shelf adds 50,000 g of capacity to the Building-owned pantry container. Removing a shelf refuses if the remaining contents or reservations would exceed the reduced capacity. | One container per shelf, owned by the furniture. | R-BUILD-DOM-004 (:169-179) says 4×50000 pantry, the kitchen shelf adds no container, and capacity removal must preserve goods and reservations. ARCH-MEM-002 budgets no furniture-owned containers. Per-shelf containers would require recomputing the 101,376-container bound. | None. A capacity-recompute rule is needed in 06.4. |
| 3c Project material | Owned by the Project and anchored at the subject's origin tile (the building, or the furniture origin). The coordinator creates it when the project opens. | Leave it unanchored and prove it only through `material_container`. | The gate already validates this handle against Inventory (`settlement_system.gd` :2736-2775). An anchor shows where it physically sits. | None. |
| 3d Satchel | **Excluded** (anchor `-1`). The occupant gate covers it. | Anchor it to the resident's current tile every tick. | INV-GOODS-R01 says goods in a satchel stay with the resident and the occupant gate remains authoritative. Updating the anchor every tick would mean a hot-path write. | None. |
| 4 Levels | **Wait for MOVE-G02.** Store the anchor as an I32 "placement cell" so a later level-plus-tile encoding fits in the same column width. No level column now. | Add an I32 level column now, defaulting to 0 (another 405,504 B). | ARCH-MEM-002 is baseline-only: "Recompute under MOVE-G02; do not multiply by an invented floor count". Task 06 still requires telling apart same-X/Z spaces on different levels, so this is a known widening later. | Nothing now. A save-schema bump when G02 lands. |
| 5 Affected tiles | **The footprint only.** That includes the door tiles, because the doorway is part of the footprint wall. Containers on the outside access tiles are reported as surviving, not as blocking. | Footprint plus the one-tile apron (the GDD :275 init clearance). | A pile outside the building survives demolition, so treating it as stranded would refuse demolitions for no reason. Decision 0145's "pile in the doorway" sits on a footprint tile. **To verify:** door tiles are footprint-perimeter tiles (GDD :690, door at interior x5 plus a 1-tile inset). | None. |
| 6 Removal order | At completion, the coordinator (`settlement_system.gd`) runs one no-yield commit. First it re-runs the gate. Then it validates every step, and only then mutates: (1) destroy footprint containers owned by the building or project; `inventory.destroy_container` already refuses a nonempty container. (2) Remove furniture (`remove_furniture` :1256). (3) Remove rooms (`remove_room` :923). (4) `demolish_building` (:643). (5) Place the 50% return into capacity reserved at admission. (6) Retire the project and advance the movement revision. **The coordinator destroys building-owned containers**, not Inventory or Buildings. | Make the player clear furniture and rooms first, and keep the BUILDING_HAS_ROOMS refusal. | Decision 0145 makes `settlement_system.gd` the only place the stores meet. Decision 0059 requires allocate-before-consume. Inventory's journal does not cover Buildings or Construction (INV-GOODS-R01 "not atomic"). | 2 sessions, including tests that refusal leaves state byte-identical. |
| 7 Ownerless containers | When INIT-C materialises the starter colony, rebind EconomySystem's pantry to the hall Building and the material store to the four stockpile Buildings (400,000 g each). Then `create_container` refuses a `NULL_REF` owner. Until that happens, an unanchored `NULL_REF` container sits outside every footprint, and an *anchored* `NULL_REF` container is a refusal. | Give them to the World directory row (`kind=world`). | `economy_system.gd` :148-151. GDD :690 gives the hall/stockpile placement and 4×400 kg capacity. INV-GOODS-R01 says orphan or stale ownership must be rejected by whoever composes the stores. | Part of INIT-C. Save migration is covered by #8. |
| 8 Save | Section 7 `inventory` owner schema **3→4** and section schema **4→5** (`save_section_inventories.gd` :208-219). **Hashed**, because placement is authoritative state. Refuse v4 saves rather than migrate them, following FISH-ID-R01 ("schema 3 is refused"). Memory: a new ARCH §2 fixed-field row, "InventoryContainer anchor_tile I32 ×101376 = 405504". | A section 1 `buildings` WorldTileMaps column. That reopens ARCH-SAVE-009's frozen nine-block payload and the not-yet-finished BUILDINGS-SAVED-BINDINGS work (`save_owner_buildings.gd` :35-39). | ARCH-SAVE-007 (:850) already keeps the comparable `InventoryContainer.reachable` persisted and hashed in section 7. | Live headroom is 21,595,565 B, so +405,504 fits. The transactional peak is already -42 MB over budget (ARCH :259-262); this adds to it, and that must be stated. |
| 9 Ground piles | Inventory publishes a single `create_ground_pile(tile)`. Rules: owner = World ref; a GROUND_PILE policy value; 400,000 g capacity; storage class 1500; one pile per tile; tile must be in bounds and passable. When full, spill to neighbours breadth-first in N, E, S, W order, capped at 16,384 tiles. A pile can never be placed on a DEMOLISHING, destroyed or inaccessible footprint. An empty pile is reclaimed when the operation commits. Refunds place lots by breadth-first search from the door's outside access tile, excluding the footprint. | Leave REQ-SET-126/127 returns as a refusal until hauling (06.4) lands. | GDD :615 (REQ-SET-110), GDD :668, ARCH-MEM-002 reclaim rule. INV-GOODS-R01 allows a pile only "through its authored placement/capacity/access contract". | Optional: a derived, unsaved tile→pile map (16384×4 = 65,536 B) so the one-per-tile check is not a 101k-row scan. **Needs Brendan's approval**, because it is new rules. 1-2 sessions. |

## The furniture rule, verbatim

> Furniture removal returns 50% of its materials (same rule as buildings), NOT the intact item.

What this changes, and what it does not:

* **It amends BUILD-C4-R01's furniture sentence.** BUILD-C4-R01 said furnishings are not refunded
  through building costs and that "each remains a separately owned item/instance". The first half
  stands: a building's 50% is still computed from the building's own paid packages and never
  includes furniture. The second half is replaced: removing a piece of furniture does **not**
  return the intact piece. It returns 50% of that piece's own materials.
* **"Same rule as buildings"** is read as REQ-SET-127's rule applied per piece, with
  BUILD-C4-R01's arithmetic: total the piece's recorded material package in milli-U per item,
  then floor the 50% once per item. *Executor's reading, to be confirmed in D5 rather than
  invented there:* the removal work is one quarter of the piece's construction WU, exactly as
  for buildings. If D5 finds the furniture build record does not carry a paid package to read,
  it refuses rather than repricing from the current catalog (BUILD-C4-R01: "never reprices
  historic work from the current catalog").
* The return goes to capacity reserved at admission, with ground piles (#9) as the fallback,
  exactly like the building return (blocker 3).

## Blockers named with the proposal, adopted as the plan of work

1. **The gate never calls `open_demolition`.** Proposal: split `request_demolition` into *preview* (what it does today) and *admit*. On a pass, *admit* runs in the same call with no yield. It snapshots the tier and paid packages (BUILD-C4-R01), reserves output capacity, calls `construction.open_demolition` (:672) and advances the destination revision. Every check runs before the first write.
2. **Completion refuses BUILDING_HAS_ROOMS** (`construction.gd` :911, `buildings.gd` :650). Use the order in #6. **A ruling is still needed** on what removing a piece of furniture returns. BUILD-C4-R01 excludes furniture from the building refund but authors no furniture return.
3. **The tier-2 basis and where the 50% goes.** Implement BUILD-C4-R01 using the already-budgeted `ConstructionPaidLedger` (ARCH :463, 663,552 B). `demolition_return_milli_into` (:979) currently reads only the base row. The destination is capacity reserved at admission, with ground piles (#9) as the fallback.
4. **No jobs, hauling or evacuation coordinator.** JOB_KIND has HAUL and BUILD (`catalog.gd` :73), but `work.gd` and `jobs.gd` never reach `construction`, and task 06.4 (physical hauling) is unchecked. Proposal: add demolition work under BUILD. Add evacuation HAUL jobs posted by a persisted "evacuate then demolish" intent in the coordinator. Retry *admit* once the source containers report empty. CONSTRUCTION-EVACUATION-INTEGRATION is "ready", but `destructive_edit_endpoint_contract.md` does not exist yet.
5. **No DEMOLISH command dispatch, and the UI is disabled.** `command_dispatch.gd` :180-189 has no DEMOLISH arm, though catalog id 6 exists. `ui_availability.gd` row 034 shows NO_BUILDING_STORE. Proposal: add a dispatch arm whose payload is the building ref, and surface the DemolitionReport's exact stranded lots and occupants (REQ-SET-128). Also needed: REQ-SET-158's pre-demolition quicksave.
6. **Nothing to demolish in real play.** `starter_structures.gd` only produces a plan (decision 0184), and nothing calls `place_building` (:549) at runtime. Proposal: an INIT-C apply step that creates the 7 buildings, 4 rooms and 31 furniture, and rebinds the containers (#7).
7. **Movement contact invalidation isn't wired.** When a building is admitted and when it is removed, advance the topology revision and `destination_revision` (`movement.gd` :373, :784), clear the footprint tiles, and re-check affected routes (MOVE-REQ-006). Haul loads must agree before a crossing (MOVE-REQ-019). Retest MOVE-TEST-05/10.

Blocker 2's open question ("A ruling is still needed on what removing a piece of furniture
returns") is answered by the furniture rule above.

**Answer 5's "to verify" is verified.** GDD §5.9 puts the starter hall's exterior south door at
interior x5, and `buildings.gd::_is_interior_tile()` defines the interior as the footprint inset
by `INTERIOR_INSET_TILES` = 1. The door therefore sits on the footprint's one-tile perimeter
ring, inside the footprint rectangle, so "footprint only" includes it. One gap remains and is
handed to D2/D5: `buildings.gd` stores **no exterior door column**, so the door's *outside access
tile* that #9's refund placement starts from must be derived from the authored layout, not
assumed.

## Scope: the full path, as steps D1–D9

Brendan approved the full path (estimate below, 16-20 sessions). The executor numbers it as
nine steps. Each step lands as its own reviewed branch, in this order unless a dependency says
otherwise; none of D2–D9 is authorised to change a rule above.

| Step | Work | Depends on | Answers / blockers |
|---|---|---|---|
| **D1** | Record this ruling. Add `inventory.gd`'s `_c_anchor_tile` I32 column (unplaced = -1), `create_container`'s optional anchor, `set_container_anchor()`, and the bounded cold-path anchor query. Section 7 `inventory` owner schema 3→4, section schema 4→5, hashed; older saves refused. ARCH §2 memory row. **Stage 5 still refuses.** | — | #1, #2, #4, #8 |
| **D2** | Ground-pile contract: `create_ground_pile(tile)` with every #9 rule (World owner, GROUND_PILE policy, 400000 g, storage class 1500, one per tile, in-bounds and passable, N/E/S/W breadth-first spill capped at 16384 tiles, never on a DEMOLISHING/destroyed/inaccessible footprint, empty-pile reclaim at commit, refund placement from the door's outside access tile). The optional derived tile→pile map (65536 B) is approved with #9 and must be ledgered if built. | D1 | #9 |
| **D3** | INIT-C live apply: materialise the 7 starter buildings, 4 rooms and 31 furniture; rebind EconomySystem's pantry to the hall and the material store to the four stockpiles (400000 g each), anchored at their origin tiles; then `create_container` refuses a `NULL_REF` owner. | D1 | #3a, #3b, #7, blocker 6 |
| **D4** | Gate pass and *admit*: stage 5 gains its success path from the anchor query (owner scan and tile scan must agree; an anchored `NULL_REF` container or an off-footprint building-owned container refuses). Split `request_demolition` into preview and admit; admit snapshots tier and paid packages, reserves output capacity, calls `open_demolition`, advances the destination revision, all before the first write. Implement BUILD-C4-R01's tier-2 basis from `ConstructionPaidLedger`. | D1, D2, D3 | #3a, #3c, #3d, #5, blockers 1, 3 |
| **D5** | Composed completion: the #6 one-commit removal order (containers, furniture, rooms, building, 50% return, retire project), furniture returning 50% of its materials, pantry-shelf capacity recompute (#3b), refusals byte-identical. | D4 | #3b, #6, furniture rule, blocker 2 |
| **D6** | Evacuation hauling: demolition work under BUILD, evacuation HAUL jobs from a persisted evacuate-then-demolish intent, retry *admit* once sources report empty. | D5, task 06.4 | blocker 4 |
| **D7** | DEMOLISH command dispatch (payload = building ref), the UI row 034 path, the exact stranded lots/occupants notice (REQ-SET-128) and REQ-SET-158's pre-major-demolition quicksave. | D4 (D6 for the evacuation flow) | blocker 5 |
| **D8** | Movement invalidation on admit and removal: topology revision, `destination_revision`, footprint clearing, route re-check (MOVE-REQ-006/019); retest MOVE-TEST-05/10. | D5 | blocker 7 |
| **D9** | Independent QA and review of the composed path, and a visible Mac run. Closes REQ-SET-127/128 and CONSTRUCTION-EVACUATION-INTEGRATION only if everything above passes. | D2–D8 | — |

Answer #4 (levels) is **deferred to MOVE-G02** by the ruling itself: the anchor is an I32
placement cell so a later level-plus-tile encoding fits in the same width, and that encoding is
a future save-schema bump, not part of D1–D9.

## Implementation status

| Step | State | Record | What landed |
|---|---|---|---|
| D1 | in review (branch `feat/demolition-d1`) | [decision 0531](../decisions/0531-demolition-containment-is-adopted-and-containers-carry-an-anchor-tile.md) | The anchor column, its two write doors, the bounded anchor query, section 7 schema 5. |
| D2 | done (branch `feat/demolition-d2`) | [decision 0532](../decisions/0532-ground-piles-are-placed-breadth-first-and-reclaimed-at-commit.md) | #9 in full, plus the follow-up ruling below: `inventory.gd::create_ground_pile()`, the derived unsaved tile -> pile map, reclaim at commit, and `ground_piles.gd`'s site authority, all-or-nothing N/E/S/W placement (16384-tile cap) and refund start tiles (door, or the footprint's ring front-first). No save schema change. |
| D3 | done (branch `feat/demolition-d3`) | [decision 0533](../decisions/0533-the-starter-colony-is-materialised-and-the-stores-are-owned-by-it.md) | INIT-C live apply: `starter_colony.gd` places the 7 buildings, 4 rooms and 31 floor furniture inside the generation transaction (and on Create), verified against the plan; the World row is created and `ground_piles.gd` composed and bound; `buildings.gd` refuses a footprint over a live pile (0532's M4); EconomySystem's pantry is owned by the hall and its material store is four 400000 g stores owned by the stockpiles, all anchored at their origin tiles; `create_container()` refuses an ownerless container. No save schema change. **The stores are still in EconomySystem's own inventory, not the one the gate reads** -- see 0533's Consequences before D4. |
| D4 | done (branch `feat/demolition-d4`) | [decision 0534](../decisions/0534-demolition-admit-and-the-adopted-inventory.md) | Stage 5's success path: the owner scan and the tile scan must agree (`container_anchor_tile_into()`), an anchored ownerless container or an off-footprint affected container refuses, a pile on the footprint is counted. `request_demolition()` = `preview_demolition()` + *admit*: every check first, then the return's capacity reserved in one surviving store (else a rolled-back ground-pile proof), `open_demolition()` with BUILD-C4-R01's snapshot, and the building's destination revision. ConstructionPaidLedger implemented; tier-2 returns total base + upgrade and floor once. EconomySystem adopts the settlement's inventory (`bind_inventory()`), so the gate sees the starter stores. `cancel_demolition()` releases the claim before retiring the project. Brendan approved 0534's five proposals as built on 2026-10-01 (store choice, pile fallback, revision owner, starter base package, free cancellation); 0534 records them as rulings R1–R5. |
| D5-D9 | not started | -- | -- |

**Follow-up ruling, 2026-10-01** (Brendan, recorded under [DEC-043](../setting_decisions.md)),
answering the two points D2 raised:

* **Doorless structures** (wells, workbenches, stockpiles, any building without an authored door)
  start the refund search from the ring of tiles touching the footprint, nearest to the building's
  front first, then spill outward breadth-first N/E/S/W as usual. "Front" is the side the
  building's rotation faces; where a type defines no front, use the rotation-0 south side rotated
  by the building's rotation, and record that choice. Buildings with an authored door keep
  starting outside the door.
* **Footprints.** A ground pile never sits on any standing building's footprint, and one being
  demolished is refused by name. This is Brendan's confirmed reading of "inaccessible footprint".

How D2 implements it (decision 0532 records each choice):
* No building type defines a front, so every front is the rotation-0 south side turned a quarter
  clockwise per rotation step (UI-SET-056): rotation 0 faces S, 1 W, 2 N, 3 E.
* Only the GDD §5.9 hall at rotation 0 has an authored door, so a rotated hall uses its ring too.
* "Touching" means sharing an edge, so the four corner tiles are not in the ring.
* "Nearest" is Manhattan distance, in half tiles, to the centre of the front side's ring segment.
  Ties go to the lower tile index.
* "Destroyed footprint" is the operation's own caller-supplied mask. It still refuses a footprint
  whose building row D5 has already removed.

## Estimate, as approved

About **16-20 agent sessions** for the full path:

| Work | Sessions |
|---|---|
| Adopt the answers in an ADR/ruling | 1 |
| Anchor column, §7 v5, memory ledger | 1-2 |
| Ground-pile contract | 1-2 |
| INIT-C live apply and container rebind | 2 |
| Gate pass and *admit*, plus the paid ledger | 2 |
| Composed completion | 2 |
| Evacuation hauling, jobs and retry coordinator | 3-4 (depends on 06.4) |
| Dispatch, UI and stranded-goods notice | 1-2 |
| Movement invalidation | 1 |
| Independent QA/review and a visible Mac run | 1-2 |

**Minimum viable slice, about 8 sessions:** a tier-1 exterior building with no rooms (for example a well, workbench or stockpile), created by INIT-C. It has the anchor column, the stage 5 success path, *admit*, demolition work under BUILD, a 50% return into ground piles, the DEMOLISH command and the UI. If goods are present it **refuses** with the exact stranded lots instead of hauling them. Not included: evacuation hauling, taking down rooms or furniture, tier-2 buildings and underground levels.

## Exclusions

* No rule above is reinterpreted by D1–D9. A step that finds a rule unimplementable refuses and
  asks; it does not pick the Alternative column.
* MOVE-G02's level encoding, underground demolition and excavation phases stay out of scope
  (ECON-C4-R01, SET-MOVE-001).
* The 16384-tile spill cap, the 400000 g pile capacity and the 1500 storage class are the
  approved #9 values; they are not balance numbers to retune inside an implementation step.

## Source

The proposal `demolition_answers.md` (executor scratch, reproduced above in full), Brendan's
rulings of 2026-10-01, INV-GOODS-R01, BUILD-C4-R01, R-BUILD-DOM-004, FISH-ID-R01,
decision 0145, decision 0511, GDD §5.9 and REQ-SET-110/126/127/128/158, ARCH-MEM-002 and
ARCH-SAVE-007.

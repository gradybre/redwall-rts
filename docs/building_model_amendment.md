# Building model amendment — painted rooms on one grid (SET-BUILD-001)

| Field | Value |
|---|---|
| Document | SET-BUILD-001, revision 1.0, 2026-10-11 |
| Authorization | Brendan, [DEC-061](setting_decisions.md#dec-061--building-matches-evil-genius-2-as-closely-as-possible): “Overall, I want us to match this functionality as close as possible to EG2.” |
| Input study | [Evil Genius 2 building study](design/underground-planning/evil-genius-2-building-study.md) (DEC-061 overrides it where they differ) |
| Amends | GDD §4.2 Building/Room/Furniture rows, §4.3 RoomType, §5.9 (tables, room validity, heat, starter layout, REQ-SET-121/122/129/136); SET-MOVE-001 level scope; UI rev 1.1 build rows; balance §4.1–4.3; architecture §2–3 room storage |
| Keeps | REQ-SET-123–128 (paths to the hall, hauled payment, 100%/80% refunds, 50% demolition return), SET-MOVE-ECON-001 excavation economy with DEC-052/DEC-059, ADR 1081 permanent room purpose, DEMO-CONTAIN-R01 |
| Status | Rules marked **ADOPTED** restate DEC-061 or derive exactly from existing numbers. Rules marked **PROPOSED** are this lane's derivations awaiting Brendan; each has an `OPEN-nn` entry in [decision 1851](decisions/1851-painted-room-contracts.md). Nothing here is runtime evidence. |
| Engineering record | [decision 1851](decisions/1851-painted-room-contracts.md) |

Notation: a **cell** is 1 m × 1 m (1024 u × 1024 u) on one level. A GDD **tile** (2 m) is exactly 2 × 2 cells: tile
`(x,z)` covers cells `2x..2x+1, 2z..2z+1`. `ceil_div` and `floor_div` are as BAL-AUTH-002. Quantities stay
`quantity_milli:int64` and work milli-WU. Living population stays capped at 256; nothing here adds residents.

## 1. What changes, in one paragraph

There is one build model on every level. A room is a set of painted cells of one room type. Furniture, machines and
connectors are **items** placed on the same cells. Outdoor structures are **outdoor items**. On the surface, walls and
roof are generated from the painted area; underground, painting a room on earth is the dig order. Tunnels are painted
Passage rooms. The entrance to the underground is a placed item. There are five levels: the surface and four
underground levels 5 m apart. Payment is unchanged: confirmed work is hauled, materials are used when work starts,
and cancel/removal refunds follow the GDD.

## 2. Requirements

| ID | EARS requirement | Status |
|---|---|---|
| BUILD-REQ-001 | The system shall represent every constructed room on every level as a set of painted cells of one room type on a 1 m cell grid (1024 u), the same grid on which items and outdoor items are placed. | ADOPTED (DEC-061 Q1, Q2) |
| BUILD-REQ-002 | When the player paints room cells, the system shall require every painted cell to lie inside at least one 2 × 2 block of cells of that same room, so that no room has a strip one cell wide. | ADOPTED (DEC-061 Q2; study §1 2×2 minimum) |
| BUILD-REQ-003 | The system shall treat each 4-connected set of same-type painted cells on one level as one room and shall apply the room rules of §4 in cells. | ADOPTED |
| BUILD-REQ-004 | When a stroke adds cells of type T touching an existing room of type T on the same level, the system shall add them to that room rather than create a second room. | ADOPTED (grow by repainting, DEC-061 Q8); joining two existing rooms is OPEN-06 |
| BUILD-REQ-005 | If a stroke would paint a room type over cells of an existing room of a different type, then the system shall refuse it with the words “Remove these cells first; a room's purpose cannot change”. | ADOPTED (DEC-061 Q8, ADR 1081) |
| BUILD-REQ-006 | When the player removes cells from a room (paint **Earth** underground, **Clear ground** on the surface), the system shall open an explicit removal review naming every affected item, occupant and stored lot and its return, and shall never sell or delete anything silently. | ADOPTED (DEC-061 Q8; REQ-SET-127/128; DEMO-CONTAIN-R01) |
| BUILD-REQ-007 | When removal of open underground cells commits, the system shall backfill each open cut quantum with `excavated_earth` under SET-MOVE-ECON-001 ECON-005. | ADOPTED |
| BUILD-REQ-008 | The system shall generate walls where painted cells meet unpainted cells, earth or the outside, and (on the surface) a roof over painted cells; it shall generate no wall between two adjacent painted rooms. Interior partitions and doors stay explicit edge items. | ADOPTED (DEC-061 Q3; GDD §5.9 partitions) |
| BUILD-REQ-009 | When a surface room is drafted, the system shall apply REQ-SET-122's terrain rules (in bounds, no overlap with rooms, items, resource nodes or water, slope ≤ 8°, height spread ≤ 0.5 m) to its painted cells, and shall require a walk path from the room to a door item on the outside boundary of its roofed room group (§4) before the room is valid. | ADOPTED (REQ-SET-122 “accessible door” restated; GDD §5.9 “connected to exterior door”) |
| BUILD-REQ-010 | When an item is placed, the system shall require its footprint cells to lie inside one room of a type the item allows (outdoor items: unpainted surface cells), to overlap no other item, to keep at least one of its access tiles free and reachable, and to satisfy its wall-behind rule where §6 declares one. | ADOPTED (DEC-061 Q7; GDD §5.9 access) |
| BUILD-REQ-011 | While an item ghost is shown, the system shall draw its footprint, its access cells and its wall-behind requirement, and shall state its validity as ✓ / ! / X with a reason in words. | ADOPTED (DEC-061 Q5, Q7; MOVE-REQ-018) |
| BUILD-REQ-012 | When a batch containing underground room cells is confirmed, the system shall create excavation for every painted cell and dig the cells one by one outward from the access face, in breadth-first priority order from the cells touching finished space, ties by cell index (parallel faces as ECON-001 allows, up to 4 builders). | ADOPTED (DEC-061 Q1–Q4; ECON-001–005) |
| BUILD-REQ-013 | While a drafted underground cell has no route to finished space or to a built connector on its level, the system shall mark it “! No way in” and refuse to confirm it. | ADOPTED; drafting against an unbuilt connector in the same batch is OPEN-07 |
| BUILD-REQ-014 | The system shall represent tunnels as rooms of type `CORRIDOR` (shown as “Passage”) at least 2 cells wide, and shall offer no polyline tunnel tool. | ADOPTED (DEC-061 Q4) |
| BUILD-REQ-015 | When the player places a surface entrance item, the system shall show its ✓ / ! / X ghost and a card stating “Connects to Underground level 1”; when the entrance is built, the system shall make level 1 paintable from it. | ADOPTED (DEC-061 Q5) |
| BUILD-REQ-016 | When the player places a connector item of the same family on a Passage on level N, the system shall offer “Connects to level N+1” or “level N−1” (an impossible direction shown disabled with its reason) and, when built, shall connect the two levels. | ADOPTED (DEC-061 Q5) |
| BUILD-REQ-017 | If removing a connector or room cells would leave any room, occupant, stored lot or reservation without another way out, then the system shall refuse the removal and name what would be cut off. | ADOPTED (MOVE-REQ-008; REQ-SET-123; study §1) |
| BUILD-REQ-018 | The system shall provide exactly five levels: the surface (level 0) and underground levels 1–4, 5120 u apart. | ADOPTED (DEC-061 Q6) |
| BUILD-REQ-019 | When the player presses Confirm all, the system shall turn the pending batch into blueprints with delivery and construction work, without deducting any material from stores (REQ-SET-124); materials are consumed when work starts (REQ-SET-125) and cancellation refunds 100% before work and 80% after (REQ-SET-126; ECON-005 per phase underground). | ADOPTED (DEC-061 “keep as we currently do”) |
| BUILD-REQ-020 | While a batch is pending, Undo and Redo shall change only drafted, unconfirmed operations and shall never alter inventory, jobs or confirmed projects. | ADOPTED (REQ-UX-012) |
| BUILD-REQ-021 | If any drafted operation in the batch is invalid, then the system shall disable Confirm all and list each invalid operation with its reason in words. | ADOPTED (REQ-UX-005; MOVE-REQ-018) |

## 3. One grid on every level

- **Cell.** 1024 u square, aligned to the excavation lattice of ECON-001 (the 1 m³ cut quantum's X/Z). The surface
  map (GDD: 256 m square, 128 × 128 tiles) is 256 × 256 cells per level.
- **Levels** (BUILD-REQ-018). Level 0 is the surface. Underground level k (k = 1..4) has its floor at excavation
  quantum y = −5k relative to the datum of `godot/data/underground/initial_level_pack.json` (datum y 512 u), i.e. world
  y = 512 − 5120k u: −4608, −9728, −14848, −19968 u. Each level keeps the pack's clear height 4096 u, protected roof
  band 1024 u and footing 1024 u. Level 4's footing ends at quantum −21, inside the pack domain's minimum −32.
  *Derived from the pack's `level_spacing_u` 5120 and DEC-061 Q6; no new constant.* Whether the terrain above a given
  level-1 cell leaves the roof band intact is the geometry owner's per-cell cover check (ECON-003, MOVE-G01), not a
  property of the level.
- **Size label.** The draft label reads cells and metres together: “17 × 6 cells (17 m × 6 m)”.
- **Items and footprints.** Every GDD footprint converts exactly: a 1 × 1 tile item is 2 × 2 cells; a tile edge is 2
  cell edges. Rotation stays 0–3 in 90° steps (R / Shift+R).
- **Room shape.** BUILD-REQ-002's 2 × 2 rule, plus `room_footprint.gd`'s existing canonical-footprint refusals
  (connected, no pinched boundary, no holes), applied on the 1 m grid.

## 4. Room rules in cells

GDD §5.9's room validity, restated exactly (1 tile = 4 cells). Furniture counts and the access-path rule are unchanged.

| Room type | GDD rule (tiles) | Rule in cells |
|---|---|---|
| DORMITORY | ≥ 3 tiles per bed, ≥ 1 bed | ≥ 12 cells per bed, ≥ 1 bed |
| PRIVATE_ROOM | ≥ 6 tiles, exactly 1 bed, partitioned enclosure | ≥ 24 cells, exactly 1 bed, enclosed by generated walls, partitions or doors |
| DINING | ≥ 2 tiles per seat, ≥ 4 seats | ≥ 8 cells per seat, ≥ 4 seats |
| KITCHEN | ≥ 6 tiles, ≥ 1 bench, ≥ 1 hearth | ≥ 24 cells, ≥ 1 kitchen bench, ≥ 1 hearth |
| COMMON | ≥ 8 tiles, ≥ 4 seats | ≥ 32 cells, ≥ 4 seats |
| INFIRMARY | ≥ 3 tiles per patient bed, ≥ 1 bed, ≥ 1 shelf, heated | ≥ 12 cells per patient bed, ≥ 1 patient bed, ≥ 1 shelf, heated |
| PANTRY | ≥ 4 tiles, ≥ 1 shelf | ≥ 16 cells, ≥ 1 shelf |
| CORRIDOR (Passage) | ≥ 1 tile wide, linked to exterior | ≥ 2 cells wide (BUILD-REQ-014), linked to an exterior door or, underground, to a built entrance |
| New room types (§5.2) | — | Large enough for their required key item's footprint and one free access tile; no further area rule |

**Heat.** A fuelled hearth heats every valid room connected to its room by open boundaries or interior doors within
one **roofed room group** (rooms whose painted cells are contiguous under one generated roof, not joined through the outside), up to 120 tiles = **480
cells** per hearth. “Within that building” in GDD §5.9 now means “within that roofed room group”; underground, a
group is the set of rooms joined without passing a connector item. Allocation order (hearth ID, then room ID) and the
whole-room rule are unchanged. REQ-SET-134's “kitchen door” is read as any walk-path entry cell of the KITCHEN
room, so a painted kitchen with open boundaries keeps the 8 m hauling bonus.

**Starter interior.** GDD §5.9's 10 × 8-tile layout is unchanged in meaning: each character becomes a 2 × 2 cell
block (20 × 16 cells), the partition at tile x4/x5 lies on cell edge x9/x10, the door on tile row 4 spans cell rows
8–9, and the south exterior door at tile x5 spans cells x10–11. Starter exterior positions convert by the tile→cell
rule (hall origin tile (58,59) → cell (116,118); interior origin = exterior origin + 2 cells). Every access rule in §6
was checked against this layout and keeps all of its pieces valid (decision 1851, “starter check”).

## 5. Surface: every building becomes a room type or an outdoor item

### 5.1 Mapping of the 30 GDD buildings

“Room” rows are painted, walled and roofed rooms. “Outdoor item” rows keep their GDD footprint (converted to cells),
bill, work, slots and services exactly. “Key item” is the machine placed inside the room that carries the old
building's service. The item bill and room-cell bill follow §7.

| # | GDD building (balance key) | New form | Room type | Required items | Levels |
|---:|---|---|---|---|---|
| 1 | Refuge/community hall (`hall`) | Room group | DORMITORY + KITCHEN + COMMON + PANTRY, as the starter layout | Beds, bench, hearth, seats, shelves (furniture §6) | Starter on surface |
| 2 | Residence (`residence`) | Room | DORMITORY or PRIVATE_ROOM | Beds (furniture); a door on the group's outside boundary on the surface | Any |
| 3 | Infirmary (`infirmary`) | Room | INFIRMARY | Patient bed(s), shelf, hearth for heat (or heat from a hearth in its group) | Any |
| 4 | Kitchen (`kitchen`) | Room | KITCHEN | Validity is §4's ≥ 1 bench + ≥ 1 hearth; the old building's 2 cooking slots equal 2 benches + 1 hearth | Any |
| 5 | Open stockpile (`open_stockpile`) | Outdoor item | — | 8 × 8 cells, 400000 g open storage | Surface |
| 6 | Covered store (`covered_store`) | Room | STORE (new) | 1 `store_bay` | Any |
| 7 | Cellar (`cellar`) | Room | CELLAR (new) | 1 `cellar_bay` | Any |
| 8 | Well (`well`) | Outdoor item | — | 4 × 4 cells | Surface |
| 9 | Workbench shelter (`workbench`) | Outdoor item (open-sided shelter) | — | 6 × 6 cells | Surface |
| 10 | Workshop (`workshop`) | Room | WORKSHOP (new) | 1 `craft_bench` | Any |
| 11 | Mill (`mill`) | Room | MILL (new) | 1 `millstone` | Any |
| 12 | Dryer (`dryer`) | Outdoor item | — | 8 × 6 cells | Surface |
| 13 | Preserver/smokehouse (`preserver`) | Room | SMOKEHOUSE (new) | 1 `smoker` | Any |
| 14 | Fisher shelter (`fisher_shelter`) | Outdoor item (open-sided shelter) | — | 8 × 6 cells, bank access | Surface |
| 15 | Weir (`weir`) | Outdoor item | — | 8 × 4 cells | Surface (water) |
| 16 | Boathouse (`boathouse`) | Room | BOATHOUSE (new) | 1 `boat_slip`; room must touch the shore line | Surface |
| 17 | Composter (`composter`) | Outdoor item | — | 6 × 6 cells | Surface |
| 18 | Apiary (`apiary`) | Outdoor item | — | 6 × 6 cells | Surface |
| 19 | Nursery (`nursery`) | Outdoor item | — | 8 × 8 cells | Surface |
| 20 | Brewery (`brewery`) | Room | BREWERY (new) | 1 `brew_vat` | Any |
| 21 | Saltpan (`saltpan`) | Outdoor item | — | 8 × 8 cells, coast ≤ 4 m | Surface |
| 22 | Forester lodge (`forester_lodge`) | Room | FORESTER_LODGE (new) | 1 `forester_rack` | Surface |
| 23 | Quarry shed (`quarry_shed`) | Room | QUARRY_SHED (new) | 1 `quarry_rack` | Surface |
| 24 | Lookout (`lookout`) | Outdoor item | — | 4 × 4 cells | Surface |
| 25 | Fence segment (`fence`) | Outdoor item | — | 2 × 2 cells | Surface |
| 26 | Stone wall segment (`stone_wall`) | Outdoor item | — | 2 × 2 cells | Surface |
| 27 | Gate (`gate`) | Outdoor item | — | 4 × 2 cells | Surface |
| 28 | Dirt path (`dirt_path`) | Outdoor item | — | 2 × 2 cells | Surface |
| 29 | Paved path (`paved_path`) | Outdoor item | — | 2 × 2 cells | Surface |
| 30 | Memorial garden (`memorial_garden`) | Outdoor item | — | 8 × 8 cells | Surface |

Totals: 13 buildings become rooms or room groups (rows 1–4, 6, 7, 10, 11, 13, 16, 20, 22, 23); 17 stay outdoor
items. DEC-061 names well, fence, paths, weir and apiary as outdoor; the other eleven outdoor classifications
(stockpile, workbench shelter, dryer, fisher shelter, composter, nursery, saltpan, lookout, stone wall, gate, memorial
garden) and the “any level” column are PROPOSED (OPEN-03).

**Services that belonged to a building without a key item** (PROPOSED, OPEN-04): the hall's Keeper 2 slots belong to
the central hall's hearth; the infirmary's Healer 2 slots belong to each INFIRMARY room; the black-box kitchen's
100000 g operational store is retired, and KITCHEN rooms draw from reachable PANTRY/STORE rooms as the starter kitchen
already does. **The central hall** of REQ-SET-123 and REQ-SET-133 is the starter's roofed room group.

### 5.2 New room types

DEC-061 needs room types the GDD does not have. They are **appended** to GDD §4.3 RoomType after `CORRIDOR=7`, so no
existing ordinal moves: `STORE=8, CELLAR=9, WORKSHOP=10, MILL=11, SMOKEHOUSE=12, BOATHOUSE=13, BREWERY=14,
FORESTER_LODGE=15, QUARRY_SHED=16`. Activation needs the versioned rules/catalog fingerprint and a save refusal of
older files, as DEC-044 did for its protected domains; `room_catalog.gd`'s “no ninth room type” comment and labels
change with it (slice G). Each new type allows only its own key item plus the shared fittings already allowed in every
room (`decoration`, `hearth`, `interior_door`, `interior_partition`, `seat`, `shelf`, `room_catalog.gd`
`COMMON_FITTINGS`).

### 5.3 New key items

Nine new item definitions, appended after the nine GDD furniture IDs (IDs 9–17): `store_bay`, `cellar_bay`,
`craft_bench`, `millstone`, `smoker`, `boat_slip`, `brew_vat`, `forester_rack`, `quarry_rack`. Each carries, from its
source building's balance §4.1/§4.2 row: materials, work, operational slots, `base_store_g`, passive slots,
`max_builders`, unlock milestone and tier-2 upgrade (covered store, workshop). Their footprints, access tiles and
wall-behind rules are **OPEN-02** (no geometry exists for them). `Room.furniture_mask`'s known mask grows from 511 to
`(1 << 18) − 1 = 262143`; R-BUILD-DOM-003/004 must be amended with it (slice G).

## 6. Furniture: footprint, access tiles, wall-behind

Footprints, bills, work and functions stay exactly GDD §5.9 / balance §4.3. An **access tile** is a 2 × 2-cell
block (one GDD tile) sharing an edge with the item's footprint — the exact conversion of GDD §5.9's “adjacent walk
tile”. Access is **rotation-independent**: the candidate access tiles are every tile side-adjacent to the footprint
(for the 2 × 1-tile bench and hearth, the tiles along either long side), and a piece is usable when at least one of
them is walkable, free of other items and reachable from the room's entrance (GDD: “at least one connected walk path
must reach every usable furniture access tile”). **Wall-behind** means at least one footprint edge touches a
generated wall or earth. Rotation (0–3) stays a presentation and footprint-orientation choice and never removes an
access candidate; `starter_structures.gd` writes rotation 0 for every starter piece and its multi-sided access lists
satisfy this rule.

| Furniture key | Footprint (cells) | Access tiles | Wall-behind | Basis |
|---|---|---|---|---|
| `bed` | 2 × 2 | Any side-adjacent tile, ≥ 1 usable | No | GDD “adjacent walk tile”; starter beds on tile rows 2 and 4 stand free |
| `patient_bed` | 2 × 2 | Any side-adjacent tile, ≥ 1 usable | No (PROPOSED, OPEN-05) | Same function as `bed`; no instance in the GDD |
| `seat` | 2 × 2 | Tile above or below (along the item's z axis), ≥ 1 usable | No | GDD “adjacent walk tile above or below”; starter seats stand free |
| `kitchen_bench` | 4 × 2 | The 2 tiles along either long side, ≥ 1 usable | No (PROPOSED, OPEN-05) | GDD 2 × 1 tiles; starter bench touches the north wall, which is permitted, not required |
| `hearth` | 4 × 2 | The 2 tiles along either long side, ≥ 1 usable | Yes (PROPOSED, OPEN-05) | Starter hearth touches the north wall; of its south tiles, (8,1) is walk and (9,1) holds the kitchen shelf |
| `shelf` | 2 × 2 | Any side-adjacent tile, ≥ 1 usable | Yes (PROPOSED, OPEN-05) | All five starter shelves touch an outside wall and have a walk tile beside them |
| `decoration` | 2 × 2 | None (no user and no service work) | No | GDD user slots 0 |
| `interior_partition` | 2 cell edges (one GDD tile edge) | None | n/a | GDD “Tile edge”; also a 1-edge half piece, §7.4 |
| `interior_door` | 2 cell edges | The 2 cells on each side touching the door edge must be walk cells | n/a | GDD “passable boundary”; also used as a surface room's exterior door (BUILD-REQ-009) |

`room_catalog.gd` `FurnitureFacts` currently says “There are deliberately no invented height, access offset … values”.
**DEC-061 Q7 now requires access cells and an optional wall-behind rule for every item**, so the access offsets above
are the contract values for slice E, and `geometry_profile_required` stays true for height and clearance, which this
amendment does not author. Body-fit on an access tile (for example a 2.55 m badger, DEC-039) remains a MOVE-G01
profile check, not a tile count.

## 7. Costs

### 7.1 What stays exactly as it is

- **Outdoor items** (17 rows of §5.1): bill, work, slots, capacity, unlock and upgrade from balance §4.1–4.2,
  unchanged.
- **Furniture** (9 rows of §6): bill and work from balance §4.3, unchanged.
- **Underground excavation**: per 1 m³ quantum brace + cut + finish, wood 250 + stone 250 milli-U, work 940 + 1880 +
  1410 = 4230 milli-WU (DEC-059 active values, BAL-UG-001), output 2000 milli-U `excavated_earth`; refunds and
  closure per ECON-005.

### 7.2 Underground room cells (ADOPTED, derived)

A painted underground cell is dug to the level's clear height of 4096 u = **4 quanta** (§3). Per cell:

| Per painted underground cell | Arithmetic | Value |
|---|---|---|
| Wood | 4 × 250 | 1000 milli-U |
| Stone | 4 × 250 | 1000 milli-U |
| Work | 4 × 4230 | 16920 milli-WU |
| Earth output | 4 × 2000 | 8000 milli-U `excavated_earth` |

A 2 × 2 Passage patch is 16 quanta: wood 4000, stone 4000 milli-U, 67680 milli-WU, 32000 milli-U earth. A cell
already open (BACKFILLED re-dig follows ECON-005's withdrawal branch) is never charged twice. Underground rooms have
no generated-wall or roof bill: their walls are braced earth.

### 7.3 Surface room cells and key items (PROPOSED, OPEN-01)

The GDD priced each building as one bill. DEC-061 splits each building into painted cells plus items, and on the
surface the cells must pay for generated walls and roof. Three derivations need no new constant:

| Option | Room cells pay | Key item pays | Problem |
|---|---|---|---|
| (a) Cells carry the whole building bill, spread over its reference area | `ceil_div(c × bill, reference cells)` | Nothing | An underground MILL would pay only excavation and get the millstone free |
| **(b) Recommended.** Key item carries its building's whole bill; cells carry one generic shell rate | Shell rate below | The source building's balance §4.1 bill and work | Surface totals rise by the shell of the painted area; balance §8 must be rerun |
| (c) Split each bill by a fixed fraction | Fraction × bill | Rest | Needs a fraction; no source supplies one |

**Generic surface shell rate under (b).** The residence is the GDD's only building whose bill is pure shell with no
service or furniture (GDD: “furniture purchased separately”). Its bill — wood 60000, stone 24000, cloth 8000 milli-U,
1200000 milli-WU — bought a floor of 8 × 6 tiles = 192 cells. For a surface room delta of `c` cells:

`shell(c) = ceil_div(c × (60000 wood, 24000 stone, 8000 cloth, 1200000 work), 192)`, per component, once per batch
operation (no per-cell rounding).

| Painted surface cells | Wood | Stone | Cloth | Work (milli-WU) |
|---:|---:|---:|---:|---:|
| 4 (2 × 2) | 1250 | 500 | 167 | 25000 |
| 24 (private-room minimum) | 7500 | 3000 | 1000 | 150000 |
| 144 (infirmary floor 6 × 6 tiles; also 6 × 6-tile black-box footprints) | 45000 | 18000 | 6000 | 900000 |
| 192 (residence floor) | 60000 | 24000 | 8000 | 1200000 |
| 320 (hall floor 10 × 8 tiles) | 100000 | 40000 | 13334 | 2000000 |

At its own floor area the residence reproduces its GDD bill exactly. The GDD hall (wood 100000, stone 60000, cloth
12000, 2400000) and infirmary (wood 40000, stone 30000, cloth 12000, 1000000) bills are retired in favour of this one
rate. A KITCHEN room with 2 benches and 1 hearth pays shell + wood 8000, stone 14000, iron 2000, 180000 milli-WU of
furniture, replacing the black-box kitchen's single bill.

### 7.4 Derived edge pieces (ADOPTED, derived)

A painted room can have an odd number of cells along a side, so a partition may span one cell edge. The half piece
costs exactly half the GDD tile-edge partition: wood 1000 / 2 = **500 milli-U**, work 8000 / 2 = **4000 milli-WU**
(both divide exactly). Doors stay 2 cell edges wide; there is no half door.

### 7.5 Removal and tier-2 upgrades

- **Removing surface cells** (Clear ground; PROPOSED with OPEN-01) is demolition of that part of the room: REQ-SET-127's
  evacuation, work of declared WU × 0.25 and 50% return, computed with `floor_div` on the removed cells' share of the
  bill **actually paid and recorded** for that room (BUILD-C4-R01: never repriced), so a return never exceeds half of
  what was paid. Items inside follow DEMO-CONTAIN-R01's 50%-of-own-materials rule.
- **Removing underground cells** (Earth) is ECON-005 backfill: earth 2000 milli-U per open quantum, 4.25 WU and
  wood 125 / stone 125 salvage per supported quantum.
- **Tier-2 upgrades** (PROPOSED, OPEN-08): the covered-store and workshop packages attach unchanged to `store_bay`
  and `craft_bench`. The residence/hall package (wood 20000, stone 40000, cloth 8000, 1200000 milli-WU) becomes a
  per-room upgrade of DORMITORY, PRIVATE_ROOM, KITCHEN, DINING, COMMON, PANTRY and surface CORRIDOR rooms, scaled
  like the shell: `ceil_div(c × package, 192)`; one upgrade per room; INFIRMARY keeps no upgrade.

## 8. Underground: paint = dig

- Painting a room on earth is the dig order (BUILD-REQ-012). Confirm all creates the excavation sites
  (`excavation_sites.gd`) for every quantum of every painted cell; the player watches the room open outward from the
  access face. Cell order is breadth-first from finished space; quantum order inside a cell is the excavation
  contract's own.
- **Passages** are `CORRIDOR` rooms ≥ 2 cells wide (BUILD-REQ-014). The demo's polyline tunnel tool, its junction
  angles and bore sizes, and the H/C room templates are retired once slices B–D land (DEC-061 Q1, Q4).
- **Ground the crew can dig.** ECON-003's refusals stand: water, protected bedrock or resource ownership, occupied or
  reserved space and protected routes refuse a cell with the reason in words. Research-gated rock and gold veins are
  not copied (study §4).
- **Spoil.** Every cut posts its 2000 milli-U earth output to adjacent legal capacity first (ECON-003); the ledger
  shows the batch's total earth.
- **Unfinished space** is not a route (MOVE-REQ-002). A room is published to topology, rooms and services only when
  its cells are finished and the shared transaction succeeds (ECON-003).

## 9. Entrance and connectors are items

| Player-facing item | `room_connectors.gd` family | Where placed | Geometry status |
|---|---|---|---|
| Burrow mouth (ramp) | `RAMP` (2) | Surface cells (entrance) or a Passage | Demo slope 1:2.5 (decision 0212) is a candidate: a 5120 u rise needs a run of at least 12800 u, plus 0212's end fillets. Not qualified. OPEN-02 |
| Stair-head, earth/timber steps | `EARTH_TIMBER` (0) | Surface or Passage | The only qualified descent is ADR 1209's 128 u rise per 512 u run; a full 5120 u level needs 40 treads over 20480 u. Shorter stairs (demo 4:5, decision 0212) are candidates. OPEN-10 (first entrance), OPEN-02 |
| Stone stairs | `STONE` (1) | Surface or Passage | OPEN-02 |
| Spiral stair | `SPIRAL` (3) | Surface or Passage | OPEN-02 |
| Hatch with ladder | `LADDER_HATCH` (4) | Surface or Passage | OPEN-02; grip, capability and load eligibility apply (levels-and-connections D04) |

- **Ghost** (BUILD-REQ-011, -015): **✓** “Can build” — every condition met; **!** “Blocked: <reason>” — valid here but
  waiting on something the player can fix (milestone, no finished Passage on the target level yet, an occupant to move,
  missing qualified geometry for this family); **X** “Not possible: <reason>” — never valid here (outside the level
  domain, water, protected ground, overlap, “No level above the surface”, “No level below level 4”).
- **Card**: direction Down / Up, the impossible one disabled with its reason; “✓ Connects to Underground level 1” (or
  “level N”); Cancel. Placing it adds it to the pending batch.
- **Built**: the entrance makes level 1 paintable from it (BUILD-REQ-015); `begin_underground_entry` is its runtime
  trigger, replacing the demo's automatic tunnel mouths.
- **Bill**: the excavation quanta the connector's geometry actually opens (§7.2 prices) plus the family's fixture
  recipe. Fixture recipes exist only for the qualified earth/timber stair (ADR 1202 L0/T0, ADR 1209 D3 treads,
  DEC-059 work); every other family's fixture bill is OPEN-02.
- **Removal**: refused while it is the only way in or out of anything (BUILD-REQ-017).

## 10. Payment: from a painted batch to blueprints

Nothing is deducted at Confirm all (DEC-061, “don't deduct at confirm, keep as we currently do”).

| Pending operation | Becomes on Confirm all | Paid by |
|---|---|---|
| Underground room delta (new cells of one room) | One room project (RoomProjects, decisions 1053/1062) owning one excavation site per quantum | Per-phase delivery and consumption, ECON-003; refunds ECON-005 |
| Surface room delta | One room-shell Construction project (material container anchored at the delta's lowest cell index); at most 4 builders | REQ-SET-124/125; refunds REQ-SET-126 |
| Item (furniture, key item, connector) | One item Construction project, which waits until its room's cells are finished (furnishing follows a completed shell, UG-FURN rules) | REQ-SET-124–126; ADR 1081 paid publication |
| Outdoor item | One building Construction project, as today | REQ-SET-124–126 |
| Earth / Clear-ground removal | One removal review (BUILD-REQ-006); after confirmation, demolition or backfill work | REQ-SET-127/128; ECON-005 |

Dependencies inside a batch run in order: an entrance before the level-1 rooms it opens, a room's cells before its
items. The ledger shows what the batch will need (natural measures, DEC-049) beside what stores hold, without reserving
anything. Cancelling one confirmed project never cancels the rest of its batch.

## 11. Gates this closes and what stays open

- **MOVE-G01 level count and spacing** (Q2-26): closed by DEC-061 Q6 — five levels, 5120 u. The other G01 inputs
  remain open (traversal profiles, connector geometry and recipes other than the qualified stair, finite water/canopy
  extents, hazards beyond ECON/HAZ).
- **MOVE-G02**: open. The 1 m cell grid over five levels is a new representation; its packed columns and bytes are a
  slice-B obligation (`systems_architecture.md` ARCH-BUILD-001).
- **MOVE-G03**: partly closed. `ui_ux_controls.md` UI-BUILD-001–014 registers the level bar and the build panel;
  route inspection, cross-layer picking and canopy/water layers remain open.
- **MOVE-G04, MOVE-G05**: open.

The OPEN list (OPEN-01 … OPEN-11) with options and recommendations is in
[decision 1851](decisions/1851-painted-room-contracts.md#open-list-for-brendan).

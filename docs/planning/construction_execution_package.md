# Construction execution package — hauling packet (task 06.4)

2026-10-02 · Owner: `PLAN-LIVE-CONSTRUCTION` (work queue). Slice H0 of task 06.4, written on
`feat/hauling-h0-h2` with Brendan's rulings of 2026-10-02 (relayed by the coordinator) and
recorded in [decision 1021](../decisions/1021-the-hauling-packet-and-brendans-hauling-rulings.md).

**This file is the hauling packet only.** `PLAN-LIVE-CONSTRUCTION`'s acceptance also names the
remaining construction commands, material delivery, upgrades and service integration; those
sections are still owed and are not written here. Nothing below closes a MOVE gate, and nothing
below claims that hauling runs in the game yet: H1 and H2 land primitives and admission, and the
first slice that moves a resident is H3.

## 1. What task 06.4 asks, and what this packet covers

[Task 06.4](../tasks/06_buildings_rooms_logistics.md): "physical hauling and output/source
reservations, storage filters/minimums/mass limits, carry/ground-pile recovery, gear
wear/equipment swaps and shared instance allocator; integrate SET_STORE_FILTER,
SET_STORE_MINIMUM and EQUIP through the task-04 dispatcher. A fishing boat's installation and
owner need a declared contract; do not fabricate a `boat` inventory item."

This packet specifies the hauling half completely and slices the rest (H6, H7). Upstream is task
05.4's RESERVED → TRAVEL → WORK; every movement gate MOVE-G01–05 is open, and decision 0185 makes
`movement.begin_travel()` refuse any profile without a qualified clearance class, which every
starter profile lacks. H3 therefore waits for Brendan's confirmation of a PROVISIONAL class
(§6, decision 1024).

## 2. Brendan's rulings, 2026-10-02

| # | Ruling | Where it lands |
|---|---|---|
| R-H1 | **Provisional ground clearance class** for the four starter adult species, recorded as NOT closing MOVE-G01, so real navigation and movement can be composed in H3. H0 proposed the values from adopted geometry; **Brendan confirmed option (a), class 1 for all four, on 2026-10-02.** | §6; [decision 1024](../decisions/1024-a-provisional-ground-clearance-class-proposal.md) |
| R-H2 | **Satchels are created per haul** (option b): made at load, sized to the hauler's species carry limit, unplaced, owned by the resident, destroyed when empty. ARCH-MEM-002's 512 satchel budget holds: one per resident at most. | H1; [decision 1022](../decisions/1022-a-satchel-is-made-per-haul-and-the-claim-travels-with-the-goods.md) |
| R-H2a | Derived from R-H2, recorded by H0: a resident who dies or departs while carrying drops the contents as a ground pile at its tile under DEC-043 #9, then the satchel is destroyed. | H1 `haul_carry.drop_satchel()` |
| R-H2b | Derived from R-H2: a haul cancelled mid-carry keeps its goods in the satchel and posts a fresh haul with the satchel as its source. | H1 `load_payload()` re-key; H2 `cancel()`; H4 posts |
| R-H3 | **Destinations**: the lowest-slot eligible store -- off the source footprint, a different ACTIVE building, reachable, filters admit, room for the payload (decision 0534 R1, reused); otherwise ground piles on the refund-seed ring (R2). | H2 `select_destination_into()` |
| R-H4 | **Approach / contact cell**: any walkable cell edge-adjacent to the footprint, chosen by lowest cell id; hall shelves use the common-room edge (GDD §5.9: "shelves can be reached from the open common-room edge"). | H3 contact producer |
| R-H5 | **The unload is worked in HAUL_OUTPUT.** WORK covers the load at the source contact; HAUL_OUTPUT covers the carry leg and the unload. The same state serves production output hauls. ARCH-JOB-001 carries a note. | H4; `systems_architecture.md` ARCH-JOB-001 |
| R-H6 | **Loads are sized at assignment** (REQ-SET-030), re-proved at load, one item lot per job at first. | H2 `admit()`; H1 `load_payload()` |
| R-H7 | **New numbered ReservationPurpose values** HAUL_SOURCE and HAUL_DESTINATION; number the domain. | H2 `reservations.gd`; [decision 1023](../decisions/1023-haul-payloads-are-sized-at-assignment-and-go-to-the-lowest-eligible-store.md) |

### Follow-up rulings, 2026-10-02 (on H0–H2's proposals; all as recommended)

| # | Ruling | Record |
|---|---|---|
| R-H8 | Decision 1024 option (a): provisional class 1 for mouse, mole, otter and squirrel; PROVISIONAL; closes no MOVE gate. | 1024 |
| R-H9 | A pile source with no free store stays queued (HAUL_NO_DESTINATION); a satchel's goods with no free store go down at the hauler's tile (H4, through the drop path). | 1023 P3 |
| R-H10 | A death or departure drop on a standing footprint starts from that building's door or front ring. | 1022 P1 |
| R-H11 | Carried lots do not merge on arrival until H7; H7 merges compatible lots, gear lots excepted. | 1022 P2 |
| R-H12 | HAUL_DESTINATION is the carried-lot claim from load to unload. | 1023 P1 |
| R-H13 | The pool refuses unnumbered purposes once every producer is numbered. | 1023 P2 |
| R-H14 | Satchels are unreachable for planning. | 1022 P3 |

## 3. The specified rules a haul obeys

| Rule | Value | Source |
|---|---|---|
| Carry limit by size | 12000 / 16000 / 24000 g (small / medium / large) | GDD §5.2; BAL-WORK-003; `residents.size_carry_g()` |
| Speed cap by size | 3277 / 4096 / 3072 u/s | GDD §5.2; BAL-WORK-003 |
| Payload per departure | `min(available, floor((carry_g - other_cargo_g) * 1000 / m))` milli-U; one lot charged `ceil(q*m/1000)` g | REQ-SET-111; BAL-NUM-001; BAL-SAFE-016 |
| Planning trips | `ceil_div(ceil_div(Q*M,1000), carry_g - other_cargo_g)`; each actual departure records its exact payload (can be one more) | BAL-WORK-003 |
| Travel lower bound | `ceil_div(D*30, v)` ticks per straight leg | BAL-WORK-003 |
| Handling work | 2000 milli-WU to load, 2000 to unload | BAL-CAT-010 |
| Pantry connection | x 9/10 handling work when a kitchen door is within 8 m walking distance of a pantry/store access point; never movement | REQ-SET-134; BAL-WORK-004 |
| Acceptance | worker, complete inputs, output capacity and destination slot reserved atomically before movement | REQ-SET-030 |
| Blocked cause | a refused reservation keeps the job queued with the exact cause, locking nothing unrelated | REQ-SET-031 |
| Leases | travelling owners renew every 30 ticks; a lease expires 300 ticks after its last renewal | REQ-SET-032; BAL-SAFE-004; ARCH-JOB-004 |
| Unreachable | 300 ticks unreachable → BLOCKED, release, retry after 900 ticks or a navigation revision | REQ-SET-033; ARCH-JOB-004 |
| Full storage | stop new production reservations; existing cargo may go to a visible temporary ground pile at the destination | REQ-SET-110 |
| One container in transit | a lot in transit is in exactly one container; source debit and satchel credit are atomic | BAL-SAFE-002 |
| No teleports | goods move only by real jobs that commit each transfer | INV-GOODS-R01 |
| Pile rules | at most 400000 g, one per tile, never on a standing footprint, breadth-first N, E, S, W from the door or the front-first ring | DEC-043 #9; decision 0532 |

## 4. The haul's life, state by state

```text
QUEUED ──admit (H2: size, choose destination, reserve grams + HAUL_SOURCE claim)──► RESERVED
RESERVED ──route ready (H3)──► TRAVEL to the source contact
TRAVEL ──arrive (H3)──► WORK: 2000 milli-WU (1800 on a pantry connection)
WORK done ──load (H1: satchel minted, goods + claim move, claim becomes HAUL_DESTINATION)──► HAUL_OUTPUT
HAUL_OUTPUT: travel to the destination contact, then 2000 milli-WU of unload
HAUL_OUTPUT done ──H2 complete_unload (H1 deliver: grams released, satchel destroyed;
                    record retired)──► COMPLETE

cancel before load  → H2 cancel: claim and grams released; nothing moved
cancel after load   → H2 cancel: grams released, claim released; goods stay in the satchel;
                      a fresh haul is posted with the satchel as source (its load re-keys)
death / departure   → H2 cancel, then H1 drop_satchel BEFORE despawn: pile at the tile (or the
                      building's refund origin when the tile is a footprint), satchel gone
lease expired       → H2 cancel (the pool's expiry sweep releases claims, never the grams)
store full at unload → complete_unload refuses; H2 cancel, then re-admit
no store, no ring   → REQ-SET-031: HAUL_NO_DESTINATION, queued, nothing locked
```

Claims and grams by phase:

| Phase | Reservation pool | Inventory | Haul record (H2) |
|---|---|---|---|
| RESERVED, TRAVEL, WORK | HAUL_SOURCE on the source lot, payload milli-U, lease | destination `reserved_mass_g` += charge | job → destination, tile, grams |
| HAUL_OUTPUT | HAUL_DESTINATION on the satchel lot, same lease | goods in the satchel; destination grams still held | unchanged |
| COMPLETE | none | goods in the destination; grams released in the unload's transaction | cleared by `complete_unload()` |

## 5. Destinations and contacts

- **Store (R1).** Lowest container slot among placed containers off the source building's
  footprint whose owner is a different live ACTIVE Building, that is reachable, not a pile, not a
  satchel, whose filters admit the item's category and whose free mass takes the whole payload
  charge. The grams are reserved at admission.
- **Ground (R2).** With no store, ground piles from the source building's refund seeds (the hall's
  door at rotation 0, else the footprint's front-first edge ring), proved by a rolled-back
  placement; nothing is reserved, as for demolition. The unload tile is the first eligible seed.
  A source with no Building owner has no ring: a pile stays queued with HAUL_NO_DESTINATION; a
  satchel's goods go down at the hauler's tile, built in H4 (R-H9).
- **Contact (R-H4, built in H3).** The approach cell for a store is the lowest-id walkable
  navigation cell edge-adjacent to its owner's footprint; for the hall's shelves, a cell on the
  common-room edge. The work point is the store's anchor. Under the provisional class 1 a cell
  is its own clearance square, so "walkable" and "passes class 1" coincide.

## 6. Movement under the provisional clearance class (R-H1, R-H8) — notes for H3

Brendan confirmed decision 1024's **option (a)** on 2026-10-02: **class 1 for all four starter
adults** (mouse, mole, otter, squirrel), the only derivation from adopted geometry that yields a
class for all four under MOVE-C2-R01's anchored containment at the baseline `(+256,+256)` offset
(DEC-039 heights × the proportion manifest's torso permille, quantized outward, margin 0). It is
PROVISIONAL: it closes no MOVE gate, leaves Q2-01–05 empty and is not a qualified envelope.

H3 is a new lane from master after this branch merges. What it must do and keep:

1. **Bind the class, visibly provisional.** `movement.gd::profile_clearance_class_into()` returns
   1 for the four starter profile ids and still refuses an invalid id. Name the value
   (e.g. `PROVISIONAL_GROUND_CLEARANCE_CLASS = 1`) and cite decision 1024 at the constant.
   `test_no_profile_publishes_a_clearance_class` changes on purpose (record it as such); decision
   0185's admission gate (exact profile/route class equality) stays exactly as it is. Keep
   `test/fixtures/synthetic_ground_movement.gd` for class-2 and mismatch witnesses.
2. **Keep MOVE-G01 open everywhere it is recorded**: `movement_profile_readiness.json`,
   `movement_starter_ground_profile.md` §5 and `movement_profile_authoring.md` get a
   "provisional class 1 bound, decision 1024; Q2-01–05 still empty" note -- no slot is filled.
3. **Route requests use class 1** for every starter; no caller-supplied class remains on a
   production path.
4. **Compose navigation and movement into the settlement tick** in ARCH-SYS order (navigation
   before movement), plus the **job state writer** RESERVED → TRAVEL → WORK (task 05.4), so a
   Job leaves RESERVED only on a READY route and reaches WORK only on real arrival at the contact.
5. **Contact producer (R-H4).** A store's approach cell is the lowest-id walkable navigation cell
   edge-adjacent to its owner's footprint; the hall's shelves use a cell on the common-room edge.
   Under class 1, walkable and "passes class 1" coincide. The work point is the store's anchor.
6. **Destination revisions.** Building contacts take `demolition_admissions.gd`'s per-building
   revision (decision 0534 R3); revalidate on admit and release. Coordinate `movement.gd` with
   DEMOLITION-D8, which owns movement invalidation on demolition.
7. **Fold the R1 duplicate.** `haul_planner.gd::_is_destination_store()` restates
   `settlement_system.gd::_is_output_store()` (plus "not a satchel"); H3 owns that file and can
   make both call one reader.
8. **Known geometry limits to test, not hide:** a 45° turn sweeps the otter's torso to ±303 u
   (outside class 1 at `+256`); tails, ears, the carried satchel and margin are unmeasured. H3
   asserts nothing about them and does not widen the class to cover them.

## 7. Slice plan H0–H8

| Slice | Content | Files owned | Depends on | State |
|---|---|---|---|---|
| H0 | This packet; queue entries; the stale GROUND-CLEARANCE-ADMISSION status; the provisional clearance proposal | this file, `docs/planning/work_queue.json`, decisions 1021, 1024 | -- | built |
| H1 | Satchel door; transactional carry doors that move claims with goods; ground-pile mover; death/departure drop; conservation tests | `inventory.gd`, `reservations.gd`, `ground_piles.gd`, new `haul_carry.gd`, tests | H0 | built |
| H2 | Payload sizer; haul demand; destination selection (R1/R2); numbered ReservationPurpose; destination mass reservation and its record | new `haul_planner.gd`, `reservations.gd`, ledger, registry, tests | H1 | built |
| H3 | Bind the confirmed provisional class 1 in `movement.gd`; compose navigation and movement into the settlement tick with the RESERVED → TRAVEL → WORK job state writer; contact producer for stores (R-H4); destination revisions; fold the R1 duplicate (§6) | `movement.gd`, `navigation.gd`, `settlement_system.gd`, a new contacts module | this branch merged (1024 confirmed; D6 merged); coordinate with DEMOLITION-D8 (`movement.gd`) | blocked on merge |
| H4 | HAUL Job lifecycle: admission at assignment, TRAVEL → WORK(load) → HAUL_OUTPUT(carry + unload through `complete_unload()` only) → COMPLETE, `work.gd` ticking HAUL_OUTPUT's unload; leases (30/300); REQ-SET-033 unreachable handling; cancel and fresh-haul re-post; a satchel's goods with no store go down at the hauler's tile (R-H9); every early end through `cancel()`; drop before despawn | `jobs.gd`, `work.gd`, `settlement_system.gd` | H3 | blocked |
| H5 | Demand producers: REQ-SET-110 ground-pile recovery, D6's evacuate-then-demolish hauls (D6b), production output hauls and REQ-SET-112 output reservations; REQ-SET-113 urgency | `settlement_system.gd`, `demolition_work.gd` | H4 | blocked |
| H6 | Storage policy: SET_STORE_FILTER, SET_STORE_MINIMUM (REQ-SET-117), mass limits, REQ-SET-134's pantry connection by walking distance | `command_dispatch.gd`, a store-policy module | H3 | blocked |
| H7 | Gear: wear, equipment swaps, EQUIP, the shared instance allocator, the boat installation/owner contract (no `boat` item); hauls never split a gear lot; carried lots merge on arrival except gear lots (R-H11) | `gear.gd`, `command_dispatch.gd` | H4 | blocked |
| H8 | Saves for the haul record (with satchel ↔ `Equipment.satchel` cross-checks), haul UI and notices, live harness, 06.4 acceptance, MOVE-TEST-02 once tunnels exist | save sections, `ui/`, `docs/tasks/` | H4–H7 | blocked |

One writer per file. H1 and H2 touched none of `jobs.gd`, `work.gd` or `settlement_system.gd`;
DEMOLITION-D6 (which owned them) merged as PR #219 and is merged into this branch.

## 8. Acceptance for the slices built here

- **H1.** Every load, unload and drop conserves each item (`audit()`; sourced and sunk
  unchanged); a lot in transit is in exactly one container; the claim moves with the goods; every
  refusal leaves Inventory, the pool and the resident equipment columns byte-identical; the
  satchel is minted inside the load's own transaction and destroyed inside the unload's.
- **H2.** Payload, trips, travel ticks and handling work match §3 at their boundaries; R1's
  seven clauses each exclude a store; R2 writes nothing; admission is all-or-nothing with the
  exact REQ-SET-031 cause; cancellation returns both claim and grams; the record and scratch are
  the ledgered sizes.

## 9. Questions for Brendan — all answered 2026-10-02

The five questions this packet first carried (decision 1024's class; the pile/satchel source with
no store; carried lots not merging; refusing unnumbered purposes; a death drop on a footprint),
together with 1022 P3 and 1023 P1, were all ruled as recommended: see R-H8 – R-H14 in §2. No
question from H0–H2 remains open.

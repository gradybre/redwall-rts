# Backlog — every remaining item as a work packet

Each packet stands on its own: a fresh agent can take one, read what it lists, and build it. Before starting any
packet, read [README.md](README.md) (how to work) and check [STATUS.md](STATUS.md) for what has landed since.

**How a packet reads.**

- **Approval**: Brendan's words and date, and the record that holds them. A packet with no approval is not here; it is
  in OPEN_QUESTIONS.md or the "not chosen" list at the end.
- **Scope**: what to build. Where the scope is the review's text, the review item ID is given; read its full text in
  `docs/reviews/2026-09-30-external-review.md`.
- **Read first**: the adopted rules and records. Where the design documents are silent, the packet says so: build the
  smallest sensible behaviour and raise a PROPOSAL (README §3.2).
- **Depends on**: what must merge first. SEQUENCE.md gives the overall order.
- **Files**: what the work will touch, and which other packets touch the same files.
- **Decisions**: the number range to use, ten per packet, allocated from 1101 for this handoff. Check each number is
  still free before you use it (README §3.6).
- **Acceptance**: what "done" means, on top of the gates every lane passes (README §3.4–3.7).
- **Art**: which assets exist (staged, gitignored; README §3.9), and whether new art would be needed. New paid art
  is always asked for first (README §3.8).
- **Pitfalls**: what has bitten, or will.
- **Open**: questions for Brendan before or during the build, numbered as in OPEN_QUESTIONS.md.

"Demo" means `godot/demo/` (the live village, decision 0196); "settlement" means `godot/scripts/` (the GDD game).
Feature numbers (#9, #18 …) are Brendan's feature-list numbers of 2026-10-01; review IDs (ECO-, SOC-, UX-, F) are the
2026-09-30 external review's (approval log: decision 0493).

## Contents

| ID | Title | Layer | Decisions |
|---|---|---|---|
| [HAUL-H3](#haul-h3) | Compose movement under provisional clearance class 1; store contacts | settlement | 1101–1110 |
| [HAUL-H4](#haul-h4) | The HAUL job lifecycle | settlement | 1111–1120 |
| [HAUL-H5](#haul-h5) | Haul demand producers, including D6b evacuation | settlement | 1121–1130 |
| [HAUL-H7](#haul-h7) | Gear wear, EQUIP and the boat contract | settlement | 1131–1140 |
| [HAUL-H8](#haul-h8) | Haul saves, UI, live harness and task 06.4 acceptance | settlement | 1141–1150 |
| [DEMO-D7](#demo-d7) | DEMOLISH dispatch, stranded notice, UI and quicksave | settlement | 1151–1160 |
| [DEMO-D8](#demo-d8) | Movement invalidation on demolition | settlement | 1161–1170 |
| [DEMO-D9](#demo-d9) | Independent QA and a visible run of demolition | settlement | 1171–1180 |
| [MEAS-2](#meas-2) | Measures phase 2 and the Underground rename | demo + settlement UI | 1181–1190 |
| [BLD-PANEL](#bld-panel) | The shared Buildings panel, thumbnails, one herb patch | demo | 1191–1200 |
| [FLAX](#flax) | Flax, and the flax → rope / linen chain | demo | 1201–1210 |
| [GOALS-2](#goals-2) | Goals "First crossing" and "Regatta day" | demo | 1211–1220 |
| [HALL-FUEL](#hall-fuel) | The hall's tier-2 fuel factor ×0.75 | demo | 1221–1230 |
| [HIVES](#hives) | Hives, honey and wax (Y: ECO-011, ECO-012) | demo | 1231–1240 |
| [PRESERVE](#preserve) | Preserving (#18) | demo | 1241–1250 |
| [BREW](#brew) | Brewing (#19) | demo | 1251–1260 |
| [FEAST](#feast) | Feasts (#9) | demo | 1261–1270 |
| [SKILLS](#skills) | Skills (#23) | demo | 1271–1280 |
| [DAYPLAN](#dayplan) | The day planner (#24) | demo | 1281–1290 |
| [WEATHER](#weather) | Livelier weather (#34) | demo | 1291–1300 |
| [WILDLIFE](#wildlife) | Wildlife (#11) | demo | 1301–1310 |
| [WATER](#water) | The water revamp (#54) | demo | 1311–1320 |
| [FISHING](#fishing) | The fishing revamp (#49) | demo | 1321–1330 |
| [TRADE](#trade) | River trade (#37) | demo | 1331–1340 |
| [PATHS](#paths) | Paths and roads (#31) with worn ground (UX-026) | demo | 1341–1350 |
| [DIG](#dig) | The digging revamp (#51) with group AA's dig items | demo | 1351–1360 |
| [ZONES](#zones) | Hauling zones (#33) | demo | 1361–1370 |
| [EXPLORE](#explore) | Exploration (#55) | demo | 1371–1380 |
| [NEIGHBOURS](#neighbours) | Neighbours (#56) | demo | 1381–1390 |
| [TIME](#time) | Time controls (#59) | demo | 1391–1400 |
| [RG-W](#rg-w) | Review group W, the rest | demo | 1401–1410 |
| [RG-Y](#rg-y) | Review group Y, the rest (gathering outings and orchard remainders) | demo | 1411–1420 |
| [RG-Z](#rg-z) | Review group Z (woodland, gear, workshops) | demo | 1421–1430 |
| [RG-AB](#rg-ab) | Review group AB (the first year's cadence) | demo | 1431–1440 |
| [RG-AC](#rg-ac) | Review group AC (roles, arcs, apprenticeship) | demo | 1441–1450 |
| [RG-AD](#rg-ad) | Review group AD (daily life, households, care) | demo | 1451–1460 |
| [RG-AE](#rg-ae) | Review group AE (civic life, customs, feasts, stories) | demo | 1461–1470 |
| [RG-AG](#rg-ag) | Review group AG (camera places, command vocabulary, "Why?", atlas) | demo | 1471–1480 |
| [RG-AH](#rg-ah) | Review group AH (sketch-fund-build, commons, renovation) | demo | 1481–1490 |
| [RG-AJ](#rg-aj) | Review group AJ: UX-025 silhouettes, UX-028's remainder | demo | 1491–1500 |
| [RG-AK](#rg-ak) | Review group AK (F48, UX-005, UX-006, bridge removal and cap) | demo | 1501–1510 |
| [MEASURE-BAL](#measure-bal) | Rerun the balance year matrix | tools | 1511–1520 |
| [MEASURE-SOAK](#measure-soak) | A windowed soak and a 25-resident soak | tools | 1521–1530 |
| [FOLLOW-UPS](#follow-ups) | Follow-up fixes not finished by `fix/follow-ups` | demo + tools | 1531–1540 |
| [FINAL-PASS](#final-pass) | The full review and playtest pass | all | 1541–1550 |
| [WIN-PERF](#win-perf) | The Windows performance test (GTX 1660 tiers) | all | 1551–1560 |

Four in-flight branches are not packets here, because they are built and only need landing (STATUS.md §2): batch 8
(#222), the review fixes (#221), route planning with the kitchen fix 1005 (`perf/route-planning`), and hauling H0–H2
(`feat/hauling-h0-h2`). Measures phase 1 (`feat/demo-measures`) lands with MEAS-2.

---

# Part 1 — Settlement: hauling and demolition

Task 06.4 (physical hauling) and the demolition path D1–D9. These are settlement-layer work: GDD-strict, packed
columns, the memory ledger and the registry. Read first, for every packet in this part:

- `docs/planning/construction_execution_package.md` (the hauling packet; on `feat/hauling-h0-h2` until that merges:
  `git show feat/hauling-h0-h2:docs/planning/construction_execution_package.md`), especially §2 (rulings), §3–§6 and
  §7 (the slice plan H0–H8, "one writer per file").
- Decisions 1021–1024 (hauling), 1031 (H6), 0531–0537 (demolition D1–D6), and the demolition ruling
  `docs/rulings/2026-10-01_demolition_containment.md` (DEMO-CONTAIN-R01; the D-table; DEC-043).
- `docs/planning/work_queue.json` tasks `HAUL-H3`…`HAUL-H8` and `DEMOLITION-D7`…`D9` (their acceptance text).
- `docs/movement_direction_amendment.md` (SET-MOVE-001, MOVE-G01–05) and decision 0185 (GROUND-CLEARANCE-R01v1).
- `docs/systems_architecture.md` §2–§3 (memory) and `docs/validation/ready07_arithmetic.py` (the ledger).

**The hauling rulings** (Brendan, 2026-10-02; `construction_execution_package.md` §2):

| # | Ruling | Record |
|---|---|---|
| R-H1 | A provisional ground clearance class for the four starter adult species, recorded as NOT closing MOVE-G01 | 1024 |
| R-H2 | Satchels are created per haul: made at load, sized to the hauler's species carry limit, unplaced, owned by the resident, destroyed when empty; at most one per resident (ARCH-MEM-002's 512) | 1022 |
| R-H2a | A resident who dies or departs while carrying drops the contents as a ground pile at its tile (DEC-043 #9), then the satchel is destroyed | packet §2; `haul_carry.drop_satchel()` |
| R-H2b | A haul cancelled mid-carry keeps its goods in the satchel and posts a fresh haul with the satchel as its source | packet §2 |
| R-H3 | Destination: the lowest-slot eligible store (off the source footprint, a different ACTIVE building, reachable, filters admit, room for the payload; 0534 R1), otherwise ground piles on the refund-seed ring (R2) | 1023 |
| R-H4 | Approach cell: any walkable cell edge-adjacent to the footprint, lowest cell id; hall shelves use the common-room edge (GDD §5.9) | packet §2 |
| R-H5 | The unload is worked in HAUL_OUTPUT; WORK covers the load at the source contact; the same state serves production output hauls | 1021; ARCH-JOB-001 note |
| R-H6 | Loads are sized at assignment (REQ-SET-030), re-proved at load, one item lot per job at first | 1023 |
| R-H7 | Numbered ReservationPurpose: `PURPOSE_UNSPECIFIED=0`, `HAUL_SOURCE=1`, `HAUL_DESTINATION=2` | 1023 |
| R-H8 | Clearance class **1** for mouse, mole, otter and squirrel; PROVISIONAL; closes no MOVE gate | 1024 |
| R-H9 | A pile source with no free store stays queued (HAUL_NO_DESTINATION); a satchel's goods with no free store go down at the hauler's tile (H4) | 1023 P3 |
| R-H10 | A death or departure drop on a standing footprint starts from that building's door or front ring | 1022 P1 |
| R-H11 | Carried lots do not merge on arrival until H7; H7 merges compatible lots, gear lots excepted | 1022 P2 |
| R-H12 | HAUL_DESTINATION is the carried-lot claim from load to unload | 1023 P1 |
| R-H13 | The pool refuses unnumbered purposes once every producer is numbered (whichever slice numbers the last producer does it) | 1023 P2 |
| R-H14 | Satchels are unreachable for planning | 1022 P3 |

**Approval for the whole part:** demolition, "answers 1–9 approved; furniture removal returns 50% of materials; FULL
PATH" (Brendan, 2026-10-01; 0531, DEC-043, the ruling's D-table D1–D9). Hauling: D6's P3, "Build hauling (06.4)
next" (Brendan, 2026-10-02; 0537), and the R-H rulings above.

**Shared pitfalls.**

- **One writer per file** (packet §7). `settlement_system.gd` is claimed by H3, H4, H5, D7 (likely) and D8 (in
  practice); `command_dispatch.gd` by H7 and D7; `movement.gd` by H3 and D8. Run them in the order SEQUENCE.md gives.
- **Memory.** Every byte added updates `ready07_arithmetic.py`, `systems_architecture.md` §2–§3,
  `persistence_state_registry.md` where it applies, and regenerates `docs/planning/registry_capacity_audit.json`
  (`python3 tools/audit_registry_capacities.py`; CI checks it is current). H0–H2 added +196,608 B (the haul record)
  and +34,956 B scratch (1023). Hand-merging these totals between branches is how errors get in; recompute.
- **Unsaved state.** HaulAdmission, the demolition admission record, the paid ledger, the evacuation intent and
  store policy are all classified UNRESOLVED and are not saved yet. `CONSTRUCTION-SAVED-BINDINGS` has no queue entry
  (open question Q-S4).
- **Queue hygiene.** On master `DEMOLITION-D1` still reads `review` though it merged as #206; fix it.

<a id="haul-h3"></a>
## HAUL-H3 — Compose movement under provisional clearance class 1; store contacts

- **Approval:** R-H1, R-H8 (clearance class 1, Brendan 2026-10-02; 1024); R-H4 (contact cell); packet §6–§7.
- **Scope** (packet §6, §7 row H3; queue `HAUL-H3`):
  1. Bind class 1 in `movement.gd profile_clearance_class_into()` as a named constant (for example
     `PROVISIONAL_GROUND_CLEARANCE_CLASS = 1`) citing 1024; still refuse an invalid profile id. The test
     `test_no_profile_publishes_a_clearance_class` changes on purpose: record it. Keep 0185's exact-class admission
     gate and `test/fixtures/synthetic_ground_movement.gd`.
  2. Keep MOVE-G01 open: note "provisional class 1 bound, decision 1024; Q2-01–05 still empty" in
     `docs/planning/movement_profile_readiness.json`, `movement_starter_ground_profile.md` §5 and
     `movement_profile_authoring.md`.
  3. Route requests use class 1 for every starter; no caller-supplied class stays on a production path.
  4. Compose navigation, then movement, into the settlement tick in ARCH-SYS order (movement is ARCH-SYS-012 and is
     not composed today), with the job state writer RESERVED → TRAVEL → WORK (task 05.4): a job leaves RESERVED only
     on a READY route and reaches WORK only on real arrival.
  5. A contact producer for stores (R-H4), in a new contacts module.
  6. Destination revisions from `demolition_admissions.gd`'s per-building revision (0534 R3), revalidated on admit and
     release.
  7. Fold the R1 duplicate: `haul_planner.gd _is_destination_store()` and `settlement_system.gd _is_output_store()`
     call one reader.
  8. **H6's owed composition** (1031 Consequences): construct `StorePolicy` in the settlement composer, call
     `bind_store_policy()`, hand the same instance to destination selection (so `select_destination_into()` asks
     `store_policy.store_admits()`, 1031 P3), and `clear()` it on every reset and load. Until this lands
     SET_STORE_FILTER and SET_STORE_MINIMUM refuse `COMMAND_STORE_NOT_BOUND`. Also 1031 P8: the composer calls
     `store_policy` instead of its own `_main_store_of()` test, and two stores at one origin are refused where stores
     are created.
- **Read first:** packet §6; 1024; 1031; 0185; `docs/movement_direction_amendment.md`; task 05.4 in
  `docs/tasks/05_movement_first_playable.md`.
- **Depends on:** `feat/hauling-h0-h2` merged (STATUS §2.4). D6 is merged; 1024 is confirmed.
- **Files:** `godot/scripts/core/movement.gd`, `navigation.gd`, `godot/scripts/systems/settlement_system.gd`, a new
  contacts module, `haul_planner.gd`, the three movement docs. Conflicts: DEMO-D8 (`movement.gd`,
  `settlement_system.gd`): do D8's movement part with or right after H3.
- **Decisions:** 1101–1110.
- **Acceptance** (queue): class 1 bound without closing MOVE-G01; real routes and arrival in the settlement tick;
  the contact producer per R-H4; destination revisions; the job state writer; H6's policy bound and consulted; tests
  for every public function; ledger and audit updated.
- **Art:** none.
- **Pitfalls:**
  - On master `profile_clearance_class_into()` refuses every profile; that is the gate being opened provisionally.
  - Known geometry limits must be tested, not hidden: a 45° turn sweeps the otter's torso to ±303 u, outside class 1;
    tails, ears, satchel and margin are unmeasured. **Do not widen the class.**
  - REQ-SET-134's pantry connection by walking distance (owed by H6, not in 1031) needs H3's navigation; take it here
    or in H4 and say which.

<a id="haul-h4"></a>
## HAUL-H4 — The HAUL job lifecycle

- **Approval:** R-H2a, R-H2b, R-H5, R-H6, R-H9, R-H12 (Brendan 2026-10-02; 1021–1023).
- **Scope** (packet §4, §7 row H4; 1023 Consequences): `admit()` at assignment with `now + LEASE_EXPIRY_TICKS`;
  TRAVEL → WORK (load, 2000 milli-WU; 1800 with a pantry connection) → `load_payload()` → HAUL_OUTPUT (carry, then
  unload 2000 milli-WU through `complete_unload()` only, never `haul_carry`'s unloads directly) → COMPLETE; `work.gd`
  ticks HAUL_OUTPUT's unload; leases renew every 30 ticks and expire after 300; REQ-SET-033: 300 ticks unreachable
  → BLOCKED, release, retry after 900 ticks or a navigation revision; cancel and re-post a fresh haul with the
  satchel as source (R-H2b); a satchel with no free store goes down at the hauler's tile through `drop_seeds_into()`
  and the pile mover (R-H9); **every early end goes through `cancel()`** (cancellation, death, departure, lease
  expiry); `drop_satchel()` is called **before** `residents.despawn()`; a store that fills before unload refuses,
  then cancel and re-admit.
- **Read first:** packet §3–§4; REQ-SET-030–033; BAL-CAT-010; BAL-SAFE-002/004; ARCH-JOB-001/004; INV-GOODS-R01.
- **Depends on:** HAUL-H3.
- **Files:** `godot/scripts/core/jobs.gd`, `work.gd`, `settlement_system.gd`. Conflicts: H5, D7, D8.
- **Decisions:** 1111–1120.
- **Acceptance** (queue `HAUL-H4`): REQ-SET-030–033 on real HAUL jobs; the full state chain; 30/300 leases;
  unreachable → BLOCKED with the 900-tick retry; cancel keeps goods and re-posts; drop before despawn; conservation
  tests (no gram lost or duplicated in any path).
- **Art:** none.
- **Pitfalls:**
  - Nothing enforces drop-before-despawn today: `despawn()` silently clears `Equipment.satchel`, orphaning the
    satchel (1022). Add the enforcement or a test that fails without it.
  - A pile unload starts from the recorded tile only; a changed world refuses and H4 re-plans (1023).
  - A missed `cancel()` leaves grams reserved that `audit()` cannot see, and that blocks the store's destruction.
  - In the real game today a removal job is posted and reserved but never worked, because nothing writes
    JOB_STATE_WORK (0537). H3's state writer fixes that for every job kind; check the BUILD removal job reaches WORK.

<a id="haul-h5"></a>
## HAUL-H5 — Haul demand producers, including D6b evacuation

- **Approval:** D6 P3 "Build hauling (06.4) next" (0537); the D-table's D6 evacuation clause (DEC-043); R-H rulings.
- **Scope** (packet §7 row H5; queue `HAUL-H5`): REQ-SET-110 ground-pile recovery; D6's evacuate-then-demolish hauls
  ("D6b": D6's persisted intent and hourly retry stay unchanged, the hauls are what empty the sources); production
  output hauls in HAUL_OUTPUT with REQ-SET-112 output reservations; REQ-SET-113 urgency bucket 2. Also 1031 P2: once
  hauling lands, disallowing an item in a store raises haul-out demand (no slice was named; it fits here).
- **Read first:** 0537 (especially "What D7 must know" and the hauling refusal, Decision item 4); 0532 (piles);
  REQ-SET-110/112/113/127; DEMO-CONTAIN-R01 blocker 4.
- **Depends on:** HAUL-H4.
- **Files:** `settlement_system.gd`, `demolition_work.gd`, `haul_planner.gd`. Conflicts: H4, D7, D8.
- **Decisions:** 1121–1130.
- **Acceptance** (queue): piles recovered into storage; D6's intent served by real HAUL jobs; outputs hauled in
  HAUL_OUTPUT with REQ-SET-112 reservations; urgency bucket 2; no teleports (INV-GOODS-R01).
- **Pitfalls:**
  - Every haul commit that empties a pile reclaims it, so pile refs are not stable: re-read by tile (0532). Use the
    `ground_piles` helpers; never create piles directly.
  - An evacuation order may never converge: goods can flow into an ordered building, and goods in an off-footprint
    owned container are invisible to the anchor scan (0537 L-4). Decide and record how the order ends.
  - REQ-SET-127 also requires residents to be evacuated before demolition; no slice owns resident evacuation
    (open question Q-S3).

<a id="haul-h7"></a>
## HAUL-H7 — Gear wear, EQUIP and the boat contract

- **Approval:** task 06.4 scope under D6 P3 (0537); R-H11 (merge on arrival, gear lots excepted; 1022 P2).
- **Scope** (packet §7 row H7; queue `HAUL-H7`): gear wear, equipment swaps, the EQUIP command (today refused with
  `EQUIP_CONTRACT_OWNED_BY_TASK_06`, `command_dispatch.gd`), the shared instance allocator (1031 found this is the
  existing ARCH-STATE-007 GearInstance pool in `gear.gd`, decision 0038, so nothing new is needed), and a declared
  boat installation/owner contract with **no fabricated `boat` item**. Hauls never split a gear lot; compatible
  carried lots merge on arrival, gear lots excepted.
- **Read first:** task 06.4 in `docs/tasks/06_buildings_rooms_logistics.md`; 0038; 1031; GDD gear rows; 0537 ("no
  wear for now" applies to demolition tools only).
- **Depends on:** HAUL-H4. Runs after DEMO-D7 or before it, never at the same time (`command_dispatch.gd`).
- **Files:** `godot/scripts/core/gear.gd`, `command_dispatch.gd`.
- **Decisions:** 1131–1140.
- **Acceptance:** task 06.4's gear items; EQUIP dispatches; no gear-lot split; merge on arrival per R-H11; the boat
  contract written down, with no boat item.
- **Open:** Q-S2 (whether a boat contract is already declared anywhere; if not, Brendan rules its shape).

<a id="haul-h8"></a>
## HAUL-H8 — Haul saves, UI, live harness and task 06.4 acceptance

- **Approval:** task 06.4 under D6 P3 (0537).
- **Scope** (packet §7 row H8; queue `HAUL-H8`): save bindings for the HaulAdmission record (registry UNRESOLVED,
  1023 §6) with satchel ↔ `Equipment.satchel` restore cross-checks (every live satchel's owner is a present resident
  whose pair names it; 1022 Consequences); haul UI and notices; a live harness; task 06's acceptance cases
  (overlapping delivery and consumption, full destination, worker death, slot reuse); MOVE-TEST-02 once tunnels
  exist. Write the lane note `docs/tasks/lanes/06/<date>-hauling-h8-acceptance.md` and tick task 06.4.
- **Read first:** section 7 (satchels, lots and claims already live there; nothing new is needed, 1022); section 4
  for `Equipment.satchel`; ARCH-SAVE; `docs/persistence_state_registry.md`; `docs/ui_ux_controls.md`.
- **Depends on:** HAUL-H5, HAUL-H6 (merged, #220), HAUL-H7.
- **Files:** save sections, `godot/scripts/ui/`, `docs/tasks/`.
- **Decisions:** 1141–1150.
- **Acceptance:** the queue's text; a save/load round trip with live hauls and satchels; the live harness at
  1280x720 and 1920x1080.
- **Pitfalls:**
  - `haul_planner.audit()` rescans 8192 rows per store; a save-time check should sum per store in one pass (1023 §4).
  - One-satchel-per-owner is enforced only in `haul_carry.gd`, not in Inventory.
  - The haul UI probably needs `ui_ux_controls.md` rows first, as 1031 P7 did for store policy (no UI until
    UI-SET rows exist). If the spec has no rows, that is a PROPOSAL, not an invention.

<a id="demo-d7"></a>
## DEMO-D7 — DEMOLISH dispatch, stranded notice, UI and quicksave

- **Approval:** the D-table, D7 (DEC-043; 0531).
- **Scope** (ruling D-table; blocker 5; queue `DEMOLITION-D7`): a DEMOLISH dispatch arm whose payload is the building
  ref; the UI row 034 path; the exact stranded lots and occupants notice (REQ-SET-128); REQ-SET-158's
  pre-major-demolition quicksave; and, from D5/D6, the player paths for single-piece furniture removal and for
  "evacuate, then demolish".
- **What D7 must know** (0535, 0536, 0537 "What D7 must know"; 0534 Consequences):
  - Cancel only through `cancel_demolition()` / `cancel_furniture_removal()`; completion is never a player command.
  - Offer "evacuate, then demolish" when `is_evacuable_refusal()` is true, through `order_evacuate_then_demolish()` /
    `cancel_evacuation()`.
  - The notice reads `blocked_furniture_count` / `blocking_furniture` for `DEMOLITION_FURNITURE_UNDER_CONSTRUCTION`
    (0535's `..._PAID_PACKAGE_UNREADABLE` was superseded by 0536 and no longer exists).
  - `DEMOLITION_RESERVATION_MISMATCH` means cancel and re-request.
  - **The notice must not promise hauling until 06.4 has landed** (H5).
  - `DemolitionReport` is shared scratch overwritten inside the tick: copy fields out. Never preview every frame.
  - A player's CANCEL_JOB on a removal job is undone on the hour (0537 P4).
- **Depends on:** D4, D6 (merged). Best after HAUL-H5, so the evacuation flow has real hauls to show.
- **Files:** `command_dispatch.gd`, `ui_availability.gd`, very likely `settlement_system.gd`, save code and UI panels.
  Conflicts: H7 (`command_dispatch.gd`), H3–H5 (`settlement_system.gd`).
- **Decisions:** 1151–1160.
- **Acceptance:** queue text; REQ-SET-128's notice lists exact lots and occupants; the quicksave is taken; refusals
  byte-identical; UI row 034 enabled with a truthful reason.
- **Pitfalls:**
  - Row 034's reason on master is `REASON_NO_BUILDINGS_PLACED` (`ui_availability.gd`); the ruling's
    "NO_BUILDING_STORE" is stale.
  - `DemolitionReport` has `occupant_count` but no occupant refs; REQ-SET-128 asks for exact occupants.
  - No save-slot, autosave or quicksave manager was found in `godot/scripts` (grep-level check): the quicksave may
    have nothing to call. Saving is otherwise deferred (group S, F23).
  - Open demolitions do not survive a load (no CONSTRUCTION-SAVED-BINDINGS).
- **Open:** Q-S1 (command kinds: ARCH-CMD-003 fixes 24 kinds; REMOVE_FURNITURE and evacuate are not among them);
  Q-S5 (when the quicksave is taken for an evacuation order); Q-S6 (quicksave with no save system).

<a id="demo-d8"></a>
## DEMO-D8 — Movement invalidation on demolition

- **Approval:** the D-table, D8 (DEC-043).
- **Scope** (D-table; blocker 7; queue `DEMOLITION-D8`): advance the topology revision and `destination_revision` on
  admit and on removal; clear the footprint; re-check affected routes (MOVE-REQ-006, revalidate before entry;
  MOVE-REQ-019, economy and movement agree on the carried load before a crossing); retest MOVE-TEST-05 and
  MOVE-TEST-10.
- **What D8 must know** (0535, 0536, 0537, 0534 R3): the destination revision already advances at admit,
  cancellation, the commit's release, a deferred hourly admit, and a commit from the work stage or the hourly retry.
  The footprint is freed in `demolish_building()` inside `_remove_structure()` (`settlement_system.gd`); the topology
  revision and route re-check belong there, wherever the commit was called from. A piece's removal advances its
  building's revision with no footprint change. A removal job's destination is the subject contact. The return's
  piles land outside the footprint. 0534 R3: the revision stays in the coordinator until BUILDINGS-SAVED-BINDINGS or
  D8 moves it into the building store. (0532's "refuse a footprint over a live pile" was done by D3 in
  `buildings.gd`.)
- **Depends on:** D5 (merged) per the queue; in practice HAUL-H3, because real routes must exist to re-check.
- **Files:** `movement.gd`, `test_movement.gd`, `settlement_system.gd _remove_structure()`. Conflicts: H3, H4, H5.
- **Decisions:** 1161–1170.
- **Acceptance:** queue text; MOVE-TEST-05 and -10 pass on the composed path.

<a id="demo-d9"></a>
## DEMO-D9 — Independent QA and a visible run of demolition

- **Approval:** the D-table, D9 (DEC-043).
- **Scope** (D-table; queue `DEMOLITION-D9`): INV-GOODS-R01's full-gate list plus DEMO-CONTAIN-R01's additions
  (`docs/planning/destructive_edit_endpoint_contract.md` §7): owner and tile scans agreeing and disagreeing; an
  anchored NULL_REF refusing; satchels excluded; an outside pile surviving; furniture returning 50%; a tier-2 fixture
  (BUILD-C4-R01); refusals byte-identical across all four stores. An independent reviewer and a visible Mac run
  (frames looked at). Closes REQ-SET-127/128 and `CONSTRUCTION-EVACUATION-INTEGRATION` only if everything passes.
  Lane note `docs/tasks/lanes/06/<date>-demolition-d9-acceptance.md`.
- **Depends on:** D2–D8 and, in effect, HAUL-H5 (0537: `CONSTRUCTION-EVACUATION-INTEGRATION` cannot close without
  real hauls).
- **Decisions:** 1171–1180.
- **Pitfalls:** tier 2 is implemented but not ACCEPTED until the ruleset, catalog and save identity are versioned
  under REQ-SET-001 (0534 Why). Do not mark it accepted.

---

# Part 2 — Measures phase 2

<a id="meas-2"></a>
## MEAS-2 — Measures phase 2: natural measures in the demo and the settlement UI, and the Underground rename

- **Approval:** Brendan, 2026-10-02: replace "U" with per-good measures (the weight in the tooltip; plain words on the
  HUD's quick readouts) and rename the "U view" to "Underground", keeping the U key. The measures table and P1–P6, P8
  approved; P7 changed to "Apply to demo and game spec"; P9 (b) and P10 (b). Recorded in decision **1011** and
  **DEC-049**, with `docs/ui_ux_controls.md` amended (all on `feat/demo-measures`).
- **Scope** (1011 §3–§5, §4a, §4b):
  - **A new module** `godot/scripts/ui/goods_measures.gd`: static, `RefCounted`, const packed rows; `amount`
    (rounds down), `need` (rounds up), `exact`, `have_need`, `weight` (integer grams) and `tooltip`; masses from
    `item_definitions.gd`; an unknown key `push_error`s and returns "?". It lives in `scripts/ui/` because the
    settlement layer must not depend on `demo/`.
  - **The demo HUD** (§3): Wood becomes the five-word band (none / very low / running low / enough / plenty; P6),
    driven by `firewood_urgent()`, `firewood_wanted()` and `projection_milli()` through `demo_hud_model.gd bind_fuel`;
    Stone shows "N blocks"; Ready food and Heating fuel stay in days.
  - **Replace and then delete the demo's U helpers** (§4): `farm_text.gd units_text` (about 140 callers),
    `forest_rules.gd units_text` (about 60), `tunnel_stores.gd units_text`/`stock_line`, `action_card.gd`
    `need_text`/`add_cost`/`amount_text`, `cellar_projects.gd`, `infirmary_project.gd`, `care_text.gd`,
    `fishery_text.gd`, `farm_tending.gd _units`, `room_fixtures.gd amounts_text`, the dispatchers in `goal_book.gd`,
    `projects.gd` and `standing_kinds.gd`, six float `%.1f U` sites and about 40 literal-U strings. About 75 files and
    280 call sites.
  - **In nine sequential slices** (§4): (1) the module and its tests; (2) the HUD and stores; (3) farm and pantry;
    (4) kitchen and winter; (5) the woods; (6) fishery and water; (7) infirmary, hall, cellars, burrow, tunnel and
    spoil; (8) guide, goals, orders and chronicle; (9) the lint switched on, the README updated, the old helpers
    deleted.
  - **The settlement UI** (§4a, §4b): `scripts/systems/ui_manager.gd` Wood and Stone counters; `scripts/ui/hud.gd
    set_counter` takes the good and the milli-U (the NP counter keeps its own unit); `scripts/ui/ui_specimen.gd`
    ("1,234 logs"); the Wood counter (UI-SET-004) also shows the word level beside its available and reserved counts
    (P10 b), reading fuel-days and the projection from the economy's §5.8 owner, with no new formula in the UI.
  - **Underground** (§5): every player-facing "U view" becomes "Underground" (`tunnel_control.gd`, `help_topics.gd`,
    `demo_lens_picker.gd`, `group_select.gd`, `demo_party_panel.gd`, `sound_table.json`, and 14 mentions in
    `godot/demo/README.md`). The 228 mentions in code comments are renamed only when a file is touched anyway.
- **Read first:** 1011 in full (the table §1, §1a, the wording rules §2, the edge cases); DEC-049; the amended rows
  UI-SET-004, -005, -043, -050, -062, -066, -099 and the new closing section of `docs/ui_ux_controls.md`.
- **Depends on:** batch 8 (#222), the review fixes (#221) and perf merged (they all change demo text files; the
  coordinator scheduled phase 2 after them). Bring `feat/demo-measures`'s three commits in first (STATUS §2.5; DEC-049
  after DEC-048).
- **Files:** about 75 demo files, plus `ui_manager.gd`, `hud.gd`, `ui_specimen.gd`, `test_ui_manager.gd`,
  `test_hud.gd`. **This touches nearly every demo panel's text**, so it conflicts with any demo lane that adds or
  edits player-facing amounts. Run it alone, or with lanes that add no amount text (SEQUENCE.md).
- **Decisions:** 1181–1190. (1011 and DEC-049 already exist; phase 2 records what it found, not the rules again.)
- **Acceptance** (1011 §2, §4 Tests, Consequences):
  - `test_demo_measures.gd`: a row for every shown good, checked against `item_definitions.json`; every measure a
    whole milli-U; boundaries at 0, 1 milli, each measure and half, the from-2 threshold, 10 measures, and just below
    each; a sweep proving `amount` ≤ true and `need` ≥ true; `exact` round-trips every `dish_book.gd` input; the
    `have_need` "enough" edge; `weight` exact.
  - From a container's from-2 threshold up, an amount is within 20% of the truth, with the exact weight in the
    tooltip.
  - `test_demo_no_u_text.gd` lints `res://demo/**/*.gd` and `.json` for "N U", `%d U`, `%.1f U`, a bare " U" and
    "U view"; its allowlist shrinks to nothing by slice 9.
  - The about 40 existing string asserts are rewritten **by hand**, never generated from the module.
  - Conservation, simulation, save and balance tests pass **unedited**. Any diff to `*_milli` arithmetic, a `STEP`,
    or `scripts/core/` is out of scope.
  - The HUD's "running low" fits the 104 px cell at 1280x720; frames at 1280x720 and 1920x1080 of every changed
    panel, looked at.
- **Art:** none. The UI reference renders still say "180 U" (`docs/design/ui_refinement/render_targets.py`,
  `woodland_art_prompt.txt`): flag them for the UI art owner; do not hand-edit them (§4a).
- **Pitfalls:**
  - 1011's file:line references were taken at `fd9b80a1`; batch 8, the review fixes and perf moved them. Re-derive.
  - Check the "½" glyph exists in the HUD body font and `NotoSerif-SemiBold.ttf`; if not, write "1 and a half".
  - P5 leaves decision 0612's mismatch alone: the Cellar building counts capacity at 500 g/U, food is 250 g/U.
    Do not "fix" it here (open question Q-D6).
  - Flax, wax and mead rows exist in the table (§1, P9) though the demo has none of these goods yet; FLAX and HIVES
    use them.

---

# Part 3 — Demo follow-ups from batches 7 and 8

Small, already-ruled items left over from the integration batches. All are demo work. Base each on `origin/master`
after batch 8 (#222) and the review fixes (#221) have merged.

<a id="bld-panel"></a>
## BLD-PANEL — The shared Buildings panel, building thumbnails, and one herb patch

- **Approval:**
  - Infirmary P4, Brendan 2026-10-01: "Build the buildings panel" — one panel for the cellar, the infirmary and the
    hall (decision **0623** P4, recorded as pending).
  - Batch 7 ruling 6, Brendan 2026-10-02: the two herb patches are merged during the Buildings-panel work (decision
    **0902**, ruling 6, "Pending"). 0902 Q6's recommendation: the herbalist gathers through the forage store.
  - Building thumbnails "rendered free during the Buildings panel work" (Brendan, 2026-10-02, with the flax icon
    sheet). **Recorded only in the coordinator's tracker**; 0972 does not mention it. Free means a Blender render of
    the staged models, no paid generation.
- **Scope:**
  - One Buildings panel listing the demo's placeable buildings (the Cellar building, the infirmary, the Great Hall's
    tiers), each with its thumbnail, cost, state, and its existing build or upgrade action. Today the controls are
    scattered: the Cellar is under Pantry ▸ Stocks ▸ "Build a cellar…" (0612), the infirmary is a section of the
    Tunnels panel (0623), and the hall opens by clicking the hall (0771). The HUD's Build command is locked; its key
    (B) opens the Dig tool (0612).
  - Thumbnails rendered from the staged models with a free script (like `tools/make_demo_crop_cards.py`), staged
    with the other art and falling back to a plain card when not staged.
  - Merge the two herb patches: the infirmary's patch at (4.2, 24.5) (`demo/infirmary/care_rules.gd`, 160 U, 0622 P6)
    and the forage basin's herb bank at (-12.0, 23.6) (`demo/forage/forage_rules.gd`) both feed the one care shelf.
    Keep one patch; the herbalist gathers through the forage store.
- **Read first:** 0612, 0621–0623, 0771, 0902 (Q6 and ruling 6), 0681; `docs/ui_ux_controls.md` for the Build
  command's zone and states; review UX-005 (stable information homes; RG-AK) so this panel can become the "Build &
  Plans" home later.
- **Depends on:** #221 merged (0995 gives the infirmary its own hearth and fuel row; the panel shows it).
- **Files:** new `godot/demo/ui/buildings_panel.gd` (or similar), `demo_village.gd` (hook), `demo_menu.gd` or the HUD
  Build command, `infirmary/*`, `forage/forage_rules.gd`, `stores/*` (cellar UI), `hall/*`; a new thumbnail tool under
  `tools/`, called from `stage_demo_assets.py`. Conflicts: RG-AK (UX-005), MEAS-2 (amount text), ZONES.
- **Decisions:** 1191–1200.
- **Acceptance:** every existing build path still works and is reachable from the panel; the old entry points either
  remain or redirect (say which in the record); frames at 1280x720 and 1920x1080; one herb patch, with the care
  shelf's restock and the forage trips still conserving herb; the thumbnail tool's self-test in CI like
  `test_stage_art_passes.py`.
- **Art:** thumbnails rendered free from staged models (`infirmary_ward`, `hall_stage2`, the Cellar's library model,
  the timber hall). No paid art.
- **Pitfalls:** the B key: UI §5 binds B to `open_build`, while the demo's Dig tool also uses B
  (`tunnel/tunnel_control.gd`). Decide and record which opens what; check `test_input_map.gd` and the input harness.
- **Open:** Q-D1 (does the Build command (B) open this panel, and Dig move elsewhere?).

<a id="flax"></a>
## FLAX — Flax, and the flax → rope / cloth chain

- **Approval:** crops P2, Brendan 2026-10-01: "Add flax now" (decision **0881**, proposal 2; recorded as pending).
  The coordinator's post-batch-7 queue added "plus the GDD's fibre → cloth chain if defined; restocks the care
  shelf's cloth" (tracker). Flax icons approved and made (0972); the flax plant model is DEC-047's (0.80 m).
- **Scope:**
  - Grow flax: the GDD's FIBER row (`docs/game_gdd.md` §5.6: loam or sand, sown spring days 1–6, 168 h, 5 U a tile,
    seed 0.25; flax 250 g, no NP, never spoils; starting `seed_flax` 16 U).
  - The chain **the GDD defines** (§5.7): `rope` = flax 2 → rope 2, 20 WU, Workbench, Start; `cloth` = flax 4 →
    cloth 2, 30 WU, Workshop, M1. 0881 recommends rope first. There are **no spinning or weaving stages** in the GDD
    ("linen" is only an icon name): do not invent them.
  - Cloth goes into **0993's single village cloth store** (`tunnel_stores.gd`, with its claimant rows for the hall,
    the infirmary and treatments). Cloth consumers in the GDD: the hall upgrade (8), the infirmary building (12),
    treatment (0.5, REQ-SET-173), beds, the boat (8).
- **Read first:** GDD §5.6–§5.7; 0881 (proposal 2 and its recommendation); 0993 (one cloth; "any new cloth consumer
  adds a claimant row"); DEC-046 (twelve beds, default sowing); 1011 (flax is counted in bundles and handfuls, P9 b).
- **Depends on:** #221 merged (0993). Before or with MEAS-2's farm slice.
- **Files:** `godot/demo/farm/farm_catalog.gd` (flax is listed as EXCLUDED; see Pitfalls), `farm_crop_roles.gd`
  (says "the demo grows no flax"), `farm_sim.gd`/`farm_planner.gd` (sowing), a workbench recipe (where the gear
  locker's rope is made today: `fishery/gear_locker.gd`), `tunnel_stores.gd` (cloth in). Conflicts: every packet that
  adds a pantry item or crop (HIVES, PRESERVE, BREW), `farm_catalog.gd` numbering (SEQUENCE §3).
- **Decisions:** 1201–1210.
- **Acceptance:** flax sown, grown and harvested on the field beds by the default sowing policy or the planner; rope
  made at the workbench; if the Workshop exists in the demo (it does not today, and needs iron 4), cloth made there,
  otherwise recorded as blocked and raised; conservation tests from seed to cloth; icons `item_flax` (and alternates)
  picked up by key.
- **Art:** `plant_flax` (art pass 2, mapped not wired; `stage_art_passes.py` writes a flax plant row) and the 0972
  icons. Nothing new.
- **Pitfalls:**
  - `farm_catalog.gd` excludes flax on purpose: "not in the pantry at all -- it is cloth and rope (§5.7), not food".
    Its crop items 0–15 are pantry items, and the catch and goods ids follow them (`FIRST_CATCH` 16 …). So flax needs
    a crop row that harvests into the village stores, not a pantry item; **inserting a crop into 0–15 would shift
    every later item id** (catch, goods, forage, fruit) and break saved numbers and tests. Record the design.
  - The Workshop needs iron, which the demo's stores do not hold (only the gear locker has 2 U).
- **Open:** Q-D2 (how cloth is made with no Workshop or iron in the demo).

<a id="goals-2"></a>
## GOALS-2 — Goals "First crossing" and "Regatta day"

- **Approval:** Brendan answered "YES" (2026-10-01) to batch 6's question on the ferry and regatta goals, option (b).
  **Recorded only in the coordinator's tracker**; decision 0901's question is still unanswered in the record. Record
  the ruling in this lane's decision, citing RULINGS.md. "Every dish" was settled separately (0902 reconciliation 5:
  everyday dishes only).
- **Scope** (0901, option b): add "First crossing" (ferry crossings ≥ 1) and "Regatta day" (regattas held ≥ 1) to the
  village goals. The counters exist: `demo/ferry/ferry.gd` `crossings_done`, `demo/regatta/regatta.gd` `feasts_held`.
  Register through `demo/goals/goal_book.gd register(...)`; the list is `demo/goals/village_goals.gd`. Not in scope:
  option (c), binding M4's `feasts` part to the regatta counter (unruled; it is not the GDD's COMPLETE count).
- **Read first:** 0781 (goals), 0901 (its question with the options), 0437–0439, 0631 (chronicle weaving of goals).
- **Depends on:** nothing beyond master.
- **Files:** `goals/village_goals.gd`, `goals/goal_book.gd`, the help topic and README section.
- **Decisions:** 1211–1220.
- **Acceptance:** both goals reach on the real counters; a test per goal; frames of the goals panel.

<a id="hall-fuel"></a>
## HALL-FUEL — The hall's tier-2 fuel factor ×0.75

- **Approval:** batch 7 ruling 5, Brendan 2026-10-02: "a per-source tier factor in `hearth_fuel.gd`" (decision
  **0902**, ruling 5, "Pending"). The value is the GDD's (§5.9: residence or hall tier 2 "heat fuel×0.75";
  REQ-SET-136; `gameplay_balance.md` hall row fuel 3/4) and decision 0771's.
- **Scope:** `demo/winter/hearth_fuel.gd` computes one `day_rate_milli` for every source and calls
  `Rules.day_demand_milli(...)` without the tier argument, so the hall burns at the full rate. Give each source its own
  tier factor (the hall's from `hall_rules.gd FUEL_PERMILLE [1000, 1000, 750]` / `demo_hall.gd fuel_permille()`;
  `winter_rules.gd TIER2_FUEL_PERMILLE` 750 already exists), and carry the per-source rate into `heating_day_milli()`,
  `demo_winter.gd`'s fuel-days, the HUD's "Heating fuel: N days" and the 12-day projection, and M4's fuel goal
  (`fuel_winter_days_milli`, 0902 item 9).
- **Read first:** GDD §5.8–§5.9; 0571; 0771; 0902; 0995 (adds an INFIRMARY source row).
- **Depends on:** #221 merged (0995 changes `hearth_fuel.gd`'s source rows).
- **Files:** `demo/winter/hearth_fuel.gd`, `winter_rules.gd`, `demo_winter.gd`, tests. Conflicts: WEATHER (exposure),
  FEAST (fuel-days), MEAS-2 (HUD wood words read the same projection).
- **Decisions:** 1221–1230.
- **Acceptance:** at hall tier 2 the hall burns 0.75 of tier 0/1; the HUD days and projection agree with the burn;
  boundary tests at each tier.
- **Pitfalls:** REQ-SET-130's 20 °C at tier 2 is also missing (`winter_rules.gd` has only HEATED_TENTHS 180). It is
  in the same rule row; record whether you add it (it is adopted GDD, so it is not a proposal).

---

# Part 4 — Approved features not started

**Where these approvals are recorded.** Brendan approved these features by number from his feature lists of
2026-10-01 (the coordinator's "FEATURE SCHEDULER" list, then "NEW 2" and "NEW 3"). Those lists survive **only in the
coordinator's tracker**, and only as titles; no longer description was kept. This handoff (RULINGS.md) is the first
repository record of them. So for each packet: the title is approved; the **scope below is derived** from the GDD and
the review items that fall under it; where the scope goes beyond what the GDD defines, that part is a PROPOSAL or an
open question. The first lane of each packet records the approval in its decision record, citing RULINGS.md.

**Shared facts every packet here needs** (checked on batch 8):

- **Food and material rules.** No livestock, milk or eggs (`docs/setting_rules_amendment.md`; pantry
  `policy.excluded_food_pipelines` in `docs/redwall-content-library/shared/pantry.json`). Fish only from the
  nine-species whitelist; eel and pike are hazards, never food. No shrimp (DEC-045). Salt only from coastal brine,
  and the demo village has no coast (`demo/water/water_dressing.gd`). Every content-library recipe is
  `NOT_RUNTIME_ACTIVE`; an added ingredient is labelled `INFERRED_GAME` (LIB-002, `authoring_handoff.md`). New
  recipes need Brendan's approval, as DEC-045 did.
- **The demo's stores** hold wood, stone, planks, water and earth (`demo/tunnel/tunnel_stores.gd`), plus cloth after
  0993. **No iron or rope** except the gear locker's 4 U rope and 2 U iron (`demo/fishery/gear_locker.gd`). So the
  GDD buildings that need iron or rope (Brewery, Preserver, Workshop, Dryer, Apiary) cannot be paid for as written.
  This is open question **Q-D3**; ask once, for all of them.
- **Milestones (M1–M4) are not evaluated in the demo**, so a GDD unlock "at M2" has no trigger. Lanes so far made
  buildings available from the start (0612 P1); that is a PROPOSAL each time.
- **Waiting art** is keyed: an item added with key `jam` picks up `item_jam` (0903 ruling 9). Models and effects are
  "mapped, not wired" (0903): each mapping file names the code meant to draw them.
- **Work-board sources and pantry items** are numbered in one file each (`work_ids.gd`, `farm_catalog.gd`); see
  SEQUENCE.md §3 for what to change and how numbering collides.

<a id="hives"></a>
## HIVES — Hives, honey and wax (group Y: ECO-011, ECO-012)

- **Approval:** group Y, 0493 (2026-09-30); "HIVES: start soon (Y hives/honey/wax) after batch 7" (Brendan,
  2026-10-01; tracker only). Bee skep (0941) and bees (0971) made under approved art passes.
- **Scope:** the GDD defines hives fully (`docs/game_gdd.md` §5.6): strength starts 8000, healthy ≥ 5000; spring to
  autumn a tended hive makes honey 2 U + wax 0.25 U a day × strength/10000 for 20 WU of service a day; winter makes
  nothing and eats 0.5 U honey a day; missing winter feed −500 strength a day, a missed service day −200, a tended
  spring day +300; at 0 the hive is abandoned; recolonising costs honey 4, wood 2, 60 WU and three days. Pollination
  ×1100 with one healthy hive within 12 m, ×1150 with two, beans and orchard fruit only (REQ-SET-082/083). Apiary 3×3,
  wood 12 + rope 2, 180 WU, Keeper 1, one hive, M2. Honey: 1200 NP, raw edible, 1440 h shelf. Wax: decoration
  furniture (wood 1 + wax 0.25), `wax_candle` (wax 1 + flax 0.25 → 4 candles, Workbench, M2; a candle lights 12 m
  for 12 hours, REQ-SET-148). Wildlife pressure takes min(2 U, honey) from an apiary on a 200/10000 summer/autumn roll,
  halved by a fence. The review adds: winter feed protected first (ECO-012), a seasonal hive rhythm and a display of
  which crops benefit (ECO-011).
- **Read first:** GDD §5.6 hive rows, REQ-SET-079–083, the apiary row, §5.7 honey and wax recipes;
  `gameplay_balance.md` (BAL-RATIO-008/009); `setting_rules_amendment.md` ("wax remains available for current
  candles"); 0671 (the demo orchard runs real `orchard_hive.gd` rows with empty pollination links); 0603 (honey
  defined, no source).
- **Code:** `godot/scripts/core/orchard_hive.gd` implements REQ-SET-079–083 (settlement); job planner hive service
  (decision 0051). Demo: `honey` is item 25 with no source (`demo/kitchen/dish_book.gd` PENDING_SOURCES); the
  raspberry cordial waits on honey; `demo/fx/bee_swarm.gd` exists, not wired.
- **Depends on:** batch 8 merged. FLAX for candles (flax 0.25).
- **Files:** `orchard/*` or a new `hives/` folder, `farm_catalog.gd` (wax as a material, or in the stores), `work_ids.gd`
  (a hive-service source), `demo_village.gd`, `dish_book.gd` (remove `honey` from PENDING_SOURCES), `kitchen.gd` only if
  honey dishes change. Conflicts: FLAX, PRESERVE, BREW (`farm_catalog.gd`, `work_ids.gd`).
- **Decisions:** 1231–1240.
- **Acceptance:** honey and wax produced by the GDD formula and conserved; winter feed drawn first; pollination factors
  real for beans and orchard fruit within 12 m; the cordial cookable once honey exists; frames of the skep and bees.
- **Art:** `bee_skep` (0941), `bee_swarm.gd` (0971), icons `item_honey`, `item_wax`, `item_wax_comb`,
  `item_wax_candles` (0972). Nothing new.
- **Pitfalls:** bees are not sapient folk here; keep the swarm presentational. `orchard_hive.gd` "cannot see farm
  plots", so bean pollination needs the ARCH-SYS-006 join. Honey is food (pantry); wax is a material (stores).
- **Open:** Q-D3 (rope for the apiary); Q-D4 (unlock without milestones).

<a id="preserve"></a>
## PRESERVE — Preserving (#18)

- **Approval:** feature #18 (Brendan, 2026-10-01; tracker only). Group W's ECO-028 preservation trade-offs (0493).
  Art pass 3's preserving props and icons (0971, approved 2026-10-02).
- **Scope:** the GDD's preserving rows (§5.7): `dry_fish` (built as the smoking rack, 0434); `dry_fruit` fruit 4 →
  dried_fruit 3 × 1400 NP, 20 WU + 12 h, Dryer, 720 h shelf, M3; `salt_fish` fish 4 + salt 1 → 4 × 1600, 20 WU + 6 h,
  Preserver, 960 h, M1; `ration` flour 2 + dried_fish 1 + nuts 1 + water 1 → 3 × 2400, Kitchen, 1440 h, M2; salt only
  from a coastal saltpan. Buildings: Dryer 4×3 (wood 16 + rope 4); Preserver 5×4 (iron 2, M1). Storage ageing: pile
  1500, covered 1000, pantry 750, cellar 350. ECO-028: drying, salting and rations each with its own purpose; fresh
  food keeps a role.
- **What the GDD does not have:** jam, pickles and cheese. Their icons exist (0971) and the content library has
  source terms only (for example elderberry or damson jam; the oat-and-seed cheese with apple vinegar, which must stay
  the specific plant-milk evidence, `authoring_handoff.md`). Dairy is excluded. Jam has no GDD sweetener except honey.
  These need Brendan's recipe approval before they are built (Q-D5).
- **Feasible now in the demo:** `dry_fruit` (orchard fruit, 0671/0672) and `ration` (flour, dried fish and nuts
  exist). `salt_fish` is impossible without a coast.
- **Read first:** GDD §5.7, §5.8 storage; 0434, 0611, 0612; ECO-028; `docs/redwall-content-library/shared/pantry.md`.
- **Depends on:** batch 8 (fruit). HIVES before any honey jam.
- **Files:** `kitchen.gd`/`meal_rules.gd`/`dish_book.gd` (rations), the rack or a dryer under `demo/fishery/` or a new
  `preserve/` folder, `farm_catalog.gd` (dried fruit, ration items), `farm_storage.gd`. Conflicts: BREW, FEAST, RG-W,
  HIVES (`farm_catalog.gd`, `kitchen.gd`).
- **Decisions:** 1241–1250.
- **Acceptance:** dry_fruit and ration made by the GDD numbers, aged by storage class, eaten in the kitchen's rules;
  conservation tests; icons by key.
- **Art:** `crock_stoneware`, `jar_shelf` (0971, mapped not wired); icons `item_jam`, `item_pickles`,
  `item_dried_fruit`, `item_cheese`. Nothing new.
- **Pitfalls:** the Dryer's slots are taken by the smoking rack (0434): decide whether dried fruit shares them. The
  cellar's 350 factor already applies through `farm_storage.gd` (0611).
- **Open:** Q-D3, Q-D5.

<a id="brew"></a>
## BREW — Brewing (#19)

- **Approval:** feature #19 (Brendan, 2026-10-01; tracker only). Group W's ECO-031, a modest drink culture (0493).
  Art pass 3's brewing props and icons (0971).
- **Scope:** the GDD has **mead** only (honey 3 + water 3 → 4, 20 WU + 72 h passive, Brewery, M2; "feast ingredient
  only; no intoxication subsystem") and the Hearth feast's warm infusion (water + herb, no stored item). Brewery 5×4,
  wood 24 + stone 12 + iron 2, 480 WU, Cook 1, four passive slots, M2. ECO-031: water service, a herb infusion, one
  seasonal fruit drink; mead optional; "no dehydration system or alcohol dependence"; new drink recipes approved
  explicitly. DEC-045's drafted cordials exist (the raspberry cordial: berries 2 + honey 0.5, `dish_book.gd`), listed
  but never served.
- **What the GDD does not have:** ale and cider (icons exist; the content library has candidates such as October ale
  and cider, inactive). DEC-007 leaves "beverage/alcohol presentation" open.
- **Read first:** GDD mead, Brewery and feast rows; DEC-007; ECO-031; 0603; 0682 (the infusion at the regatta).
- **Depends on:** HIVES (mead and the cordial need honey); PRESERVE (it shares `kitchen.gd` and the passive-stage
  machinery).
- **Files:** `dish_book.gd`, `kitchen.gd`, a brewing station under a new folder, `farm_catalog.gd` (mead), the regatta
  menu if drinks are served there. Conflicts: PRESERVE, FEAST.
- **Decisions:** 1251–1260.
- **Acceptance:** mead brewed by the GDD row; drinks served at a feast; the infusion and cordial served where the
  ruling says; no intoxication mechanic.
- **Art:** `ale_cask`, `brew_vat` (0971); icons `item_ale`, `item_cider`. Nothing new.
- **Open:** Q-D3 (iron for the Brewery); Q-D5 (ale and cider; how alcohol is depicted, DEC-007).

<a id="feast"></a>
## FEAST — Feasts (#9)

- **Approval:** feature #9 (Brendan, 2026-10-01, "NEW 2"; tracker only). Group AE's SOC-023 (feasts with occasion
  and memory), 0493. Feast rulings of 2026-10-01: "Add nuts & herbs now" (done, 0681/0682) and the feast stays at the
  17:00 supper (tracker; written into `demo/regatta/regatta_rules.gd` as the regatta's time, not as a recorded
  ruling).
- **Scope:** the GDD's feasts, REQ-SET-100–106: block if fewer than 3 food-days or 3 fuel-days remain, unless
  overridden (REQ-SET-101); start at 18:00 in up to three waves (REQ-SET-103); themes Hearth (M1: bean_hotpot ceil(E/3),
  nut_loaf ceil(E/3), infusion; Shared Warmth: cold −25%, mood +400, 48 h), Harvest (M2: feast_fish, berry_tart,
  mead) and Orchard (M3: nut_roast per SET-AMEND-001 §4.2, orchard_crumble, mead); 2 cooks + 1 keeper at skill ≥ 2;
  seats ≥ ceil(E/3); wood ceil(E/12); at most one feast in any 72 h. The regatta (0437–0439, 0682) already serves the
  Hearth feast in full once a season; this packet makes feasts a player-called occasion and adds the other themes as
  their ingredients exist.
- **Read first:** GDD §5.7 feast rows and REQ-SET-100–106; DEC-007 (layered feast meanings); 0438, 0682; SOC-023;
  `docs/setting_rules_amendment.md` §4.2.
- **Depends on:** HIVES and BREW for Harvest and Orchard themes (mead, honey); DAYPLAN if the feast hour moves.
- **Files:** `demo/regatta/*` (shared feast machinery), `kitchen.gd`, `goals/*` (M4 `feasts`), `winter/cold_exposure.gd`.
  Conflicts: PRESERVE, BREW, RG-W (`kitchen.gd`), HALL-FUEL (fuel-days).
- **Decisions:** 1261–1270, superseded by **1701–1709** (the digging branch uses 0991–1217; README §3.6). Built: 1701.
- **Acceptance:** a Hearth feast can be called, is refused truthfully under REQ-SET-101, serves its waves, and its
  buff reaches the residents; the other themes cook when their ingredients exist and say "needs X" otherwise.
- **Pitfalls:**
  - The regatta's `fuel_days_milli` counts only the kitchen's wood (`regatta.gd`); since winter, §5.8 fuel-days live
    in `winter/hearth_fuel.gd fuel_days_hundredths`. Use those.
  - Shared Warmth is published as `cold_exposure_permille` (`regatta_menu.gd`) but `winter/cold_exposure.gd` never
    reads it: wire it.
  - M4's `feasts` goal is not bound (0901).
  - 0438 records SOC-024 (several feast forms; separate verdicts instead of the GDD's 80% rule) as NOT adopted.
- **Open:** none. Q-D11 is CLOSED: "All at 17:00 supper" (Brendan, 2026-10-07; decision 1701).

<a id="skills"></a>
## SKILLS — Skills (#23)

- **Approval:** feature #23 (Brendan, 2026-10-01; tracker only). Group AC's SOC-002 and SOC-005 (0493), with "the
  mentoring rule change to be recorded" (RG-AC).
- **Scope:** the GDD's skills (§4.3 catalogue; §5.2 work factor; §5.3 XP and levels): 10 XP per productive WU; level = min(10, floor_sqrt(floor(xp/5000)));
  skills never decay; skill factor 1000 + 50 × level; total work factor = clamp(floor(skill × mood × health / 10^6),
  300, 1800); 12 skill columns, 11 active (REQ-SET-025); starting levels 2 (the keeper's KEEP 3); mentoring 100 XP an
  hour; a naming trigger at skill 8; UI-SET-040 skill row. Unify the demo's per-lane skills into one set.
- **Read first:** GDD §4.3, §5.2 (work factor), §5.3 (skills), REQ-SET-025; `ui_ux_controls.md` UI-SET-040; LORE-P12 (skills are not
  species); 0571 (Chilled is a ruling replacing the GDD's health loss); 0622 (`demo/work/work_pace.gd`).
- **Code today:** each lane keeps its own XP (`forest_skills.gd`, `demo/tunnel/dig_skills.gd`, bridging,
  `forage_skills.gd`, `fishery/fish_skills.gd`, the healer). Dig and bridging are demo skills outside §4.3. The People
  panel watches four. `work_pace.gd` multiplies owner factors (infirmary health 600/850, winter Chilled 800); "the demo
  has no mood".
- **Depends on:** nothing hard; RG-AC's SOC-005 apprenticeship fits here (recommended).
- **Files:** the skill files above, `work/work_pace.gd`, `people/*`, crews (`swim_rules.gd`, `fishery_rules.gd`, dig and
  woods crews). Conflicts: most crew files; run it alone or with lanes that touch no crew.
- **Decisions:** 1271–1280.
- **Acceptance:** one skill set per resident with the GDD columns; each crew's speed reads it once; the 300–1800 clamp
  applied; no double counting; existing crew tests still pass or are changed for a recorded reason.
- **Pitfalls:** several crews already apply 1000 + 50 × level themselves; adding a skill factor to `work_pace` would
  double-count. Forage level is deliberately "never a work speed" (`forage_skills.gd`).
- **Open:** Q-D9 (the mentoring rule change, if SOC-005 is folded in).

<a id="dayplan"></a>
## DAYPLAN — The day planner (#24)

- **Approval:** feature #24 (Brendan, 2026-10-01; tracker only). Group AC's SOC-006 seasonal schedules (0493).
- **Scope:** the GDD's schedules (§5.3): default SLEEP 22–06, ANYTHING 06–07, WORK 07–12, ANYTHING 12–13, WORK 13–18,
  SOCIAL 18–20, ANYTHING 20–22; a night shift offset 12 h; Flexible all ANYTHING; REQ-SET-034 (a change waits for the
  current ≤ 30-WU segment); UI-SET-042 schedule grid and UI-SET-091 templates (Day, Night, Flexible). Darkness: seasonal
  daylight; unlit outdoor work ×0.75 (REQ-SET-148).
- **Code today:** `demo/burrow/night_routine.gd` fixes DUSK 20 / DAWN 6; hearths 19–07; the cook rises at 05:00; meals
  called at 07 and 17 (`kitchen/meal_rules.gd`). Lighting (0541) uses the GDD's seasonal daylight but "the demo applies
  no darkness penalty". Run-until targets Dawn 06:00 and Dusk 20:00.
- **Read first:** GDD §5.3 schedules, §5.10 daylight, REQ-SET-034, REQ-SET-148; `ui_ux_controls.md` UI-SET-042, -091;
  0541, 0571, 0381.
- **Depends on:** HIVES/FLAX for candles if darkness is applied.
- **Files:** `burrow/night_routine.gd`, `kitchen/meal_rules.gd`, `session/run_until.gd`, `work/*`, a new planner UI.
  Conflicts: FEAST (feast hour), RG-AD (serving windows), TIME.
- **Decisions:** 1281–1290.
- **Acceptance:** per-resident schedules on the GDD's templates; changes wait for the segment; frames of the grid.
- **Pitfalls:** in winter daylight ends at 16:00 but residents work outdoors until 20:00 with no penalty; supper at
  17:00 differs from the GDD's SOCIAL 18–20; the feast time and run-until's Dusk target both depend on DUSK_HOUR.
- **Open:** Q-D14 (apply the GDD's darkness penalty in the demo; move meals to the GDD's hours).

<a id="weather"></a>
## WEATHER — Livelier weather (#34)

- **Approval:** feature #34 (Brendan, 2026-10-01; tracker only). Fire and lightning effects and the ice shader made
  under art pass 3 (0971).
- **Scope:** the GDD's weather (§5.10): exactly one major event a season, announced three days ahead (REQ-SET-142);
  storm (boats disabled, outdoor work ×0.80), drought, blight, early frost, hard freeze (exposure ×2); calm days; the
  ideal spell forced in the first spring. Make these visible and felt: storms with lightning, frost and ice, using the
  waiting effects.
- **Read first:** GDD §5.10; 0196, 0301, 0541, 0551, 0571; `demo/weather/demo_weather.gd`, `weather_view.gd`;
  `demo/farm/farm_season.gd` (REQ-SET-142 announcement).
- **Depends on:** nothing hard; WATER for river ice.
- **Files:** `weather/*`, `fx/lightning_fx.gd`, `fx/fire_fx.gd`, `work/work_pace.gd` (storm factor), `boats/*` (storm
  disables boats). Conflicts: WATER, HALL-FUEL, SKILLS (`work_pace.gd`).
- **Decisions:** 1291–1300.
- **Acceptance:** each GDD event shown and applied by its numbers; the storm's ×0.80 applied once through `work_pace`;
  frames of each event.
- **Pitfalls:** the GDD says "no additional random disaster, structure fire, siege or raider simulation exists in
  release 1" (§5.9, in the wildlife-pressure rule): a lightning-started fire would contradict it. Storms hurt nobody.
- **Open:** Q-D15 (may lightning start fires in the demo?).

<a id="wildlife"></a>
## WILDLIFE — Wildlife (#11)

- **Approval:** feature #11 (Brendan, 2026-10-01, "NEW 2"; tracker only). The rigged songbird, butterfly, frog and
  leaping trout made under art pass 2 (0951; sizes DEC-047: robin 0.45 m, butterfly 0.36 m span, frog 0.40 m;
  "ambient wildlife, not residents").
- **Scope:** ambient, presentational wildlife: birds perched and flying, butterflies in season, frogs at the water,
  trout leaping, following the seasons and the time of day. **No fauna simulation**: the GDD keeps FaunaStockReserved
  empty (REQ-SET-059/065), and `docs/planning/fauna_component_validation_contract.md` authorises "no active fauna".
- **Read first:** DEC-047; 0951; the fauna contract; REQ-ADM-001 (no hunting of mammals or birds); ECO-038 (no pest
  swarms).
- **Depends on:** nothing.
- **Files:** a new `demo/wildlife/` folder, `demo_village.gd` hook, `demo_prewarm.gd` (prewarm the clips). Few
  conflicts.
- **Decisions:** 1301–1310.
- **Acceptance:** wildlife drawn by season and hour; no simulation rows; frame cost measured at 9 and 25 residents;
  frames looked at.
- **Pitfalls:** birds can be sapient residents in this world (sparrows, kestrels in the species catalogue): the robin
  must read as a non-speaking bird.

<a id="water"></a>
## WATER — The water revamp (#54)

- **Approval:** feature #54 (Brendan, 2026-10-01, "NEW 3"; tracker only, title only). The ice shader (0971).
- **Scope (derived; confirm, Q-D16):** the tracker started it after the ferry, seasons and winter "(ice)". What
  exists: water part B (0431–0436), the weir sluice and leat (0441), the ferry (0437), pond ice for ice fishing (0433),
  and `demo/water/water_iced.gdshader`, used by no scene. Likely scope: seasonal water (winter ice on the river and
  ponds with the shader, spring flow), plus group AA's ECO-040 purposeful diving surveys (authored underwater sites
  with shore clues; random dive finds exist from 0196).
- **Read first:** GDD §5.4 fishing; SET-MOVE-001 and HAZ-001..003 (`underground_economy_hazard_amendment.md`);
  MOVE-G01–05 (swimming and diving stay inside the adopted movement scope); 0231 (water safety), 0431–0442.
- **Depends on:** WEATHER (freeze events); the follow-up "water rescue admission ignores injury" (FOLLOW-UPS).
- **Files:** `water/*`, `waterplay/*`, `fishery/*`. Conflicts: FISHING, TRADE, WEATHER.
- **Decisions:** 1311–1320.
- **Open:** Q-D16 (what #54 covers).

<a id="fishing"></a>
## FISHING — The fishing revamp (#49)

- **Approval:** feature #49 (Brendan, 2026-10-01, "NEW 3"; tracker only, title only). Group W's ECO-024 (catch plans
  and selective gear), ECO-025 (seasonal fishery stewardship), ECO-026 (demand-aware catch collection), 0493.
- **Scope (derived):** the review items above; the unwired parts of the GDD's fishing: the hazard roll (per 10000:
  net 12, trap 8, weir 5, boat 20, ice 24) and the rare-quality roll ("the roll is phase 2's",
  `demo/water/fishing_driver.gd`); "fishing boats" (the tracker made river trade wait on this for its boats).
- **Read first:** GDD §5.4 (habitats, gear, the catch formula, REQ-SET-043–056); 0431–0436; ECO-023–026;
  `setting_rules_amendment.md` (the fish whitelist; eel and pike hazards).
- **Depends on:** the infirmary (0621–0623) for injuries from the hazard roll. FOLLOW-UPS lists "the fishing hazard
  roll is unwired" too: it is the same item, so do it once, in whichever lane comes first.
- **Files:** `fishery/*`, `water/fishing_driver.gd`, `boats/*`. Conflicts: WATER, TRADE.
- **Decisions:** 1321–1330.
- **Acceptance:** catch plans, gear choice and stewardship shown before choosing; hazard and quality rolls by the GDD
  numbers, deterministic; boats use the new route planner (perf 1001).
- **Pitfalls:** boats need `route_kinds.gd` boat-crossing rows (group P's note); route code changed in perf 1001–1004.

<a id="trade"></a>
## TRADE — River trade (#37)

- **Approval:** feature #37 (Brendan, 2026-10-01; tracker only, title only).
- **Scope:** **undefined, and in tension with adopted rules.** The GDD has no trade (only future transfer hooks,
  REQ-SET-176–181). LORE-T05 rejects "claiming a functioning campaign, trade route or allied army where none exists".
  DEC-004 (regional relations) is open. SOC-042 (seasonal barter with two neighbours) is in **deferred** group V.
  Do not build until Brendan scopes it (Q-D17).
- **Depends on:** FISHING (boats), NEIGHBOURS.
- **Decisions:** 1331–1340.

<a id="paths"></a>
## PATHS — Paths and roads (#31), with worn ground (UX-026)

- **Approval:** feature #31 (Brendan, 2026-10-01; tracker only). UX-026 ground shaped by use, group AJ (0493), "no paid
  spend without asking".
- **Scope:** the GDD's paths (§5.9 building catalogue): Dirt path 1×1, no materials, 2 WU, ground speed +10%, Start; Paved path stone 1,
  6 WU, +20%, replaces dirt, M2; one project per road segment; REQ-SET-123 (a placement may not sever the last path to
  the hall). UX-026: plinths, doorsteps, aprons, yards; cosmetic wear that follows real route use, "without inventing
  a new maintenance tax".
- **Code today:** authored cosmetic paths (`demo/world/world_layout.gd PATH_SEGMENTS`, drawn on the minimap); the
  garden's paths (`farm/farm_garden.gd`); route previews from the real router (0461). No placeable path; no speed
  effect.
- **Read first:** GDD path rows, REQ-SET-123; UX-026; 0461; perf 1001–1004 (the planner the speed must enter).
- **Depends on:** perf merged (the router changed).
- **Files:** `world/*`, `cast/cast_nav.gd`, `tunnel/tunnel_router.gd`, `routes/*`. Conflicts: perf follow-ups,
  RG-AK (bridges), DIG.
- **Decisions:** 1341–1350.
- **Acceptance:** paths placed and built; walking speed changes through the router's costs with the cache invalidated
  (map revision); wear drawn from measured use; frame cost measured.
- **Pitfalls:** keep worn ground cosmetic only.

<a id="dig"></a>
## DIG — The digging revamp (#51), with group AA's dig items

- **Approval:** feature #51 (Brendan, 2026-10-01, "NEW 3"; tracker only). Group AA (0493): ECO-043 useful warren
  destinations, ECO-044 consequential discoveries, ECO-046 passage upgrades ("bracing reconciled with the adopted
  support contract"), ECO-047's remainder, ECO-048 tip reclamation, ECO-049 earth landscaping, ECO-050 inhabited
  rooms, ECO-051 cellars for different needs, ECO-052 a shared junction nook. Timber supports, rock face and find
  icons made under art pass 3 (0971).
- **Scope:** the review items above, on the adopted underground rules: SET-MOVE-ECON-001
  (`docs/underground_economy_hazard_amendment.md`): a 1 m³ cut quantum: brace wood 250 + stone 250 for 2000 mWU, cut
  4000 mWU giving 2000 milli-U `excavated_earth`, finish 3000; 9000 mWU a quantum; tips, backfill and salvage
  (ECON-004/005). Already built: ECO-045 dig stages (0461), ECO-047's first half (spoil is earth, never compost; 0401),
  the cellars (0611/0612), outlets (0884), the brace art (0903).
- **Read first:** the underground amendment in full; GDD adoption note; 0204–0212, 0361, 0371, 0401, 0461, 0611, 0612,
  0884; ECO-043–052; DEC-029, DEC-031, DEC-040.
- **Depends on:** batch 8 merged.
- **Files:** `tunnel/*`, `burrow/*`, `spoil/*`, `stores/*` (cellars). Conflicts: PATHS (embankments), ZONES (earth
  destinations), MEAS-2.
- **Decisions:** 1351–1360.
- **Acceptance:** each item met or a recorded PROPOSAL; ECON-002's costs unchanged; no surprise collapse (ECO-046:
  "never add surprise collapse to force upgrades"); the bracing reconciliation written down.
- **Art:** `tunnel_set`, `rock_face` (wired), `tunnel_post`, `tunnel_lintel` (staged, unused), icons `find_coins`,
  `find_old_map`, `find_spring`.
- **Pitfalls:** a "coins" find implies currency, which the GDD's economy does not have: a PROPOSAL. Digging is a demo
  skill outside §4.3 (see SKILLS). The amendment closes no MOVE gate.
- **Open:** Q-D21 (the coins find).

<a id="zones"></a>
## ZONES — Hauling zones (#33)

- **Approval:** feature #33 (Brendan, 2026-10-01; tracker only). Group W's ECO-033 purpose-based reserves and ECO-034
  shared storage policies (0493).
- **Scope:** demo stockpile zones and store policies on the GDD's model: ZoneType STOCKPILE = 7; REQ-SET-117 store
  filters and minimum reserves; REQ-SET-110 ground piles; 64-bit item filters per container. Unify the demo's separate
  stores (village stores, farm pantry, gear locker, care shelf) behind one policy view; carry goods between them by
  real hauls (today `demo/stores/cellar_haul.gd` moves surplus food; standing orders keep totals, 0711).
- **Read first:** GDD REQ-SET-110, -117, ARCH-STATE-004; 1031 (H6: a minimum is a withdrawal floor, never a fill
  target, P5; no store-policy UI until `ui_ux_controls.md` has UI-SET rows, P7); 0611, 0711; ECO-032–034.
- **Depends on:** batch 8; HAUL-H3+ if the demo is to share the settlement's policy code (it need not).
- **Files:** `stores/*`, `farm/farm_pantry.gd`, `fishery/gear_locker.gd`, `infirmary/*` (shelf), `orders/*`.
  Conflicts: BLD-PANEL, RG-W, MEAS-2.
- **Decisions:** 1361–1370.
- **Open:** Q-D18 (UI rows for store policies: 1031 P7 forbids a store-policy UI until the spec has rows; the demo
  lanes have built demo UI without spec rows before; confirm the demo may).

<a id="explore"></a>
## EXPLORE — Exploration (#55)

- **Approval:** feature #55 (Brendan, 2026-10-01, "NEW 3"; tracker only, title only).
- **Scope:** **the GDD is silent** (no exploration or fog of war; the map is a fixed 128×128 estuary with one exit;
  expeditions cover fishing only). Adjacent approved items: ECO-040 diving surveys, ECO-043/044 warren destinations and
  discoveries (group AA), the forage spots (0681), map layers (0581). ECO-042 canopy access waits on the MOVE gates.
  Confirm scope before building (Q-D19).
- **Depends on:** map layers (done).
- **Decisions:** 1371–1380.

<a id="neighbours"></a>
## NEIGHBOURS — Neighbours (#56)

- **Approval:** feature #56 (Brendan, 2026-10-01, "NEW 3"; tracker only, title only).
- **Scope:** **undefined, and in tension with adopted rules.** Neighbours as trading or allied partners collide with
  group V's deferral (SOC-042 barter, SOC-045 region), DEC-004 (open) and LORE-T05. The approved form nearest to it is
  SOC-021 visitors (group AE), which itself sits near "newcomers", which Brendan did not choose. Confirm scope first
  (Q-D19).
- **Depends on:** EXPLORE.
- **Decisions:** 1381–1390.

<a id="time"></a>
## TIME — Time controls (#59)

- **Approval:** feature #59 (Brendan, 2026-10-01, "NEW 3"; tracker only). The winter ruling "a Skip-to-next-season
  control" (0571 ruling 4); the tracker placed the skip "in the speed area".
- **Scope:** the GDD's speeds (PAUSED, 1, 2, 4 only; no 3x), REQ-SET-002/003/004/008 (overload steps down, or pauses at
  1x); UI-SET-014–018; keys Space and F1/F2/F3; pause reasons. Bring the Skip-to-next-season control from the Demo Lab
  (F8, `demo/winter/season_skip.gd`) into the speed area beside Run-until (`session/time_control.gd`, `run_until.gd`,
  `pause_ledger.gd`, 0471).
- **Read first:** GDD REQ-SET-002–008; `ui_ux_controls.md` UI-SET-014–018 and the input table; 0471, 0492, 0571.
- **Depends on:** nothing.
- **Files:** `session/*`, `winter/season_skip.gd`, the HUD top-right zone. Conflicts: DAYPLAN (run-until targets).
- **Decisions:** 1391–1400.
- **Acceptance:** the skip in the speed area with a confirmation; its effects match the Lab's; key bindings unchanged
  or recorded.
- **Pitfalls:** the skip deliberately does not live walking, meals or exposure (`season_skip.gd`); say so in its
  tooltip. Check F1–F3 against the demo's F-keys (F7, F8, F11, F12) — unverified.

---

# Part 5 — Review groups approved and not built

All approved by Brendan on 2026-09-30 (AK on 2026-10-01) and logged in decision **0493**. Read each item's full text
in `docs/reviews/2026-09-30-external-review.md` (search the ID). The status per item below was checked against the
decision records on batch 8; "built" means a record says so.

**Rules for every packet in this part.**

- These are proposals from an external review that Brendan approved as **directions**. Their numbers (percentages,
  counts) are the review's suggestions, not adopted values. Where the GDD or content library defines the thing,
  implement the adopted rule; where it is silent, the smallest sensible behaviour plus a PROPOSAL (README §3.2).
- 0493 is append-only: when you build an item, your own record says so; do not edit 0493's table.
- Several items overlap feature packets; the overlap is assigned below so nothing is built twice.

<a id="rg-w"></a>
## RG-W — Review group W, the rest

- **Approval:** 0493 row W (2026-09-30), with Brendan's conditions: "content calls within the content library,
  recorded in decisions; the pantry rules respected (eel a hazard, no shrimp, mussel coast-only, saltpan from coastal
  brine)". Queued after N and water B (both done).
- **Already built or assigned elsewhere:** ECO-023 fishing livelihoods (built, 0431); ECO-024 catch plans, ECO-025
  stewardship, ECO-026 demand-aware collection → **FISHING**; ECO-028 preservation's salting and rations →
  **PRESERVE** (drying rack built, 0434); ECO-031 drinks → **BREW** (the cordial row exists, 0603; the infusion is
  regatta-only, 0682); ECO-033 purpose reserves and ECO-034 shared storage policies → **ZONES**.
- **Scope here:**
  - **ECO-002** protected seed and recovery: auto-reserve next season's seed, show "feed now or expand", a yearly
    relief pouch after a failed seed harvest. Not built: the demo's seed is unlimited (0196).
  - **ECO-013** lasting roles for foraged foods: everyday-menu roles for nuts, mushrooms, herb and berries, roots as
    a fallback. Partly built (0681, 0682, 0622).
  - **ECO-027** bounded recipe substitutions: staple base, a required character ingredient, an optional seasonal
    accent; protected stocks. Not built (0601/0603 have the cook's choice and "waits: X" only).
  - **ECO-029** seasonal menus and daily service: a small menu planned two or three days ahead; today's food, winter
    stores and feast demand kept apart. Partly built (0381, 0601–0603).
  - **ECO-030** cooking preparation modes (everyday, careful, emergency). Not built.
  - **ECO-032** local supply buffers: refill targets at kitchen and workshop backed by deep stores. Not built
    (adjacent: 0611, 0612, 0711).
  - **ECO-035** a production flow view: gathered, carried, processed, served, spoiled, with the bottleneck and two
    suggested actions. Not built.
- **Read first:** GDD §5.6–§5.8 (food, recipes, storage); `docs/setting_rules_amendment.md` (food rules);
  `docs/redwall-content-library/` (pantry dependencies); 0381, 0601–0603, 0611, 0711, 0912.
- **Depends on:** MEAS-2 (amount text), PRESERVE and BREW (menu content), DAYPLAN if service windows change meal
  times. Split into two lanes if it grows: (a) ECO-002, ECO-029, ECO-030 (kitchen); (b) ECO-032, ECO-035 (stores and
  a view).
- **Files:** `kitchen.gd`, `meal_rules.gd`, `dish_book.gd`, `farm_pantry.gd`, `farm_sim.gd` (seed), new view files.
  Heavy `kitchen.gd` conflict with PRESERVE, BREW, FEAST.
- **Decisions:** 1401–1410.
- **Acceptance:** each item's review text met or a recorded PROPOSAL for what differs; conservation tests for seed
  reserves; no change to adopted recipe numbers.
- **Pitfalls:** ECO-002's "relief pouch" is a new source of seed; it needs a PROPOSAL, since nothing in the GDD gives
  free seed. Recipe substitutions must not invent recipes: dishes come from §5.7 and DEC-045.

<a id="rg-y"></a>
## RG-Y — Review group Y, the rest: gathering outings and orchard remainders

- **Approval:** 0493 row Y (2026-09-30). The orchard lane built most of Y (0671–0677, in batch 8). Hives, honey and
  wax are the **HIVES** packet.
- **Scope:**
  - **ECO-014** prepared gathering outings: the smallest slice exists (0681: a party of one to three goes out and
    returns with a haul). Remains: return-before-dark planning, a carry kit, a rest stop, an optional named lead, a
    remembered place, consent.
  - **ECO-009** nursery plans: remains moving a sapling with a delay (0673 says it needs its own ruling).
  - **ECO-010** orchard harvest groups: remains carts (baskets only today) and shares as percentages (built as a
    destination choice, 0674).
  - **ECO-015** protected groves: remains the grove's forage reserve, rest as a need, more than one grove (0675's
    own "not built" list).
- **Read first:** 0671–0677, 0681, 0682; GDD foraging rows; the content library for what may be gathered.
- **Depends on:** batch 8 merged. ZONES (carts are a hauling concern), DAYPLAN (return before dark).
- **Files:** `godot/demo/forage/*`, `godot/demo/orchard/*`, `work_ids.gd` only if a new board source is needed.
- **Decisions:** 1411–1420.
- **Open:** Q-D7 (moving saplings; carts).

<a id="rg-z"></a>
## RG-Z — Review group Z: woodland, gear and workshops

- **Approval:** 0493 row Z (2026-09-30), queued after M (done). No lane has started.
- **Scope:**
  - **ECO-016** woodland compartment rotations: two to four named compartments (harvest, recover, protected) with
    renewal dates.
  - **ECO-017** timber preparation choices: timber by use (fuel/deadfall, structural, sawn) rather than species, so
    log versus plank bridges is a real trade-off.
  - **ECO-018** landmark trees and clearance plans: "retain mature trees", marked landmark trees, a conflict
    preview (the protected grove, 0675, is adjacent).
  - **ECO-019** equipment packages: outcome bundles ("equip a bank fishery") as a readable bill of goods (gear is
    real, 0435).
  - **ECO-020** automatic repair and quality: an auto-swap rack, a repair budget, "serviceable" versus "carefully
    made" (partly built: no surprise breakage and manual Mend, 0435).
  - **ECO-021** workshop fittings (ropewalk, repair bench, sawing yard).
  - **ECO-022** craft provenance: maker and source notes on made objects.
- **Read first:** GDD forestry, workshop and gear rows; 0435; 0675; the woods code `godot/demo/forestry/`.
- **Depends on:** SKILLS for "carefully made" quality and makers; FLAX if the ropewalk uses flax.
- **Decisions:** 1421–1430.
- **Pitfalls:** quality tiers are not in the GDD's gear rows as far as checked (unverified): a PROPOSAL.

<a id="rg-ab"></a>
## RG-AB — Review group AB: the first year's cadence

- **Approval:** 0493 row AB (2026-09-30), queued after O (done).
- **Scope:** **ECO-036** calm earned through preparation (an authored first-year rhythm: learn one pressure, invest
  in one remedy, then a visibly quieter period); **ECO-037** seasonal work suggestions ("good time for…" from the
  real season and weather rules); **ECO-038** bounded landscape risk (named threats showing condition, maximum
  consequence and remedy; fence and lookout do different jobs; no animal pests). None built; threats were only moved
  onto the calendar, about one every nine days (0912, E7).
- **Read first:** 0451 (seasonal planner), 0571 (winter, the 12-day pre-winter target, Skip to next season), 0912;
  GDD threats and seasons.
- **Depends on:** WEATHER (threat sources), the balance rerun (MEASURE-BAL) to know whether the first year is calm.
- **Decisions:** 1431–1440.
- **Open:** ECO-036 leans on SOC-034's difficulty knobs, which are in deferred group AF: build only what stands
  without them, and raise Q-D8.

<a id="rg-ac"></a>
## RG-AC — Review group AC: roles, arcs and apprenticeship

- **Approval:** 0493 row AC (2026-09-30): approved, "the mentoring rule change to be recorded". **That record does
  not exist yet**: the first lane here writes it (a `DEC-nnn` for the rule change, because it changes the GDD's
  friendship-gated mentoring, plus the engineering record).
- **Built:** SOC-001 optional notability (0491 §4; remains the "first excellent craft" trigger, which needs craft
  quality).
- **Scope:** **SOC-002** physical limits versus learned roles in job explanations; **SOC-003** short hero arcs
  (non-military); **SOC-005** visible apprenticeship (one lead, up to two apprentices, lessons cost crew time,
  experience only from supervised work); **SOC-006** seasonal schedules with recovery (saved crew schedules; overtime
  repaid as rest).
- **Read first:** GDD skills and mentoring rows (the rule being changed); 0491; 0411 (crews); 0571.
- **Depends on:** SKILLS (#23) for SOC-005; DAYPLAN (#24) for SOC-006. Run after both, or fold SOC-005 into SKILLS and
  SOC-006 into DAYPLAN (recommended; say so in their records).
- **Decisions:** 1441–1450.
- **Open:** Q-D9 (the exact mentoring rule wording to record).

<a id="rg-ad"></a>
## RG-AD — Review group AD: daily life, households and care

- **Approval:** 0493 row AD (2026-09-30): "the child and elder items wait on the family package (PC-04)". PC-04 was
  adopted with children inactive (0521, DEC-044); its engineering gates 1–6 stay open.
- **Scope:** **SOC-007** daily service as the reward (player-set serving windows and capacity, staggered sittings, a
  social period, packed meals; meals at the hall and the night routine exist); **SOC-008** chosen community
  aspirations; **SOC-009** actionable community concerns grouped by real cause (notices 0591 and incidents 0331 are
  adjacent); **SOC-010** shared community care (settlement stores exist, 0521; the care selection pass is gate 6;
  nothing in the demo); **SOC-011** households and belonging (settlement `households.gd` exists; nothing in the demo);
  **SOC-012** life stages taking part (children inactive); **SOC-017** community recovery and care (injuries,
  treatment and the infirmary are built, 0621–0623, and 0995 on #221; remains the predicted range, a convalescent
  policy, light duties); **SOC-018** remembrance (no deaths in the demo); **SOC-019** emergency recovery chapter (needs
  SOC-034, deferred).
- **Read first:** 0521 and `docs/planning/family_*`; DEC-032, DEC-033, DEC-044; 0381, 0591, 0621–0623.
- **Depends on:** DAYPLAN (SOC-007's serving windows), FEAST. The child and elder parts wait on PC-04's gates and on
  children being activated, which needs Brendan (Q-D10). SOC-019 waits on AF (deferred).
- **Decisions:** 1451–1460.
- **Pitfalls:** DEC-033: children are never given hazardous work; with children inactive, build nothing that makes
  them act.

<a id="rg-ae"></a>
## RG-AE — Review group AE: civic life, customs, feasts and stories

- **Approval:** 0493 row AE (2026-09-30): "lore original only".
- **Built:** SOC-014 relationships from shared experience (0491 §6; no mechanical effect yet); SOC-026 a minimal
  repertoire (the otter songs, 0442); SOC-028 player-curated history (0491 §5, 0631).
- **Scope:** SOC-013 practical civic commitments; SOC-015 customs with obligations; SOC-016 rescue preparedness
  (rescue by capability 0231 and boat rescue 0432 are adjacent); SOC-021 visitors; SOC-022 a welcome period;
  SOC-023 feasts with occasion and memory (→ **FEAST**); SOC-024 several feast forms (0438 records it as NOT adopted:
  the GDD's feast rules are used as written; building it needs a GDD ruling, Q-D20); SOC-025 traditions with annual
  variation (the regatta has a graceful skip, 0438); SOC-026's remembrance piece; SOC-027 fair investigations;
  SOC-029 knowledge through people; SOC-030 rare, interpretable wonder (DEC-009, DEC-030: rare and meaningful, truth
  uncertain).
- **Not to build:** **SOC-020** admission as a service commitment overlaps "newcomers", which Brendan did **not
  choose** (2026-10-01); SOC-021 and SOC-022 depend on arrivals too. Ask before building any of the three (Q-D12).
- **Read first:** DEC-009, DEC-022, DEC-030; 0442; 0491; 0631; 0438.
- **Depends on:** RG-AD; FEAST for SOC-023.
- **Decisions:** 1461–1470.
- **Pitfalls:** every text is original; nothing quoted from the books (DEC-016, DEC-017 voice rules).

<a id="rg-ag"></a>
## RG-AG — Review group AG: camera places, a command vocabulary, "Why?" and an atlas

- **Approval:** 0493 row AG (2026-09-30), queued after E, F and G (done).
- **Scope:** **UX-003** camera places and return paths (partly built by the camera lane 0801: four session
  bookmarks, Follow, orbit, cutaway; remains Peek, Back, named views with layer and thumbnail, the layer handoff at
  entrances, saving them); **UX-004** a shared command vocabulary (a searchable action palette; menus, buttons and
  keys share named actions; debug triggers moved to a developer surface); **UX-010** "Why?" cause chains (at most
  three causes, linked remedies); **UX-012** a layered atlas (surface, water, underground; named places, entrances,
  player notes; map layers 0292/0581 are adjacent).
- **Read first:** `docs/ui_ux_controls.md` §5 (input) and the zone rules; 0332, 0461, 0581, 0801.
- **Depends on:** MEAS-2 (text). UX-004 touches every key binding: run it alone.
- **Decisions:** 1471–1480.
- **Pitfalls:** UX-004 must keep every existing binding working (`test_input_map.gd`, the input live harness); the
  binding inventory is in SEQUENCE.md §4.

<a id="rg-ah"></a>
## RG-AH — Review group AH: sketch-fund-build, commons and renovation

- **Approval:** 0493 row AH (2026-09-30): "paid art for the kit asked separately". Queued after M and H (done).
- **Scope:** **UX-013** sketch, fund, build (ghosts, then a funded phase, then staffed work; phases can pause);
  **UX-015** useful communal places (commons whose capped benefits come from real use); **UX-016** renovation with
  service continuity (preview who loses beds or access and where contents go; demolition D1–D6 is the settlement
  groundwork).
- **Not here:** **UX-014**, the composable architecture kit: "needs design brief" and was excluded from art pass 2;
  Brendan has not chosen it (see "Not chosen"). Do not build it.
- **Read first:** GDD construction rows; 0211 (construction theatre); 0531–0537; 0883 (garden placement waits on
  UX-013).
- **Depends on:** BLD-PANEL (building UI home); DEMO-D7 if renovation reuses demolition.
- **Decisions:** 1481–1490.

<a id="rg-aj"></a>
## RG-AJ — Review group AJ: UX-025 silhouettes and UX-028's remainder

- **Approval:** 0493 row AJ (2026-09-30): UX-025, UX-026, UX-028 approved, "with no paid spend without asking".
  UX-026 is in **PATHS**.
- **Scope:** **UX-025** silhouettes at play distance (a three-level visual hierarchy; five building silhouettes;
  tool silhouettes; a hero emblem); **UX-028**'s remainder: the seasons lane (0551) delivered only the seasonal art
  slice; remains lived seasonal scenes, date plaques and commemorative objects (feast dressing from real food is in
  0438, fruit-tree seasons in 0677).
- **Read first:** DEC-037, DEC-038, `docs/art-reference/visual_direction_alignment.md`; 0551; 0677.
- **Depends on:** FEAST and RG-AE for commemorations.
- **Decisions:** 1491–1500.
- **Art:** likely needs new models for silhouettes; that is a paid request (README §3.8). Prefer tints and existing
  models first.

<a id="rg-ak"></a>
## RG-AK — Review group AK: F48, UX-005, UX-006 and bridge removal with a cap

- **Approval:** 0493 row AK (Brendan, 2026-10-01; coverage gaps found after the review was decided).
- **Scope:**
  - **F48**: ambient jobs and props imply work they don't do. Mark real work sites (hover name, purpose, a valid
    verb) and stop showing fake visits as work. `godot/demo/cast/cast_routines.gd` still routes the fisher via the
    well, square and cauldron.
  - **UX-005**: stable information homes (shared workspaces: Stores, Work, Build & Plans, Community, Chronicle,
    Almanac, with Back and kept scroll position). Coordinate with BLD-PANEL, which builds one of these homes.
  - **UX-006**: demand-based plan comparisons (stores split into on hand, available, committed, expected; a "Compare
    plan" drawer). Partly adjacent: the Pantry shows stock plus incoming (0292).
  - **Bridge removal and a cap**: `godot/demo/waterplay/bridges.gd` has a fixed pool `MAX_BRIDGES = 6` and no remove
    function. The tracker's one line is the only specification found.
- **Read first:** the review's F48, UX-005, UX-006 text; 0292; 0461; `bridges.gd`.
- **Depends on:** BLD-PANEL (UX-005 shares its shell); MEAS-2.
- **Decisions:** 1501–1510.
- **Open:** Q-D13 (what "cap" means for bridges: keep 6, a different number, or a cost-based limit; what removal
  returns).

---

# Part 6 — Measurement

<a id="measure-bal"></a>
## MEASURE-BAL — Rerun the balance year matrix

- **Approval:** Brendan's tuning rulings of 2026-10-01 (E1 and E7 built in 0912; E2–E4 in 0603; E5 in 0886 and
  DEC-046) came with "rerun the year matrix after these and the winter merge" (tracker). Batch 7 ran only smoke runs
  (0902 reconciliation 13). The full matrix has not been rerun since the 2026-10-01 baseline.
- **Scope:** run the balance harness (decision 0911) on master after batch 8, the review fixes (0997 changes meal
  finalizing) and perf with 1005 (the cook serves as it cooks) have merged; write a dated report beside the baseline;
  compare with `docs/balance/2026-10-01-first-year-baseline.md` (92–98% of meals missed, 95–99% idle, 45 threats a
  year before tuning) and against `tools/balance_thresholds.json`.
  ```bash
  python3 tools/run_balance_matrix.py --out-dir <dir> --seeds 1 2 3 --days 48 --jobs 3
  python3 tools/balance_report.py --out docs/balance/<date>-<name>.md --svg-dir docs/balance/<date>-<name> <dir>/*.json
  ```
  Success is the log's `BALANCE-RUN ok` line, not exit 0; `--fixed-fps 30` is required (the run checks it).
- **Depends on:** #222, #221, perf merged. Rerun again after any packet that changes food, fuel or work (PRESERVE,
  BREW, FEAST, SKILLS, DAYPLAN, HALL-FUEL).
- **Files:** `docs/balance/` only, unless a harness fix is needed (`godot/tools/balance/*`).
- **Decisions:** 1511–1520 (only if a choice is made; a report alone needs none).
- **Acceptance:** the report committed with its SVGs; any threshold breach listed as a question for Brendan with
  options (as the baseline's E1–E7 were), never "fixed" by changing a rule.

<a id="measure-soak"></a>
## MEASURE-SOAK — A windowed soak and a 25-resident soak

- **Approval:** the soak test, feature #14 (Brendan, 2026-10-01; 0921), and its report's recommendations 3 and 4
  (`docs/performance/2026-10-01-soak-test.md`), which the coordinator queued: "rerun soak windowed and at 25".
  Also 0998 P3 (Brendan, 2026-10-02): give the soak's `CLOSE_FRAMES` close the same WeakRef audio wait as the scale
  test "when the soak harness is next touched".
- **Scope:**
  1. A `--windowed` switch in `tools/soak_test.py`, using the scale test's windowed set-up (vsync off, the window's
     size: `scale_test.gd _initialize`). The harness already samples `video_kb` and `texture_kb`. Estimate: half a day.
  2. A windowed 20-day soak at 9 residents, on this Mac and (on request) on the Windows build's machine class.
  3. A 25-resident 20-day soak (`--residents 25`). At 25 the routing cost dominated before perf 1001–1004; measure
     after them.
  4. 0998 P3's audio wait in the soak's close.
  5. Optionally, recommendation 5: find the "+2 objects per Restart" (also in FOLLOW-UPS; do it once).
- **Commands:** `python3 tools/soak_test.py --out-dir <dir> --days 20 [--residents 25]`; a restart run:
  `--days 3 --restart-every-hours 6`; when the kitchen, cast or night change, also `REDWALL_SLOW_TESTS=1`.
- **Depends on:** perf merged.
- **Files:** `tools/soak_test.py`, `tools/soak_report.py`, the soak harness under `godot/`, `docs/performance/`.
- **Decisions:** 1521–1530.
- **Acceptance:** two dated reports in `docs/performance/`, each with a verdict; no flag, or each flag explained;
  `tools/test_soak_report.py` still passes in CI.

---

# Part 7 — Follow-up fixes

<a id="follow-ups"></a>
## FOLLOW-UPS — Follow-up fixes not finished by `fix/follow-ups`

- **Approval:** the coordinator's post-batch-7 queue item 12 and its wrap-up line (2026-10-02, "STARTED follow-up
  fixes (fix/follow-ups, 1041–1049)"), under Brendan's standing instruction to fix found defects. Each item below is a
  defect against an already-ruled behaviour, not new scope.
- **First, check `fix/follow-ups`.** It started on 2026-10-02 with decision range 1041–1049. Its brief is not in the
  repository. By the snapshot it had committed items 1, 2 and 9 below (decisions 1041, 1043 and 1042) and was working
  on item 3. Read its decisions 1041–1049 (on its branch or on master) and strike what they finished. **What it did not
  finish is this packet.**
- **The candidate items** (the coordinator's list; source in brackets). The ten most likely in the lane's brief:
  1. The routes live harness's "dig: confirm refused for 120 frames" at 1280x720 on CI: find the root cause (a
     placeholder resident on the entrance?) instead of retrying. Codex review R08. [0903; tracker; R08; done by 1041]
  2. Tegwin spawns inside the cabbage bed. [the ferry lane's report, in the tracker; done by 1043]
  3. The Woods tree marks, LEAF against UMBER, fail the colour-blind check (forestry-owned colours). [the map layers lane's
     report, in the tracker]
  4. Bare boughs lose their LODs. [the seasons lane's report, in the tracker]
  5. Water rescue admission ignores injury (infirmary review M6). [the infirmary lane's report, in the tracker]
  6. The fishing hazard roll is unwired (`demo/water/fishing_driver.gd`; also FISHING). [the infirmary lane's report, in the tracker]
  7. `people_card` sizing. [tracker]
  8. +2 objects per Restart, held by something alive (owner not found; the soak report's two ways to find it).
     [`docs/performance/2026-10-01-soak-test.md` "Open"]
  9. `docs/validation/setting_contract.py` fails on master: it expects 60 items and the balance doc has 61 since
     `excavated_earth` (commit 52cc3fa8, 2026-09-12); fix the count at `setting_contract.py` and the "183 references"
     text in `docs/validation/README.md` if it moved. It was not in CI (excluded as a generator). [1011; tracker;
     done by 1042, which also puts it in CI]
  10. Fish on the store shelves (`farm_stock_view.gd`), and the "Harvested" label that covers the catch. [batch 5
      follow-ups; tracker]
- **Smaller open items found along the way** (lower priority; each from a record or the tracker):
  - an intermittent ambience-loop leak at headless quit (batch 3 and 5 notes; 0998 now waits on playbacks in the
    scale test);
  - "demo stores" wording in `tunnel_actions`, `room_fixtures` and `forest_crew`; the ledger scroll bar overlap; the
    roster's empty band (group E's open items, 0251);
  - at 720p the Residents workspace covers two right-column buttons; the history window needs two Esc presses; stale
    "(demo)" docstrings (group G's open items, 0261);
  - the playtest log's breadcrumbs copy owners' constants; Settings shows the full log path, which includes the
    account name (0562's open LOW/MEDIUM);
  - 0998 P2: fail the scale subprocess's other `WARNING:` lines (such as CI's "plays silent" cues);
  - 0997: `_publish` does not refuse a missing tally row;
  - the perf doc's "what is next" (`docs/performance/2026-10-02-route-planning.md`): `group_select.gd` status spikes at
    256 (29–32 ms p95), retried plans to goals no route reaches, the dusk crowd's walking step, a routing window
    overrunning by one expansion, tunnel and crossing trips unmeasured at scale, the cook's slot not handed its round
    at 256;
  - a layout check ("party 9: every member row reachable") failed once under doubled load (0902 "What the gates
    found");
  - the art notes in 0941 and 0951: the baked-fish icon has lemon slices; the raspberry's leaf mask is weak; the
    staged `residence` and `hall` keep 4096 px maps where GAP-04 says 2048; some bare-oak root flares catch snow.
- **Depends on:** nothing.
- **Files:** various; small and local. Conflicts: whichever packet owns the file.
- **Decisions:** 1531–1540 (1041–1049 belong to `fix/follow-ups`).
- **Acceptance:** each fix with a test that fails without it; the gates.

---

# Part 8 — The finish line

<a id="final-pass"></a>
## FINAL-PASS — The full review and playtest pass

- **Approval:** the coordinator's standing plan, "review and playtest pass; performance test (including Windows
  overload, the GTX 1660 floor)" (tracker, "OLD PLAN leftovers"); the release gates Brendan folded into this step on
  2026-10-01: asset contact metadata, the silent-video work chain, graphics tiers with the GTX 1660 floor, and
  fresh-player sessions run by Brendan (0493).
- **Scope:**
  1. **An independent full review** of everything merged since the Codex review of 2026-10-02 (which covered batches
     5–7 and D1–D4), in the same form: `docs/reviews/<date>-<name>.md`, findings with severity, then Brendan rules
     which to fix (as for R01–R07).
  2. **A composed playtest pass** at 1280x720 and 1920x1080: maximum notices, a party selection, winter and care
     feedback, a building card (the Codex review's "remains useful" item); every workspace and panel; a full game year
     with Skip to next season.
  3. **The art visual acceptance**, which only Brendan gives: `python3 tools/art_gate.py --check <id>` against
     `docs/planning/art_approvals.json` (only Brendan writes it). Pending for 0941, 0951, 0971, 0972 and 0981. Prepare
     the comparison frames; do not mark anything accepted.
  4. **The review's P8 asset items** (`docs/reviews/2026-09-30-external-review.md`, plan P8): support and contact
     metadata per featured asset (pivot, support anchors, door or use point, obstruction shape) and the "silent video"
     embodied-work chain (fell → shape → carry → saw → stack → bridge, checked as a silent video before sound).
  5. **Old visual reminders** (tracker): grass speckle, the gait's swing-foot scrape, a head-swing check. Art pass 2
     listed "free fixes" for some of these; 0951 records only the window glow masks and the winter oak, so check the
     others.
  6. **Fresh-player sessions** are run by Brendan, not by an agent: prepare a build only when he asks.
- **Depends on:** most packets done; at least MEAS-2 and the follow-ups.
- **Decisions:** 1541–1550.
- **Acceptance:** the review document committed; the playtest frames committed under `docs/playtests/` or listed;
  every finding either fixed, ruled, or queued with an ID.

<a id="win-perf"></a>
## WIN-PERF — The Windows performance test (GTX 1660 tiers)

- **Approval:** REQ-SET-163 (GDD: the qualification budgets on the Windows reference floor before claiming 256
  residents); the release gate "graphics tiers with the GTX 1660 floor" (0493); "Windows build only on request"
  (Brendan's standing rule; memory note).
- **Scope:** measure the demo and the settlement on the qualification floor (Ryzen 5 3600 / GTX 1660 Super 6 GB /
  16 GB, 1920x1080; `CLAUDE.md` "Performance targets"): frame p95/p99, simulation tick, UI work, memory; at 9, 25, 50,
  100 and 256 residents (the scale test's ladder). Define graphics tiers (none exist in the demo as far as checked:
  unverified) so the floor machine has a setting that meets the budget.
- **What exists:** `docs/validation/WINDOWS_START.md` (a headless validation package for Brendan's own PC, a 5090: it
  does **not** certify the floor); `docs/validation/qualify.py`; the scale test (`tools/scale_test.py`, `--windowed`);
  the perf doc's Mac numbers, which are "not REQ-SET-163 qualification results".
- **Depends on:** perf merged; MEASURE-SOAK's windowed switch; Brendan's hardware (a floor machine is not known to be
  available: Q-F2).
- **Files:** tools and `docs/performance/`; graphics-tier settings in the demo (a PROPOSAL).
- **Decisions:** 1551–1560.
- **Pitfalls:** the Windows build is made only when Brendan asks (README §3.10), from a checkout with the art
  restaged. The main checkout is stale (STATUS §3): build from a fresh worktree of `origin/master`.

---

# Deferred: do not build without asking

Brendan put these on the backlog. Building any of them needs his go-ahead first.

| Item | What | Record |
|---|---|---|
| Group V, SOC-035–045 | Combat, army, campaign (doctrines, formations, morale, militia, escorts, defensible places, barter with neighbours, an antagonist, a mission clock, a small region) | 0493: deferred to a separate tactical prototype (2026-09-30) |
| Group AF, SOC-031–034 | Progression and difficulty: unlock by competence, three starting premises, Charter "proofs", an explicit cozy contract | 0493: "come back to later"; raise again once a community day works (2026-09-30) |
| UX-021 | The paused return journal and save browser | 0493: deferred with saving and AF |
| UX-024 | Honest experience selection | 0493: deferred with saving and AF |
| F23, group S's save half | Save and resume for the demo | 0493 (group S: "save deferred"); "save reconsider" not chosen (2026-10-01, tracker) |
| UX-030 | An earned village music motif | 0493: backlog |
| UX-032 | A few named voices | 0493: backlog |
| Crowd rendering past 24 residents | The crowd presentation path (Codex R07's second half; scale-test hot spot 3); capacity limits (POI slots, seats, beds, hall door places, roster pool, overlay marks) | Brendan 2026-10-01/02: "route work now, crowd later"; "crowd path + capacity limits NOT now" (tracker; the perf doc says "deferred by Brendan") |
| Canopy access, ECO-042 | Trunk and ladder routes into the canopy | 0493 row AA: waits on MOVE-G01–05 |

<a id="art-next"></a>
## ART-NEXT — The next costed art list (nothing approved, nothing spent)

Paid generation is by request (README §3.8, decision 0961): put this list to Brendan, itemised and costed, and
generate nothing until he approves it and a cap. Add each new art need here as it is found, with its key and source.

| Item | Key(s) | Why | Style and cost | Source |
|---|---|---|---|---|
| The feasts' four new courses | `dish_feast_fish`, `dish_berry_tart`, `dish_nut_roast`, `dish_orchard_crumble` | They show the fallback swatch in the Pantry and the guide (no dish art) | The 3D-render item-icon style (ART-LOCK-001 as amended, 0971); one `nano-banana-2` image-to-image 3×3 sheet conditioned on pass 1's `sheet_foods_a`, as 0972's was: **about 6 credits** (0972's sheet cost 6; suggested cap 12). Five spare cells for other waiting dishes | Decision 1701 P8 (b), approved by Brendan 2026-10-07 |

# Not chosen: do not build

Brendan was offered these on 2026-10-01 and did not choose them (tracker, "Not chosen"; no repository record before
this file). Do not build them, and do not let another packet build them by the back door.

| Item | Notes |
|---|---|
| Newcomers (feature #7) | Also blocks review items SOC-020, and SOC-021/022 as far as they need arrivals (RG-AE) |
| The trader (feature #12) | TRADE (#37) was approved separately but has no scope: ask (Q-D17) |
| Mood bubbles (feature #13) | |
| Session recording (feature #6) | |
| Saving (feature #5, "save reconsider") | Saving stays deferred (above) |
| Seasonal foliage | Not chosen on 2026-10-01, marked "re-offer later": offer it again, do not build it unasked |
| The UX-014 building kit | Approved in 0493 group AH with "paid art for the kit asked separately"; art pass 2 excluded it ("needs a design brief") and it has not been asked for. Treat as not chosen until Brendan asks for a design brief |

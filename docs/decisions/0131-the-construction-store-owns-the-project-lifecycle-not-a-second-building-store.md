# 0131 — The Construction store owns the project lifecycle, not a second Building store
Date: 2026-09-12 · Status: Accepted

## Decision

Task 06.1's **Construction store** lands as `godot/scripts/core/construction.gd`, composed into
`settlement_system.gd` over the Building store decision 0087 already composed. It implements
REQ-SET-124–128 and REQ-SET-137's project lifecycle and nothing else.

| What | Where |
|---|---|
| GDD §4.2's Construction row + seven new index/ledger columns | `godot/scripts/core/construction.gd` (new) |
| §4.1/§4.2/§4.3's `materials_milli` bills, as this store's own catalog | same file |
| `Construction.new(_buildings)`, `clear()`, `construction()` | `godot/scripts/systems/settlement_system.gd` |
| 45 store tests + 5 composition tests | `godot/test/test_construction.gd` (new), `godot/test/test_settlement_system.gd` |

**06.1 stays unchecked and the §7.2 starter settlement is still not built.** Decision 0087's five
blockers are untouched: no owner for the starter build, no store for §5.11's unlock mask, no
room-validity declaration, no edge-furniture representation, no composed `gear.gd`. A generated
settlement holds 0 buildings, 0 rooms, 0 furniture **and 0 construction projects**, and a test now
pins the fourth number the way an existing test pins the first three.

## Why these choices

### Why this is not a second building store

`buildings.gd` owns the Building/Room/Furniture rows, the presence mask, the tile maps and the
unlock gate. This store owns only what stands behind a `Building.construction` reference: the
bill, the delivered ledger, the work remainder, the phase and the refund arithmetic. It BORROWS
`buildings.gd` — `Construction.new(p_buildings)` — and takes its directory and its definitions
from that store rather than building either. A `Construction` over its own allocator would open
projects, price them, refund them and pass its own suite while refusing `open_build()` for every
real blueprint; the composition test asserts the borrow, not the type.

### Why the §4.1 material bills live HERE and not in `building_definitions.gd`

Decision 0088 declined to transcribe §4.1's typed pair lists into that module in terms: "A pair
list is not an int32 column and transcribing it into one here would fix a representation the store
that needs it has not chosen." This is that store, and the representation it chose is an
owner-major table at a fixed stride of four, with a cell holding an INDEX into `MATERIAL_KEYS`
rather than a compiled ItemDefinition id — because ids are compiled at runtime from
`item_definitions.gd` and ARCH-CAT-004 forbids compiling one in. `building_definitions.gd` is
byte-untouched.

The stride is 4 because the largest authored bill is THREE typed pairs (§4.1 hall, kitchen,
workshop, weir, boathouse, brewery, preserver; §4.2 hall and residence; §4.3 kitchen_bench) and
the fourth cell is spare so that ECON-003's brace input cannot force a column reallocation.
`_assert_bills()` refuses construction if any authored row exceeds it.

### Why `begin_work()` is one function with one precondition

REQ-SET-125's consumption is the single most dangerous moment in the store: a half-committed
project that consumed materials and produced nothing is the worst failure the system can have.
So consumption is exactly one transition with exactly one gate, `add_work_mwu()` REFUSES in every
phase but PHASE_WORKING, and `_work_begun` is a column of its own rather than an inference.

**`_work_begun` is not derivable from `_remaining_mwu`.** A project whose work has begun but which
has earned no milli-WU yet still refunds 80%, and `remaining == declared` in both cases. Deriving
it would have made the very first tick of work invisible to the refund rule.

### Why there are two refund functions and no shared helper

ARCH-JOB-004 says in terms that construction's "100%/80% cancellation and 50% demolition rules …
must not share an undifferentiated 'refund all' helper". `cancellation_refund_milli_into()`
REFUSES a demolition project and `demolition_return_milli_into()` REFUSES everything else. They
read different bases — the per-project delivered ledger versus the immutable §4.1 bill — and
neither can be reached through the other. A test asserts both refusals by their own codes.

### Why cancellation and completion are both two-phase

`begin_refund()` freezes the project in PHASE_REFUNDING and frees nothing; `close_refund()` retires
the row once the caller has physically placed the manifest. If the placement fails the caller
simply does not call `close_refund()`, the project stands, and the retry spends nothing. The same
shape on the completion path: `commit_completion()` leaves the project in PHASE_WORK_DONE with its
earned work intact when the Building edit refuses.

This is SET-MOVE-ECON-001 **ECON-003**'s "explicit work-ready/commit-pending condition and an
idempotent settlement retry", applied to cancellation as well as completion because both can fail
at an output. Two tests reach the refusal through the real store — `buildings.demolish_building()`
refuses while the structure owns rooms — and assert that the collaborating stores are byte
identical afterwards.

### Which of ECON-003's phases this store's phases map onto

ECON-003 requires nine EXCAVATION phases — SOLID, BRACING, BRACED, CUTTING, OPEN_UNFINISHED,
FINISHING, SUPPORTED_VOID, CLOSING, BACKFILLED — and says they are "a separate typed
project/physical-site domain". **They are a property of ground, not of a project, and they map onto
NONE of this store's five phases one for one.** The mapping is one level up: each ECON-003
transition is reached by running ONE project through this whole lifecycle.

| ECON-003 | This store |
|---|---|
| SOLID/BACKFILLED → BRACING → BRACED | one project, opened at SOLID, whose PHASE_WORK_DONE commit advances the site to BRACED and installs the support |
| BRACED → CUTTING → OPEN_UNFINISHED | one project whose CUTTING output reservation is checked at PHASE_WORK_DONE and whose failure keeps it there |
| OPEN_UNFINISHED → FINISHING → SUPPORTED_VOID | one project; publishing navigable space happens at its commit, never before |
| "consume material inputs once at WORK start, into project WIP" | `begin_work()` verbatim |
| "retain earned work/WIP and phase but do not publish any part of the batch" | PHASE_WORK_DONE with an idempotent `commit_completion()` retry |
| "any pending phase also has a distinct operational paused/blocked reason" | `_paused`, which is orthogonal to `_phase` precisely so a pause cannot erase where the work stands |

The site column, its compiled ASCII phase ids and its `excavated_earth` output belong to the
excavation owner and to `catalog.gd`. Neither was pre-empted, renamed or widened here.

### Why `PURPOSE_*` and `PHASE_*` are module ordinals and not a catalog domain

No document numbers them, `catalog.gd` was not on this change's allowlist, and inventing a
protected domain would fix ordinals a later ruling has to live with. They are module constants and
the registry row says a codec must pin them itself. ECON-003's phase domain is the one that is
authored, and it is a different domain.

### Why the Building state machine is driven here

`open_demolition()` sets DEMOLISHING, `begin_work()` sets BUILDING on a build project,
`commit_completion()` sets ACTIVE, and a cancelled demolition restores ACTIVE. §4.3 authors all
six BuildingState ordinals and REQ-SET-127 speaks of "an active building"; leaving BUILDING and
DEMOLISHING unreachable would have made a building under demolition indistinguishable from one in
service. A cancelled BUILD project removes the blueprint outright, because a cancelled blueprint
is not a building.

## What is deliberately NOT implemented, and why

- **REQ-SET-128's STRANDED-GOODS HALF IS NOT ENFORCED.** The resident half is, against the real
  store: `open_demolition()` refuses a building whose rooms report occupants or whose furniture
  has a live user, and the refusal carries the exact count. The goods half needs to enumerate the
  containers `inventory.gd` holds for a building owner, and `inventory.gd` publishes no owner
  index and no container iteration — `container_owner()` needs a reference the caller must already
  have. Accepting a caller-supplied "goods are clear" boolean would be exactly the unbounded
  attestation MOVE-DEP-R05 rejects, so no gate was fabricated. **This is an open blocker.**
- **A TIER-2 BUILDING'S DEMOLITION BASIS IS UNRESOLVED.** REQ-SET-127 says "50% original material
  costs" and "the declared construction WU × 0.25". §4.2's upgrade table declares no demolition
  consequence and nothing says whether a tier-2 package's materials and work join that basis. The
  store uses the BASE §4.1 row for every tier and says so in its header. No summation rule was
  invented.
- **NO CONTAINER IS CREATED OR READ.** `material_container` is stored as the §4.2 column it is, in
  the INVENTORY CONTAINER generation namespace, and `set_material_container()` range-validates the
  pair and nothing more, because this store holds no `inventory.gd` reference. Every OTHER
  reference on the row is a DIRECTORY reference validated through `is_valid_of_kind()`. The four
  namespaces — directory, inventory container, inventory lot, navigation route — stay distinct.
- **NO JOB, NO COMMAND, NO TICK STAGE.** REQ-SET-124's delivery and build jobs are `jobs.gd`'s and
  the productive tick is `work.gd`'s; neither calls this store. `TICK_STAGE_COUNT` is still **8**
  and every stage keeps its name. The PLACE_BLUEPRINT / PLACE_FURNITURE / DESIGNATE_ROOM /
  UPGRADE / DEMOLISH / SET_DOOR_OPEN dispatcher integration, and 06.1's service and storage
  indexes, are NOT done.
- **`refund_policy`'s MISMATCH BRANCH IS UNREACHABLE THROUGH THE PUBLIC API**, exactly as
  `buildings.verify_room_masks()`'s is. See the surviving mutants below; this is reported, not
  hidden.

## Consequences for the ledgers — reported, not edited

`docs/systems_architecture.md` and `docs/persistence_state_registry.md` were **not on this change's
allowlist and are byte-untouched**. `state_registry_coverage.py` therefore FAILS with
`C1 construction.gd has no registry section` until the registry row below is applied; that is
expected and was not worked around. `ready07_arithmetic.py` still passes at 142 field rows / 28
allocation rows, because §3 is untouched.

### New §3 rows required, totalling 5 142 528 bytes

| Table | Columns | Type | Width | Cols | Length | Bytes |
|---|---|---:|---:|---:|---:|---:|
| ConstructionIndex | `present, work_begun` | B8 | 1 | 2 | 82944 | 165888 |
| ConstructionIndex | `ref_slot, ref_generation, subject_slot, subject_generation, purpose, type_id, phase` | I32 | 4 | 7 | 82944 | 2322432 |
| ConstructionMaterialLedger | `delivered_milli` | I64 | 8 | 1 | 331776 | 2654208 |

§2.2 already carries `material_container_slot, material_container_generation, assigned_count,
max_workers, refund_policy` (I32 × 5 × 82944), `remaining_mwu` (I64 × 1 × 82944) and `paused`
(B8 × 1 × 82944). Those rows are **not** re-added and not enlarged. `delivered_milli`'s length is
`CONSTRUCTION_CAPACITY × MATERIAL_SLOTS_PER_PROJECT` = 82944 × 4 = 331776.

The consequent §2.3 figures, each recomputed from the row above it:

| Row | Was | Becomes |
|---|---:|---:|
| Auxiliary payload | 20172256 | 25314784 |
| Planned allocated payload | 63779731 | 68922259 |
| One live world plus reserve | 72168339 | 77310867 |
| Headroom below decimal 100 MB | 27831661 | 22689141 |
| Additional candidate mutable state | 57564147 | 62706675 |
| Transactional peak plus same reserve | 129732486 | 140017542 |
| Transactional headroom | −29732486 | −40017542 |

ARCH-MEM-009's trail gains one row: `Construction project lifecycle | decision 0131 | +5142528 |
68922259 | 77310867`, and 68922259 + 8388608 = 77310867 as every row above it does. The "was"
column is `origin/master` at **63cb6a4**, the commit this branch is rebased onto; decision 0127's
§15 declaration table (+18384) is already folded into it.

The bill tables are immutable catalog data totalling **3828 bytes**
(120 × 4 × 2 + 120 × 8 × 2 + 36 × 4 + 36 × 8 + 30 × 4 × 2 + 9 × 4 + 30 × 8) and fall inside §2.3's
existing 2097152-byte read-only catalog/lookup arena on decision 0056/0088's precedent, so they
move no ledger row.

### The registry section required

Fourteen rows under `### \`godot/scripts/core/construction.gd\``, seven category 1 (the project
columns, the pause/consumption latch, occupancy, identity/subject, classification and the
delivered ledger) and seven category 2 (the three bill tables, their counts, the tier-2 package
work, and the store's counts and collaborators). The exact block was verified by inserting it,
running `state_registry_coverage.py` to **PASS — 51 modules, 346 rows, 675 packed columns**, and
restoring `persistence_state_registry.md` to a byte-identical `shasum -a 256`. It is handed to the
owner of that file rather than committed here.

## Evidence

`godot --headless --path godot --script test/run_tests.gd`:
**4062 test(s), 139366 assertion(s), 0 failure(s)** on this branch rebased onto `origin/master`
at 63cb6a4, whose own measured baseline in a separate detached worktree is
**4012 test(s), 138867 assertion(s), 0 failure(s)** — **+50 tests, +499 assertions**, which is the
45 store tests and 5 composition tests this change adds. At the branch's original base 914444b the
same change read 3962 / 135380 / 0 against a 3912 / 134881 / 0 baseline, the same +50 / +499.

`ready07_arithmetic.py`: PASS, 142 field rows, 29 allocation rows.
`decision_numbers.py`: PASS, 119 records, 0 problems.
`validate_underground_economy_hazards.py`: 21 tests, 0 failures, 0 errors.
`state_registry_coverage.py`: **FAIL, C1 `construction.gd` has no registry section** — the expected
failure named above.

Thirteen single-line mutations, **one per Godot invocation**, run serially on the rebased branch,
each restored and byte-compared with `shasum -a 256` against a pristine copy taken from the final
file. `construction.gd` is byte-identical afterwards at
`accd44a3c6a367d132e5189698171b9991c103ab70a9b03cdfabf20721b8fe8e`.

**One harness trap is recorded because it cost a whole run.** A second copy of the harness was
launched before the first had finished, and the two mutated the same file concurrently: the second
reported `MUTATION_NOT_APPLIED` for M1 because the first had already rewritten the line, and
reported M2 killing three tests instead of two because it was measuring a file carrying somebody
else's mutation. Every contaminated verdict was discarded, the harness took a single-instance
lock, and all thirteen were re-run from a restored file. The table below is that clean run, and it
reproduces the earlier pre-rebase run mutation for mutation.

| # | Mutation | Result |
|---|---|---|
| M1 | a refused demolition commit no longer restores `Building.construction` | **killed, 1** |
| M2 | `REFUND_PARTIAL_NUM` 4 → 5 (the 80% fraction becomes 100%) | **killed, 2** |
| M3 | `_policy_for()` never returns REFUND_PARTIAL (the boundary never moves) | **killed, 3** |
| M4 | `REFUND_DEMOLITION_DEN` 2 → 1 (demolition returns 100% of original cost) | **killed, 1** |
| M5 | `add_work_mwu()`'s phase gate accepts every phase but REFUNDING | **killed, 2** |
| M6 | `close_refund()` stops retiring the row (a cancelled project stays live) | **killed, 2** |
| M7 | every project opens in PHASE_READY regardless of its bill | **killed, 30** |
| M8 | the over-delivery guard is removed | **killed, 1** |
| M9 | a refused delivery still writes the ledger | **killed, 4** |
| M10 | the demolition occupant gate tolerates three residents | **killed, 1** |
| M11 | the one-project-per-building gate is removed | **killed, 1** |
| M12 | `verify_refund_policies()` can never refuse | **survived — unreachable branch** |
| M13 | `begin_work()` drops its `_all_materials_delivered()` gate | **survived — equivalent** |

M9 is the brief's "a refusal that still consumed materials" in its most literal form and M1 is it
in its most dangerous one: a refusal that published half a transaction. Both are killed by tests
whose assertion is a `state_bytes()`-level byte comparison across the Construction store, the
`entity_directory`, and a full field image of every live Building row, not by an eyeballed field
check.

**The two survivors are reported rather than papered over.**

*M12 is unreachable, not untested.* `_refund_policy` is written only by `_policy_for()`, which is
the same function `verify_refund_policies()` runs, so no sequence of public calls can make them
disagree. Its caller is the save decoder, which writes the column straight from a file and is the
one thing that can — and no decoder exists. `buildings.verify_room_masks()` carries exactly this
caveat for exactly this reason (decision 0088). What IS pinned is that the check walks the live
rows and reports how many it verified, so a check that returned early dies.

*M13 is an equivalent mutant, and the redundancy is deliberate.* PHASE_READY is reachable today
only through complete delivery, so the phase gate and the ledger gate cannot differ through the
public API. The second gate is defence against a decoder that writes PHASE_READY over an empty
ledger, which is precisely the case M7 proves matters — moving the phase initialization alone
fails 30 tests. Deleting the redundant gate to make a mutant die would remove the protection the
mutant is complaining about.

## Source

GDD §4.2 (the Construction row and "At most 1 project/building/furniture/road segment"), §4.3
(BuildingState), §5.9 ("Construction materials are delivered to the project container before BUILD
phase", "Maximum 4 builders/project unless listed"), REQ-SET-121–128, 136, 137;
`gameplay_balance.md` §4.1, §4.2's tier-2 table, §4.3, BAL-CAT-006, BAL-BUILD-001;
`systems_architecture.md` §2.2's Construction rows, §3, ARCH-MEM-002, ARCH-MEM-005, ARCH-CAT-004,
ARCH-JOB-003/004; `docs/underground_economy_hazard_amendment.md` ECON-003; decisions 0059
(allocate before consume), 0062 (the state registry), 0074 / R-BUILD-DOM-001–004, 0088 (the packed
Building/Room/Furniture stores and its "NO CONSTRUCTION STORE" entry), 0087 (the composition, and
the five §7.2 blockers this change does not close).

# 0534 — Demolition admit, the stage-5 success path, and the adopted inventory
Date: 2026-10-01 · Status: Accepted (four PROPOSALS below await Brendan's ruling)

Numbered 0534 because the brief named it. No record numbered 0534–0539 exists on any branch
(`git ls-tree` over every ref) or in any sibling worktree when this was written;
`docs/validation/decision_numbers.py` refuses a collision at merge.

## Decision

**Step D4 of [DEMO-CONTAIN-R01](../rulings/2026-10-01_demolition_containment.md) lands with this
record.** It covers answers #3a, #3c, #3d, #5 and #7's gate half, blockers 1 and 3, BUILD-C4-R01's
tier-2 basis, and all four of [decision 0533](0533-the-starter-colony-is-materialised-and-the-stores-are-owned-by-it.md)'s
Consequences that name D4.

1. **EconomySystem adopts the settlement's inventory (0533's first Consequence; decision 0087).**
   - `economy_system.gd::bind_inventory(store)` adopts a borrowed store BEFORE the stores open.
     It refuses `STORES_ALREADY_OPEN`, `INVALID_INVENTORY_BINDING` (null), `CATALOG_UNAVAILABLE`
     and `INVENTORY_CATALOG_MISMATCH` unless all 256 item ids register identically (presence,
     mass, category) in both stores, so a compiled id here always names the same item there.
   - **`reset()` drops a borrowed store and never clears it** (decision 0087's named wrinkle).
     It returns to the private store, which is the one cleared and reloaded. The private store
     stays the default, so a test-built EconomySystem touches no autoload state.
   - `main.gd::_seed_stores()` and `ui_manager.gd::_reconcile_economy_after_create()` bind
     `SettlementSystem.inventory()` before `open_and_seed_starter_stores()`. A refused adoption
     leaves the stores closed rather than opening them in an inventory nobody else can see.
   - **Chosen over scanning both inventories**, the D3 record's other option, because only one
     store lets one inventory transaction cover a demolition (admit's reservation and, in D5,
     the return), and because a second scan would have to be repeated by section 7, the
     ground-pile composer and every future gate. The adopted contracts allow it: 0087 recommends
     it in terms, INV-GOODS-R01 wants one authority, and no rule requires two stores.
   - Consequences of the adoption, each checked: section 7 now carries the starter stock; the
     five starter stores carry no StockAge declaration, so `stock_age.gd` counts them undeclared
     and does not age them (unchanged behaviour: nothing aged them before); the stock-integrity
     pause (decision 0100) keys on preflight refusals and refused lots, neither of which an
     undeclared container produces.
2. **Stage 5 has its success path (#3a, #3c, #5, #7).** `settlement_system.gd`:
   - `_footprint_containment_refusal()` marks the footprint (door tiles included, #5) with
     `ground_piles.gd::refund_seeds_into()`, which also yields the refund seeds — the one
     16384-byte mask decisions 0531 and 0532 told D4 to build.
   - **Owner scan ⊆ tile scan:** a third pass of the one endpoint walk (`ENDPOINT_STAGE_CONTAIN`)
     requires every container keyed to the building, its rooms, its furniture and their projects,
     and every project's material handle, to be anchored ON the footprint, read through
     `container_anchor_tile_into()` (0533's second Consequence). Off it, or unplaced:
     `DEMOLITION_OWNED_CONTAINER_OFF_FOOTPRINT`.
   - **Tile scan ⊆ owner scan:** `containers_anchored_in_into()` over the footprint; each found
     container must have been seen by stage 3's owner scan, or be a ground pile (its lots and
     claims join the goods totals). A malformed owner is #7's
     `DEMOLITION_ANCHORED_NULL_OWNER_CONTAINER`; any other owner is
     `DEMOLITION_FOREIGN_CONTAINER_ON_FOOTPRINT`. The report names the container
     (`blocking_container`) and counts `anchored_container_count`.
   - Satchels are unplaced and never on a tile (#3d). An unanchored ownerless container is
     outside every footprint (#7's other half). A pile outside the footprint survives (#5).
   - Stranded goods found only on the footprint refuse `DEMOLITION_BLOCKED_STORED_GOODS`, a
     pile's claim `DEMOLITION_BLOCKED_CAPACITY_CLAIM`, exactly like stage 3's.
3. **`request_demolition()` is split into preview and admit (blocker 1).**
   - `preview_demolition()` is today's read-only gate, five stages.
   - `request_demolition()` runs the preview and, only on a pass and in the same call with no
     yield, `_admit_demolition()`. Every check runs before the first write:
     `construction.demolition_open_refusal()` (new: every refusal `open_demolition()` can return,
     including a full CONSTRUCTION kind), the admission record's own refusal, a caller's open
     inventory transaction (`DEMOLITION_INVENTORY_TRANSACTION_OPEN`), and the output plan.
   - Then, in order: one inventory transaction holding the reservation and `open_demolition()`
     (a transition that still refused would roll the reservation back); commit; the admission
     record and the destination revision. Two guards that the proofs make unreachable — a commit
     or record refusal — undo the published project and the reservation.
   - `DemolitionReport` gains `project_ref`, `output_container`, `output_reserved_g`,
     `output_to_ground_piles` and `destination_revision`.
4. **Output capacity is reserved (blocker 3; BUILD-C4-R01 "reserve legal output capacity").**
   The return's charge is the sum of each line's own `ceil(q * m / 1000)` lot debit. It is
   reserved with `inventory.reserve_container_mass()` in ONE surviving store (PROPOSAL P1). With
   no such store the return falls back to ground piles (#9), proved placeable now by
   `preflight_lots_from_seeds()` from the refund seeds with the footprint excluded, and nothing
   is reserved (PROPOSAL P2). Neither: `DEMOLITION_NO_OUTPUT_CAPACITY`, writing nothing.
5. **BUILD-C4-R01's tier-2 basis, from ConstructionPaidLedger.** `construction.gd` gains
   `_paid_base_type` and `_paid_upgrade_mask`, I32 × 82944: §3's already-budgeted
   ConstructionPaidLedger row (663552 B), now implemented.
   - Every project records its paid package KEYS at admission: BUILD and FURNITURE their own type
     and no upgrade; UPGRADE `NO_PAID_PACKAGE` (-1) and `UPGRADE_TIER_TWO_BIT`; DEMOLISH the
     building's type and, at tier 2, the upgrade bit — **the snapshot, taken in the same write
     that publishes the row**. Retirement clears the pair.
   - The return totals each item over the base package plus the completed upgrade, in milli-U,
     then floors the 50% ONCE per item (`demolition_return_milli_into`,
     `demolition_return_key_index_into`, `demolition_return_size_into`; one line per item, base
     bill order then upgrade-only keys). The work is a quarter of the same completed WU sum.
   - `demolition_return_preview_into()` gives admit the exact manifest the snapshot will carry.
   - `_assert_bills()` proves every base+upgrade union fits the four manifest lines.
   - Tier 1 is unchanged: every existing test of the 50% and the 0.25 still passes.
6. **The destination revision is produced (PROPOSAL P3).** `core/demolition_admissions.gd`, one
   row per Building typed row (1024): the admitted project, the output container and grams,
   and MOVE-DEP-R05's destination revision — `FIRST_DESTINATION_REVISION` (1) after `clear()`,
   +1 per admitted demolition, refusing at I32 max. A record whose project is no longer live is
   read as absent. Composed and cleared by the settlement (`demolition_admissions()`).
7. **`ui_world_session.gd` declares `KIND_CONSTRUCTION`** among its reset's cleared kinds
   (0533's third Consequence), so Create during an admitted demolition still succeeds
   (`test_create_still_succeeds_while_a_demolition_is_admitted`).
8. **`test_every_starter_building_still_refuses_demolition_at_stage_5` was changed on purpose**
   (0533's fourth Consequence). With the economy adopting the settlement's inventory, the hall and
   the stockpiles now refuse `DEMOLITION_BLOCKED_STORED_GOODS` because the gate sees their goods;
   the well is admitted into the fourth stockpile's headroom (75000 g) and the workbench then
   falls back to ground piles. A fifth test shows the hall reading as empty when the economy is
   left on its private store — the reason for item 1.

## PROPOSALS needing Brendan's ruling

Where the documents are silent the smallest sensible behaviour was built and is marked here.

- **P1 — which store the return's capacity is reserved in.** Built: the lowest-slot container
  anchored off the footprint, owned by a different ACTIVE building, reachable, not a ground pile,
  whose filters admit every returned item and whose free mass takes the WHOLE return. One
  container per demolition. Lowest slot follows §5.9's only authored order ("filling container
  IDs ascending"). Options: (a) as built; (b) split the return line by line across stores, which
  needs a variable-length reservation record; (c) only the economy's stockpiles; (d) always
  ground piles, reserving nothing. **Recommendation: (a)**; (b) when hauling (06.4) makes store
  choice a logistics policy.
- **P2 — the pile fallback reserves nothing.** An empty pile with a claim is refused at commit
  (decision 0532), so pile capacity cannot be held from admit to completion. Built: a rolled-back
  placement proves it now; D5 places for real and stays commit-pending if it then fails.
  Options: (a) as built; (b) refuse admission whenever no store can take the return.
  **Recommendation: (a)**, since #9 names piles as the fallback.
- **P3 — who publishes the building contact's destination revision.** No building, room or
  service store publishes one (movement.gd's `revalidate_destination()` says so), and MOVE-DEP-R05
  gives it to the contact owner. Built: the coordinator, per Building row, monotonic across row
  reuse. Options: (a) as built until BUILDINGS-SAVED-BINDINGS / D8 move it into the building
  store with its contacts; (b) a `buildings.gd` column now, reopening that store's frozen save
  bridge. **Recommendation: (a).**
- **P4 — a never-built (starter) building's base package counts as paid.** BUILD-C4-R01 reads
  "the recorded paid base package", but INIT-C places the starter colony without a project.
  Built: the snapshot records every live building's base package, on BUILD-C4-R01's own "Ordinary
  tier-1 behavior remains the inherited formula", and tier 2 is the record of the completed
  upgrade (BAL-SAFE-013 sets it once, only on completion). Options: (a) as built; (b) starter
  structures return nothing; (c) record a per-building paid mask (ARCH's BuildingService
  `upgrade_paid_mask`) and treat INIT-C as paying. **Recommendation: (a).**

## Why — the executor's other readings

- **The ledger and the record are classified UNRESOLVED, not category 1.** Both are
  future-affecting, but construction's section 4 owner is ADR 0186's frozen 16-column body and an
  open project is in no save yet (CONSTRUCTION-SAVED-BINDINGS). The households precedent
  (decision 0521) is followed: each row states the owner/ordinal question. Saving them is that
  binding's work; until then, a load would keep section 7's reserved mass and lose its owner,
  which is stated here rather than discovered.
- **Ruleset identity is not snapshotted per row.** The ARCH row says "costs retrieved by rules
  hash", and the rules hash is the save header's (REQ-SET-001); within one ruleset the compiled
  bills cannot change, so a per-row copy would duplicate a world-wide fact.
- **A DEMOLISHING building's stores are never an output.** Its containers are destroyed by its
  own completion (#6 step 1), so the store scan requires an ACTIVE owner.
- **No rule was reinterpreted.** Every refusal named in the D4 row is implemented with its own
  code; nothing picks an Alternative column.

## Consequences — what D5 must know

- **The return is already decided.** Read `demolition_admissions().output_container_of()` and
  `output_reserved_g_of()`; the manifest is `construction.demolition_return_*` (already halved and
  floored once per item, from the snapshot). Release exactly `output_reserved_g_of()` and create
  the lots in the same inventory transaction. A null container means ground piles from
  `refund_seeds_into()` (call it before `demolish_building()`); the placement helper refuses an
  open transaction, so D5 still needs 0532's in-transaction variant.
- **Re-running the gate at commit:** `preview_demolition()` stage 1 refuses a building that
  carries a project and is not ACTIVE, which is exactly a DEMOLISHING building. D5 needs a
  commit-time variant of stages 2–5 that expects its own demolition project as an endpoint (it has
  no material container and nothing delivered, so the walk passes it).
- **Cancellation does not release the reservation.** `construction.close_refund()` on a
  demolition sets the building ACTIVE and retires the row; the admission record then lapses, but
  the store keeps the reserved grams. A coordinator cancellation path must release
  `output_reserved_g_of()` first (D5/D6/D7).
- **The destination revision advances only at admit.** Removal (D5) and D8's movement wiring
  must advance it again; `demolition_admissions.record()` is admit-only, so D5 adds the removal
  door.
- **A pile fallback proved at admit can fail at completion** (the world changed). D5 stays
  commit-pending and retries at no extra cost, per ECON-003.
- **Open demolitions do not survive a load** (CONSTRUCTION-SAVED-BINDINGS), but section 7 saves
  the reserved mass. Whoever saves construction must also save `demolition_admissions.gd`.
- **Memory.** +63808 B: the record (28672, §3 `DemolitionAdmission`, folded into the Auxiliary
  payload) and the admit scratch (35136, one §2.3 row). Live total 79088068, headroom 20911932;
  the rejected two-world peak is a further 127616 B worse (-43542331). The paid ledger was
  already budgeted. `ready07_arithmetic.py` checks all of it.
- `docs/planning/registry_capacity_audit.json` is regenerated (`construction.gd` and
  `settlement_system.gd` moved). No save schema or registry version changes.

## Evidence

Filled in below from the runs on this branch.

## Source

DEMO-CONTAIN-R01 #3a, #3c, #3d, #5, #7, blockers 1 and 3 (Brendan, 2026-10-01, DEC-043);
BUILD-C4-R01 and BAL-SAFE-013; INV-GOODS-R01; MOVE-DEP-R05; REQ-SET-112/127/128; decisions 0087,
0100, 0145, 0186, 0521, 0531, 0532, 0533; GDD §5.8, §5.9; ARCH §3 ConstructionPaidLedger.

# 0038 — GearInstance uses a lowest-free-row pool with an exclusive Job claim
Date: 2026-09-09 · Status: **Accepted** (Brendan adopted the READY_06 handoff) ·
Resolves: **the GearInstance half of U5** · Source:
`docs/rulings/2026-09-09_ready06_open_item_answers.md` §4

## Decision
16384 `GearInstance` rows allocated **globally from the lowest free index**, plus
two columns naming the one Job that exclusively claims a piece of gear.
Implemented in `godot/scripts/core/gear.gd`; owning budget is
`docs/systems_architecture.md` **ARCH-STATE-007**.

## What U5 actually was, and was not
U5 was **missing allocator and ownership bookkeeping, not missing capacity.** The
16384 rows and their 540672-byte fixed-field payload were already budgeted in §3
before this change, and are unchanged by it. In particular:

- **No gear row per resident.** The pool is global; a resident owns gear by
  reference, not by reserving a row.
- **No growth in the global entity directory.** `entity_directory.gd` is
  untouched. A gear instance is a child record of an `InventoryLot`, not a
  referenceable entity of its own.

## Packed layout

| Allocation | Bytes |
|---|---:|
| Occupancy: byte × 16384 | 16,384 |
| Free-row min-heap: int32 × 16384 | 65,536 |
| Heap count: int32 | 4 |
| Exclusive-claim Job slot/generation: two int32 × 16384 | 131,072 |
| **Additional packed payload** | **212,996** |

The allocator alone is **81,924**; the remaining **131,072** identifies the
claiming Job, as REQ-SET-044 requires. Additional to the existing 540,672-byte
`GearInstance` payload. It contains **no reverse index** and no cycle-operation
state; adding either is a separate budgeted change.

Dependent totals move accordingly: auxiliary payload 16,384,856 → **16,597,852**;
planned allocated payload 58,660,042 → **58,873,038**; one live world plus
reserve 67,048,650 → **67,261,646**; two-world peak 119,493,108 → **119,919,100**.

## Rules
- **Allocate before consume.** A creation that cannot get a row refuses *before*
  any material is consumed or any loose output lot is created. `gear.gd` publishes
  `preflight_create()` for exactly that call order. This is the hazard decision
  0024 named.
- **Initialise before publish.** Every field is written before the occupancy byte
  is set, and a row is blanked before it returns to the heap. The order is
  *enforced*, not merely followed: `_publish_row()` refuses a row whose identity
  columns are still blank and the caller returns it unpublished.
- **Save occupancy and the authoritative fields; rebuild the heap ascending on
  load.** The heap and its count are derived, never restored from an image, so a
  loaded world reuses rows in the same order as the world that saved it.
- **No raw gear-row index escapes as a durable handle.** A row carries no
  generation, so a handle to one would silently re-point when the row is reused.
  Public entry points take a validated, generation-checked `InventoryLot`
  reference and verify the row's recorded identity. A persistent `GearRef` needs
  its own budgeted generation column and retirement rule **first**.
- **The claim is exclusive and belongs to the Job** (decision 0017), not to a
  worker. Refused: a second owner; repair or an ownership change while claimed; a
  cycle whose available durability is below its specified wear. Completion applies
  wear once and releases the claim; cancellation releases it and applies nothing.

## Instance eligibility is a named predicate, not a category test
Instance-required keys are exactly `tool`, `net`, `trap`, `ice_kit`,
`outfit_tier2`. **`candle` is category GEAR and is deliberately excluded**: it
stays stackable consumable inventory. That single counter-example is why
`category == GEAR` is the wrong predicate, and `test_gear.gd` asserts the
predicate independently of the category.

Tier-2 outfits keep identity for equipment transfers but have canonical
durability/cap **0/0**, with wear and repair refused as inapplicable and no claim
possible — there is no durability to reserve. **This introduces no clothing
degradation mechanic.** Starter tier-1 clothing remains `Equipment.clothing_tier`,
not an invented `ItemDefinition`.

## Two wear models, kept distinct
| | General (`tool`) | Fishing (`net`, `trap`, `ice_kit`) |
|---|---|---|
| Source | GDD §5.7 | GDD §5.4 |
| Rate | 1 point per completed 10 WU, remainder preserved | fixed per cycle: net 20, trap 10, ice kit 20 |
| Cap | 1000 basic / 1500 iron | 1000 |
| Repair | wood 1 + **stone 0.5**, 30 WU, +200 | wood 1 + **rope 0.25**, 30 WU, +200 |

Repair **clamps** to the model's own cap — the one clamp the ruling states — and
is **not** a durability reset. The general model's remainder is not stored in this
component: `ResidentRuntime.wear_remainder` already carries it at length 512, so
the wear operation takes it in and hands it back rather than allocating a second
copy, which is the same double-allocation ARCH-STATE-005 forbids for the scan
cursor.

## Resolutions recorded as resolutions, not as specified rules
1. **`manufacture_recipe` carries a local two-member domain** (`BASIC`, `IRON`),
   not a compiled `RecipeDefinition` id. `catalog_ids.gd` states outright that no
   module implements the RecipeDefinition domain and that transcribing the balance
   tables into a registry would be the hand-written second copy it exists to
   prevent — so no recipe id exists to store. **Migration obligation:** when that
   domain is compiled, this column must carry the compiled id. The byte layout is
   unchanged; the values are not, so the migration moves the save digest.
   `MANUFACTURE_IRON` is refused for anything but `tool`, because `tool` is the
   only §5.7 output with two recipes.
2. **A general-tool wear application that exceeds the remaining durability debits
   to exactly 0 and reports `broke`.** §5.7 fixes the rate and says "Broken tools
   block tool-required work"; it does not name this case. Refusing would leave
   finished work having cost nothing, which is worse, and the floor at 0 is the
   break the GDD already describes. The remainder still carries forward and the
   outcome reports the shortfall, so it cannot read as a clean debit.
3. **An ice kit is a separate gear object from the net it modifies**, so a
   frozen-lake cycle claims and wears both, 20 each. §5.4 gives the ice kit its own
   construction cost, wear column and row.
4. **Lot resolution is a bounded ascending scan**, because the ruling excludes
   reverse indexes from this budget. Measured: filling all 16384 rows costs 3994 ms
   in total, i.e. the scan is only expensive at full occupancy; at realistic live
   counts (the 24 starter tools plus a handful of nets and traps) it ends after a
   couple of dozen comparisons, and no gear operation runs inside a per-tick loop.
   A lot-indexed reverse column is a separate, budgeted increment.

## Deliberately out of scope — documented, not faked
- **The equipped-lot inventory amendment.** Ruling §4 permits
  `InventoryLot.container = NULL_REF` for a validated equipped record with a live
  owner, and says in the same breath that "the allocator alone does not authorize
  null-container lots": `inventory.gd`'s validation, its mass accounting, its
  availability queries and its consumers must change **together**. None of that is
  done here, `inventory.gd` is not weakened, and there is consequently **no
  equip/unequip API**. The `equipped` byte is allocated and saved because the
  ledger budgets it; it is always 0 in this increment and has a reader but no
  setter. **Dependency:** the inventory amendment.
- **Installed gear — boats and weirs.** These are installed structures, not
  `ItemDefinition` inventory output. The boat owner/instance discriminator is
  unresolved and belongs to the expedition/installed-gear contract; a boathouse is
  **not** identical to every boat it services. So no fake boat `InventoryLot` is
  minted, no boat or weir per-cycle wear constant exists here, and `set_owner()`
  admits only a live `KIND_RESIDENT` reference, refusing other kinds explicitly
  rather than guessing. Hand-net, trap and ice-kit gear proceed regardless.
  **Dependency:** the expedition/installed-gear contract, whose owner capacity,
  discriminator and directory delta must be recorded before implementation.
- **Cycle driving.** Expedition columns do not exist, so wear application is a
  parameterised operation this store owns. It is **not** a callback into
  `jobs.gd`, and `gear.gd` does not depend on the Job store at all — it holds the
  same boundary `reservations.gd` holds, validating a Job reference's range and
  comparing the full `(slot, generation)` pair.

## U5 is only partly closed
U5 as written in `docs/tasks/02_settlement_foundation.md` covers **six** child
stores. Reservation was budgeted by decision 0019 and GearInstance by this record.
**`BatchState`, `LotEffect`, `NoticeCondition` and `ChildSliceIndex` still have no
allocator storage budgeted**, so U5 must not be marked closed as a whole. §3.1
carries this as an explicit line.

## Acceptance evidence
`godot/test/test_gear.gd`, 44 tests. Every acceptance item ruling §4 names has its
own named test: allocation reaching row 16383; atomic full-pool refusal;
deterministic lowest-freed-row reuse; stale lot, owner and job handles failing;
two Jobs unable to claim one gear object; exact wear starting and one below
refusing; repeated completion and cancellation unable to double-debit or
double-release; repair clamping to the correct cap per model. Suite: **1268 tests,
36462 assertions, 0 failures** (baseline on this branch before the change: 1224
tests, 35844 assertions, 0 failures).

Mutation-tested: 40 mutations, one per suite run, each restored and byte-compared
against a pristine copy by SHA-256. **39 killed** on a genuine expected-versus-got
value mismatch — no parse errors and no aborted tests. Two survivors were real
findings and were fixed rather than explained away: a broken general tool could be
claimed with the claim bar mutated to 0 (no test covered §5.7's "Broken tools block
tool-required work"; `test_a_broken_general_tool_cannot_start_work` now does), and
one clause of the publish guard was unreachable given the restore validator (the
guard is now a single condition that the test does exercise). The one remaining
survivor is **equivalent**, not a gap: `_write_new_row()` and `_blank_row()`
deliberately both cover every column, so removing either one's claim-column reset
changes no reachable behaviour. The redundancy is intentional and is flagged in
`gear.gd`'s header so a later reader does not "tidy" it away.

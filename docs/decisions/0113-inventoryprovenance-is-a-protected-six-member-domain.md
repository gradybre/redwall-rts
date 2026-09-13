# 0113 — InventoryProvenance is a protected six-member domain, and inventory admits only its members
Date: 2026-09-12 · Status: Accepted

## Decision

Implement **PROV-R01** of
[the 2026-09-12 save-registry answers](../rulings/2026-09-12_save_registry_answers.md).

1. **Publish `InventoryProvenance` in `godot/scripts/core/catalog.gd` as a
   PROTECTED enum domain**, carrying the ruling's own numbers verbatim:
   `ORDINARY=0, STARTER=1, COASTAL_BRINE=2, EXCAVATION=3, BACKFILL_RECLAIM=4,
   SPOIL_RECLAIM=5`. `COUNT` is not a member and there is no seventh key.
   `catalog_ids.json` moved from 4161 bytes / 29 domains / 282 rows /
   `d5bf21b45b31a2d90d7d0f6b9367450787eb506fd5ae27b6f6f54c08f23cfd67` to
   **4282 bytes / 30 domains / 288 rows /
   `4b25ab62a4a0330c3acf5ebeba83ddd1019c29cc9650b8b9ce4822d8b035677d`**. That is
   an intentional catalog/schema change, not a parity result: every save written
   against the old digest refuses until an explicit migration exists.
2. **`inventory.gd` refuses any lot provenance outside those six**, with a new
   `REFUSE_INVALID_PROVENANCE` code, at `create_lot()` — the only door that
   writes `_l_provenance` from a caller's argument. `UNSET_PROVENANCE` keeps the
   value 0 and is redefined as the **compatibility spelling of ORDINARY**, read
   from `Catalog.PROVENANCE_ORDINARY` rather than restated.
3. **The item-keyed half of PROV-R01 lives in `catalog.gd`, not in inventory**:
   `check_lot_provenance()`, `check_salt_brine_input()`,
   `recipe_output_provenance()` and `check_earth_withdrawal()`.
4. **Existing arbitrary-int fixtures were fixed, not grandfathered.**
   `test_inventory.gd` used 5, 6, 7 and `INT32_MAX` as opaque provenance
   stand-ins; those are now member values or explicit refusal cases.

This closes catalog.gd's BLOCKER EH-01-B. It closes no MOVE gate, certifies no
release save, and adds no packed column.

## Why

### Protected, and emphatically not sorted

Decision 0018 fixes the rule: every enum whose numbers a contract states
individually lives in `PROTECTED_ENUM_DOMAINS`, because a protected table is the
thing that *refuses* a recompile. PROV-R01 states all six individually and says
in terms "This is a protected enum, NOT a lexicographically assigned domain …
Do not silently retain a three-member ECON-only domain or sort these values."

This is the clearest case in the module. Ascending ASCII over these keys
generates `BACKFILL_RECLAIM=0, COASTAL_BRINE=1, EXCAVATION=2, ORDINARY=3,
SPOIL_RECLAIM=4, STARTER=5` — **all six disagree** with the ruling, where
InjuryKind at least had `CUT=1` in common. A sorted build would read every
ordinary lot in every save as reclaimed backfill.

### The default is a member, not an unknown

`UNSET_PROVENANCE=0` was a local sentinel meaning "a field the caller left
unset", explicitly documented as *not* a catalog ID. PROV-R01 reverses that: it
is ORDINARY, a real member that grants no privilege and "does not prove coastal
collection or a virgin source". The distinction matters because a wildcard
reading would let every cleared column pass an origin check. The refusal-carrying
`lot_provenance_into()` exists for the same reason — a zeroed value channel must
not be readable as ORDINARY.

### Why the item rules are not enforced inside `inventory.gd`

"COASTAL_BRINE requires the `brine` item" and "all three earth labels require
`excavated_earth`" are rules about ItemDefinition **keys**. `inventory.gd` holds
an item's compiled id, mass and category and has never known a key —
`register_item()` takes no name. Enforcing them there would need an id-based
second copy of the same rule, which is exactly the drift this codebase refuses
elsewhere. The rules are therefore published and tested on `catalog.gd`, which
owns the domain, and the producers that hold the key call them before reaching
`create_lot()`. Two consequences are reported rather than papered over: the
saltpan recipe's input filter and EH-02's excavation/backfill/spoil transactions
still have to make those calls, and neither file is in this lane's ownership.

### The ledger, not the label

PROV-R01: "Source and embedded ledgers, not the label alone, prove that a
corresponding withdrawal/output may occur exactly once."
`check_earth_withdrawal()` is the arithmetic half — a pure integer predicate over
a balance the caller supplies. The ledger **columns** are EH-02's tip/excavation
store; their extents and save rows are not settled, so none is invented here.

### Rejected

- *Widening the domain to admit the old fixtures.* The ruling forbids it in
  terms, and an `INT32_MAX` provenance in a save is indistinguishable from
  corruption.
- *Treating `UNSET_PROVENANCE` as a seventh member or an unknown wildcard.*
  Both readings are ruled out; either would let an unproven lot satisfy an
  origin check.
- *Publishing only the three ECON-002 members.* That renumbers every member the
  day the fourth lands — the failure `BuildingDefinition` was published complete
  to avoid.

## Consequences

- Every save written against
  `d5bf21b45b31a2d90d7d0f6b9367450787eb506fd5ae27b6f6f54c08f23cfd67` refuses.
  Any development conversion must be an explicit versioned tool; `1..5` is never
  reinterpreted blindly.
- A seventh origin needs an explicit amendment, a new protected identity and
  compatibility handling — never a key appended to this table.
- `_l_provenance` gains a bounded extent (0..5) without changing its width,
  ordinal or byte length. §7 `inventory` owner schema 2 already carries this in
  REG-R01's baseline version vector.
- `_c_policy` stays genuinely opaque. No ruling has closed the container-policy
  domain, and the asymmetry is deliberate.

## Source

- [`docs/rulings/2026-09-12_save_registry_answers.md`](../rulings/2026-09-12_save_registry_answers.md)
  §PROV-R01, and its REG-R01 §7 baseline schema version 2.
- [`docs/planning/canonical_state_registry.json`](../planning/canonical_state_registry.json)
  `inventory_provenance`, which declares the same six members.
- [decision 0018](0018-explicit-enums-live-in-catalog.md) for
  protected-versus-compiled, and
  [decision 0108](0108-injurykind-is-published-and-spoil-waits-for-its-authored-row.md)
  for the publication pattern this follows.

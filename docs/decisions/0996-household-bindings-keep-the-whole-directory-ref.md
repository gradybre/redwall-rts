# 0996 — Household bindings keep the whole directory EntityRef, not its generation
Date: 2026-10-02 · Status: Accepted (Brendan's ruling on review finding R04, 2026-10-02) · Amends [0521](0521-pc04-adopted-with-children-inactive.md) and FAMILY-STATE-R01

## Decision

`godot/scripts/core/households.gd` binds each dependent row to the resident's **whole directory
EntityRef**, `(slot, generation)`, and not to the generation alone. A new
`_d_resident_slot: PackedInt32Array[512]` (canonical unused `-1`) sits beside
`_d_resident_generation`. Every place that asks whether a row belongs to a resident compares the
full pair:

- **Readers.** `is_bound()` and every row reader built on it use `_binding_is_current()`, which
  compares the stored ref with `Residents.ref_of(row)`.
- **Mutations.** Every ref-addressed entry goes through `_bound_row_into()`, which refuses
  `HOUSEHOLD_STALE_BINDING` unless the stored ref equals the caller's ref.
  `bind_resident_into()` reports `HOUSEHOLD_RESIDENT_ALREADY_BOUND` only for the same full ref,
  and `HOUSEHOLD_STALE_BINDING` otherwise.
- **The care tick.** `advance_care_into()` refuses while any bound row is stale.
- **Recovery.** `release_stale_row_into()` treats a row as current only when it matches the full
  ref, so it now releases a row whose previous tenant shared the new tenant's generation.
- **Column validation.** `columns_refusal()` refuses `HOUSEHOLD_COLUMN_BINDING` unless
  `(d_resident_slot, d_resident_generation)` equals the present resident's directory ref. An
  unbound row must hold `(-1, 0)`; anything else is `HOUSEHOLD_COLUMN_UNUSED`.
- **The image.** `Columns` gains `d_resident_slot`, which becomes the first of eleven (was ten)
  512-row int32 columns. Capture, restore, `state_bytes()` and `payload_bytes()` all use the same
  list.

## Why

The independent review of 2026-10-02 (R04) reproduced the failure. The directory allocates a
**slot** and a **typed row** independently, and a generation belongs to the slot. The sequence:

1. A bound resident `(0,1)` at typed row 0 is despawned without `unbind`. Decision 0521
   explicitly supports this case through `release_stale_row_into()`.
2. A resource node takes directory slot 0.
3. The next resident reuses typed row 0 under slot 2, at the same generation 1.

The generation-only check then read the previous tenant's household, `willing = 0` and decayed
care as the new resident's. It also refused both repairs:
- a fresh bind refused `ALREADY_BOUND`;
- `release_stale_row_into()` refused `NOT_STALE`.

For an unhoused child the captured image even **passed** validation, carrying 6000 care into a
new child. The existing test at the old line 920 respawned immediately. That reused the same
slot and advanced the generation, so it masked the case.

Brendan's ruling: *"keep and validate the full bound directory EntityRef (slot and generation) in
every reader, mutation, recovery path and column validator."*

**Options rejected:**
- **Bind on the directory persistent ID.** It is unique per entity too, but the ruling names
  the EntityRef. Every other reference in this store (member arena, provider) is already a full
  EntityRef, so this keeps one identity form.
- **Derive the slot from Residents on each read.** That is exactly what cannot tell the old
  tenant from the new one; the slot has to be *stored* when the row is bound.

Member and provider refs were already full EntityRefs, and a despawned resident's ref never
validates again (generations only increase, and a max-generation slot retires). So member
compaction, provider cleanup and their validators needed no change. Preferences are persistent
IDs, which are never reissued.

## Column-size impact

| Figure | Before | After |
|---|---:|---:|
| Dependent/provider payload | 26632 | 28680 |
| Owner payload (`payload_bytes()`) | 46352 | 48400 |
| Owner payload + 5632 selection scratch (not yet allocated) | 51984 | 54032 |
| Live + scratch + one `Columns` snapshot | 98336 | 102432 |
| §3 DependentCare I32 row | 10 cols, 20480 | 11 cols, 22528 |
| Auxiliary payload (§2.3) | 25368304 | 25370352 |
| Planned allocated payload | 70699460 | 70701508 |
| One live world plus reserve | 79088068 | 79090116 |
| Headroom below decimal 100 MB | 20911932 | 20909884 |
| Additional candidate mutable state | 64454263 | 64456311 |
| Rejected two-world transactional peak | 143542331 | 143546427 (-43546427 headroom) |

The ledger figures above are as of this branch's base (d75d9d89). Merged with master's decisions 0536 and 0537
(2026-10-02), the same +2048 lands on their totals: Auxiliary 25394928, planned payload 70726292, live 79114900,
headroom 20885100, candidate 64481095, transactional peak 143595995 (−43595995); the trail row follows 0537's.
Merged again with master's decision 1031 (+4096, store filters): Auxiliary 25399024, planned payload 70730388, live
79118996, headroom 20881004, candidate 64485191, transactional peak 143604187 (−43604187); the trail row follows 1031's.

`docs/systems_architecture.md` carries the new §3 row text, the Auxiliary and metric rows and an
ARCH-MEM-009 trail line. `docs/validation/ready07_arithmetic.py` adds
`DECISION_0996_ADDED = 4*512` to its allocation identity and pins the new totals; it passes.

`docs/planning/family_state_schema.md` (FAMILY-STATE-R01) gains the `resident_slot` row, the new
figures and an amendment note. `docs/persistence_state_registry.md` lists `_d_resident_slot` in
the UNRESOLVED "Dependent references and care" group, and `state_registry_coverage.py` passes.

The capacity audit (`tools/audit_registry_capacities.py --check`) passes unchanged, because the
owner has no canonical-registry rows yet (gate 3). `validate_save_registry_handoff.py` passes.
No canonical-registry number, owner ID or ordinal was taken. `OWNER_SCHEMA_VERSION` stays 1,
because no saved household image has ever been written: no settlement composes the store and no
section codec exists (gate 3). The schema-1 column set is simply redefined before first use.

## Tests and mutation result

`godot/test/test_households.gd` gains:
- **The two reuse reproductions.** A resource node is interposed so the replacement reuses the
  typed row under a different slot at the same generation.
  - Housed adult: no inherited household or willingness. Bind, detach, the willingness setter
    and household creation each refuse STALE, and so does the care tick. The image is refused.
    The stale row releases, the partner survives, the fresh bind takes the ADULT default, and the
    store is saveable again.
  - Unhoused child at 6000 care: no inherited care or eligibility. The image is refused
    `HOUSEHOLD_COLUMN_BINDING` and does not restore. After release the child binds at 6500.
- **A test that bind and unbind write and clear the whole pair.**
- **Validator boundaries.** A swapped slot/generation, the slot ±1, another living resident's
  slot at the same generation, a null slot on a bound row, and a slot on an unbound row.
- **The payload pin**, now at 48400.

There are 23 hand mutants of the new identity code:
- dropping the slot or the generation from each comparison;
- removing the check;
- swapping slot and generation;
- off-by-one slots;
- not writing, not clearing, or zero-clearing the slot;
- the unused-row rule;
- the `Columns` null fill;
- swapped or missing column order in either column list;
- the allocation.

Each was run against `test_households.gd`. **23 killed, 0 survived.**

## Consequences

- The store's identity rule matches AGENTS.md's EntityRef. A later store keyed by **typed row**
  must store the full directory ref for the same reason. Stores indexed by the directory slot
  itself do not have this alias.
- Gate 3's §4 ordinal allocation must include `resident_slot` alongside `resident_generation`.

## Proposals

None. The ruling fixes the rule. The only choice made here is the column's position: first in
the int32 list, slot before generation, as with `provider_slot` and `member_slot`. Every
capture, restore and digest in this file follows that order, so nothing external depends on it
until gate 3 assigns ordinals.

## Source

Brendan's ruling of 2026-10-02 on R04. The finding is in
`docs/reviews/2026-10-02-codex-review.md` on branch `codex/review-2026-10-02`, under R04.
Also AGENTS.md's EntityRef rule, FAMILY-STATE-R01 (`docs/planning/family_state_schema.md`) and
[decision 0521](0521-pc04-adopted-with-children-inactive.md).

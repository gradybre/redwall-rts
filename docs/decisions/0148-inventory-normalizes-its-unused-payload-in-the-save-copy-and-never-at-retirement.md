# 0148 — Inventory normalizes its unused payload in the save copy, and never at retirement
Date: 2026-09-15 · Status: Accepted

## Decision

[INV-CANON-R01](../rulings/2026-09-14_cycle02_inventory_canonicalization.md) is
activated in one coordinated change. `inventory.gd` publishes a **quiescent,
caller-owned, normalized projection** of every physical container and lot row;
`save_section_inventories.gd` encodes, decodes and validates section 7's
`inventory` block from that projection at **owner schema 3** and **section
descriptor schema 3**; and `canonical_state_hash.gd`'s section 15 adapter for
that owner reads the **same staged block** the encoder drains.

Six things move together, because a tree where the registry says schema 3 and
the codec still writes 2 is a broken tree:

1. **`godot/scripts/core/inventory.gd`** gains `CanonicalColumns`,
   `copy_canonical_columns_into()` and `restore_canonical_columns()`, plus
   `CANONICAL_OWNER_SCHEMA_VERSION = 3` and `CANONICAL_GENERATION_MIN = 1`.
2. **`godot/scripts/core/save_section_inventories.gd`** reads that owner schema,
   publishes `SECTION_SCHEMA_VERSION = 3`, refuses a noncanonical unused value
   and a zero row generation, and gains `capture_inventory_into()`,
   `apply_inventory()`, `InventoryAdapter` and `register_inventory_adapter()`.
3. **`docs/planning/canonical_state_registry.json`** takes `(7, inventory)` to
   `owner_schema_version` **3** and `section_schema_versions[6]` to **3**, and
   changes the rules identity: `registry_id` becomes
   `RWL-CANONICAL-REGISTRY-2026-09-15-3` and `registry_version` becomes **3**.
4. **`tools/generate_canonical_state_table.py`** regenerates the compiled table
   in `canonical_state_hash.gd`. `--check` is the CI gate; nothing is hand-edited.
5. **`docs/persistence_state_registry.md`** prints the unused-value table on the
   two occupancy rows and narrows the §7 codec row's BLOCKER I1.
6. **The three suites** activate with them, including two existing assertions
   that legitimately changed answer (below).

## Neither registry count moves, and that is the result

`record_count` stays **596** and `packed_source_field_count` stays **550**. The
ruling's `canonical_record_delta` is 0: schema 3 restricts what an **already
declared** field may hold on an **inactive** row. No field is added, none is
retired, no `hash` flag moves, and no packed column is reclassified. The reason
is written beside both pins in `validate_save_registry_handoff.py` and
`test_canonical_state_hash.gd`, because a pin without its reason becomes a
format constant that later refuses every legitimate change.

## Why normalization is in the copy and not in `_retire_lot()`

A blanket retirement clear is **unsafe in the current algorithm**, which is the
finding this decision exists to respect. `_apply_transfer()` retires the source
**before** `_credit_new_lot()` reads its item, quality, provenance and recipe,
and with one free lot slot the allocator hands back that same physical slot
under a new generation. Clearing the source at retirement would destroy the
values the very next statement reads. So `copy_canonical_columns_into()` writes
only into the caller's buffer, and `test_canonical_copy_leaves_the_live_columns_byte_identical`
compares `state_bytes()` across the call. `state_bytes()` remains the full
rollback/debug image and deliberately keeps stale payload.

## The reserved-merge residue, and why zeroing it creates no second claim

`_apply_merge()` moves the source's reserved quantity onto the destination and
leaves the number in the dead source. Reserving 250 milli-U on a 1000-milli-U
lot and merging it into a compatible 1000-milli-U lot therefore leaves dead
quantity 0 / dead reserved 250 beside a live destination correctly holding
reserved 250. The live audit passes, and a raw serialization plus an
unconditional `reserved <= quantity` check would reject that reachable state.
The projection writes **dead reserved 0** and retains the live claim, because
occupancy is decisive. **External `reservations` rows still need their own
retargeting and cross-store validation.** The store-level probe and the tests
here do not prove the orchestrated claim path, and nothing below claims they do.

## INT32_MAX is three states, not one

Freeing a slot from INT32_MAX−1 increments it to INT32_MAX and **pushes it**,
allowing one final valid allocation. So free-MAX (inactive, on the prefix),
live-MAX (occupancy 1) and retired-MAX (inactive, off the prefix) are three
distinct persisted states, separated by prefix membership and occupancy. The
projection copies every row's own generation unchanged and preserves both free
stacks' used prefixes **in pop order**, rebuilding only the excluded tail to −1.
Rebuilding the stack, sorting it, filtering MAX rows out of it, or zeroing an
inactive generation collapses two of the three and is a defect.

## Generation zero is refused

Every instantiated inventory generation is in 1..INT32_MAX: `_init()` calls
`clear()`, which steps each column from 0 to 1. Schema 2's shared
`_generation_refusal()` accepted 0 on an inactive row; schema 3 refuses it. A
virgin zero-generation allocator would need its own explicit contract, and this
decision invents none.

## Two existing tests changed answer, and were updated rather than weakened

`test_owner_schema_versions_match_the_registry` asserted owner schema **2** and
now asserts **3**; `test_wrong_owner_schema_version_is_refused` flipped the wire
byte from 2→1 and now flips it 3→2. Both are the activation making an old answer
wrong, not a check being relaxed: a schema-2 reader accepts a retired row still
carrying its last live item, quantity and reserved quantity, which is exactly the
non-determinism being removed. **No old development save is reinterpreted as
schema 3**; a schema-2 stream refuses, because no migration exists.

## What this does NOT establish

No release-save completeness. `release_save_ready` stays **false**. BLOCKER I1 is
**narrowed, not closed**: `fishing`, `forage`, `gear`, `reservations` and
`stock_age` still publish no columns, so there is no whole-section capture and
the production walker still refuses with `CANONICAL_NO_ADAPTER` for 51 owners.
Cross-owner validation and the load barrier remain the orchestrator's. The
end-to-end save→continue→compare tests the ruling asks for stay **blocked** until
a composed loader exists.

## Alternatives rejected

**Blank the row in `_retire_lot()`.** Rejected: it breaks `_apply_transfer()`,
as above. Astra's probe reproduces the exact sequence.

**Omit inactive rows, or sort the free stacks.** Rejected by the ruling and by
arithmetic: occupancy and generation per physical slot are the state, and pop
order is the array permutation.

**Leave the registry identity at `-2`.** Rejected. The declaration under schema 3
accepts a strictly smaller set of states; shipping it under the 2026-09-14 name
would satisfy every self-referential check while the field set behaved
differently.

**Reuse `canonical_fill_of()` as the decoder's expectation.** Rejected as
symmetric blindness: that function is what a freshly allocated column is *filled*
with, so the check would move with the thing it checks. The codec carries the
ruling's twenty-two numbers as its own literals, and the test reads them back off
the encoded wire at hand-added offsets.

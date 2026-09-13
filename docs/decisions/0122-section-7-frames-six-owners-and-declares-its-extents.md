# 0122 — Section 7 frames six owners in ASCII order and declares every extent it cannot infer
Date: 2026-09-12 · Status: Accepted

## Decision

Implement ARCH-SAVE-002 **section 7 INVENTORIES_AND_LEASE_INDEXES** as
`godot/scripts/core/save_section_inventories.gd`, under
[REG-R01](../rulings/2026-09-12_save_registry_answers.md) and SAVE-LAYOUT-R01.

1. **Six owner blocks, in ASCII key order, tiling the section with no gaps.**
   `store_count:u32 = 6`, then `fishing`, `forage`, `gear`, `inventory`,
   `reservations`, `stock_age`, each with the standard wrapper (`owner_key`,
   `owner_schema_version:u32`, `primary_count:u64`, `payload_byte_length:u64`).
   `inventory` is owner schema **2**; the other five are **1**. Column-major, per
   SAVE-LAYOUT-R01. Field order is REG-R01's declared **ordinal**, which for
   `inventory` interleaves container and lot columns and is not GDScript
   declaration order. A stream whose blocks arrive in any other order is
   **refused**, not sorted on the way in.

2. **Every extent is declared, and none is inferred from a column.** The owner
   payload opens with `child_extent_count:u32` and that many `u64` child extents
   before any field. `inventory` declares one child extent — `_l_capacity` — with
   `primary_count = _c_capacity`; the other five declare zero and their
   `primary_count` is their single table's row capacity. Every column then carries
   its own `element_count:u64`, which must equal whichever declared extent its
   REG-R01 shape names.

3. **Count-governed columns persist their live prefix only.** `_c_free`,
   `_l_free` and `_declared_slots` are written for exactly `_c_free_count`,
   `_l_free_count` and `_declared_count` entries, **in order**. The tail beyond the
   count is never written, and a decoded record rebuilds it as canonical
   `NULL_SLOT`.

4. **`_l_provenance` is refused outside 0..5, never clamped**, per decision 0113 /
   PROV-R01, on every row rather than only on live ones.

5. **No generation is invented for `gear` or `reservations`.** Their declared
   field lists are pinned by test at twelve and eight keys, neither containing a
   row-owned generation, and both are written at full row extent so a load cannot
   compact them.

6. **ARCH-SAVE-003 chunking applies and is implemented.** At the compiled maxima
   with every slot free the section is **10437959 bytes**, larger than section 3's
   6343616, so `ChunkCursor` streams it field-aligned in runs of at most 65536
   bytes. `encode_record()` concatenates the same chunks for a caller that wants
   one buffer.

This adds **no authoritative packed column**, closes no MOVE gate, and **certifies
no release save**. It writes bytes for six owners and validates them; it does not
capture from or restore into any live store — see BLOCKER I1.

## Why

### The primary count could not be guessed, so it is declared

REG-R01: "Module owners containing several differently sized logical tables need
an explicitly validated primary count and child extents before their wire body is
frozen; the logical registry does not authorize guessing these from the first
column."

`inventory` is that owner twice over. Its containers run to `_c_capacity <=
101376` and its lots to `_l_capacity <= 16384`, and **both are constructor
arguments**, so neither is a compile-time constant a reader could assume. Worse,
its FIRST declared field is the scalar `_c_free_count`, whose element count is
**1**: an implementation that took the extent off the first column would produce
one, not 101376 and not 16384.

The choice recorded here is that `primary_count` is the CONTAINER capacity and the
lot capacity is a child extent. That ordering is not arbitrary — containers hold
lots, and `_l_container_slot` is bounded by the container extent while
`_c_first_lot` is bounded by the lot extent — but it is a choice, and it is
written down rather than left implicit. `child_extent_maximum_of()` bounds each
declared extent against its owning module's compiled constant BEFORE anything is
allocated, which is H4's "bounds are checked before allocation".

`gear`, `reservations` and `inventory` all size their tables from a constructor
argument; `fishing`, `forage` and `stock_age` are compile-time fixed and admit no
other value. `PRIMARY_COUNT_IS_FIXED` carries that distinction explicitly rather
than treating every count as a range.

### The free stacks are the state, and their tails are not

`inventory.gd`'s comment at line 259 is explicit that `_c_free`/`_l_free` are
STACKS, not `entity_directory.gd`'s min-heaps. `_alloc_lot_slot()` pops
`_l_free[_l_free_count - 1]`, so the next slot handed out depends on the array
PERMUTATION and not on the free SET. That is exactly why decision 0103 could
rebuild section 3's heaps and section 7 cannot rebuild these: rebuilding them
ascending would be a different world, not the same one.

The tail beyond the count is the opposite case. It is stale garbage left by
earlier pops, and two worlds identical in every observable way can hold different
garbage there. Persisting it would give those two worlds different bytes and
different CRCs. `set_stack_column()` is therefore the only way to fill one of
these columns: it copies `count` entries in order and fills the rest with
`NULL_SLOT`. `stock_age._declared_slots` is the same shape for a different
reason — `_drop_declaration()` swaps the last entry into the freed position, so
its ORDER is the hourly sweep order and is not recoverable from
`_c_storage_class` ascending.

`_stack_partition_refusal()` validates the counts against occupancy and
retirement, as REG-R01 requires: every slot is live, on the stack, or retired at
`MAX_INT32`, and there is no fourth state. `_free_lot_slot()` returns without
pushing exactly when the generation has reached `MAX_INT32`, which is the only way
a slot leaves both sets.

### Four generation namespaces, and two owners that have none

Two of the four spaces the 2026-09-11 addendum names are owned here:
`inventory._c_generation` and `inventory._l_generation`. They are also BORROWED
here — `stock_age._c_declared_generation` is a container generation,
`gear._lot_generation` and `reservations._r_lot_generation` are lot generations,
and `gear._owner_generation`, `gear._claim_job_generation`,
`forage._claim_*_generation` and `fishing._effort_claim_*_generation` are
DIRECTORY generations. Each is validated against the range of the space it
belongs to; none is merged with another.

REG-R01 is equally explicit about the negative case: "gear and reservations have
no invented generation and cannot be compacted." A gear row and a reservation row
are addressed by bare index, so the index IS the identity. Nothing here adds a
column to either, and the tests pin both declared field lists so nothing can.

### Refusals, not sentinels, and the sign trap

Every four-byte signed field is read through `Reader.read_i32_into()`, which
carries signedness explicitly. A generation whose bytes are `00 00 00 80` decodes
as **-2147483648** and is refused as negative, rather than being accepted as a
plausible 2147483648 no i32 column could hold. The suite builds that boundary
through `SaveCodec.u32_bits_to_int32()` and asserts the pair agrees before using
it, because typing the signed literal is how a sign-trap test ends up testing
nothing.

Provenance is the case where clamping would be silent and wrong. A stored 6
mapped onto ORDINARY would pass every round trip and would change whether the lot
can enter a saltpan under PROV-R01's `COASTAL_BRINE` rule. `_provenance_refusal()`
refuses. It is the same failure mode AGENTS.md records for the `-1` overflow
sentinel that wrote a negative age; `_lot_quantity_refusal()` refuses a negative
`_l_age_milli_hours` for the same reason.

### Two findings mutation testing produced, both fixed in the source

* **A declared payload length was compared against itself.** `_read_block()`
  originally recomputed the payload length from the decoded extents. That
  compares the reader to the reader: any `payload_byte_length` inside the
  arithmetically possible window was accepted, which for `inventory` is an
  eight-byte range because its free stacks are variable. The wrapper's own value
  is now carried back through `_read_wrapper()` and compared to the bytes the
  block ACTUALLY consumes, and the extent-derived figure is checked as a second,
  separate comparison.
* **One validation line was unreachable.** `_declared_count_refusal()` compared
  `declared != count` after already proving every declared container was marked
  in a `seen` window carrying exactly `count` marks. The comparison could not
  fail for any input, and the mutant that deleted it survived. The line is gone
  and the reason is recorded in the function's docstring.

## Consequences

### BLOCKER I1 — no owner publishes its columns, so there is no live capture

`save_section_directory.gd` can capture a live store because
`entity_directory.gd` grew `copy_columns_into()` / `restore_columns()` for it
(decision 0105). **None of the six section-7 owners has an equivalent.** Their
columns are underscore-prefixed members, no module in this repository reads
another's, and reaching into them from here would put the free-stack, min-heap and
intrusive-chain invariants in two files.

So this module is the wire format and the validator, reached through
`OwnerRecord`'s typed column setters, and there is no `capture_into(store)` or
`apply(record, store)`. Closing it needs the same shape the directory added, on
six files this lane does not own: `inventory.gd`, `gear.gd`, `reservations.gd`,
`stock_age.gd`, `forage.gd`, `fishing.gd`. The gap is named rather than
half-published.

### Two sub-capacities REG-R01 does not register

`gear` and `reservations` each hold a `_job_capacity` and a `_lot_capacity` that
are ALSO constructor arguments, and `reservations._check_job_ref()` bounds
`_r_job_slot` by its own `_job_capacity`. REG-R01 declares neither as a field, so
the wire cannot carry them and this module bounds those references by the
compiled `JOB_CAPACITY` / `LOT_CAPACITY` maxima instead. A restore into a store
constructed with smaller sub-capacities cannot be validated from the wire alone.
That belongs to the load orchestrator or to a REG-R01 amendment; it is not
invented here.

### `inventory.gd` does not blank a retired row

`_retire_lot()` clears `_l_live` and frees the slot, leaving `_l_item_id`,
`_l_quality` and `_l_provenance` at their last live values; `fishing`, `forage`,
`gear` and `reservations` all blank a released row completely. So two observably
identical inventories can differ in a retired row's bytes. This module enforces
the canonical blank form for the four owners that guarantee it and does NOT refuse
inventory's residue, because that is the store owner's design. Section 15's
canonical digest will have to decide whether a retired row's residue is part of
the state; it is recorded here so that decision is made rather than inherited.

### The descriptor's `row_count` for a six-owner section is unresolved

SAVE-LAYOUT-R01 settles it for section 3 and REG-R01 settles a `primary_count`
per owner, but nothing says what a multi-owner section's single 64-byte
descriptor `row_count` is. Summing six unrelated capacities would be a number
with no meaning, so this module publishes no `descriptor_row_count()`. The header
owner needs that ruled.

### Registry row owed and not applied

`docs/persistence_state_registry.md` is another owner's file, and
`state_registry_coverage.py` C1 fails without a section for this module. The exact
row is reported with this work. The module holds **no module-level `var`** — every
function is static — so it is a category 3 row of the same shape as
`save_section_directory.gd`'s.

## Evidence

`godot --headless --path godot --script test/run_tests.gd`:
**3833 test(s), 133967 assertion(s), 0 failure(s)**. Of those, 42 tests and 743
assertions are `test_save_section_inventories.gd`.

Real byte vector, empty world at the compiled maxima:

| Block | Bytes |
|---|---:|
| `store_count:u32` | 4 |
| `fishing` | 12891 |
| `forage` | 434298 |
| `gear` | 688256 |
| `inventory` | 7481637 |
| `reservations` | 1212520 |
| `stock_age` | 608353 |
| **section** | **10437959** |

Round trip is byte-identical, including a store whose free stack is partially
consumed and whose remaining prefix is a non-descending permutation.

Seventeen mutation runs, one mutant per Godot invocation, the production file
`shasum -a 256` byte-compared against a pristine copy after each restore. Fifteen
mutants died. The two survivors were both real defects and are fixed above.

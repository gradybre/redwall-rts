# 09.3 — section 7 INVENTORIES_AND_LEASE_INDEXES — 2026-09-12

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12


Decision [0122](../decisions/0122-section-7-frames-six-owners-and-declares-its-extents.md).
New files: `godot/scripts/core/save_section_inventories.gd` and
`godot/test/test_save_section_inventories.gd`. No existing file was edited.

- [x] **Six owner blocks in REG-R01's ASCII order, tiling the section with no gaps.**
      `store_count:u32 = 6`, then `fishing`, `forage`, `gear`, `inventory`,
      `reservations`, `stock_age`, each with SAVE-LAYOUT-R01's wrapper. `inventory`
      is owner schema 2; the other five are 1. Column-major. Field order is the
      declared REG-R01 **ordinal**, which for `inventory` interleaves container and
      lot columns and is not GDScript declaration order. Blocks out of ASCII order
      are refused, not sorted.
- [x] **Extents declared, never inferred.** Each payload opens with
      `child_extent_count:u32` and its child extents. `inventory` declares
      `primary_count = _c_capacity` and one child extent `_l_capacity`; the other
      five declare zero. Each column's own `element_count:u64` must equal whichever
      declared extent its shape names. Every count is bounded against the owning
      module's compiled maximum **before** an `OwnerRecord` is allocated.
- [x] **Free stacks: prefix in order, tail never written.** `_c_free`, `_l_free`
      and `stock_age._declared_slots` persist exactly their count fields' worth of
      entries in order; the stale tail is rebuilt as canonical `NULL_SLOT`. Counts
      are validated against occupancy and retirement: every slot is live, on the
      stack, or retired at `MAX_INT32`.
- [x] **`_l_provenance` refused outside 0..5 (decision 0113), never clamped**, on
      every row rather than only on live ones.
- [x] **No generation invented for `gear` or `reservations`.** Both declared field
      lists are pinned by test at twelve and eight keys, and both tables are written
      at full row extent so a load cannot compact them.
- [x] **ARCH-SAVE-003 chunking implemented.** The empty section at the compiled
      maxima is 10437959 bytes, larger than section 3's 6343616, so `ChunkCursor`
      streams it field-aligned at no more than 65536 bytes per chunk. The stream
      reproduces `encode_record()` byte for byte.
- [x] **Real byte vector**, empty world at the compiled maxima: `store_count` 4,
      `fishing` 12891, `forage` 434298, `gear` 688256, `inventory` 7481637,
      `reservations` 1212520, `stock_age` 608353, section **10437959**.
- [x] **Round trip byte-identical**, including a store whose free stack is
      partially consumed and whose live prefix is a non-descending permutation.
- [x] **Seventeen mutation runs**, one mutant per Godot invocation, the production
      file `shasum -a 256` byte-compared against a pristine copy after each restore.
      Fifteen died. Both survivors were real defects and were fixed: a declared
      `payload_byte_length` that was compared against a figure recomputed from the
      same read, and one unreachable comparison in the declared-list validator.
- [x] Full suite: `3833 test(s), 133967 assertion(s), 0 failure(s)`.

- [ ] **BLOCKER I1 — no section-7 owner publishes its columns.** There is no
      `capture_into(store)` and no `apply(record, store)`, because none of
      `inventory.gd`, `gear.gd`, `reservations.gd`, `stock_age.gd`, `forage.gd` or
      `fishing.gd` has the `copy_columns_into()` / `restore_columns()` pair decision
      0105 added to `entity_directory.gd`. Six files this lane does not own.
- [ ] **Registry row owed and not applied** (`docs/persistence_state_registry.md`
      is another owner's file). `state_registry_coverage.py` C1 fails without a
      section for `save_section_inventories.gd`. The module holds no module-level
      `var`, so the row is category 3, the same shape as
      `save_section_directory.gd`'s. Exact text reported with this work.
- [ ] **`gear` and `reservations` sub-capacities are unregistered.** Both hold a
      `_job_capacity` and a `_lot_capacity` that are constructor arguments, and
      REG-R01 declares neither as a field. This module bounds those references by
      the compiled maxima; a restore into a store built with smaller sub-capacities
      cannot be validated from the wire. Needs a REG-R01 amendment or an
      orchestrator rule.
- [ ] **The 64-byte descriptor's `row_count` for a six-owner section is
      unresolved.** No document settles it, so no `descriptor_row_count()` is
      published rather than a summed number with no meaning.
- [ ] **`inventory.gd` does not blank a retired row**, unlike the other four row
      owners, so two observably identical inventories can differ in a retired row's
      bytes. Not refused here; recorded for section 15's canonical digest.

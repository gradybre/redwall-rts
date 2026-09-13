# 0121 — Section 9 NAVIGATION persists used prefixes, not tails, and declares its own primary count
Date: 2026-09-12 · Status: Accepted

## Decision

Implement ARCH-SAVE-002 **section 9 NAVIGATION** as
`godot/scripts/core/save_section_navigation.gd`, under REG-R01 of
[the 2026-09-12 save-registry answers](../rulings/2026-09-12_save_registry_answers.md).

1. **Two owner blocks in ASCII key order, `movement` then `navigation`**, each with
   SAVE-LAYOUT-R01's wrapper (`owner_key`, `owner_schema_version:u32`,
   `primary_count:u64`, `payload_byte_length:u64`) behind one `store_count:u32 = 2`.
   The blocks tile the section with no gaps; bytes are column-major; field order is
   the **declared ordinal** from `docs/planning/canonical_state_registry.json`, which
   differs from GDScript declaration order in both blocks.
   `movement` is schema 1 with primary count 512; `navigation` is schema 2 with
   primary count 8192.
2. **`_heap` and `_arena` are persisted as used prefixes and their tails are dropped**,
   per the ruling's "Navigation partial search, arena used-prefix and queue progress
   remain required" and the registry's `count_field` shapes. `set_navigation_prefix_column()`
   copies `[0, used)`, zeroes the rest and sets the count scalar in the same call;
   `record_refusal()` refuses a Record whose tail is nonzero.
3. **`owner_schema_version = 2` IS PATH-R02's route-semantics gate.** The ruling's
   reason for §9's version 2 is "exact-start navigation semantics", and `navigation.gd`
   publishes the same 2 as `ROUTE_SEMANTICS_VERSION`. The decoder compares both and runs
   the version through `Navigation.refuse_route_semantics()`. Version 1 anchor-composition
   state is refused with no migration. Two PATH-R02 consequences are wire rules:
   `_r_start_cell` must equal `_r_exact_start` in every row, and `PHASE_SEARCHING_LOCAL`
   may not appear.
4. **`navigation`'s primary count is DECLARED here as `PATH_REQUEST_CAPACITY` = 8192**,
   because no ruling publishes one and REG-R01 forbids guessing it from the first column.
   Every child extent is validated separately against the field table, never derived from it.
5. **No `capture_into(store)` and no `apply(record, store)`** — see BLOCKER N1 below.

This claims no release-save completeness, closes no MOVE gate, and adds no authoritative
packed column.

## Why

### The tail is not state, and persisting it would break CRC equality

`_compact_arena()` slides live route blocks down and leaves the old copy of every moved
block behind; `_heap_pop()` leaves the popped cell at `_heap[_heap_size]`. Two worlds that
are identical in every observable way can therefore hold different bytes there. Writing
them would give those worlds different section bytes, different CRC-32s and a different
body SHA-256 — which is exactly the reasoning decision 0103 applied to the directory's free
heaps, reaching the same conclusion about a different array. The registry agrees: `_heap`
and `_arena` are the only two §9 fields shaped `used_prefix_preserve_order`.

The builder residue is deliberately treated differently. `_g`, `_parent`, `_heap_position`
and `_state` are meaningful only where `_stamp[cell] == _search_serial`, so they carry
residue too, but the registry declares all four at full `SpatialWorld.CELL_COUNT` with
`ascending_physical_slot` order, and `docs/persistence_state_registry.md` says §9 "may
encode only the stamped cells … but must reproduce them exactly". This module follows the
declared shape and writes them verbatim. **Sparsifying them is a later schema version's
change and needs a ruling**, because it changes what the §15 digest covers.

### Primary count: declared, not guessed

REG-R01 says a "module owner containing several differently sized logical tables needs an
explicitly validated primary count and child extents before its wire body is frozen".
`navigation` is that owner: 13 scalars, four 262144-cell builder columns, 256 descriptors,
8192 requests and two used prefixes. Nothing publishes its primary count. Refusing to
implement §9 over an unstated framing field would have blocked the whole section for a
number that describes nothing but itself, so the owner declares it — the path request is
what §9 is about — and validates every child extent independently, so the declaration
carries no load beyond the wrapper. A ruling that names a different value changes one
constant and increments the schema version.

### The route-descriptor generation namespace

`_d_generation`, `_r_route_generation` and `movement.gd`'s `_cursor_route_generation` are
**route-descriptor** generations. `_r_job_generation` and both contact owner generations are
**directory slot** generations, halves of an `EntityRef`. A validator that checked a READY
request's hold against the requester's directory generation would accept a stale hold whose
two unrelated integers happen to match, and republish an evicted route to a live holder.
The fixture in `test_save_section_navigation.gd` deliberately puts descriptor generation 5
against directory generation 1 so no such confusion can pass by coincidence; a mutation that
reads the hold from the directory namespace fails 17 of that suite's cases.

### BLOCKER N1 — neither owner publishes a bulk column reader or writer

`navigation.gd` and `movement.gd` expose no `copy_columns_into()` / `restore_columns()` pair,
and their §9 columns are underscore-prefixed privates. No module here reads another's
privates: `save_section_directory.gd` hit the same wall (its BLOCKER D1) and refused to reach
in, and the directory owner then added the API under decision 0105 — as `sim_clock.gd`'s owner
did under RESTORE-R01. So this module is complete from `Record` outwards and deliberately has
no store-level capture or apply. `agrees_with_navigation()` cross-checks a decoded Record
against a live navigator as far as the public readers allow. The exact signatures needed are
listed in the module header; they belong to those two owners, not to this lane.

### A stale movement cursor is legal state

`movement.gd::_settle()` leaves a cursor in place when a body arrives or loses its route,
and `_route_still_valid()` is what compares its route generation with the descriptor's.
So §9 validates a cursor's own fields against each other — a detached row carries `stop()`'s
whole null tuple, an attached row carries a real admission — and does **not** require it to
match a live descriptor. Refusing or repairing a stale cursor on load would reattach an
arrived body to a live route.

## Consequences

- `docs/persistence_state_registry.md` needs a `### godot/scripts/core/save_section_navigation.gd`
  section with one **category 3** row citing no save section. `state_registry_coverage.py`
  reports exactly one C1 failure until that row lands; the file is owned elsewhere and was
  not edited here. `Record` (10422324 bytes), `Derived` (10240 bytes) and the transient
  `GroupBuffers` are **bounded codec scratch on ARCH-SAVE-003's cold path**, not new
  authoritative columns: no new row is owed in `docs/systems_architecture.md`, which
  carries no `save_section_*.gd` rows at all.
- Section length is **not fixed**: `4 + 32 + 18504 + 34 + 5161468 + 4*(heap_size + arena_used)`,
  so 5180042 bytes for an empty navigator and 10422922 at the ceiling. A caller comparing a
  descriptor's declared length needs `section_length_refusal(byte_length, record)`, not a
  constant.
- Changing any field ordinal, extent or the prefix rule changes the wire format and must
  increment `OWNER_SCHEMA_VERSION_NAVIGATION` (or `_MOVEMENT`) and the rules identity.

## Source

- REG-R01, SAVE-LAYOUT-R01 and the baseline section vector `[2,2,1,2,1,1,2,1,2,1,1,2,1,2,1]`
  in [`docs/rulings/2026-09-12_save_registry_answers.md`](../rulings/2026-09-12_save_registry_answers.md).
- The ordinals, types and owner schema versions in
  [`docs/planning/canonical_state_registry.json`](../planning/canonical_state_registry.json).
- [Decision 0091](0091-exact-start-astar-replaces-macro-anchor-composition.md) for why §9's
  semantics are version 2, and [decision 0103](0103-section-3-writes-six-columns-and-rebuilds-the-rest.md)
  for the used-prefix argument this record reuses.
- `docs/persistence_state_registry.md`'s `navigation.gd` and `movement.gd` rows for the
  category 1 / 2 split.

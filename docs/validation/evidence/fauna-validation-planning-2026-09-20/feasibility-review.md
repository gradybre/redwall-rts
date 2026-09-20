# Feasibility review: WorldInit owner-17 reserved-fauna validator

2026-09-20. Independent read-only review of `astra-source-note.md`. No implementation, no
run, no edit to any other file. Every number below is re-derived from the sources in this
packet, not copied from the note under review.

## 1. Shape, re-derived from three independent writers

**`world_init.gd`.** `FAUNA_STOCK_ROWS = 384`, `FAUNA_I32_COLUMNS = 8`,
`FAUNA_I64_COLUMNS = 1`. `_allocate_fauna_columns()` resizes nine private arrays to 384 and
fills them: `_fauna_zone_slot` with `EntityDirectory.NULL_SLOT` (-1),
`_fauna_zone_generation` with `NULL_GENERATION` (0), and `_fauna_species_id`,
`_fauna_population`, `_fauna_capacity`, `_fauna_tracks`, `_fauna_harvest_today`,
`_fauna_migration_link`, `_fauna_birth_remainder` with 0. It is the only writer: no other
function in the module names any `_fauna_*` column, and `fauna_reserved_bytes()` returns
`384 * (8*4 + 1*8) = 15360`.

**`save_component_columns_schema.gd`.** Owner 17 is `world_init`, the last key in ASCII
order, key length 10, version 1, primary count 384, child extents 0, field count 9, field
span beginning 289. The nine field keys are exactly the nine members above, in that order;
the nine type codes are `2,2,2,2,2,2,2,2,4` (eight i32, one i64); the nine element counts
are 384. Payload arithmetic closes: `4 + 9*8 + 8*(384*4) + 1*(384*8) = 4 + 72 + 12288 +
3072 = 15436`, matching `OWNER_PAYLOAD_BYTES[17]`. Block closes: `24 + 10 + 15436 = 15470`,
matching `OWNER_BLOCK_BYTES[17]`, and `12932095 + 15470 = 12947565 = SECTION_BYTES`.

**`docs/persistence_state_registry.md`.** The `world_init` FaunaStockReserved rows record
eight i32 and one i64 at 384, category 1, section 4, canonically empty, no mutator.

Three writers agree on 9 / 8+1 / 384 / 15360 logical bytes and on the (-1, 0) null zone
reference with seven other zeros. The shape is settled and needs no ruling.

## 2. Authority, and what it forbids

REQ-SET-059 and GDD §4.2 require reserved allocation only: all numeric fields 0, refs
(-1,0), no active rows, no updates. SET-AMEND-001 §3 retires hunting, keeps the allocation
as `FaunaStockReserved`, and explicitly permits the schema hole while forbidding hidden
hunting behaviour. Task 09.2 requires rejecting incompatible v1 hunting state. The registry
adds that these bytes must not be repurposed.

Consequences the validator must honour, and which this review treats as non-negotiable:
an all-zero framed block is **invalid**, because `zone_slot` must be -1; a correctly filled
empty frame is the only acceptance; no active fauna, no capacity repurposing, no species
mapping, and no repair of a zero-wire default into the canonical default.

## 3. Constructor finding: confirmed

`WorldInit._init()` adopts nine collaborators, calls `_allocate_columns()` (which sizes the
four published tile columns, five staged tile columns, four basin columns, the 3000-entry
centre plan, the grove plan, the fish id buffer and the nine fauna columns), then
`_assert_authored_constants()` and `_stage_masks()`, a 16384-tile double loop. Constructing
one to validate a frame would allocate roughly 160 KB of map storage plus 15360 fauna bytes
and execute generation staging. The validator must therefore be **static**, as the parent
finding states. The existing section-1 API on this module is instance-scoped and is not a
precedent for the section-4 path.

## 4. Proposed API

One shared static predicate on `world_init.gd`:

```
static func fauna_columns_refusal(zone_slot, zone_generation, species_id, population,
        capacity, tracks, harvest_today, migration_link, birth_remainder) -> StringName
```

Nine typed packed arguments in canonical order, first eight `PackedInt32Array`, last
`PackedInt64Array`. No constructor, no collaborator, no catalog scan, no diagnostic write,
no default projection, no duplicate, no sort, no range `Array`.

Two global gates, in order:

1. all nine extents exactly 384 -> `COLUMN_FAUNA_SHAPE`;
2. whole-column defaults (`zone_slot` all -1, the other eight all 0) ->
   `COLUMN_FAUNA_RESERVED`.

One combined reserved code is sufficient and correct: the eight zero-default columns are
semantically interchangeable, so a mutation swapping two of them is an equivalent mutant and
must not be reported as killed. Splitting the code per column would claim a distinction the
authority does not make.

`PackedInt32Array.count()` is already used in `entity_directory.gd`, so `count(-1) == 384`
and `count(0) == 384` are available for the eight i32 gates. `PackedInt64Array.count()`
appears nowhere in this packet; until a source-level probe confirms it, the `birth_remainder`
gate should use a single bounded loop. Either form allocates no scratch and owns no state.

`fauna_is_canonically_empty()` then delegates to the same predicate and compares the code, so
the one rule is stated once. `fauna_zone_ref_of()` keeps its existing out-of-range guard and
`NULL_REF` return unchanged; that behaviour is relied on by `test_world_init.gd` and must be
preserved verbatim.

## 5. Proposed bridge

A new `save_owner_world_init.gd`, modelled gate-for-gate on `save_owner_schedule.gd`:

1. null record -> `SAVE_COMPONENT_SHAPE`;
2. owner index other than 17 -> `SAVE_COMPONENT_OWNER`;
3. `Schema.schema_refusal()` forwarded unchanged;
4. owner-17 metadata -> `SAVE_COMPONENT_METADATA`, detail prefixed
   `WorldInit owner17 metadata:`: key `world_init`, version 1, primary 384, child extents 0,
   field count 9, each of the nine field keys / type codes / element counts, plus the owner's
   own `FAUNA_I32_COLUMNS` 8, `FAUNA_I64_COLUMNS` 1, `FAUNA_STOCK_ROWS` 384;
5. `Section.owner_shape_refusal()` forwarded unchanged;
6. nine explicit typed accessors, first eight `i32_column`, last `i64_column`;
7. `WorldInit.fauna_columns_refusal(...)` -> the raw unwrapped column code, detail naming
   owner 17 and that code, with no row identity.

Preloads: `WorldInit`, `Schema`, `Section`, `SaveHeader`. **Inspection item before
authorization:** `WorldInit` preloads `resource_catalog_binding.gd`, which preloads
`catalog_ids.gd`, which preloads several owner modules; the schedule bridge already omits
`CatalogIds` for exactly this reason. The closure must be walked to confirm no edge reaches
back into the section-4 modules. This is a read-only check, not a contradiction.

Memory: one framed image is 15360 logical packed bytes, already inside the caller's streamed
owner allowance; no new resident packed memory, no projection, no duplicate.

## 6. Fault oracles

- **Substitution.** Each of the eight zero-default fields, given a single 1 or a signed
  INT32 extremum at row 0, row 191 and row 383 of an otherwise valid empty image, must
  refuse `COLUMN_FAUNA_RESERVED`. `birth_remainder` additionally at INT64 extrema and at
  values not exactly float-representable (for example 9007199254740993).
- **Omission.** Replacing `zone_slot` with a 384-zero column must refuse; this is the
  positive empty control's own omission oracle. Passing any column twice, or passing a
  zero column in place of `zone_slot`, must not accept.
- **Shape.** Each of the nine columns empty, one short and one long -> `COLUMN_FAUNA_SHAPE`,
  independently.
- **Metadata.** Schema-valid but wrong owner index, wrong key, wrong version, wrong primary
  count, wrong field count, wrong per-field type or extent -> gate 4, and each must be
  reachable rather than masked by an earlier gate.
- **Negative control.** A raw all-zero frame must refuse, proving no zero-wire repair.
- **Non-mutation.** Every caller array is byte-identical after accepted and refused calls.
- **Preservation.** `fauna_is_canonically_empty()` before and after an actual `generate()`
  must still answer true, matching the existing behaviour in `test_world_init.gd`; the
  section-1 diagnostics, `section_1_code()` / `section_1_detail()`, and every ordinary
  generation and section-1 restore path must be untouched.

## 7. Fixture without a public snapshot

No public reader exposes all nine columns; only `fauna_row_capacity()`,
`fauna_zone_ref_of(row)`, `fauna_is_canonically_empty()` and `fauna_reserved_bytes()` exist.
A fabricated private getter would add a reader that authority does not require. The actual
owner fixture is therefore built from source-owned fixed defaults (-1, 0, and seven zeros at
384 rows), cross-checked against `fauna_zone_ref_of()` over all 384 rows,
`fauna_is_canonically_empty()` before and after generation, `fauna_reserved_bytes() ==
15360`, and the compiled schema extents. That is sufficient because the defaults are
compile-time constants with no writer.

## 8. Scope this does not close

Acceptance of one framed owner-17 block is not world acceptance. Bulk section-1 and
section-4 atomic restore stays with the existing task and the unpublished barrier; no second
world and no independent publication is implied. Cursor, catalog and world identity are not
read. Section-2 catalog identity, cross-owner reconciliation and coordinator policy remain
separate. Verdict: **feasible as specified**, with the two read-only inspection items above.

# Independent source review — reserved-fauna component validation

Independent review of `world_init.gd`'s `fauna_columns_refusal()` and the new
`save_owner_world_init.gd` bridge against accepted FAUNA-S4-VALIDATE-R01v1 and ADR 0174.
Re-derived from the sources supplied, not from the author's summary. No execution is
claimed here; recorded evidence is cited as recorded.

## Exact image and canonical mapping

The compiled schema's owner 17 span is `OWNER_FIELD_BEGIN[17] = 289`, nine fields, so
ordinals 289..297. `FIELD_TYPES[289..296]` are type 2 and `FIELD_TYPES[297]` is type 4 —
eight i32 then exactly one i64, with `FIELD_COUNTS` 384 in all nine positions and the keys
in the contract's table order. The bridge's `FIELD_ZONE_SLOT..FIELD_MIGRATION_LINK` call
`i32_column` and `FIELD_BIRTH_REMAINDER` alone calls `i64_column`, in the predicate's
argument order; `_field_parity_refusal()` pins the same eight/one split by key, type code
and 384 extent. The mapping is correct and independently source-checked, which is the
check the contract requires because swapping two zero-default columns is admittedly not
killed by mutation.

Byte arithmetic reconciles: 384 x (8x4 + 8) = 15,360 value bytes; + 9 x 8 element counts
+ 4 child-count word = 15,436 = `OWNER_PAYLOAD_BYTES[17]`; + 24 wrapper + 10 key bytes =
15,470 = `OWNER_BLOCK_BYTES[17]`; `OWNER_OFFSETS[17]` 12,932,095 + 15,470 = 12,947,565 =
`SECTION_BYTES`, world_init being the last owner. The contract's three figures hold.

## Predicate

All nine extents are tested in one leading condition before any value is read, so a short
or long column can never be reported as noncanonical data. The nine value checks then use
packed `count(expected) == FAUNA_STOCK_ROWS`: `NULL_SLOT` for zone slot, `NULL_GENERATION`
for zone generation, literal zero for the other seven. Zone slots are therefore -1 and
every other element is zero, and an all-zero raw frame is refused because `count(-1)` is 0.
`FramedOwner.new(17)` zeroes its columns, so the raw-frame rejection is exercised by
construction rather than by a hand-built fixture. `PackedInt64Array.count` is used on the
i64 column with no widening, division or conversion: there is no float in either file and
no path that could round a 2^53-exceeding magnitude.

The function is static, reads only `size()` and `count()`, allocates no scratch, range
Array, projection, duplicate or sort, and returns only a `StringName`. Inputs cannot be
mutated by it.

## Delegation and untouched surfaces

`fauna_is_canonically_empty()` is one call to the shared predicate over the nine private
columns in the same order `_allocate_fauna_columns()` fills them, compared with
`REFUSE_NONE`; its public boolean contract is unchanged and no snapshot or private-column
getter was added. `fauna_zone_ref_of`, `fauna_row_capacity`, `fauna_reserved_bytes`,
allocation, generation, the section 1 copy/validate/restore methods and both section 1
diagnostic channels are unmodified. The added surface is two refusal constants and the
static predicate.

## Bridge

Gate order matches the contract exactly: null -> `SAVE_COMPONENT_SHAPE`; owner != 17 ->
`SAVE_COMPONENT_OWNER`; `Schema.schema_refusal()` returned unchanged, code and detail;
metadata -> `SAVE_COMPONENT_METADATA` with detail beginning `WorldInit owner17 metadata:`;
`Section.owner_shape_refusal()` returned unchanged; nine typed accessors; the raw column
code with a detail containing `WorldInit owner 17 ` and the code and no row identity.
Success carries an empty code and empty detail. Because gates 3 and 4 can share
`SAVE_COMPONENT_METADATA`, the prefix is the only discriminator, and the recorded
`schema-first-forwarding` case asserts both the absent prefix and detail equality.

No WorldInit or collaborator is constructed. `WorldInit.EntityDirectory.NULL_SLOT` is a
constant chain through preloaded scripts, not an instantiation. There is no projection,
duplicate, scratch, catalog read, clock, barrier, callback, live store or diagnostic write;
accessors hand the caller's frozen COW buffers straight to the predicate. Source sentinel
and shape constants are pinned inside gate 4, ahead of every column read, so a changed
`NULL_SLOT` or `NULL_GENERATION` is a metadata fault and cannot surface as column data.

Minor, not a defect: `OWNER_I32_COLUMNS + OWNER_I64_COLUMNS != OWNER_FIELD_COUNT` compares
three bridge constants and is statically false, so that clause is dead.

## Metadata fault arithmetic, re-derived

The field-count counterfactual pops descriptor 288 — Work's last `u8[512]` — and appends it
after all nine fauna descriptors, leaving Work at 8 fields and world_init at 10 beginning
at 288, the nine fauna descriptors still first and exact. That descriptor is 512 value
bytes plus its 8-byte count, hence -520 on Work's payload and block, +520 on world_init's,
and -520 on world_init's offset; the 298-entry tables and the section total are unchanged.
The child counterfactual moves one 8-byte extent from owner 10 to owner 17, giving child
begins 4 for owners 11..17 and +-8 on the two payloads with -8 offsets for 11..17. The
primary fault pairs 385 on owner 17 with 511 on owner 16 so `DESCRIPTOR_ROW_COUNT` still
sums. Type i32->i64 is 384 x 4 = +1,536 and extent 384->385 is +4, both propagated to the
payload, block and the pinned section totals. Every counterfactual therefore presents a
valid schema and a physically coherent frame before gate 4, which is what makes the eight
bypass kills meaningful. The two sentinel faults edit a disposable clone only and the tool
re-asserts the originals in `finally`.

Case accounting closes: 1 control + 8 x 2 + 2 x 2 + 1 forwarding = 22 cases at 9 assertions
= 198, of which 10 are bypass kills (8 schema, 2 source-null), matching the recorded log.
The sentinel bypass oracle is genuine: the fixture's -1/0 are literals independent of the
source constants, so with the guard removed the altered sentinel yields a column code
rather than the expected metadata code.

## Mutation witnesses

The runner performs nine zero-substitutions, nine omitted per-column constant checks and
one shape gate that ignores the i64 extent — the 19 required mutants, plus baseline and
restored controls, with `len(results) == 21` asserted and product files restored and
re-hashed. Oracles hold: zone-slot substitution breaks the valid-empty control; each other
substitution is caught by the single-nonzero-field fixture; each omitted constant check is
caught by that same fixture or, for zone slot, by the all-zero frame; the i64 shape
omission is caught by the short-birth fixture, which carries no other fault and so
distinguishes `COLUMN_FAUNA_SHAPE` from `COLUMN_FAUNA_RESERVED`.

## Tests and evidence

The focused suite covers all nine empty/short/long shapes, null and wrong-owner and
malformed-bucket frames, the raw all-zero refusal, the canonical-empty success, all 3,456
row positions, i32 and i64 extrema and values above exact float integer precision,
reference-pair versus numeric-default separation, exact detail text and complete
nonmutation of both caller and frame inputs. The actual-owner test is an allocation-only
fixture with negative and high reader addresses and a real section 1 refusal preserved
across bridge calls; it is correctly not described as a private-column snapshot, and the
full existing generation test remains in `test_world_init.gd`. The recorded focused log
shows 8 tests, 6,019 assertions, 0 failures.

## Tracked items and blockers

No blocker. Two items must close before merge:

1. `metadata-preflights-first.log` pins `world_init.gd` at `e919eb18...`, which predates the
   parent's comment-only allocation-writer correction; the frozen file now hashes
   `1b4c7d85...`. The log is honest about when it ran, but a final metadata run must re-pin
   the post-correction hash, and the full suite is still pending.
2. `run_mutants.py` invokes `res://test/fauna_validation_focus.gd`, which is outside the
   reviewed input set. Its contents — that it lists exactly `test_save_owner_world_init.gd`,
   matching the runner's expected test count — could not be verified here.

Registry and CI are consistent: the persistence registry row classifies the bridge category
3 with 15,360 logical packed bytes already inside the caller's streaming allowance and makes
no native-memory claim, and the workflow carries the fauna metadata injection step.
Mutation results are archival rather than CI-gated, which matches the contract's division of
ownership. Combined section 1/4 restore, full-file publication and bulk owner APIs remain
explicitly deferred and are not scope defects.

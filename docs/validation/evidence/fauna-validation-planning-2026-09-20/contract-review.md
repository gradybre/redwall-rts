# Contract review: FAUNA-S4-VALIDATE-R01 draft1

2026-09-20. Independent final review before author dispatch. Read-only: nothing here was run,
imported or applied. Every number below is re-derived from `world_init.gd`, the compiled
`save_component_columns_schema.gd` tables and the packet evidence, not copied from the draft.

## 1. Verdict

Dispatchable once the five wording findings in section 9 are folded in. No contradiction with
the authority order, the source or the parent dispositions was found.

## 2. Authority and exact image, re-derived

REQ-SET-059 / GDD §4.2 and SET-AMEND-001 §3 require reserved allocation only and forbid
repurposing or reviving retired hunting state. The draft introduces no active fauna, species
remapping, population update, migration link or repair, and claims no resident-cap interaction.
That is consistent.

Owner 17 is `world_init`, version 1, primary count 384, zero child extents, nine fields at global
289–297: eight i32 then one i64, each 384 elements. `_allocate_fauna_columns()` fills
`_fauna_zone_slot` with `EntityDirectory.NULL_SLOT` (-1), `_fauna_zone_generation` with
`NULL_GENERATION` (0) and the remaining seven i32 columns plus the i64 column with literal 0.

Arithmetic closes independently: values `384 * (8*4 + 1*8) = 15360`; payload
`4 + 9*8 + 15360 = 15436` = `OWNER_PAYLOAD_BYTES[17]`; block `24 + 10 + 15436 = 15470` =
`OWNER_BLOCK_BYTES[17]`; `12932095 + 15470 = 12947565` = `SECTION_BYTES`. The draft's three
figures are correct.

The fixed reserved-empty image is therefore one -1 column, one 0 generation column, six further
zero i32 columns and one zero i64 column. A raw all-zero frame is invalid because zone slots must
be -1, and no normalization of that frame is permitted. The draft states both.

## 3. Shared static predicate

Nine explicitly typed arguments — first eight `PackedInt32Array`, ninth `PackedInt64Array` — in
canonical ordinal order. All nine exact extents are checked before any value check, giving
`COLUMN_FAUNA_SHAPE`; then exact whole-column constants give `COLUMN_FAUNA_RESERVED`; otherwise
`REFUSE_NONE`. That ordering is what makes the shape-gate mutant in section 6 observable.

Delegating `fauna_is_canonically_empty()` to the predicate preserves its public behaviour: the
nine private columns are sized once in `_init()` and never resized, so the shape gate is total and
the value gate is equivalent to the existing per-row loop over `fauna_zone_ref_of` and the seven
zero fields. `fauna_zone_ref_of` and its out-of-range `NULL_REF`, `fauna_row_capacity`,
`fauna_reserved_bytes`, allocation defaults, ordinary generation and the whole section 1
copy/validate/cross-check/restore surface, including `section_1_code()` / `section_1_detail()` and
both existing refusal channels, remain unchanged. No snapshot or private-column getter is added.
No constructor, collaborator, live store, catalog scan, callback, file I/O, reflection, diagnostic
mutation, default projection, duplicate, sort, scratch or range `Array` appears. Only a
`StringName` is returned, over caller-frozen COW buffers.

## 4. Bridge gates and metadata cross-checks

Gate order — null, wrong owner, forwarded `Schema.schema_refusal()`, owner-17 metadata, forwarded
`Section.owner_shape_refusal()`, nine typed accessors, raw column code — matches the
`save_owner_transforms.gd` precedent, including forwarding the schema refusal unchanged and
reserving the `WorldInit owner17 metadata:` prefix for gate 4.

Metadata cross-checks are source-reachable. `FAUNA_STOCK_ROWS`, `FAUNA_I32_COLUMNS` and
`FAUNA_I64_COLUMNS` are constants on `world_init.gd`. `EntityDirectory` is a const preload there
and `NULL_SLOT` / `NULL_GENERATION` are constants on it, so `WorldInit.EntityDirectory.NULL_SLOT`
and `.NULL_GENERATION` resolve from the bridge without adding a preload edge. That chained
constant read is expected to compile but has not been imported; treat it as confirmed at actual
import, not before. Scalar constants only; no new const `Array`.

The bridge constructs no WorldInit, which is required rather than stylistic: `_init()` allocates
the tile, basin, centre, grove, fish and fauna columns and then runs `_stage_masks()` over 16384
tiles. Independent generator and source-capacity checks remain required, and the draft correctly
declines to claim an owner publication-table comparison.

## 5. Field-count fault arithmetic

Re-derived from the descriptor tables. Work is owner 16 with `OWNER_FIELD_BEGIN` 280 and count 9,
so its fields are 280–288 and its trailing descriptor at global 288 is `_tool_broken`, u8, 512
elements. Owner 17 begins at 289 with count 9.

Moving descriptor 288 to the end of all three field tables yields: owner 16 fields 280–287, count
8; owner 17 begin 288, count 10, holding the nine fauna descriptors at 288–296 in their original
order followed by the moved field at 297. The global field total stays 298.

Bytes: `8 + 512*1 = 520`. Work payload/block -520, WorldInit payload/block +520, owner 17 offset
-520, section bytes and descriptor row count unchanged. The draft's numbers are correct.

This isolates the field-count guard: every pinned fauna key, type and extent still matches, so
only the count comparison can fail. The other faults were checked the same way. Key
`world_init` → `world_iniu` keeps ten bytes and still sorts after `work`. Version 1 → 2 and
primary 384 → 385 with owner 16 512 → 511 both leave `schema_refusal()` satisfiable, since it
requires only version ≥ 1, primary > 0 and an unchanged descriptor-row sum. Moving owner 10's one
child extent to owner 17 shifts child begins 11–17 to 4, moves 8 bytes of payload and block, and
shifts offsets 11–17 by -8 with the section total unchanged. First-field type i32 → i64 is
`384*8 - 384*4 = +1536`; extent 384 → 385 is `+4`. All reach gate 4 rather than being masked.

## 6. Mutant oracles, re-derived

Nineteen: nine argument substitutions, nine omitted per-column constant checks, one shape gate
blind to the i64 extent. Zone-slot substitution is killed by the valid-empty control; each other
substitution needs a fixture nonzero only in the omitted field, which the draft states. The
omitted-check variants are distinct from the substitutions and need a fixture defective in that
column alone.

Swapping or reusing two like-typed zero-default arguments is semantically equivalent under these
rules and is correctly not claimed caught; exact canonical mapping stays an independent source
review. A swap between an i32 and the i64 argument is not expressible against the explicit types.
Zone default -1 and raw-zero invalidity are both exercised. No owner construction, projection or
callback appears in any oracle.

## 7. Preload closure and i64 precision

The probe log records engine 4.7.2 and a pass over 384 zeros, 9007199254740993 and both signed
extrema, so `PackedInt64Array.count` is exact above float integer precision on the installed
engine. The closure evidence shows 26 nodes with existing self-preloads in `int_math.gd` and
`save_codec.gd` — actual source, already compiled by passing suites — and no cycle involving the
proposed bridge. The draft's wording claims exactly that and no more; it must not be upgraded to
an acyclic-graph claim, and actual import remains outstanding.

## 8. Scope limits confirmed

No bulk or combined section 1/4 transaction, regenerated map, owner publication or full-world
acceptance is claimed; SAVE-S4-OWNER-BINDINGS keeps combined restoration under the unpublished
load barrier. Fixture values are source-owned fixed defaults, not a private-field snapshot.
Native and wrapper overhead remain unmeasured, and the 15,360 bytes sit inside the existing
one-owner stream allowance.

## 9. Findings to fold in before dispatch (non-blocking)

1. Gate 4's detail must distinguish a field-count fault from a per-field key/type/extent fault;
   both return `SAVE_COMPONENT_METADATA`, so the detail text is the only witness.
2. The sentinel-clone witness depends on gate 4 preceding column evaluation. State that ordering
   explicitly in the contract, since a predicate built on a faulted `NULL_SLOT` would otherwise
   refuse a canonical image with a column code instead.
3. "17 static/source gates" reads ambiguously against "owner 17". Enumerate the gates or reword.
4. State outright that the bridge constructs no WorldInit and no collaborator, with the
   `_stage_masks()` cost as the reason.
5. Pin the accessor mapping explicitly: ordinals 0–7 through `i32_column`, ordinal 8 through
   `i64_column`, in canonical order.

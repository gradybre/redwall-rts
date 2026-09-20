# Reserved-fauna component validation — FAUNA-S4-VALIDATE-R01 v1

Date: 2026-09-20. Accepted by Astra after two independent planning reviews and an actual integer-count probe; ordinary implementation is authorized under ADR 0174. This validates WorldInit's section 4 reserved columns only.

## Authority and exact image

GDD REQ-SET-059/065, SET-AMEND-001 section 3 and task 09.2 require canonical empty fauna allocation and rejection of noncanonical retired hunting state. These bytes cannot be repurposed. No active fauna, species remapping, population updates, migration links or repair is introduced.

Owner 17 is `world_init`, version 1, primary count 384, no child extents and nine fields:

| Ordinal | Field | Type / count | Exact value in every row |
|---|---|---|---|
| 0 | `_fauna_zone_slot` | i32 / 384 | -1 |
| 1 | `_fauna_zone_generation` | i32 / 384 | 0 |
| 2 | `_fauna_species_id` | i32 / 384 | 0 |
| 3 | `_fauna_population` | i32 / 384 | 0 |
| 4 | `_fauna_capacity` | i32 / 384 | 0 |
| 5 | `_fauna_tracks` | i32 / 384 | 0 |
| 6 | `_fauna_harvest_today` | i32 / 384 | 0 |
| 7 | `_fauna_migration_link` | i32 / 384 | 0 |
| 8 | `_fauna_birth_remainder` | i64 / 384 | 0 |

Value bytes: 15,360; payload: 15,436; block: 15,470. Schema, owner version, keys, types and extents remain unchanged. All-zero wire is invalid because zone slots must be -1. A correctly filled empty image is the only locally admissible image. The resident population cap does not apply to this reserved allocation.

## Shared static predicate

Add `static func fauna_columns_refusal(zone_slot, zone_generation, species_id, population, capacity, tracks, harvest_today, migration_link, birth_remainder) -> StringName` to `world_init.gd`. All parameters are explicitly typed: the first eight `PackedInt32Array`, the last `PackedInt64Array`.

1. Check all nine exact extents before any value checks. Failure: `REFUSE_COLUMN_FAUNA_SHAPE` / `COLUMN_FAUNA_SHAPE`.
2. Check every column's exact constant across all 384 rows. Failure: `REFUSE_COLUMN_FAUNA_RESERVED` / `COLUMN_FAUNA_RESERVED`.
3. Success: existing `REFUSE_NONE`.

Use packed `count(expected) == FAUNA_STOCK_ROWS` checks. Both i32 and i64 operations are verified in the installed engine; no float conversion is allowed. Use `EntityDirectory.NULL_SLOT` and `NULL_GENERATION` for the reference pair, with exact -1/0 contract values pinned by tests and bridge metadata. Ordinary numerical fields require literal zero.

No constructor, collaborator access, live store, catalog scan, callback, file I/O, reflection, diagnostic mutation, default projection, duplicate, sort, new packed scratch or range Array. The caller freezes its columns for this synchronous read. Only a `StringName` result is returned.

Replace the body of `fauna_is_canonically_empty()` with one call to this shared predicate over all nine existing columns, comparing with `REFUSE_NONE`. Preserve `fauna_zone_ref_of` and its out-of-range behavior, allocation defaults, ordinary generation, section 1 copy/validation/restore methods and both existing refusal channels unchanged. Do not add a public snapshot or private-column getter solely for tests.

## Framed bridge

Add `save_owner_world_init.gd`, exposing only `static framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal`. Preload only WorldInit, Schema, Section and SaveHeader. Construct no WorldInit or collaborator: its constructor allocates and stages map data.

Gate order: null → `SAVE_COMPONENT_SHAPE`; owner other than 17 → `SAVE_COMPONENT_OWNER`; `Schema.schema_refusal()` forwarded unchanged; exact metadata → `SAVE_COMPONENT_METADATA`; `Section.owner_shape_refusal()` forwarded unchanged; nine explicit canonical typed accessors (ordinals 0–7 i32, ordinal 8 i64); predicate's raw column code. Success has empty code and detail.

Metadata pins owner key, version, primary count 384, zero child extents, nine fields, and every field key, type and count. Cross-check WorldInit's `FAUNA_STOCK_ROWS=384`, `FAUNA_I32_COLUMNS=8`, `FAUNA_I64_COLUMNS=1`, plus `WorldInit.EntityDirectory.NULL_SLOT=-1` and `NULL_GENERATION=0`. Use scalar constants, no new const Array. Independent generator and source-capacity checks remain required; do not claim an owner publication-table comparison.

Metadata detail must identify whether an owner count or a specific field key/type/extent comparison failed. Source-sentinel metadata checks run before column evaluation, so a changed null constant cannot be reported as a column-data defect.

Gate 4's detail begins exactly `WorldInit owner17 metadata:`. Column failure detail contains `WorldInit owner 17 ` and the exact code, without row identity. Schema refusal code and detail remain unchanged. No normalization of the raw zero frame is permitted.

The caller's 15,360 packed bytes are already inside the existing stream allowance. Accessors share frozen COW buffers. No packed projection or scratch is added. Native/wrapper overhead remains unmeasured. The reviewed preload closure contains existing supported self-preloads in IntMath and SaveCodec, but no cycle involving this proposed bridge; actual import must still pass.

## Acceptance and witnesses

Parent tests all nine empty/short/long shapes before value checks; null, wrong-owner and malformed buckets; raw all-zero refusal; correctly filled empty success; all 384 row positions in each field; positive and negative i32/i64 extrema; i64 values above exact float integer precision; exact raw diagnostics; and complete input nonmutation.

Nine required argument substitutions replace one accessor with a correctly sized all-zero column of its type. Zone-slot substitution must reject the valid-empty control. For each other argument, a fixture has a nonzero value only in that field; substitution would incorrectly accept it. Also kill each omitted per-column constant check (nine variants) and a shape gate that ignores the i64 extent (one variant). That is 19 required mutants. Reusing/swapping two zero-default columns may be equivalent under these rules and is not claimed caught; exact canonical mapping is independently source-reviewed.

Actual-owner evidence uses existing public fauna readers and the existing before/after generation test. Add negative/high reader-address checks and verify static/bridge calls preserve the live owner's section 1 refusal code/detail, publication state and fauna emptiness. Fixture values are source-owned fixed defaults, not claimed as a snapshot of private fields.

Real-engine metadata faults must preserve valid schema and physical shape before reaching gate 4. Cover owner key/version/primary/child count/field count/field key/type/count, unchanged schema forwarding, exact prefix and eight matching bypasses. Additionally fault the two null sentinel constants in a disposable clone and prove the metadata guard rejects them; do not edit production sentinels. Actual assertion failures, expected suite counts and absence of parser/script errors are required for every mutant claim.

Import, the seventeen repository checks enumerated in the predecessor’s `contracts-first.json` (not a reference to owner index 17), focused and full suites, independent source review and exact-head CI precede merge. No bulk section 1/4 transaction, regenerated map, owner publication or full-world acceptance follows from this primitive. Existing SAVE-S4-OWNER-BINDINGS owns combined restoration under the unpublished load barrier.

Author owns only `world_init.gd` and the new bridge through a bounded SHA-pinned patch. Parent owns tests, fault tooling, category-3 registry classification, capacity sidecar, queue, documentation and CI.

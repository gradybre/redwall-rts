# Independent source review — ResourceNodes owner 13 validation

Date 2026-09-20. Scope: `resource_nodes.gd` and the new `save_owner_resource_nodes.gd` read against
RESOURCE-NODES-S4-VALIDATE-R01 v1 and ADR 0176. Source reading only. Nothing below is a claim that
any suite, tool or engine import was executed in this review.

## Predicate

`columns_refusal()` is static and pure over its ten arguments. Gate order in the source is shape,
present flag, exhausted flag, resource id, quantity, capacity, regrow days, planted day, stock,
present day, exhaustion, tile, ref, inactive — fourteen gates, each a separate whole-image sweep of
all 4096 physical rows, none fused per row, none capped at the living 256. Shape is proved for all
ten columns before any indexing. `present` is exactly `present[row] == 1` and the exhaustion
relation is the pinned `(exhausted[row] == 1) == (quantity_milli[row] == 0)`, both only after the
flag gates. Tile bound is `TILE_COUNT`, reference bound is
`EntityDirectory.DIRECTORY_CAPACITY` (352418) and never the typed 4096, Transforms 87552 or a Work
typed row; inactive sentinels are exactly `NO_NODE` and `(-1, 0)`. Gate 14 forces only inactive
quantity and exhaustion to zero, so nonnegative retained id, capacity, regrow period and planting
date survive in any mixture, with no tuple reconstruction. Stock's `quantity <= capacity` applies to
every physical row. No float, no allocation, sort, duplicate, scratch, range Array, constructor,
directory or catalog access, diagnostic write, normalization, default projection or repair appears
anywhere in the added code, and `INT64_MAX` is compared, never summed or converted. No local
uniqueness scan exists, which matches the contract's deferral.

## Bridge

`framed_refusal()` is the only public entry and runs exactly the seven contracted gates: null →
`SAVE_COMPONENT_SHAPE`; owner ≠ 13 → `SAVE_COMPONENT_OWNER`; `Schema.schema_refusal()` forwarded
unchanged; metadata; `Section.owner_shape_refusal()` forwarded unchanged; ten explicit canonical
typed accessors; then the raw column code. The accessors are u8 at ordinals 0 and 6, `i64_column`
at 2 and 3 — both genuinely i64, no zero substitute or narrowing — and i32 at 1, 4, 5, 7, 8, 9.
Success carries an empty code and empty detail. The metadata prefix is exactly
`ResourceNodes owner13 metadata:`; the column detail begins `ResourceNodes owner 13 ` and carries
the exact unwrapped code with no row identity. Pins cover key, version 1, primary 4096, zero
children, ten fields with their exact keys, types and 4096 counts, plus
`RESOURCE_NODE_CAPACITY` 4096, `MAP_TILES_X/Z` 128, `TILE_COUNT` 16384, `MIN_CALENDAR_DAY` 1,
`NO_NODE` −1, `NULL_REF` (−1, 0), `DIRECTORY_CAPACITY` 352418 and `NULL_SLOT/NULL_GENERATION`. All
are constant chains, constructing nothing, and refuse before any column is read. Preloads are the
four permitted modules. The §1 owner at version 2 with 16384 rows remains a distinct block, and the
version pin makes confusing them a refusal.

## Existing behaviour

No ordinary method, §1 API, diagnostic, reader, scratch capacity or persistence shape changed. The
only repair is `resource_id_of()`'s stale "unstated domain" phrasing, now stating that ADR 0052
settles the domain and that this store validates range only, with the matching correction to the
old unit test's header comment.

## Parent evidence, as stated rather than observed

The focused suite is 8 tests / 85132 assertions / 0 failures after the alias fix; every packed
column is duplicated for both the nonmutation snapshots and the bad fixture, which removes the
shared-element aliasing the first run exposed. The raw first-failure disposition is recorded and the
author's 434-line estimate is corrected to the actual 545-line raw patch, inside the 650 bound,
with no normalization used. The 30 mutants (10 zero-accessor substitutions, 17 clause omissions, 3
order reversals) and the 18-case / 162-assertion metadata matrix are coherent as planned: the
omission set matches the seventeen source clauses one-for-one, the capacity omission is correctly a
refusal-code-identity kill (CAPACITY versus STOCK) and not an acceptance mutation, and the metadata
faults re-balance payload, block, offset and section totals so each reaches gate 4 with a valid
schema. I did not run them and make no claim about their outcome.

## Blockers

1. Mutant, metadata, focused and full runs remain outstanding; source coherence is not execution.
2. Local acceptance proves scalar domain only. Duplicate tiles and duplicate references pass here;
   RESOURCE-NODES-SAVED-BINDINGS still owns the saved §1 inverse, Directory kind/typed-row/ref
   agreement, uniqueness in both directions and same-file catalog output-ID membership.
3. Generic fixture ids in the ordinary suite and the wide-value probe are not published catalog
   identity.
4. Preload closure and engine import are unverified from source; native and wrapper overhead beside
   the 172032 caller bytes is unmeasured.
5. Schema generator and source-capacity audits remain independent; the metadata pins are not an
   owner-publication-table parity proof.

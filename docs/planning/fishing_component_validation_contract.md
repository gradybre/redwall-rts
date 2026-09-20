# Fishing component validation contract

FISHING-S4-VALIDATE-R01 · version 1 · accepted for bounded implementation, 2026-09-20; ADR0181.

This milestone adds cold section-4 column validation without changing gameplay, section-7 effort claims, schema versions, capture/restore APIs or world publication. Independent feasibility and contract review have confirmed the source domains; the existing public lifecycle probe passes106 assertions. Review findings are dispositioned in the evidence folder.

## Layout and defaults

Owner4 `fishing`, section-4 owner version1, primary32, no independent child extents, global fieldbegin80/count22. Stock fields have literal96 extents. Value bytes5344, payload5524, block5555, offset8503348. The existing CANONICAL_OWNER_SCHEMA_VERSION2 belongs to section7 claims and is not this version.

Add `class Columns` with exactly the following typed packed arrays, `_init` sizing and clear defaults, and `is_sized()`. Defaults are all zero except habitat_zone_slot, habitat_ref_slot, stock_habitat_slot and stock_species_id, which are -1. Cold clear defaults differ from a created live habitat.

| Ordinal | Property (canonical key adds `_`) | Type | Count |
|---|---|---|---|
| 0 | habitat_present | u8 | 32 |
| 1 | stock_present | u8 | 96 |
| 2 | habitat_type | i32 | 32 |
| 3 | habitat_zone_slot | i32 | 32 |
| 4 | habitat_zone_generation | i32 | 32 |
| 5 | habitat_effort_slots | i32 | 32 |
| 6 | habitat_pollution | i32 | 32 |
| 7 | habitat_danger | i32 | 32 |
| 8 | habitat_protected_fraction | i32 | 32 |
| 9 | habitat_capacity_milli | i64 | 32 |
| 10 | habitat_ref_slot | i32 | 32 |
| 11 | habitat_ref_generation | i32 | 32 |
| 12 | habitat_effort_used | i32 | 32 |
| 13 | habitat_intensive | u8 | 32 |
| 14 | stock_habitat_slot | i32 | 96 |
| 15 | stock_habitat_generation | i32 | 96 |
| 16 | stock_species_id | i32 | 96 |
| 17 | stock_population_milli | i64 | 96 |
| 18 | stock_capacity_milli | i64 | 96 |
| 19 | stock_harvested_today_milli | i64 | 96 |
| 20 | stock_closed | u8 | 96 |
| 21 | stock_restocking | u8 | 96 |

## Pure predicate and deterministic priority

Add static `columns_refusal(image: Columns) -> StringName`. Argument-only, immutable input, no live Fishing/Directory/Forage/Jobs/catalog construction, no callbacks, diagnostics, float, clock or allocation per row. Preserve all existing methods and refusal behavior. Existing REFUSE_NONE is success. New constants REFUSE_COLUMN_* return the exact corresponding codes below.

1. Null or any of the22 wrong extents gives COLUMN_SHAPE before indexing.
2. Global byte validation in canonical field order: habitat_present, stock_present, habitat_intensive, stock_closed, stock_restocking, ascending physical rows within each. Any value above1 gives COLUMN_FLAG.
3. Ascending habitat rows, these gates in order:
   - Type0..2 gives COLUMN_HABITAT_ENUM otherwise.
   - Pollution and protected_fraction are full nonnegative i32; danger0..3. Violation gives COLUMN_HABITAT_VALUE. Do not invent units, effects or a10000 bound.
   - Present self reference requires slot0..352417/generation>0. Present zone allows exact NULL(-1,0) or the same nonnull structural domain; stale references remain legal locally. Inactive self and zone must both be exactly NULL. Violation gives COLUMN_HABITAT_REF.
   - Inactive: capacity0, effort_used0, intensive0; effort_slots must be0 or EFFORT_SLOTS_BY_TYPE[type]. Preserve valid retained type, pollution, danger and protected_fraction. Violation gives COLUMN_HABITAT_FREE.
   - Present: effort_slots exactly EFFORT_SLOTS_BY_TYPE[type], effort_used0..effort_slots, capacity exactly the sum of the three source species capacities times1000. Violation gives COLUMN_HABITAT_STATE. Never compare effort_used with live or saved section7 claims here.
4. Ascending stock rows, parent habitat is row/3 and species position row%3:
   - stock_present must equal habitat_present of that parent, else COLUMN_STOCK_LINK.
   - Inactive: stock_habitat_ref exact NULL, species_id-1, population/capacity/harvested0, closed/restocking0; else COLUMN_STOCK_FREE.
   - Present: stock habitat slot/generation must equal the parent's saved self reference, else COLUMN_STOCK_LINK.
   - species_id is full nonnegative i32, not a nine-row table index; else COLUMN_STOCK_SPECIES.
   - capacity exactly `SPECIES_CAPACITY_U[HABITAT_SPECIES_ROWS[type*3+position]]*1000`; population at least `capacity*10/100` and at most capacity; harvested_today0..parent capacity/40. Violation gives COLUMN_STOCK_VALUE. Bounds make later three-stock sums safe; no arbitrary i64 values reach products.
   - Strict hysteresis using cross multiplication100*P versus30*K/40*K: below30% requires restocking1, above40% requires0, inclusive30..40% accepts either. Else COLUMN_STOCK_STATE. closed remains an independent stored boolean; do not derive it from species, current season or weather.
5. Ascending present habitats: the three species item IDs must be distinct, else COLUMN_SPECIES_DUPLICATE; then the sum of their harvested_today must be <=habitat capacity/40, else COLUMN_QUOTA. All single-stock values were bounded before summing.
6. Across present habitat pairs in ascending row order, duplicate self SLOT gives COLUMN_SELF_DUPLICATE. Then in a separate pass, duplicate nonnull zone SLOT+GENERATION pair gives COLUMN_ZONE_DUPLICATE. Two zone generations sharing one slot are accepted; two current self generations sharing one slot are refused. Nested scans across32 rows need no packed scratch. No global uniqueness of stock species IDs across different habitats.

The rules follow every public writer, not a fabricated catalog: creation starts at80% stock; harvest respects10% hard floor and daily shared quota; recovery caps atK; both update hysteresis; deletion retains selected habitat history and clears all stock rows. Whole-file validation still needs external identity and producer bindings. A public claim restore before aggregate rebuild is a staging operation, not evidence of a publishable world.

## Framed bridge and pins

New `save_owner_fishing.gd` preloads only Fishing, Schema, Section and SaveHeader. Seven gates: null record; wrong owner4; unchanged schema refusal; owner metadata plus source pins; unchanged section owner shape refusal; one cold Columns with22 explicit typed assignments in canonical order; exact raw predicate code wrapped with owner-qualified detail. Empty code/detail on success. `METADATA_DETAIL_PREFIX` is `Fishing owner4 metadata:`; column details contain `Fishing owner 4 ` and exact code. No row identities in column diagnostics.

Pin owner key/version/primary/childcount/fieldcount and each22 key/type/count. Use OWNER_INDEX/OWNER_KEY/OWNER_VERSION/OWNER_PRIMARY_COUNT/OWNER_CHILD_EXTENT_COUNT/OWNER_FIELD_COUNT and FIELD_KEYS/FIELD_TYPES/FIELD_COUNTS, matching existing bridge conventions. Do not pin or reinterpret section7's version constant.

Source pins: FISH_HABITAT_CAPACITY32, SPECIES_PER_HABITAT3, FISH_STOCK_CAPACITY96; HABITAT_COAST0/LAKE1/RIVER2 and HABITAT_TYPE_COUNT3; COAST_EFFORT_SLOTS6/LAKE_EFFORT_SLOTS6/RIVER_EFFORT_SLOTS4; SPECIES_COUNT9 and named TROUT0/DACE1/SALMON2/PERCH3/CARP4/WHITEFISH5/HERRING6/MACKEREL7/MUSSEL8; MILLI_PER_UNIT1000; DANGER_MIN0/MAX3; HARD_FLOOR_PERCENT10, DEPLETION_WARNING_PERCENT30, RESTOCK_RECOVERY_PERCENT40, PERCENT_DENOMINATOR100, DAILY_QUOTA_DIVISOR40; NULL_REF(-1,0), Fishing.EntityDirectory NULL_SLOT-1/NULL_GENERATION0/DIRECTORY_CAPACITY352418 (indirect access through the existing Fishing preload; no fifth direct preload).

Pin all three source table lengths before any entries: EFFORT_SLOTS_BY_TYPE length3 `[6,6,4]`, HABITAT_SPECIES_ROWS length9 `[6,7,8,3,4,5,0,1,2]`, SPECIES_CAPACITY_U length9 `[600,900,600,900,700,600,1200,900,1000]`. These are wire compatibility pins, not a new gameplay mapping. Pure validation may use source constants directly after type gates; bridge establishes compiled-table compatibility before projection. Do not call live catalog verification.

Caller5344 + default Columns5344 =10688 conservative logical packed bytes, within the6417408 stream allowance. Nested fixed-size duplicate scans add no packed buffers. Native object/array overhead and RSS remain unmeasured. No second world or persistent authoritative column is added.

## Verification before milestone acceptance

Freeze explicit accepted and refused images, coherent metadata counterfactuals, independent projection witnesses and logical code mutations before dispatching authors. Public probes must cover actual habitat creation for all types, maximum scalar/item IDs, quota sharing/reset, closure independence, 30/40 hysteresis directions, hard floor refusal atomicity, destruction/recreation and stale/new zone generations. Do not claim private inactive bytes from getters that refuse inactive rows.

Test all22 projections/extents, both bucket sizes, every32 habitat and96 stock row, full capacity and head/tail relations; priority pairs, nonmutation, broad inactive retained scalars, all source table short/long/value faults, duplicate species within/across habitats, duplicate self slots and exact zone pairs versus different generations. Metadata fault cases: key/version/primary/children/fieldcount/fieldkey/type/extent with coherent section arithmetic and each individual bypass, positive control/schema forwarding, plus9 source table cases. Remove live autoloads only in the disposable metadata clone for malformed source-table experiments; normal focus/import/full suite retain actual startup.

Required final gates:17 static checks and capacity regeneration, actual import, focused and full suite, metadata faults, mutation campaign (assertions only, no parser/runtime-error kills), independent source review, exact-head CI and merge. Any equivalent mutation must be explicitly excluded instead of mislabeled killed.

FISHING-SAVED-BINDINGS remains required: same-file Directory kind/generation/typed-row identity, Forage basin semantics, item definitions and species mapping, section7 effort totals/claims with Jobs and Expedition, loaded events/clock and file provenance. Full habitat/stock bulk capture/apply and the fishing gameplay loop are not completed by this milestone.

## Frozen review refinements

The value-image set contains196 explicit cases; shape-witnesses.json adds67 null/extent/paired-flag cases. Parent tests also cover every physical row, all22 projections and complete packed nonmutation. The63 required code mutations include six deliberately swapped-order variants; these names describe faults, never the implementation order. Equivalent arithmetic rewrites and runtime-error-only whole-shape bypasses are excluded explicitly. Three source table fault triplets plus the18 schema/control/bypass cases total27 planned engine cases/243 assertions. Actual results remain outstanding.

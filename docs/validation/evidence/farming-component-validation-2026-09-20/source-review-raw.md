# Farming component source review — FARMING-S4-VALIDATE-R01 v1 / ADR 0180

Independent reading of the two reconstructed candidate sources, not an execution report.
Neither is applied to production: PR170 CI is running and the validated raw patches are to be
applied only after merge, with SHA identity checked then. This review covers exactly these
bytes — candidate-farming.gd `41439e1b…`, candidate-save_owner_farming.gd `f6a34982…`. Any
substantive change to either requires re-review of the affected source.

## Layout, projections and typed defaults

All fifteen canonical columns are projected explicitly, in ordinal order 0..14, with the
declared widths: `present` u8, `growth_milli_hours` and `compost_milli` i64, the remaining
twelve i32. FIELD_KEYS carry the leading-underscore registry keys; Columns exposes the same
names without it, as the contract requires. Columns defaults mirror `_clear_plot_columns`
exactly: crop -1, state 0, soil 0, family -1, tile -1, self (-1,0), everything else zero-filled
by `resize`. Live creation's health 10000 / moisture 6000 / tile fertility are correctly absent.
No new capture, restore, getter or alternate live constructor is introduced.

## Refusal order

`columns_refusal` settles null and all fifteen extents before any indexing, then scans the whole
4096-row present byte, then walks rows ascending with ENUM, VALUE, HISTORY, IDENTITY and finally
FREE_ROW or STATE, then tile uniqueness before self-slot uniqueness. That is the contract order,
and it yields the frozen priority witnesses (late present byte over early bad soil; earlier-row
value over later-row enum; duplicate tile before duplicate ref).

State relations read as specified: EMPTY requires crop NONE, growth 0, health 10000, sow day 0;
non-EMPTY requires crop 0..4, sow day >= 1, an allowed crop/soil pair and growth at most
target+999; SOWN is growth 0 with full health; GROWING is positive health strictly below target;
RIPE is positive health at or above target; WITHERED admits both zero health below target and
positive health at or above it, so healthy WITHERED is accepted and is not confused with health
death. Inactive rows require only crop NONE and state EMPTY, keeping retained soil, moisture,
MAX-i64 growth, health, history, compost 2000 and MAX-i32 sow day valid — the broad inactive
domain ADR 0180 states, with pair consistency still enforced on those rows.

## Source pins and indexing safety

The bridge gates are null, wrong owner, forwarded `Schema.schema_refusal`, metadata plus source
pins, forwarded `Section.owner_shape_refusal`, the cold Columns projection, then the exact raw
column code wrapped with an owner-qualified detail; success is empty code and empty detail. Both
crop table **lengths** are compared before any entry is read, and the crop and soil ranges are
settled in the predicate before `CROP_ALLOWED_SOILS` or `CROP_GROWTH_HOURS` is indexed, so no
malformed table or illegal ordinal can reach unsafe indexing. Capacities, sentinels, scalar
bounds, the global Directory handle and the 0..4 wire ordinals are pinned as compatibility
checks, not as a second gameplay domain.

## Purity and memory

The predicate is static, reads only its argument and compiled constants, calls no live Farming,
Directory or Catalog object, runs no callback, diagnostic, normalization, calendar or float, and
mutates nothing: the two uniqueness passes sort private duplicates. 565248 is a conservative
logical packed-byte figure (caller image, default Columns buffers, two 4096-entry i32 copies);
it is arithmetic, not a measured resident set, and it is conservative because the fifteen
projection assignments release the default buffers.

## Findings

No production defect identified in either source. Three non-blocking observations:

1. COLUMN_SHAPE is unreachable through the bridge, since the section shape gate precedes the
   projection; the typed-extent witnesses therefore rest on forwarded section refusals plus the
   direct pure-predicate cases. Coverage note, not a defect.
2. The enum lower bounds use SOIL_LOAM, STATE_EMPTY and CROP_NONE as minima; correctness depends
   on the pinned 0/0/-1 ordinals, which gate 4 does pin.
3. The bridge's shared-buffer claim holds only while nothing writes; the predicate never writes.

The harness correction that disables autoloads applies to the disposable metadata clone only and
does not touch these sources; focus, import and full runs retain normal startup. The initial
focus result (7 tests, 17915 assertions, 0 failures, clean) stands; the 24 metadata cases and 50
mutation units are still running and no outcome is asserted here. Runtime or parser errors are
not mutation kills. Whole-file bindings, bulk FarmPlot capture and apply, saved section 1 /
Directory / clock joins and farming gameplay completion remain outstanding; this local predicate
is not a whole codec, and acceptance here is not publication.

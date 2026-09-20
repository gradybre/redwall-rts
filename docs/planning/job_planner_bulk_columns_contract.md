# Exact planner capture, restore and section8 adapters

SAVE-J2-R02 · version2 accepted for bounded implementation · 2026-09-19 · Astra

Implement the remaining J2 owner boundary and connect the existing section8 codec.
SAVE-J2-R01's format is already integrated:35 fields, owner/section schema2,
primary8192,383884 canonical value bytes,384164 payload and384203 section bytes.
No schema, ordinal, type, extent, canonical registry version or fingerprint change.
This is one owner's exact restore, not a whole-world save coordinator.

## Shared layout and compatibility

Add `godot/scripts/core/job_index_schema.gd` containing the existing codec's pure
layout constants, Record and record_refusal with its structural validators.
`save_section_job_indexes.gd` extends this shared script and retains its byte
codec/framing, EncodeResult and public adapter functions. Godot4.7.2 probes already
confirm inherited constants, static validators, nested types and Codec.Record.new()
resolve and interoperate. Existing public API names remain available. Do not add
a planner preload to the helper or any path from helper back to codec/planner.

Move the exact21 planner constants currently required by the codec (including
FIRST_CYCLE), plus STATUS_UNMET so all four status members share one owner to the shared helper and keep backward-compatible owner aliases.
Use the same existing leaf-store capacity expressions and numeric values. Shared
helper may preload EntityDirectory, Farming, Forage, OrchardHive, SaveCodec and SaveHeader;
these dependencies must be checked for cycles. All four STATUS members move
together, as do both farm operation values/count. Domain counts REASON_COUNT,
BLOCKER_COUNT and HIVE_BLOCKER_COUNT retain their existing numbers and owner
assertions tie them to their final ordinal+1. Owner's public names do not vanish.
Tests compare helper/owner/registry values and existing golden encoded bytes.
No interpretation of a field changes merely because its validator moves.

Strengthen the shared shape gate to reject a null record, wrong typed-group
lengths (8u8,25i32,2i64), then wrong column extents before indexing. Use existing
SAVE_JOB_RECORD_SHAPE diagnostic. No out-of-range exception replaces a refusal.
Expose `shape_refusal(record:Record)->SaveHeader.Refusal` for output-only shape
validation; `record_refusal` delegates before its existing semantic checks.
Record.copy_from remains a low-level operation on correct shapes; public APIs
validate output shape first. Success replaces each output buffer with a copy;
no preserved-buffer-identity promise exists. Inputs/outputs must not alias owner
arrays; exports and restores both duplicate, and tests mutate them afterwards.

## Owner API

JobPlanner preloads the shared helper as JobIndexSchema and publishes:
- copy_job_index_columns_into(out:JobIndexSchema.Record)->bool
- restore_job_index_columns(columns:JobIndexSchema.Record)->bool
- last_column_refusal()->StringName
- state_bytes()->PackedByteArray (diagnostic, cold, not a production tick call)

New owner diagnostic scalar `_last_column_refusal` is category3 and not canonical.
Success clears it. Failure changes only this scalar; no owner array, derived
counter, history, operational diagnostic, collaborator or scratch changes.
Owner codes:
COLUMN_JOB_INDEX_SHAPE (target shape/null),
COLUMN_JOB_INDEX_RECORD (domain/table/list validation),
COLUMN_JOB_INDEX_REFERENCE (a resolving reference contradicts its expected kind
or owner row). Preserve the shared validator's exact code/detail in codec-facing
validation before invoking the owner; owner bool reader's code identifies stage.

Capture validates output shape first, validates all3live dirty counts in their
native i64 range before narrowing to extent1i32 (out-of-range refuses
COLUMN_JOB_INDEX_RECORD), then stages exact copies of all
35fields (including free rows/history). Validate the staged record and reference
rules below before replacing output buffers. No public gameplay getter may
synthesize inaccessible bytes; no other module reads the owner's private fields.
Before capture publication also verify source derived invariants: each membership
byte is0/1, exactly saved_count bits are1, and every saved prefix entry is1;
each of the8derived counters equals its status/enablement count. Mismatches refuse
COLUMN_JOB_INDEX_RECORD. No normalization, stale-row dropping, sorting or repair.

Restore validates the full input record and reference rules before the first
owner write. Install all arrays as independent copies and3exact scalar counts.
Rebuild only `_is_dirty`, `_is_zone_dirty`, `_is_hive_dirty`: zero then mark saved
prefix entries; never mark_all_* or call mark_* operations. Derive8counters from
status/enablement arrays: pending,unmet,requested; demand_enabled,pending,unmet;
hive_pending,unmet. These are category2 (some guard midnight settlement), not
outcome diagnostics. Correct the registry's broad category3 row accordingly.
The three persisted dirty counts remain category1, despite the audit's accidental
inclusion in its category2 list.

Reset exactly the21non-derivable outcome diagnostics listed in the feasibility
audit (the existing _reset_counters implementation is the source of the list),
including _last_blocker and _dropped_on_load_count. This is a fresh observation
session after load; none decides future simulation. Do not persist new diagnostic
fields. Existing `_math` and `_calendar` scratch may remain unchanged.
Do not call clear(), revalidate_after_load(), any reconcile/service/claim operation,
a collaborator mutator, or publish a signal. No jobs, IDs, claims, goods or work
are created/consumed by either copy or restore.

state_bytes is a diagnostic format, not the canonical wire image. It records the
35fields in ordinal order: each packed array as u32length then raw array bytes;
canonical scalar counts as signed i64 so an injected out-of-range native count
is not truncated. Then3membership arrays in farm/zone/hive order with u32length;
then8derived counters in the order above as i64; then21diagnostics in exact
_reset_counters assignment order, each int as i64, _last_blocker as u32UTF8length
then UTF8bytes. Integers are little-endian (Godot target byte-order guard retained).
It excludes _last_column_refusal and borrowed objects/scratch. It never normalizes
or mutates. Tests separately inspect math/
calendar scratch and collaborator bytes on refusal. For successful round trips,
compare canonical record bytes; diagnostics intentionally begin a new session.

## References and load ordering

Stale historical references are legal: the actual stale_job_probe reproduces a
pending row with an out-of-band destroyed Job; current structural validation
accepts it, and the next normal reconcile creates a new generation exactly once.
Preserve these bytes. Do not make restore repair them early or refuse solely
because Directory.is_valid(ref) is false. This applies to farm/zone/hive owners
and pending Job references, including references retained by disabled zones.

For a NONNULL reference that DOES resolve in the bound directory:
- service owner must be KIND_FARM_PLOT with typed row floor(service_row/OPERATION_COUNT);
- retained zone owner must be KIND_HARVEST_ZONE with typed row zone_row;
- hive owner must be KIND_HIVE with typed row hive_row;
- pending job must be KIND_JOB. A completed/cancelled job is still permitted.
Use pure Directory queries. Do not query present-state operational gates or
require a fresh service to be executable during load. Strict row shape/nullness
remains the shared schema's responsibility. Cross-checking forage claims and Job
requester/target semantics remains the full coordinator's explicit obligation;
this owner API does not certify those other owners. No arbitrary callbacks.

Directory and Jobs/Farming/Forage/OrchardHive must be restored before this owner
and belong to the same bound world. Existing construction asserts shared bindings.
The owner cannot distinguish not-yet-loaded collaborators from legitimate stale
references; do not claim it can enforce restore order from the columns alone.
The full coordinator owns that prerequisite and may not publish a partial world.

## Codec adapter and barrier

capture_into(store,out) refuses null store or output, then delegates the real
owner capture. capture_record_into validates both input and target shape; malformed
outputs never crash or partially copy. production_write_refusal() returns success
for section8 only after this integration's tests; it is not release_save_ready.

apply(record,store,clock:SimClock=null) preserves the existing2argument call shape
but requires a real supplied clock with is_load_barrier_held() before mutation.
Exact order: null record (SHAPE), null store, null clock, lowered barrier,
then shared record validation and owner validation.
New codec diagnostics SAVE_JOB_NULL_STORE, SAVE_JOB_NULL_CLOCK,
SAVE_JOB_BARRIER_NOT_HELD (null record uses SAVE_JOB_RECORD_SHAPE). A2argument
legacy call now explicitly refuses missingclock. The caller owns clock/world
association, as in save_identity_restore.gd. Never acquire/release the barrier,
change pause/tick, or claim whole-world rollback. Refused apply leaves owner and
input record unchanged. No existing test may be weakened to hide schema drift.

## Budget and tests

Record383884B, dirty validation scratch4096B, owner membership existing5248B.
Capture can stage one record plus duplicated publication; restore duplicates
existing arrays after validation. Account actual peak packed buffers including
record constructor copies and largest-column overlap before claiming a budget.
No permanent new packed owner array or second simulation world is permitted.
No latency or RSS qualification inferred from arithmetic.

Required: existing codec/planner suites unchanged except former explicit-J2 tests
updated to actual capture/apply+barrier refusals. Independently pin all35ordinals,
zero/free/history rows, type/shape/group-length failures, listorder/counts/tails,
allstatus-derivedcounters and diagnosticreset. Actual simultaneous farm/sow/
forage/hive activity snapshots and stale refs round-trip exact. Reject wrong-kind
and wrong-typed-row resolving refs with unchanged owner/input. Dirty order [0,1]
versus [1,0] must reproduce distinct subsequent job IDs after restore; empty saved
membership must not become all dirty. Mutate caller input/output after success to
prove no alias with owner; reuse malformed/aliased records without partial writes.
Capture->encode->decode->apply->capture canonical parity plus matching next normal
reconcile proves this owner boundary. No release-save or first-playable claim.
Independent contract/source reviews, focused/full suite, static gates and import
precede merge. Full SAVE-CAPTURE remains blocked on its other owners/coordinator.

## V2 review disposition incorporated

Keep public REFUSE_STORE_NO_COLUMN_API as a deprecated compatibility constant;
no production path returns it after acceptance. Remove old blocker explanations
from live docstrings. Existing2argument apply calls now refuse NULL_CLOCK before
semantic malformed-record checks; keep those semantic assertions with a supplied
barrier-held clock, plus explicit new precedence regressions. Null record precedes
all other missing participants. All decoder output Records must also be shape
validated before publication, after preamble/extent guards, to avoid malformed
target crashes; keep input refusal precedence explicit in tests.

Shared helper leaf preload closure was checked across19existing modules with no
planner or codec reached (helper-dependency-census.json); recheck the actual new
source graph and import before merge. Tail-zero was independently confirmed in
all3pop methods and clear. Explicit duplicate remains required: actual4.7.2
class-field alias probe contradicts review F8's claim of universally safe plain
assignment. Probes reading private fields remain test/evidence-only.

Record arithmetic is not a full capture/encode peak claim. As an illustrative
conservative accounting scenario, two retained records + twice payload bytes +
32768B column conversion +4096B validator scratch totals1572960B; actual retained
outputs, section/header buffers and engine allocation growth must also be counted.
No strict bound, latency, RSS or measured pipeline peak is asserted from this sum.
Owner-copy tests measure record arrays; full pipeline profiling remains a distinct
qualification obligation. Do not alter the codec format to optimize this estimate.

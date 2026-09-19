# Preserve the planner's dirty work lists across saves

SAVE-J2-R01 · version 2 · 2026-09-19 · Astra accepted engineering contract after independent review disposition

The existing classification is disproved by runtime evidence. Three planners
with identical 362880-byte projections of the 29 declared section-8 columns,
identical directory/farm state and the same tick produce different jobs solely
because the excluded dirty lists differ. Marks [0,1] produce plot job IDs [4,3];
marks [1,0] produce [3,4]; no marks produce [3,0] at tick600. The independent
probe and log are in `docs/validation/evidence/planner-save-contract-2026-09-19/`.
This is source/runtime evidence, not a full-world round-trip or hash proof.

`_pop_dirty`, `_pop_dirty_zone` and `_pop_dirty_hive` are LIFO. Dirty membership
controls whether an owner runs now or at its staggered sweep. Both order and
membership can affect identity allocation and later outcomes. Marking everything
dirty on load cannot preserve continuation. Sorting the same membership on load
also cannot preserve it. Do not change normal scheduling to disguise missing state.

## Representation and classification

Retain the exact LIFO arrays and counts. Promote the three arrays and their three
counts to canonical category1. Keep membership-bit arrays category2: they are
reconstructed exactly from the saved prefix, not by marking live owners. No new
runtime packed arrays or scalar fields are required. Existing diagnostic outcome
counters remain category3. Correct the codec comment that currently calls all
counters category2; the registry already distinguishes diagnostics.

Append these fields after the existing29 ordinals, without renumbering those29:

| Ordinal | Member | Canonical type | Count | Bytes |
|---:|---|---|---:|---:|
|29|_dirty_rows|i32/code2|4096|16384|
|30|_dirty_count|i32/code2, scalar|1|4|
|31|_dirty_zone_rows|i32/code2|128|512|
|32|_dirty_zone_count|i32/code2, scalar|1|4|
|33|_dirty_hive_rows|i32/code2|1024|4096|
|34|_dirty_hive_count|i32/code2, scalar|1|4|

Arrays keep their current extents. Count must be0..extent. Prefix [0,count) holds
unique typed row indices in0..extent−1, in current push order (last is next pop).
Unused [count,extent) is canonically0. Empty typed rows may be queued: destroying
an owner legitimately dirties it to retire prior service records. Do not require
queued rows to name a currently living entity. Membership bits exactly equal the
set of prefix entries, with all other bits0.

The existing clear/construct path already zeroes arrays. Each pop must read its
row, zero the popped cell, clear membership and return the row. An idempotent mark
must retain original position; duplicate marks do not move an entry. A later
remark after pop pushes once at the new tail. All three queues follow the same
rule. This erases only formerly irrelevant stale tail bytes; it changes no live
order, budgets, jobs, ordinary counters or lookup semantics.

## Wire and declarations

Advance `job_planner` owner schema1→2 and section8 schema1→2. Outer format2 remains.
Registry version4→5, retaining the opaque registry_id namespace. Append6canonical
records, of which3are newly classified packed fields. Expected registry totals:
610listed,602canonical,553persistedpacked; the full source artifact has604listed
(sum of owner fields),596canonical and550persistedpacked before this change.
The supplied review excerpt omitted the604baseline; parent verified the complete
artifact. Add explicit registry rows for thethreecountscalars as well as
reclassifying thethreearrays; rewrite allsixarray/membershipnotes.
No new owner and no reordered owner key. Generate the canonical declaration table
and capacity sidecar with repository tools, never edit generated regions by hand.

Canonical values:362880+21004=383884bytes. With35element-count words, payload is
383884+35×8=384164bytes. Existing39byte owner-wrapper prefix yields section length
384203bytes. Primary count remains8192 for the pending-service table. The new three
counts are scalar fields represented onwire as extent-1 i32columns, each with its
own8byte element-count prefix. They are not bare scalar words or newprimary-count
interpretations. FIELD_STORAGE appends i32groupindices19..24; allsixnewfields enter
NON_NEGATIVE_FIELDS, none enters SLOT_FIELDS (typedrowsarenotdirectoryslots).
All values use existing signedi32 encoding; negative counts or indices refuse.

Record scratch grows21004bytes. Two simultaneous full Records (caller plus staged
decode) grow42008bytes before object/array overhead. This is not new permanent
simulation payload and does not prove the full-world load peak fits its budget.
The implementation must inventory any additional seen-bit scratch. A single local
seen-byte scratch derived from max(OWNER_ROWS,ZONE_ROWS,HIVE_ROWS), currently
4096bytes, reused and cleared across allthreequeue validations is sufficient; it must
not become an unclassified permanent column. Avoid a dictionary per queue.

Old owner schema1 refuses explicitly. There is no migration that guesses dirty
membership/order, clears the pending lists or marks everything dirty. Preserve
caller Record/output bytes on malformed or unsupported input. Known-section
version dispatch must happen at the wrapper schema before interpreting the larger
column body, so an old valid-length section receives an unsupported-schema refusal
rather than being mistaken for a truncated new body where the preamble is readable.

## Validation and live-adapter boundary

Extend the existing section validator with count/prefix/tail/uniqueness checks
for allthreequeues. Keep all29original rules. Pure structural codec checks do not
claim references point into a live decoded world. The forthcoming bulk planner API
must validate the full columns plus cross-owner identities, then restore arrays,
counts and rebuild only membership bits; it must never call mark_all_*_dirty().

The existing `revalidate_after_load()` operational repair can drop stale pending
service jobs and is separately authorized by old rulings. It is not a strict
release-save validator and must not be called invisibly from canonical restore.
Its relationship to full-file cross-reference validation remains a separately
named SAVE-COLUMNS-JOBPLANNER contract decision, before that adapter is implemented.
This format repair alone does not close J2 or supply capture_into/apply.

## Required tests and acceptance

1. Pin the35field ordinals/types/extents and exact384203section bytes independently;
   preserve old29field values and8192primarycount. Valid schema2 byte round-trip.
2. Full prefix, empty prefix, row0, highestindex, and each3queue type. Reject negative/
   over-cap counts, negative/out-of-cap indices, duplicateprefix, nonzerotail; refusal
   preserves predirtied Record and output. Oldschema1 explicitly refused.
3. Real planner marks in both orders and clean/partialdrain/remark paths; the same
   preexisting live order and produced jobs remain. Popped tail is zero for all3
   queues, including pop ofrow0. No new jobs or counter changes from capture.
4. Canonical emission distinguishes reversed order and different membership using
   the production compiled fields, rather than hashing an unrelated test buffer.
5. Retain the source probe as the failing old-contract counterexample, then add an
   exact projection fixture showing the revised declared image separates its cases.
6. Full suite,15static checks, editorimport, independent source review and exact-head
   CI before merge. Source/worker/patch/evidence hashes retained. No assertion that
   this supplies a complete save, first playable, native art or Windows validation.

## Version2 schema dispatch and precise API contract

Keep `decode_section_into(bytes, offset, out)` as a standalone known-current-schema
codec entry. Add `decode_section_with_schema_into(bytes, offset, section_schema_version,
out)` for a caller with an actual descriptor. The former delegates with the compiled
SECTION_SCHEMA_VERSION=2; it does not claim to have validated an unseen descriptor.
Full-file orchestration MUST use the latter with the same file's descriptor value.

Before new-body extent checks or Record allocation, validate offset and a complete
23byte minimum preamble, then storecount, exact ownerkey and wrapperownerschema.
Owner schema unsupported returns existing SAVE_JOB_OWNER_SCHEMA_VERSION. Only after
a valid ownerschema2, reject section_schema_version!=2 with new
SAVE_JOB_SECTION_SCHEMA_VERSION. Thus pair(1,2) refuses owner, pair(2,1) refuses
section, pair(1,1) refuses owner; notationhereis(owner,section). Any non2version
including0/future follows thisorder. A short preamble refusesTRUNCATED, a negative
offset NEGATIVE_OFFSET. After bothschemaspass, run existing full extent/framing/
primary/payload checks, then decode/validate into a local Record and publish once.
There is no preload dependency on a new module and no defaulting from actualunknown
descriptor values. SaveHeader continues generic descriptor framing; no whole-file
version-dispatch claim is introduced by this helper.

Dirty validator order follows existing shape/domain/service/demand/hive checks,
then farm/zone/hive queues in thatorder. Allnegative values retain the existing
NEGATIVE_VALUE refusal. Above-cap counts use SAVE_JOB_DIRTY_COUNT; prefix index
>=extent uses SAVE_JOB_DIRTY_INDEX; repeatedprefixentry uses SAVE_JOB_DIRTY_DUPLICATE;
nonzero unusedtail uses SAVE_JOB_DIRTY_TAIL. Countisthesoleprefixboundary, so one
queuedrow0 and anemptyqueue differ in count and both are valid. No membershipbit
columns are serialized. Scratchallocation is cold-path, function-local and bounded.

The old projection probe remains unchanged as historical evidence with its source
SHA. The new projection comparison must use the same method over revised FIELD_KEYS,
including scalarcounts as one-elementi32columns, and separately test actual production
canonical-field emission. Zeroing poppedtails is the sole live scheduling-code
change. Capture/apply remain explicit J2refusals until the separate bulk API packet.

# Independent contract review: SAVE-J2-R02 version 1

2026-09-19 - reviewer packet, docs only. No source edited, nothing executed, no
suite run. Every number below was recomputed from the supplied sources.

## Verdict

Approve with fixes. No contradiction blocks implementation. Nine findings, none
requiring a decision outside this packet. The contract correctly refuses to
become a whole-world coordinator, and that restraint is not treated here as a
gap.

## Independently verified

**Constant count is exactly 21 plus STATUS_UNMET.** Enumerating every
`JobPlannerScript.` reference in `save_section_job_indexes.gd`: SERVICE_ROW_COUNT,
OWNER_CAPACITY, ZONE_OWNER_CAPACITY, DEMAND_ROW_COUNT, HIVE_OWNER_CAPACITY,
OPERATION_COUNT, OPERATION_FARM_TEND, OPERATION_FARM_SOW, PATCH_KIND_COUNT,
STATUS_FREE, STATUS_PENDING, STATUS_REQUESTED, STATUS_COUNT, REASON_COUNT,
BLOCKER_COUNT, HIVE_BLOCKER_COUNT, NO_DAY, NO_CYCLE, NO_CROP, MAX_FIELD_CYCLE,
and FIRST_CYCLE (used only inside `_sow_cycle_refusal`). That is 21. STATUS_UNMET
is the fourth status member and is not currently referenced by the codec, so the
contract's stated reason for moving it - keeping all four members with one owner -
is the only justification, and it is sufficient.

**Typed-group lengths 8 / 25 / 2 are right.** FIELD_TYPES yields u8 at ordinals
6, 7, 10, 13, 16, 17, 27, 28 (8), i64 at 20 and 26 (2), i32 for the remaining 25.
The shape gate's group-length check is therefore well defined and is a genuinely
stronger gate than the existing per-column `column_size` loop, which indexes
`FIELD_STORAGE` and would fault on a short group before it could refuse.

**Eight derived counters, and they really are derivable.** `_pending_count`,
`_unmet_count`, `_requested_count` from `_status`; `_demand_enabled_count` from
`_demand_enabled`; `_demand_pending_count`, `_demand_unmet_count` from
`_demand_status`; `_hive_pending_count`, `_hive_unmet_count` from `_hive_status`.

**Exactly 21 reset diagnostics.** `_reset_counters()` assigns 21 members, and the
list does include `_last_blocker` and `_dropped_on_load_count` as the contract
claims. Cross-check: the owner declares 29 counter members; 21 + 8 = 29. The three
dirty counts are separate members and are persisted as fields 30, 32, 34, so the
contract is right that they are canonical and that the audit mislabelled them.

**Byte arithmetic is exact.** Summing FIELD_WIDTHS x FIELD_EXTENTS by table:
service i32 262144, service u8 24576, owner i32 32768, dirty_rows 16384, zone u8
128, zone i32 1024, dirty_zone_rows 512, demand u8 1280, demand i32 5120, demand
i64 5120, hive i32 20480, hive i64 8192, hive u8 2048, dirty_hive_rows 4096, three
scalars 12 = **383884**. Plus 35 x 8 count prefixes = **384164**; plus 39 framing
= **384203**. The membership figure is also right: 4096 + 128 + 1024 = **5248**.
The scratch figure is right: `maxi(4096, maxi(128, 1024))` = **4096**.

**Stale-reference policy is evidenced, not asserted.** `stale_job_probe.log`
shows `pending=1 ref=(1,1) resolves=false structural_refusal=` (empty) and then
`natural_reconcile_new_ref=(1,2) pending=1`. That is the exact claim: current
structural validation accepts an unresolvable pending Job reference, and the next
normal reconcile creates one new generation. The disposition's refusal to reuse
the audit's `retire_service` anecdote is correct discipline.

**Tail-zero will not cause spurious capture refusals.** `_pop_dirty`,
`_pop_dirty_zone` and `_pop_dirty_hive` each write 0 back into the vacated stack
slot, and `clear()` fills the arrays with 0, so the live tail is already zero.
The staged record therefore satisfies `_dirty_lists_refusal`'s tail rule without
normalisation - which matters, because the contract forbids normalisation.

## Findings

**F1 (must fix, missing interface).** Capture validates the three live dirty
counts in i64 before narrowing to i32, but the contract assigns no refusal code to
that failure. COLUMN_JOB_INDEX_SHAPE is defined as target shape or null, and this
is neither. Specify COLUMN_JOB_INDEX_RECORD, and pin it with a test that drives a
count outside i32 through a test subclass.

**F2 (must fix, ordering ambiguity).** `apply` lists missing participants before
the barrier, then the shared record - but also says a null record uses
SAVE_JOB_RECORD_SHAPE. Those two sentences disagree about whether a null record
precedes or follows the barrier check. `save_identity_restore.gd` settles it by
precedent: null record, null store, null clock, barrier, then record validation.
Adopt that order verbatim and pin it: a null record with a lowered barrier must
return SAVE_JOB_RECORD_SHAPE, not SAVE_JOB_BARRIER_NOT_HELD.

**F3 (must fix, missing interface).** `state_bytes()` has no defined field order
and no encoding for `_last_blocker`, which is a StringName rather than an int. The
contract makes tests compare these bytes, so the order and the string encoding are
wire-like even though they are not saved. Specify: the 35 canonical columns in
ordinal order, then the three membership arrays, then the 8 derived counters, then
the 21 diagnostics, with each StringName written as u32 UTF-8 length plus bytes.

**F4 (must check before merge, cycle risk).** The contract asserts the helper's
preloads must be checked for cycles but supplies no evidence. The codec already
depends on EntityDirectory, Farming and SaveHeader transitively, but the helper's
edges to Forage and OrchardHive are new as direct edges. Record a static import
probe showing none of entity_directory.gd, farming.gd, forage.gd, orchard_hive.gd
or save_header.gd preloads the helper, the codec or the planner. D4's position -
that no deliberately cyclic preload need be tested because the implementation must
have none - is acceptable only if that one-directional check is actually produced.

**F5 (overclaim, budget).** The budget accounts records and scratch but not the
encode buffer. `encode_payload` builds a PackedByteArray by repeated
`append_array` with no reservation, so a capture-then-encode sequence peaks near
two live records (2 x 383884) plus a reallocating payload buffer approaching
2 x 384164, plus per-column `column_bytes` duplicates up to 32768 and the 4096
seen array - roughly 1.5 MiB transient, not the ~0.8 MiB the record arithmetic
alone implies. State that figure, or reserve the buffer. Either way the contract's
refusal to infer latency or RSS from arithmetic is correct and should stand.

**F6 (must decide, dead constant).** Once capture/apply delegate,
REFUSE_STORE_NO_COLUMN_API is referenced only by `production_write_refusal()`,
whose text must also change. Decide explicitly whether the constant is retained
for the production gate or retired; it is not a wire value, so either is safe, but
an unreferenced refusal constant is exactly the kind of dead guard this codebase
has been bitten by.

**F7 (test impact, precedence change).** Existing tests that call the 2-argument
`apply` with a malformed record currently receive a record refusal, because today
`apply` validates the record first. Under the new order they receive
SAVE_JOB_NULL_CLOCK. The contract permits updating former explicit-J2 tests; make
that specific case an enumerated update rather than a discovery during merge, so
the change is visibly a precedence change and not weakened schema coverage.

**F8 (clarify, aliasing).** GDScript packed arrays are copy-on-write, so plain
assignment from owner columns into a staged record is already non-aliasing in
observable behaviour. The contract's duplicate-on-both-sides rule is still the
right instruction, but the reason should be stated as explicitness rather than
correctness, and the mutate-after-success tests remain necessary precisely because
copy-on-write makes the wrong implementation look correct until something writes.

**F9 (minor, evidence hygiene).** `stale_job_probe.gd` builds its record by
reading private fields through `planner.get(...)`. That is legitimate for a probe
and is exactly the access the contract forbids in production, but the review file
for the implementation should say so, so the probe is never cited as a precedent
for a public reader.

## Accepted without change

Owner-atomic restore (validate everything, including reference rules, before the
first owner write), the prohibition on mutating collaborators or publishing
signals, the refusal to repair stale references, the wrong-kind and wrong-typed-row
rules for references that do resolve, the category-2 reclassification of the 8
derived counters with no wire change, the dirty-order [0,1] versus [1,0] test, the
empty-saved-membership test, and the explicit statement that full SAVE-CAPTURE
remains blocked. No release-save or first-playable claim appears anywhere in the
contract, and none should be added by this packet.

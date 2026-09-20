# Independent source review — SAVE-J2-R02v2 planner column persistence

2026-09-19 · independent reviewer · authoritative contract: SAVE-J2-R02v2
(`docs/planning/job_planner_bulk_columns_contract.md`, sha 455cb9aa…), decision 0160.
Scope: the owner block appended to `job_planner.gd`, the shared
`job_index_schema.gd`, the section 8 adapters in `save_section_job_indexes.gd`,
and the two focused suites. Author of the implementation was a separate session.
No tools were available: every statement below is derived from the supplied text
by hand, and anything I could not derive is listed as unverifiable rather than
asserted. No source was edited.

**Verdict: accept with findings.** I found no defect that corrupts owner state,
breaks atomicity, aliases a buffer, or changes the wire format. Eight findings
are recorded; two are worth fixing before merge because they weaken the evidence
rather than the code.

## 1. What I independently recomputed and confirm

**The 35-field declaration is internally consistent.** I walked `FIELD_KEYS`,
`FIELD_TYPES`, `FIELD_WIDTHS`, `FIELD_EXTENTS`, `FIELD_UNUSED` and
`FIELD_STORAGE` ordinal by ordinal. All six tables hold 35 entries; every width
matches its type code; every declared unused value matches the owner column it
names (ordinals 14/18/21/24 are `NULL_SLOT`, 15/19/22/25 are `NULL_GENERATION`,
23 is `NO_DAY`, 9 is `NO_CROP`, 29–34 are 0). The storage indices partition
cleanly into 0–7 (u8), 0–24 (i32), 0–1 (i64), and the eight u8 ordinals
6/7/10/13/16/17/27/28 map to 0–7 in that order, so no two fields share a slot and
none is unreachable.

**The byte totals are correct.** Summing widths × extents: 35 B/row × 8192 =
286720; 8 × 4096 = 32768; 9 × 128 = 1152; 18 × 640 = 11520; 30 × 1024 = 30720;
plus 16384 + 4 + 512 + 4 + 4096 + 4 for ordinals 29–34. Total **383884** value
bytes, **384164** payload (+35×8 element counts), **384203** section (+39
framing). These are the contract's numbers, so the canonical value image and the
section length are preserved by the schema extraction.

**The pinned wrapper decodes correctly.** `01000000` store_count 1; `0b000000`
key length 11; `6a6f625f706c616e6e6572` is exactly `job_planner`; `02000000`
owner schema 2; `0020000000000000` is 8192 LE at byte 23; `a4dc050000000000` is
0x05dca4 = 384164 at byte 31. The literal offsets 23/31/39 and the module's
`OFFSET_*` constants are asserted separately, which is the right shape for a wire
pin.

**Copy ordering and completeness.** `_stage_service_columns` … `_stage_dirty_columns`
cover ordinals 0–10, 11–12, 13–20, 21–28, 29–34 in declared order with no field
omitted or repeated, and `_install_*` mirrors them. Types match on both sides
(20 and 26 are the only i64 moves; the eight u8 moves are the eight u8 ordinals).
Free rows, retained history (`_serviced_day`, `_cycle_cursor`, `_completed_cycle`,
blocker bytes, hive feed demand) and the dirty tails are copied verbatim; nothing
normalizes, sorts, drops or repairs.

**Refusal ordering matches the contract.** Capture: target shape (null accepted
and refused) → three live dirty counts in native range before any narrowing into
the extent-1 i32 columns → stage → shared `record_refusal` → source membership
and derived-counter invariants → resolving-reference rules → publish. Restore:
shape → shared record → reference rules → derived-buffer shape → install → rebuild
bits → derive 8 counters → reset 21 diagnostics. Codec `apply`: null record
(SHAPE) → null store → null clock → lowered barrier → shared record → owner.
`capture_into` refuses a null store, then a malformed target. Decoder validates
preamble and extent first, then the target record's shape before publication, and
refuses a null target without dereferencing it.

**Atomicity, including the case the contract singles out.** The trap here is a
malformed source shape reaching membership indexing. Two guards hold it:
`_source_invariants_hold()` calls `_membership_shapes_are_valid()` before
`_membership_agrees()`, and — more subtly — `FIELD_DIRTY_ROWS`,
`FIELD_DIRTY_COUNT` and their zone/hive twins are in `NON_NEGATIVE_FIELDS`, so
`_domain_refusal` refuses a negative row or count before `_dirty_lists_refusal`
evaluates `seen[row]`. Without that membership the packed-array index would abort
rather than refuse. `_dirty_lists_refusal`'s own upper bound (`row >= rows.size()`,
`count > rows.size()`) closes the other end, and the 4096-byte `seen` scratch is
sized by `maxi` over the three capacities, so the zone and hive passes cannot run
off it. On every refusal path the only write is `_last_column_refusal`.

**No aliasing.** Every staged column is `.duplicate()`d out of the owner, `out.copy_from`
duplicates again on publication, and every installed column is `.duplicate()`d out
of the record. The membership bitsets are rebuilt in place and never taken from
the caller, so array identity and extents survive `_allocate_columns()`'s
allocate-once rule. No permanent new packed owner array is introduced.

**References.** Stale references are preserved: `_reference_is_legal` returns true
for `NULL_SLOT` and for any reference `Directory.is_valid()` rejects, and only
constrains kind and typed row when the reference resolves — farm plot at
`row / OPERATION_COUNT` (non-negative, so floor and truncation agree), harvest
zone at `zone_row`, hive at `hive_row`, Job unconstrained by row. Retained
references on disabled zones pass through the same rule and are not singled out.
Nothing queries an operational gate.

**Restore side effects.** `restore_job_index_columns` touches no collaborator
store other than read-only `Directory.is_valid*`, calls no `mark_*`, `clear()`,
`revalidate_after_load()`, reconcile, service or claim operation, and emits no
signal. The 21 diagnostics reset are exactly `_reset_counters`'s assignment list
(I counted them: 21, including `_last_blocker` and `_dropped_on_load_count`), and
the 8 derived counters are rebuilt in the contract's order.

**Shared schema, no cycle.** Across the three supplied files: the schema preloads
no planner and no codec; the codec extends the schema and preloads the planner;
the planner preloads only the schema. That graph is acyclic. All 22 moved
constants (21 plus `STATUS_UNMET`) are re-exported as owner aliases, including
`FIRST_CYCLE`, `MAX_FIELD_CYCLE`, `NO_CROP` and the three domain counts, and the
owner assertions tie each count to its final ordinal + 1.

**Budget arithmetic.** 2 × 383884 + 2 × 384164 + 32768 + 4096 = 1572960, so the
contract's illustrative figure reproduces. It is explicitly not a measured peak;
I make no latency or RSS claim, and none is derivable from this packet.

## 2. Findings

**F1 — capture-path reference validation is untested (moderate).**
`_record_references_are_legal(staged)` inside `copy_job_index_columns_into` has
no covering case: `test_resolving_wrong_kind_and_wrong_owner_row_refuse` mutates
the record and exercises restore only. Reproduction: delete that call from
`copy_job_index_columns_into` — both suites stay green. Correction: one case that
writes a live hive's `(slot, generation)` into `_owner_slot`/`_owner_generation`
at row 0 via the existing private-field probe and asserts capture refuses
`COLUMN_JOB_INDEX_REFERENCE` with output and source bytes unchanged.

**F2 — `state_bytes()` member coverage is unpinned (moderate).** The image is the
instrument both suites use to prove a refusal changed nothing, but nothing
asserts which members it covers. Reproduction: delete
`_append_u8_column(image, _gate_reason)` — both suites stay green, and every
subsequent "owner unchanged" assertion becomes blind to `_gate_reason`.
Correction: extend the existing `_fields()` reflection helper into a test that
perturbs each script variable except `_last_column_refusal` and the borrowed
objects and asserts `state_bytes()` changes for each.

**F3 — `state_bytes()` field order is unverified (low).** The contract specifies
"Format v2, exactly". Only the diagnostic *census* is pinned, by source parsing;
the order of the 35 fields, 3 membership arrays, 8 counters and 21 diagnostics in
the image is self-consistent and never decoded. Swapping two `_append_i64` calls
is an unkillable mutant. Correction: set the 21 diagnostics to distinct values
and decode the trailing i64 run against `_reset_counters` order. Functional risk
is low — the image is diagnostic only and comparisons are order-symmetric — so
this is secondary to F2.

**F4 — one vacuous assertion (low).** In
`test_stale_job_reference_survives_roundtrip_and_reconciles_normally`,
`assert_equal(_planner.dropped_on_load_count(), 0, "no repair occurred")` cannot
fail: `_reset_counters()` zeroes that counter in the same call. The genuine
no-repair proof in that test is `after.equals(_record)` canonical parity, which is
present and sufficient. Correction: annotate or drop the counter assertion so the
evidence is not read as stronger than it is.

**F5 — stale owner diagnostic after a codec-stage refusal (low).** `Section.apply`
and `capture_into` refuse NULL_STORE, NULL_CLOCK, BARRIER_NOT_HELD and shared
record failures without touching `store.last_column_refusal()`, which may still
hold a code from an earlier owner-stage refusal. Correct behaviour — a codec
refusal is not a bulk column call — but a caller that reads the owner scalar
instead of the returned `Refusal` will be misled. Correction: one docstring
sentence on `apply` directing callers to the returned refusal.

**F6 — untested precedence in `capture_record_into` (low).** Input is validated
before target, which is a defensible choice, but V2 asked for explicit precedence
regressions and the both-malformed case is not covered.

**F7 — a gate that cannot fail (informational).** `production_write_refusal()`
returns success unconditionally; nothing structurally ties it to this
integration's test result. This is the same hazard the codec's own
`encode_section` comment names about guards that cannot fire. Recorded, not a
change request.

**F8 — ordering dependency worth recording (informational).**
`_reference_is_legal` accepts `slot == NULL_SLOT` without inspecting the
generation half; a half-null pair is caught only by `_pair_is_shaped` inside
`record_refusal`, which both entry points run first. Correct as written; the
dependency should not be inverted by a later edit.

## 3. Not verifiable from this packet

Stated so they are not mistaken for cleared: (a) the leaf preload closure —
`save_codec`, `save_header`, `entity_directory`, `farming`, `forage`,
`orchard_hive` are not supplied, so the census recheck and import remain
outstanding, though no cycle is introducible by the three files here; (b) the
registry category-2/category-1 row corrections; (c) the provenance of the pinned
`46760dad…` empty-section hash as a pre-extraction value — the byte-format
evidence I could verify independently is the arithmetic and the wrapper hex
above; (d) the full-suite result. The focused log records 256 tests, 3369
assertions, 0 failures across four files, which matches the packet.

## 4. Accepted as coordinator obligations

Owner restore order and whole-world consistency; clock/world association (a held
barrier on any clock authorizes the write, as the barrier test demonstrates);
cross-owner forage claim and Job requester/target semantics; disk rollback and
release-save readiness. This review makes no first-playable, release-save,
latency or RSS claim.

# Work component validation — WORK-S4-VALIDATE-R01 v1

Date2026-09-20. Accepted by Astra after independent feasibility, contract review and repair confirmation; ADR0175 authorizes the bounded implementation. This is owner16 local-domain validation, not complete same-file Work/Gear/Jobs acceptance.

## Authority and exact image

GDD sections5.2/5.3/5.7, REQ-SET-020/061, BAL-NUM-001, decisions0017/0110 and the current public writers own the behavior. Remainders survive ticks, task changes and claim release. Retired skill3 remains zero. Memory sum is a signed input, not a bounded need value. A stale current-job comparison is a productive-tick refusal, not permission to rewrite retained saved binding history.

Owner16 `work`, version2, primary512, no child extents, nine fields:

| Ordinal | Field | Type/count | Local domain |
|---|---|---|---|
|0|_potential_remainder|i32/512|0..999|
|1|_xp_remainder|i32/6144|0..999; resident*12+3 exactly0|
|2|_memory_total|i32/512|entire signed int32 range|
|3|_wear_remainder|i32/512|0..9999|
|4|_tool_lot_slot|i32/512|null-1 or0..16383|
|5|_tool_lot_generation|i32/512|null0 orpositive|
|6|_tool_job_slot|i32/512|null-1 or0..8191|
|7|_tool_job_generation|i32/512|null0 orpositive|
|8|_tool_broken|u8/512|0 or1|

Value bytes39424, payload39500, block39528, offset12892567. Fieldbegin280/count9; nextowner17offset12932095. Schema, versions, keys, field order and widths stay unchanged. InventoryLot and Job refs are typed-store handles, NOT EntityDirectory handles. Null means exactly(-1,0), otherwise slot is bounded and generation1..INT32_MAX. Both refs must be null together or nonnull together. Null binding requires broken0; a bound row permits broken0 or1. No resident-present column, absent-row-zero rule, living256 cap, or carry clearing. No local duplicate lot/job rejection: same-file ownership/claim coherence is downstream, not established by this predicate.

## Shared static predicate

Add `static Work.columns_refusal(potential_remainder, xp_remainder, memory_total, wear_remainder, tool_lot_slot, tool_lot_generation, tool_job_slot, tool_job_generation, tool_broken) -> StringName`. First8 explicit PackedInt32Array parameters, final PackedByteArray. Gate order is global: finish checking every row at each gate before proceeding.

1. All nine exact shapes; code `COLUMN_SHAPE` / constant REFUSE_COLUMN_SHAPE.
2. Potential0..WORK_FACTOR_DENOMINATOR-1; COLUMN_POTENTIAL_REMAINDER.
3. All6144 XP0..MILLI_WU_PER_WU-1; COLUMN_XP_REMAINDER.
4. Every reserved skill index3 XP exactly0; COLUMN_RESERVED_XP.
5. Wear0..WEAR_MWU_PER_DURABILITY_POINT-1; COLUMN_WEAR_REMAINDER.
6. Broken byte0..1; COLUMN_BROKEN_FLAG.
7. Every lot ref exact null or slot0..GearScript.LOT_CAPACITY-1 and generation>0; COLUMN_TOOL_LOT_REF.
8. Every Job ref exact null or slot0..GearScript.JOB_CAPACITY-1 and generation>0; COLUMN_TOOL_JOB_REF.
9. Per row both refs null together/non-null together, and null pair requires broken0; COLUMN_TOOL_BINDING.
10. Existing REFUSE_NONE on success.

Constants use REFUSE_ plus each exact code. A private static scalar reference helper may share the null/domain rule; no live collaborator call. Memory has no value gate. Preserve every existing constructor, ordinary method, reader, state_bytes order, carry, diagnostic and tool-count behavior. No bulk API or live predicate wrapper is added in this slice.

All arguments frozen for synchronous read. No owner construction, live lookup, catalog, callback, repair, diagnostic write, file I/O, reflection, default projection, duplicate, sort, new packed scratch or range Array. Use integer-count loops or packed count when suitable; avoid fabricated value restrictions to improve mutant counts.

## Framed bridge

New `save_owner_work.gd` exposes only `static framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal`. Preload Work, Schema, Section and SaveHeader only. No Work/Jobs/Inventory/Gear/Residents/Needs/Directory constructor.

Gates: null -> SAVE_COMPONENT_SHAPE; wrongowner16 -> SAVE_COMPONENT_OWNER; Schema.schema_refusal unchanged; exact owner/field/source metadata -> SAVE_COMPONENT_METADATA; Section.owner_shape_refusal unchanged; nine explicit typed canonical accessors (0..7i32,8u8); raw predicate code. Success emptycode/detail.

Metadata pins key/version2/primary512/nochildren/9fields and every key/type/extent. Source pins Work.RESIDENT_CAPACITY512, SKILL_COUNT12, SKILL_RESERVED_INDEX3, WORK_FACTOR_DENOMINATOR1000, MILLI_WU_PER_WU1000, WEAR_MWU_PER_DURABILITY_POINT10000; Work.GearScript.LOT_CAPACITY16384/JOB_CAPACITY8192, Work.InventoryScript.LOT_CAPACITY16384, Work.JobsScript.JOB_CAPACITY8192, Work.NULL_SLOT-1 and Work.EntityDirectory.NULL_GENERATION0. These constant chains do not construct collaborators. No new const Array/publication-table claim; independent schema generator/source-capacity audit remain required. Source mismatches refuse metadata before column reads.

Metadata prefix exactly `Work owner16 metadata:`; diagnostics distinguish owner counts from specific field key/type/count errors. Raw column detail contains `Work owner 16 ` and exact code, no row identity. One framed39424-byte caller image is already inside stream allowance6417408; no added packed allocation. Native/wrapper overhead unmeasured. Proposed preload closure22nodes contains baseline IntMath/SaveCodec/SaveSectionComponentColumns self-preloads and no new bridge cycle; actual import still required.

## Parent tests and required mutants

Exact layout/default-null success/raw-zero refusal; every9field empty/short/long extent; null/wrong-owner/malformed typed buckets; every512physical-row and6144XP-entry position including row511 and reserved slots; all domain endpoints, signed extrema, malformed null halves and slot limits; mixed bound/unbound references, broken history and paired-null rule. Keep full signed memory endpoints valid on idle physical-tail rows, arbitrary positive/negative values, and retained work/XP/wear when unbound. Every result asserts exact code and complete input nonmutation. Paired faults at different rows prove global precedence.

Actual public runtime probe has217assertions/0: one factor510 tick yields40accepted/800workcarry/40XP/40wear; release retains all carries; memory extrema on physical rows510/511 accepted; job change retains old binding and refuses productive tick; real tool break retains binding. Probe diagnostic has28objects/5resources at shutdown, not a clean teardown claim. Parent regression fixtures may reuse test_work helpers but must use public owner state_bytes/readers, not private production column getters. Existing fulltest_work covers normal historical behavior.

Diagnostic `state_bytes()` puts memory BEFORE XP. Explicitly remap to canonical XP-before-memory; this is equality-test data, not an existing save format. Preserve source bytes/diagnostics/derived tool count (via public bind/release behavior where accessible) across pure static/bridge checks.

Required mutants:8zero accessor substitutions (all except memory); omit each of9value clauses (potential, XP, reservedXP, wear, broken, lotref, jobref, paired-null, unboundbroken); ignore memory extent (direct static wrong-length memory witness, because framed shape checks run first); and3order reversals (shape behind values, reservedXP behind wear, lotref behind jobref). Total21required. Each must fail real assertions with full expected suite count and no parser/script errors; baseline/restored controls pass. The correctly sized memory-zero substitution is semantically equivalent while everyint32 value is allowed; it is excluded, documented and its exact canonical mapping is independently source-reviewed. Source assertions are never described as an executable value-domain kill.

Real-engine metadata faults: ownerkey/version/primary/children/fieldcount/fieldkey/type/extent with8matching bypasses; positivecontrol and unchanged schema forwarding ->18cases/162assertions. See metadata-fault-plan.md for coherent arithmetic, including adding fauna firsti32[384] after all9Work fields to isolate countguard. Final tool must verify physical shape and schema before gate4. No production table changes.

Independent final contract/source review,17repository checks, import, focused/full tests and exact-headCI precede merge. Combined bulk capture/restore/derived bound-tool count, saved Work/Gear/Jobs/Inventory/resident identity and coherent claims remain explicit downstream prerequisites under SEMANTICS and OWNER-BINDINGS. Current runtime tool-required enforcement and MoodMemory authoring are separate gameplay work, not excuses for loader normalization.

Author owns only work.gd plus new save_owner_work.gd through bounded SHA-pinned patch. Astra owns tests, mutation/metadata tools, registry category3/capacity sidecar, queue/docs/CI and integration. Do not intake production patch before predecessor PR165 merges.

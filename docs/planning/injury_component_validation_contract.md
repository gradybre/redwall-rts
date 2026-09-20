# Injury component validation — INJURY-S4-VALIDATE-R01 v1

2026-09-20. Accepted by Astra after independent final review and original boundary characterization. ADR0177 authorizes the bounded implementation. This packet covers owner6 local validation and a bounded runtime overflow repair; it does not complete saved Needs/Directory/movement binding.

## Authority, layout and retained history

GDD4.2/4.3, REQ-SET-171–174 and SET-MOVE-ECON-001 HAZ-004 govern. Existing public writers preserve aggregate care/time across incidents, positive incident ordinals and episode flags after treatment, and stale rescuer references. A healthy present row can bind a rescuer because the current setter does not require active injury. Do not impose an injury requirement or silently clear history.

Owner6 injury version1, primary512, no children, globalfieldbegin122/count11:

| Local ordinal | Field | Type/count |
|---|---|---|
|0|_present|u8/512|
|1|_kind|u8/512|
|2|_airless_episode|u8/512|
|3|_exhaustion_latch|u8/512|
|4|_care_context_blocked|u8/512|
|5|_severity|i32/512|
|6|_rescuer_slot|i32/512|
|7|_rescuer_generation|i32/512|
|8|_untreated_ticks|i64/512|
|9|_care_progress_mwu|i64/512|
|10|_last_incident_ordinal|i64/512|

Values20992, payload21084, block21114, offset8539433; nextownerJobs at8560547. No schema/version/key/order/count/width changes. Kind derives from protected Catalog.INJURY_KIND: NONE0,CUT1,BITE2,FALL3,EXPOSURE4,EXHAUSTION5. Severity is injury0/1/2, not alert severity. Global Directory refs use352418slots; never compare refslot to patient typed row to infer self-rescue. No living256 cap in this local predicate.

Care and incident ordinal can reach INT64_MAX by existing public APIs; untreated ticks likewise admit full nonnegative signed-int64 saved domain. No care cap at recipe60000/120000, no arbitrary elapsed-time ceiling and no float. A full-range untreated counter requires the runtime overflow repair below before publication.

## Pure static predicate

Add static Injury.columns_refusal(present, kind, airless_episode, exhaustion_latch, care_context_blocked, severity, rescuer_slot, rescuer_generation, untreated_ticks, care_progress_mwu, last_incident_ordinal) -> StringName. Types follow the exact table, five bytes/threei32/threei64. All arguments remain frozen during synchronous validation. Every gate finishes its complete512-row scan before the next gate.

1. All11exact shapes before indexing: COLUMN_SHAPE.
2. present/airless/exhaustion/context all0..1: COLUMN_FLAGS.
3. kind0..5: COLUMN_KIND.
4. severity0..2: COLUMN_SEVERITY.
5. rescuer is exactly(-1,0) or slot0..352417/generation>0: COLUMN_RESCUER_REF.
6. untreated_ticks>=0: COLUMN_UNTREATED_TICKS.
7. care_progress_mwu>=0: COLUMN_CARE_PROGRESS.
8. last_incident_ordinal>=0: COLUMN_INCIDENT_ORDINAL.
9. kind==NONE iff severity==NONE: COLUMN_KIND_SEVERITY.
10. kind==NONE requires untreated_ticks0 AND care_progress0: COLUMN_NO_INJURY.
11. active kind requires ordinal>0; either airless/exhaustion flag1 also requires ordinal>0: COLUMN_INCIDENT_HISTORY. Do not constrain a latched row to a particular current kind; treatment/other incidents retain flags.
12. inactive requires kind/flags/severity/ticks/care/ordinal all0 and rescuer exactlynull: COLUMN_INACTIVE. Clear/spawn/despawn reset all these fields; unlike ResourceNodes no inactive numeric residue is retained.
13. No duplicate exact nonnull rescuer pair across present rows: COLUMN_RESCUER_DUPLICATE. Use nested bounded integer-count scans, skip null rows, compare both slot and generation. Distinct generations on the same global slot remain legal. No temporary packed array/sort/map.
14. Existing REFUSE_NONE on success.

Constants are REFUSE_ plus each exact code. Helpers may divide the implementation while preserving global priority. After flags, presence means ==1. Every physical row checked. No live Needs/Directory/catalog instance, constructor, callback, reflection, diagnostic write, projection, normalization or extra packed scratch. Only local scalar rules and exact pair uniqueness; current Directory liveness is deliberately unavailable.

## Runtime untreated-counter repair

Retain the current tick_all public signature and normal behavior. After existing diagnostic reset/null-Needs refusal, preflight every present, injured, living row in ascending order. If its untreated counter is INT64_MAX, set last_refused_slot to that row and return existing REFUSE_OVERFLOW with value0 BEFORE any counter increments. Then run the existing increment sweep only if the full preflight passes. No health update, second rate path, skipped-overflow partial progress, extra columns or owner construction. Dead/uninjured/inactive rows remain skipped. Successful calls preserve existing advanced-row count.

Canonical Injury and Needs data are byte-identical on overflow refusal; last_refused_slot intentionally reports the first blocked row. The null-Needs path leaves last_refused_slot at-1, as today. CounterMAX-1 advances once toMAX and the next eligible sweep refuses. A lower-index valid row must not advance when a later row blocks. Existing checked care addition and incident-ordinal monotonicity stay unchanged.

A narrowly labeled test fixture may inject only _untreated_ticks through RefCounted.set, then use public readers/state_bytes and tick_all for boundary observations. No production setter/getter, no claim of public history reachingMAX, no claim of saved restoration. The original-source characterization passed12assertions/0 observing the bug: success, earlier-row advance, MAX->MIN wrap and no refusal diagnostic. A separate public-history probe passed47assertions/0. Future bulk restore must separately prove real saved-state continuation.

## Framed bridge

Add save_owner_injury.gd with only public static framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal. Preload Injury, Schema, Section, SaveHeader only. Seven gates: null->SAVE_COMPONENT_SHAPE; wrongowner6->SAVE_COMPONENT_OWNER; unchanged Schema.schema_refusal; metadata/source pins->SAVE_COMPONENT_METADATA; unchanged Section.owner_shape_refusal;11explicit canonical typed accessors; raw columns_refusal code. Success emptycode/detail. Metadata prefix `Injury owner6 metadata:`; column detail contains `Injury owner 6 ` and raw code, no row identity.

Pin owner key/version1/primary512/nochildren/11fields with all keys/types/counts. Source pins: Injury.RESIDENT_CAPACITY512, Injury.Needs.RESIDENT_CAPACITY512; KIND_NONE0/CUT1/BITE2/FALL3/EXPOSURE4/EXHAUSTION5/KIND_COUNT6; SEVERITY_NONE0/MINOR1/SERIOUS2; Injury.EntityDirectory.DIRECTORY_CAPACITY352418, NULL_SLOT-1/NULL_GENERATION0, Injury.NULL_SLOT-1/NULL_GENERATION0/NULL_REF(-1,0). Constant chains do not instantiate owners. Independent generator/source-capacity audit remains required. No new const Array/publication table.

Caller20992packedbytes fit existing stream6417408; no added packed scratch. Two nested uniqueness scans allocate nothing. Native/wrapper memory remains unmeasured. Actual import and preload closure audit must distinguish existing supported self-preloads from new cycles.

## Parent verification and independent review

Each of the11zero-accessor mutants needs its own explicit witness: especially care_context_blocked2 must refuse COLUMN_FLAGS rather than becoming an unobserved valid0. Tests cover all11fields empty/short/long, all512physical positions, allscalar endpoints and bool/kind/severity boundaries, inactive defaults, healthy bound rescuer, stale refs/different generations, exact duplicatepair, free-row nondefaults, kind/severity equivalence, no-injury time/care reset, incident/latch history, signedi64 extrema and global gate priority. Compare every input buffer before/after each checked call. Wrongowner/null/typed-bucket errors and rawzero-frame refusal required. No literal unsigned/float substitute for i64.

Public history repeats ordinary incidents, MAXcare and checkedoverflow, treatment retaining ordinal/latches, healthy/stale rescue and death-skip. state_bytes is var_to_bytes(PackedInt64Array): count then11values per present row, not raw canonical concatenation. The eleven diagnostic values are row, kind, severity, ticks, care, ordinal, rescuer slot/gen, then airless/exhaustion/context; this differs from canonical column order. Decode/remap explicitly or use public readers; do not infer private inactive capture. Existing full Injury suite still runs. Boundary fixtures seed one counter column and assert actual public tick/refusal/data/diagnostics across two living rows, dead/no-injury skips and MAX-1/MAX transition.

Required33mutants:11zero-accessor substitutions;17value-clause omissions (fourbooleanflags, kind, severity, refpair, untreatednonnegative, carenonnegative, ordinalnonnegative, kind/severityrelation, no-injuryticks, no-injurycare, activeordinal, latchedordinal, inactivecanonicalgate, duplicatepairgate);3order reversals (shape behind flag with safe indexing, untreated behind care, inactive behind duplicate with a noncanonical inactive row and a duplicate pair across two different present rows);2runtime mutants (disable overflow check; increment an earlier row before a later overflow refusal). Exact-code witnesses are valid but must not be called acceptance-domain kills when a later gate still refuses. Every mutant must run all expected tests, fail real assertions/nonzeroexit, and have no parser/script errors; baseline/restored controls pass.

Metadata plan specifies18real-engine cases/162assertions (8schema faults,8bypasses,positive,schemaforward), independently re-derived arithmetic.17repository checks, capacity regeneration, import, focused/full tests, independent source review and exact-head CI required before merge. No production intake before predecessor ResourceNodes PR merges.

Author owns injury.gd and new save_owner_injury.gd only. Astra owns tests, fault tools, registry/queue/docs/CI. Add INJURY-SAVED-BINDINGS as explicit section4-semantic prerequisite: saved Needs/resident presence, health/injury-state agreement, Directory patient/rescuer kind and identity without rejecting lawful stale generations, movement care context and same-file provenance. Full capture/restore and derivedcounts remain owner-binding work. First-playable/full-save acceptance remains open.

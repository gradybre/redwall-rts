# Schedule component validation — SCHEDULE-S4-VALIDATE-R01 v1

Date:2026-09-20. Accepted by Astra after source review, public history probe and independent final contract review; ordinary settlement-scope implementation authorized. This is owner14 validation, not capture/apply or world publication.

## Fixed owner and numeric domain

Owner14 key `schedule`, version1, primary512, zero child extents, six canonical fields:

| ordinal | field | type/count |
|---|---|---|
| 0 | _present | u8/512 |
| 1 | _hourly_activity | u8/12288 |
| 2 | _template | i32/512 |
| 3 | _current_activity | i32/512 |
| 4 | _sleep_satisfied | u8/512 |
| 5 | _resolved | u8/512 |

All512physical rows are addressable; no256living cap belongs here. Activities are the protected0..3 enum, ANYTHING1. Numeric template IDs are0..TEMPLATE_COUNT-1 (currently3templates). Catalog key/ID identity is separately verified by section2 CatalogIds.verify_embedded, which rejects mismatches; no migration or live catalog compilation is introduced. Never preload CatalogIds from Schedule or this bridge: CatalogIds already preloads Schedule.

## Pure owner predicate and exact refusal order

Add `static func columns_refusal(present: PackedByteArray, hourly_activity: PackedByteArray, template_ids: PackedInt32Array, current_activity: PackedInt32Array, sleep_satisfied: PackedByteArray, resolved: PackedByteArray) -> StringName` to schedule.gd. template_ids is the `_template` field. No owner instance, Columns object, default buffers, duplicate/sort/range Array, callbacks or diagnostic write. Use bounded loops/count scans and named constants.

Every gate is complete across all physical rows before the next gate, including row-state gates:
1. All six exact extents before domain/index reads: REFUSE_COLUMN_SHAPE / COLUMN_SHAPE.
2. present0..1: REFUSE_COLUMN_PRESENT_BYTE / COLUMN_PRESENT_BYTE.
3. sleep_satisfied0..1: REFUSE_COLUMN_SLEEP_SATISFIED_BYTE / COLUMN_SLEEP_SATISFIED_BYTE.
4. resolved0..1: REFUSE_COLUMN_RESOLVED_BYTE / COLUMN_RESOLVED_BYTE.
5. Every hourly byte0..ACTIVITY_COUNT-1: REFUSE_COLUMN_HOURLY_ACTIVITY / COLUMN_HOURLY_ACTIVITY.
6. Every signed template ID0..TEMPLATE_COUNT-1: REFUSE_COLUMN_TEMPLATE_ID / COLUMN_TEMPLATE_ID.
7. Every signed current activity0..ACTIVITY_COUNT-1: REFUSE_COLUMN_CURRENT_ACTIVITY / COLUMN_CURRENT_ACTIVITY.
8. Every inactive row must hold template0, currentANYTHING, hourlyANYTHING for all24hours, sleep0/resolved0: REFUSE_COLUMN_FREE_ROW / COLUMN_FREE_ROW.
9. Every present resolved0 row must hold currentANYTHING and sleep0: REFUSE_COLUMN_UNRESOLVED_STATE / COLUMN_UNRESOLVED_STATE.
10. Every present sleep1 row must hold currentANYTHING: REFUSE_COLUMN_SLEEP_STATE / COLUMN_SLEEP_STATE. Gate9 already ensures resolved1 for such a row.
11. Success existing REFUSE_NONE.

Share exactly one helper: `static func _free_row_is_clear(hourly_activity: PackedByteArray, template_ids: PackedInt32Array, current_activity: PackedInt32Array, sleep_satisfied: PackedByteArray, resolved: PackedByteArray, slot: int) -> bool`. It takes no presence argument and performs no bounds check: callers must supply a validated slot0..SCHEDULE_CAPACITY-1 and correctly sized columns. Existing inactive_row_is_clear keeps its exact address/present guards, then delegates. The validator calls it only after complete shape/domain checks and for inactive rows. No other gameplay path changes.

The two present-row state implications are producer invariants proven by all existing writers, as dispositioned in feasibility-disposition.md. They compare saved local values only. DO NOT compare current activity with the current timetable, assigned template, clock, hunger/rest or Needs status. Custom hourly edits retain template identity. assign_template resets the sleep latch but deliberately retains current_activity/resolved. A successfully resolved activity remains canonical history, including after an edit, reassignment or refused subsequent resolve. No repair or normalization on failure.

Correct only the registry wording claiming resolved means this hour was applied: it records that at least one successful resolve produced the row's current_activity and is not derived from the clock. That doc edit belongs to the parent.

## Framed bridge

Add save_owner_schedule.gd, only public API `static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal`. Allowed preloads Schedule, Schema, Section, SaveHeader. Never construct Schedule (its constructor allocates a private Needs) or any live owner.

Gates: null -> SAVE_COMPONENT_SHAPE; owner!=14 -> SAVE_COMPONENT_OWNER; Schema.schema_refusal forwarded unchanged; exact owner/field metadata -> SAVE_COMPONENT_METADATA; Section.owner_shape_refusal forwarded unchanged; six explicit typed accessors passed to the owner predicate in canonical order: `u8_column(FIELD_PRESENT=0)`, `u8_column(FIELD_HOURLY_ACTIVITY=1)`, `i32_column(FIELD_TEMPLATE=2)`, `i32_column(FIELD_CURRENT_ACTIVITY=3)`, `u8_column(FIELD_SLEEP_SATISFIED=4)`, `u8_column(FIELD_RESOLVED=5)` (the notation pins scalar ordinal constants, not an assignment expression at the call site); return its raw COLUMN_* code. Success emptycode/detail. Column failure detail names `Schedule owner 14 ` and exactcode, no row identity. Gate4 detail begins exactly `Schedule owner14 metadata:`; gate3 retains original detail.

Metadata pins key/version/primary/zerochildren/6fields and every field key/type/count. Cross-check Schedule.SCHEDULE_CAPACITY512, HOURS_PER_DAY24, ACTIVITY_COUNT4, TEMPLATE_COUNT3 and ACTIVITY_ANYTHING1. Existing static constants and pinned literals suffice; no owner-publication-table parity claim or new const Array. Independent schema generation/source-capacity audit remains the source proof.

Caller freezes/holds its record for this synchronous read; six accessor values share COW buffers and are never retained. Logical packed bytes are512+12288+2048+2048+512+512=17920, already inside the caller's streamed owner allowance. Add no packed projection or scan scratch. Native/wrapper overhead is unmeasured. Arbitrary zero wire is not a valid empty Schedule; validation must refuse rather than fill ANYTHING defaults.

## Acceptance and ownership

Parent tests actual public histories from the probe, all3templates and4activities, every12288hourly byte, signed i32 extrema and range edges, all flags, all512present, exact inactive defaults, both state implications, first-refusal across different rows, wrongowner/null, every extent/bucket mismatch, rawcode/detail, and complete input nonmutation. A zero frame refuses COLUMN_FREE_ROW; properly filled empty image accepts. An inactive hourly byte4 returns COLUMN_HOURLY_ACTIVITY before the inactive-residue gate. Use the named witnesses in parent-test-matrix.md; correctly-sized zero substitutions may refuse with another code and still must be killed by exact-code assertions.

Six argument-substitution mutants replace one accessor with a correctly-sized allzero buffer; tests use per-field invalid values and exact codes, not the empty control. Distinct sleep/resolved codes kill their argument swap. Distinct template/current codes kill a type-compatible swap. Omit free-row/unresolved/sleep gates and invert the two present-state gates; assertions must kill each, never parse errors. Include live reader guards after helper sharing.

Real-engine counterfactual metadata faults must prove prerequisites still valid before gate4; test owner identity, fields and types/counts, malformed schema forwarding, exact prefix and bypasses. Production sources remain unchanged during clone fault tests. Source review, focus/full suites, import/static checks and exact-head CI precede merge.

Author owns only schedule.gd and new save_owner_schedule.gd via a SHA-pinned bounded unified patch. Parent owns tests, registry/classification, sidecar, docs/queue and CI. Bulk APIs/present_count rebuild, Needs agreement, section2common-file catalog matching, lifecycle/barrier publication, remaining owners and full save/load stay explicit downstream requirements.

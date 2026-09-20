# Needs component validation — NEEDS-S4-VALIDATE-R01 v2

Date: 2026-09-20. Accepted by Astra after three independent planning reviews; author dispatch authorized in the existing settlement scope. This is an owner-9 validation primitive and a corrective restore boundary, not completion of all Needs semantics or section4.

## Authority and corrective scope

GDD §5.2 line329 requires DEAD at health0. The public status_probe.gd reproduces the current defect: restore accepts health0/ACTIVE and recounts one living resident; the next tick sets DEAD but living_count remains1 because no positive-to-zero health transition occurred. Reject that inconsistent image before publication. Never repair incoming status or compensate after installation.

For present rows require `(health == 0) == (status == STATUS_DEAD)`. This admits current public lifecycle output, including dead-but-present rows, and rejects both zero-health/nondead and positive-health/dead contradictions. Add `REFUSE_COLUMN_HEALTH_STATUS = &"COLUMN_HEALTH_STATUS"`. Do not change live tick/death bookkeeping without a separate reachable witness; preventing this invalid restore is the repair.

Other domain rules remain exactly the existing accepted Needs restore rules. In particular departure_days accepts0..INT32MAX, inactive size/environment/garment residue remains legal, and no rule ties historic starving_ticks to current hunger. Correct the three overbroad departure comments (header, column declaration, accessor) to distinguish an unimplemented normal producer from an admitted nonnegative saved counter. No departure mechanics or reinterpretation of LEAVING/TRANSFERRED is introduced.

## Single pure owner predicate

Expose `static func columns_refusal(columns: Columns) -> StringName` in needs.gd. It is the single implementation called by restore_columns and offline validation. It returns REFUSE_NONE on success and the exact existing/new code on refusal; it touches no owner state or diagnostic.

Total order:
1. Null/shape: every20column extent exact, before indexed/domain reads. Null returns COLUMN_SHAPE.
2. Existing byte domain sequence: present, flags, clothing, enums.
3. Existing value domain sequence: need, health, departure, starving, cold milli-hours, three remainders.
4. Existing inactive-row rule.
5. New present-row death equivalence.
6. Recomputed living cap256.

Convert these **nine** existing argument-only helpers to static: `_columns_are_capacity_sized`, `_column_byte_domain_refusal`, `_byte_column_below`, `_column_value_domain_refusal`, `_int32_column_within`, `_int64_column_within`, `_column_free_row_refusal`, `_free_row_is_clear`, `_living_row_count`. Add one static `_column_health_status_refusal`. There are ten helpers after the addition, plus the public predicate. Preserve all existing callers, including counter rebuild and copy_columns_into. Put the null guard in the shared shape predicate so both restore_columns(null) and copy_columns_into(null) safely refuse with their existing COLUMN_SHAPE diagnostic instead of dereferencing null.

restore_columns retains its current install/rebuild/diagnostic behavior after the predicate succeeds, and sets only last_column_refusal on failure. No live mutation/capture logic is moved into the pure predicate. The old private root may be renamed or delegate to the public predicate, but no second semantic implementation is allowed.

## Pure framed bridge

Add `godot/scripts/core/save_owner_needs.gd`, with one public API:

`static func framed_refusal(record: Section.FramedOwner) -> SaveHeader.Refusal`

Allowed preloads: Needs, component Schema/Section, SaveHeader. No live Needs instance, store calls, capture/apply, clock, barrier, signal, callback, filesystem, JSON, reflection or per-row objects.

Bridge gate order:
1. Null record -> SAVE_COMPONENT_SHAPE.
2. record.owner !=9 -> SAVE_COMPONENT_OWNER.
3. Schema.schema_refusal, forwarded unchanged on refusal.
4. Compiled owner key `needs`, version2, primary512, zero child extents, field count20, plus parity of all20keys/type codes/counts against Needs.COLUMN_KEYS/COLUMN_TYPE_CODES/COLUMN_EXTENTS and their array lengths. Mismatch -> SAVE_COMPONENT_METADATA. Gate4 detail begins `Needs owner9 metadata:`; gate3 forwards the schema detail unchanged. Code alone does not identify which metadata gate fired.
5. Section.owner_shape_refusal, forwarded unchanged.
6. Construct one temporary Needs.Columns and explicitly assign all20fields from the framed record through owner-local typed accessors, using these ordinals:

| ordinal | field | type/count |
|---|---|---|
| 0 | present | u8/512 |
| 1 | need_value | i32/2560 |
| 2 | need_remainder | i64/2560 |
| 3 | health | i32/512 |
| 4 | health_remainder | i64/512 |
| 5 | cold_milli_hours | i64/512 |
| 6 | cold_remainder | i64/512 |
| 7 | starving_ticks | i64/512 |
| 8 | departure_days | i32/512 |
| 9 | status | u8/512 |
| 10 | size_class | u8/512 |
| 11 | activity | u8/512 |
| 12 | comfort_environment | u8/512 |
| 13 | social_paired | u8/512 |
| 14 | purpose_source | u8/512 |
| 15 | cold_environment | u8/512 |
| 16 | clothing_tier | u8/512 |
| 17 | infirmary | u8/512 |
| 18 | injury_state | u8/512 |
| 19 | airless | u8/512 |

7. Call Needs.columns_refusal on the temporary projection. Return the exact unwrapped StringName as Refusal.code (for example COLUMN_HEALTH_STATUS); detail identifies Needs owner9 and that same column code. Success has empty code/detail. No projection is returned or retained. Private helpers may divide assignment groups for readability; omission cannot fall back to constructor defaults.

The caller keeps and freezes its record for this synchronous call. Packed assignments share COW buffers; validation only reads them and sorts private copies. The bridge must call no duplicate(), must not reach _install_columns, and must not capture from a live owner. Only the existing range helpers duplicate and sort their private temporary copies. Both accepted and refused calls preserve all caller arrays. A positive result certifies only the predicate above, not common-file origin, resident/Directory matching, Injury agreement or complete world validity.

## Domains and memory

Use existing named constants, not duplicated gameplay limits. Need values0..10000; health0..100; need remainder ±749999; health/cold remainder ±749; counters nonnegative up to their signed type maxima; declared enum/flag ranges unchanged. Clothing is1..2 even on inactive rows. Inactive rows require DEAD and cleared health/health remainder/cold/cold remainder/starving/need values/remainders, while other existing retained values keep their present domain rules.

One framed Needs image contains57344 value bytes. Normal Columns construction transiently adds57344 before the explicit assignments drop its default buffers. Conservatively charge both throughout validation plus the largest single returning sort-copy (need_remainder2560*8=20480): **135168 bytes**, before wrappers/native overhead. i32 and i64 helper sort copies do not coexist across returning calls. This is conditional allocation arithmetic, not measured RSS; no new resident allocation row or canonical field is added. Do not optimize range scans or introduce an alternate unallocated Columns constructor in this slice.

## Acceptance and exact ownership

Production author owns only needs.gd and new save_owner_needs.gd. Use a bounded unified implementation.patch against SHA-pinned supplied inputs, with no other target, rename, binary or mode change. Parent owns tests, registry classification, source-capacity sidecar regeneration, docs and evidence.

Parent tests must cover:
- All20mapping omissions through per-field invalid fixtures with exact refusal codes; keep a present health100 row for the invalid status witness, so its omission returns COLUMN_HEALTH_STATUS instead of the expected COLUMN_ENUM_BYTE; valid nondefault fixtures and input equality before/after accepted/refused checks.
- Null columns/record and copy_columns_into(null), wrong owner, metadata disagreement, malformed buckets and short/long extents before indexing. No newly added live owner may be constructed by the bridge.
- Every enum/flag and signed range boundary; zero FramedOwner fails clothing rather than passing as defaults; valid retained inactive residue and nonnegative departure maximum accepted.
- All six non-DEAD statuses paired with health0 refuse; DEAD with health1/100 refuses; dead-but-present health0 accepted; full-health injured ACTIVE and injured sleeper INJURED remain accepted; historic starving ticks after feeding remain legal.
- Public static predicate, framed bridge and live restore diagnostic agree for the same semantic fixture; refused restore preserves the prior target, and static/bridge checks mutate no world.
- First-refusal ladder including free-row before death equivalence and death equivalence before living cap; 256/257 living boundaries remain intact.
- Actual per-field mapping omission mutants, death-rule omission/direction mutants and a precedence mutant killed by assertions, not parser errors.

Run focused and full Godot suites, source/static gates, editor import and independent source review before exact-head CI/merge.

SAVE-S4-SEMANTICS remains an incomplete18-owner parent. This primitive does not settle total nonfatal status precedence/LEAVING/TRANSFERRED (`NEEDS-STATUS-PRECEDENCE`), departure production/counter semantics (`NEEDS-DEPARTURE-DOMAIN`), cross-owner saved consistency or owner capture/apply. Record those dependencies explicitly. Sort-copy optimization is optional and not a correctness blocker; do not create a repair task for the tick path without evidence of a reachable invalid state after this gate.

# PC-04 v4 draft set and FAMILY-RULES-R01 v1 — independent bounded review

2026-09-19 · Independent reviewer · **Review only. No code, schema, fixture, catalog entry, command or test was written; nothing was run, applied, activated or verified by execution. This document completes no PC-04 gate and no task may self-approve from it.**

**Subject.** `family_execution_package.md` (FAMILY-C4-R01 v4 draft), `family_state_schema.md` (FAMILY-STATE-R01 v3 draft), `family_lifecycle_contract.md` (FAMILY-LIFE-R01 v3 draft), `family_rules_api_contract.md` (FAMILY-RULES-R01 v1 draft).

**Evidence.** The four drafts, `draft-v3-review.md` and `arithmetic.json` as supplied. No repository file was opened or executed. Where a surface lies outside the supplied text it is recorded as an obligation to cite at dispatch, never as a claim of absence. Previously confirmed arithmetic is not recomputed or re-narrated here.

**Disposition.** C-01 through C-04 are **resolved as drafted**. No new blocker. Three residual obligations (R-1..R-3) and two helper citation items (H-1, H-2) are listed; none is a coefficient, scope, spend or art decision.

---

## 1. C-01 — false CHILL_UNTREATED resurrection: RESOLVED

The fix adopts the scoped option B. `chill_active` B8[512] is a separate untreated bit set atomically with a successful onset commit and cleared atomically with successful aggregate treatment; `chill_episode` remains purely the onset/rearm latch with rearm at `cold_milli_hours <= 1000` **and** `chill_active = 0`. The notice predicate is now `chill_active = 1` alone, severity WARNING or CRITICAL at `health <= 15`.

The v3 reproducer no longer fires: onset gives (1,1); treatment at cold 2000 gives (1,0) and clears the notice; an unrelated CUT at cold 2000 leaves (1,0) and raises no CHILL notice; shelter to cold 1000 gives (0,0) even with CUT active; a later genuine onset at cold 4000 gives (1,1). Immediate re-onset while deeply exposed is still forbidden, which was the reason clearing `chill_episode` at treatment was rejected. Failure to commit either onset or treatment changes neither bit, and both bits belong to the same atomic Injury operation as the aggregate change rather than a best-effort coordinator write. Death/row retirement clears both.

Byte accounting is coherent across files: two B8[512] columns = 1024 live + 1024 snapshot, outside the family owner's 46352-byte payload, inside the single Injury schema 1→2 bump, and the v4 disposition's `+512 beyond the previous proposal` is the correct delta from the single-bit v3 design.

**R-1 (obligation, not a blocker).** The stated load invariant `chill_active = 1 requires chill_episode = 1 and an active aggregate injury` is safe only if treatment is the sole path by which an aggregate leaves the active set. If the existing Injury owner also retires aggregates by recovery, expiry, severity retirement or row reuse, a saved (1,1) row could become (1,1)-with-no-aggregate and refuse a legitimate world. The drafts do not exhibit the Injury retirement rule and I do not assert its content. At dispatch, cite the actual aggregate-retirement paths and either confirm each clears `chill_active` atomically or relax the invariant to `chill_active = 1 implies chill_episode = 1`.

---

## 2. C-02 — pass predicate prose: RESOLVED

The *Daily routines and shared care* sentence now reads `in-flight tick k modulo 30 = 0, before completed_tick publication`, matching the v3 disposition and the ARCH-SYS-019a description. The surrounding clauses remain consistent: the pass runs after that tick's care/health/lifecycle commit, grants no restoration in its own selection tick, stages assignments for the next interval, and ordinary job selection consumes the prior pass's staged reservations. The midnight-crossing sequence (attribute the elapsed interval to the old day, reset daily provider totals after lifecycle commit, then select) is stated once in each file without divergence. The 4500/13500/18000 congruences are unchanged and the withdrawn `4500 mod 18000 = 0` claim does not reappear.

---

## 3. C-03 — dual day-field authority: RESOLVED

The v4 text assigns clear ownership: `paired_social_day` owns the pair-day tick accumulator and its 750-tick once-per-day award latch; `last_contact_day` owns eviction eligibility and oldest-contact sorting; both are written together, to the current absolute day, on every qualifying paired care/social interval in ARCH-SYS-018. Generic rescue/feast/conflict contact may advance `last_contact_day` alone, which only protects an edge longer and cannot award again. Consequently `paired_social_day <= last_contact_day` holds by construction on every write path, so the restore-time refusal of a paired day later than last contact is a genuine corruption detector rather than a rule that can fire on legitimate play. The eviction guard reads `last_contact_day`, which is the later-or-equal field, so a same-day awarded edge cannot be evicted and recreated for a second award within the day. New-day paired contact resets ticks before adding; no paired-day field is reset by an attempted eviction.

**R-2 (obligation).** The Relationship owner's actual column name, row capacity 2048 and the +24576 mutable bytes plus equal snapshot payload must be cited from that owner at dispatch and budgeted in the implementation packet, not folded into 46352. The drafts already state this; it remains unclosed and is outside the helper packet.

---

## 4. C-04 — single final mood ordering: RESOLVED

ARCH-SYS-017b no longer claims to publish final mood. The order is 017a care integration (preceding committed interval only), 017b CHILL onset and medical completions, 018 SocialMood consuming preceding-interval paired participation exactly once, updating the shared pair-day accumulator and award, applying that tick's scheduled social and conflict/memory events, then deriving final mood from post-017a care and post-017b health, then 019 lifecycle. The child divisor-12 formula's `care` term therefore reads a committed value, adult/elder keep divisor 10, and no second health integration or persistent duplicate mood column is introduced; existing Needs mood readers stay pure formula helpers. Lifecycle and progression read the 018 result, and reputation/M4 mean mood read lifecycle-committed state, which is strictly after 018 — the older `post CareHealth` phrasing in the v2 section is now merely loose, not contradictory.

**R-3 (obligation).** The draft itself states that one participation producer must be bound so care and social cannot double-credit a single pair in a single interval, and that these ordinals are proposals until `systems_architecture.md` is amended and reconciled with ARCH-TICK-003. Both remain open and are correctly not claimed as done.

---

## 5. FAMILY-RULES-R01 v1 — helper readiness

**Preload cycle avoidance — sound.** The helper preloads only `int_math.gd` and derives nothing from Residents/Needs, which are the eventual consumers. The stage/size identities are declared as local protected inputs with equality asserted from the *tests*; test-side preloads are outside the helper's own graph and do not reintroduce the cycle. The caller supplies a validated stage and size, so no species-to-size inference leaks in.

**36 outputs and indexing — sound.** Two private PackedInt64Array fields of 18 values, `index = life_stage*6 + size_class*2 + (winter ? 1 : 0)`, is a bijection onto 0..17 for stage 0..2 and size 0..2; the maximum index 17 is in range and no cell is aliased or unreachable. The 36 published values reproduce the confirmed table, including the 480000 adult/elder large-winter maximum and the exact child fractions; every product divides the 1000000000 denominator exactly at these inputs, so the single final floor division introduces no rounding ambiguity, and the largest checked product stays far inside i64. Keeping NP/day on its own base rather than rounding it from the hourly hunger result is correct even though the adult small case coincides.

**288 derived bytes — sound.** 2 × 18 × 8 = 288 immutable packed bytes, explicitly excluded from the 46352-byte mutable owner payload and from any canonical image, with object/scalar overhead disclaimed rather than hidden. Category-2 registration with no canonical field-count or version change is consistent with that classification, as is the memory-ledger entry.

**Refusal precedence and readiness — sound.** Precedence is total and deterministic: unavailable table, then stage outside 0..2, then size outside 0..2. `is_ready()` is true only after both 18-row tables are complete and checked; an overflow or domain failure during `_init()` leaves readiness false and partially built private storage unqueryable, which is the right shape for a GDScript constructor that cannot itself refuse. Refusal sets value 0 with an explicit error, and the acceptance criteria require that a refusal clears a previously successful reused outcome, so zero can never pass as data. Domain checks precede index arithmetic, so large signed inputs are never multiplied or used to index.

**Zero allocations on queries — sound as specified.** Both queries write a caller-owned `IntMath.IntResult` and return `out.ok`; there is no public array accessor, borrow, setter, reset or catalog-reload method, no Dictionary or nested array, and no per-tick rebuild. Tables are built once in `_init()`.

**Scope discipline — correct.** The packet changes no runtime child coefficient, no Needs/Residents consumer, no catalog fingerprint and no save; composition of one instance per published rules catalog is deferred. Implementing it before full family activation is therefore legitimate, and the contract says so without claiming that children can be spawned or played.

### Helper items to cite before dispatch (not contradictions)

**H-1.** The exact `IntMath.IntResult` surface — field or method names for value, ok and error, and how an error identifier is carried — is not exhibited in the supplied text. Cite the current signature at dispatch rather than assuming it; the contract's `writes caller-owned outcomes and returns out.ok` must match it literally.

**H-2.** Ownership of `FAMILY_STAGE_RULES_UNAVAILABLE`, `FAMILY_STAGE_INVALID` and `FAMILY_SIZE_INVALID` is unstated. Confirm whether these are strings, an existing shared error domain, or three new identifiers, and confirm that adding them touches no catalog fingerprint — the packet's `no canonical version change` claim depends on that answer. The first code is already used by the parent draft at catalog publication and spawn/admission, so the two uses must agree on one spelling and one owner.

Neither item changes a number, an index or the public shape; both are citations the implementing task must make against current source.

---

## 6. Helper blockers versus intentionally open work

**Helper blockers: none.** Only H-1 and H-2 above, which are dispatch-time citations.

**Intentionally open, and correctly not claimed by the helper packet:** exact public API parameter records and wire signatures for the family owner, including the `select_care_into` and `advance_care_tick` fact records; the atomic multi-owner admission and lifecycle transaction with its participants, ordering and fault boundary, and the atomic-unit `ACCEPT_CANDIDATES` variant and replay identity; `systems_architecture.md` ordinals 017a/017b/019/019a and the ARCH-TICK-003 reconciliation; GDD protected-enum and schedule-template amendments; Injury schema 2 against its verified baseline and the Injury/CareHealth ordinal submission order, I64_MAX refusal and publish-hold fault evidence; the Relationship pair-day contract and budget (R-2); the single participation producer (R-3); PC-03's named family-enabled profile and finite unit sequence; the stage-qualified movement/geometry/bed/contact producer; complete codecs, world-level snapshot accounting, and native Mac player-flow captures. None of these gates the pure rate-table helper, and none may be described as closed by it.

---

## 7. Scope statement

This document is a review. It produced no code, schema, fixture, catalog entry, command or test and changed no file other than itself. It activated nothing and ran nothing. R-1..R-3 and H-1..H-2 are bounded proposals derived from the drafts' own statements; none carries user authority and none is a scope, spend or art decision. The family package remains in-flight planning, not runtime.

# SAVE-CLAIM-CHECK-R01 draft1 — independent contract review

Read-only. Reviewer: Claude. 2026-09-19. Inputs: the draft1 contract,
`contract-complete-calls.md`, `followup-sources.md`, `followup-registry-snapshot.json`,
`followup-review.md`, `followup-disposition.md`, `test_resource_claim_lifecycle.gd`,
`save_section_directory.gd`, `save_identity_restore.gd`, `save_resource_claims_restore.gd`.
Nothing was written, executed, compiled or tested by this reviewer. No gameplay rule is
invented. This review accepts the disposition's refutation of the prior X1/X2/X3 and does
not reopen them; no missing-context allegation is repeated. It closes no blocker and does
not authorize implementation.

## 1. Verified from source, not restated on trust

**V-1. Every published byte figure recomputes.** FishComponents 32 + 4·128 = 544.
ForageComponents 128 + 4·512 + 1024 + 640 + 2·2560 = 8960. JobComponents
8192 + 2·32768 + 65536 = 139264. Sum 148768. Derived = 352418·4 + 2·(18·4) = 1409816.
Max sums 512·6 = 3072 and 8192·1180000 = 9666560000. All match the contract exactly.

**V-2. `rebuild_into` does not mutate its Record.** `_domain_refusal` and
`_persistent_id_refusal` each `duplicate()` before `sort()`; `_scan_live_refusal`,
`_retirement_refusal` and `_closure_refusal` only read. Only the caller-owned `Derived` is
written (`out.clear()`). The contract's unchanged-on-success-and-refusal claim holds for
the Directory record.

**V-3. Column counts match the existing adapter.** fishing 1 u8 + 7 i32 + 0 i64 = 8 fields;
forage 1 + 7 + 3 = 11. Registry confirms §7 fishing `owner_schema_version: 2` and forage 1.

**V-4. Cursor rule is reachable-world exact.** `_publish_row` assigns `_next_persistent_id`
then increments, so the cursor is strictly above every assigned — hence every live — id;
`PERSISTENT_ID_MIN` 1 and `PERSISTENT_ID_EXHAUSTED` 2147483648 match 1..2147483648.

**V-5. Asymmetric typed-row rules are correct.** Fishing constrains only the Expedition's
typed row to the claim row (`_refuse_stored_effort_claim`, `purge_stale_effort_claims`);
the owning Job's typed row is unrelated and the draft rightly does not constrain it. Forage
claim row IS the Job typed row (`claim_forage` line 2172), and the public fixture asserts
`claim.value == _job_row` with `_job.x != _job_row`.

**V-6. Habitat cannot die under a live or stale fishing claim.** `destroy_habitat` refuses
while `_habitat_effort_used[slot] > 0`, and only `_release_effort_claim_row` decrements it,
so "mandatory live habitat" is not stricter than the reachable world.

## 2. Blocking contract gaps

**G-1. The private scratch ceiling is understated by ~2.82 MB.** The contract budgets
1411096 packed bytes and attributes the remainder to "native object overhead". But
`rebuild_into` → `_domain_refusal` allocates `record.generation.duplicate()` (1409672 bytes)
and `_closure_refusal` → `_persistent_id_refusal` allocates
`record.persistent_id.duplicate()` (1409672 bytes). Both are PACKED, not object overhead,
and the first is still reachable when the second is taken if a future edit reorders the
gates. Restate the ceiling as 1411096 resident plus up to 2819344 transient inside the
reused Directory validator, or the contract's allocation clause is false on first call.

**G-2. `rebuild_into` is a script static, not a method on `Derived`.** The contract says
"allocate one SaveSectionDirectory.Derived and invoke **its** existing rebuild_into".
The actual signature is `static func rebuild_into(record: Record, out: Derived)` on
`save_section_directory.gd`. Name the call site exactly; the current wording invites
`derived.rebuild_into(...)`, which does not exist.

**G-3. The fishing aggregate comparison has no stated relation.** "compare all 32 rows
against saved habitat_effort_used and physical habitat_effort_slots" does not say which is
equality and which is a bound. The reachable world supports total == `habitat_effort_used`
AND total <= `habitat_effort_slots`; write both operators.

**G-4. `Result.row` has no row-space discriminator.** One `int` must carry a §7 claim row
(0..511 / 0..8191), a component row (habitat 0..31, zone 0..127, patch 0..639, job
0..8191), and — for a bijection or cursor failure — a Directory slot (0..352417). These
overlap. Either add a row-space enum field or require `detail` to name the space in a fixed
prefix; otherwise a reported row is not localizing.

**G-5. Gate-to-code binding and precedence are unmapped.** Eleven new codes are listed but
no gate is bound to one. Undecidable today: which code a Directory→component bijection
failure takes (`CLAIM_CHECK_COMPONENT` or `CLAIM_CHECK_IDENTITY`); and whether the
stricter owner quantity bound reports `CLAIM_CHECK_QUANTITY` or is preempted by
`codec.owner_refusal` (gate order implies the codec wins and `CLAIM_CHECK_QUANTITY` fires
only for the residual stricter band — say so).

**G-6. `CLAIM_CHECK_OVERFLOW` is dead as specified.** The contract proves both maxima
cannot overflow i64 and forbids manufacturing a public witness, and the evidence list
contains no overflow test and no overflow mutant. A refusal code with no reachable path,
no test and no mutant is contract debt: either require a direct unit test of the checked-add
helper at synthetic inputs, or delete the code and keep the checked math unlabelled.

**G-7. `Result.code` empty-value convention conflicts with the save layer.** Every
neighbouring module signals acceptance with `SaveHeader.REFUSE_NONE`, and this checker
forwards `SaveHeader.Refusal.code` values from `rebuild_into` and `codec.owner_refusal`
verbatim into `Result.code`. "On success code empty" must be restated as
`SaveHeader.REFUSE_NONE`, or a forwarded accepting code and a checker empty code become two
different successes.

## 3. Stricter-than-reachable-world risks

**S-1. "active identity full-pair mirrors the Directory" must exclude the zone basin pair.**
`destroy_zone` clears the destroyed row's own `_zone_basin_*` but does NOT clear
`_zone_basin_slot/_zone_basin_generation` on other zones that pointed at it, and
`_release_claims_of_zone_slot` only releases claims. A present, claim-free zone can
therefore legitimately carry a dangling basin pair. The draft only constrains basin
self-binding through a claim, which is correct — but the blanket "full-pair mirrors the
Directory" sentence reads as covering `zone_basin_*` too. Scope it explicitly to the
self-reference pair, or the checker refuses reachable healthy worlds.

**S-2. Fishing quantity 1..6 and effort capacity 1..6 are not derivable from the supplied
source.** `EFFORT_SLOTS_BY_TYPE` is elided in `followup-sources.md`
(`const EFFORT_SLOTS_BY_TYPE: Array[int] = [`), so the maximum habitat effort capacity is
unproven. The `0..6` tolerance for an inactive row after `destroy_habitat` is correct in
shape — that function never zeroes `_habitat_effort_slots` — but the numeral 6 is asserted,
not derived. Supply the constant or express the bound symbolically.

**S-3. Forage 1..1180000 conflates a zone quota ceiling with a per-claim amount.**
`MANUAL_QUOTA_MAX_MILLI = 1180000` bounds a MANUAL quota; `claim_forage` refuses only
`amount_milli <= 0`, and the upper bound arrives through `_may_reserve_quota`, whose body
is not supplied. Automatic-mode ceilings are not shown. Either supply `_may_reserve_quota`
/ `_check_claim_limits` or downgrade the upper bound to the codec's i64 domain and let the
aggregate comparison carry the real constraint.

**S-4. Owner block indices 0 and 1 are asserted, not read.** `save_resource_claims_restore.gd`
uses `Codec.OWNER_FISHING` / `Codec.OWNER_FORAGE`; the codec is not among the inputs, so
"fishing index 0 / forage index 1" is unverified. Cite the constants, not the literals.

**S-5. `NULL_GENERATION == 0` is assumed.** `NULL_SLOT == -1` is confirmed by
`save_section_directory.gd`'s declared unused values; `NULL_GENERATION` is never shown.
The "generations 0" clause for inactive rows and empty patch refs rests on it.

## 4. Hidden allocation and mutation of the reused Directory validator

Beyond G-1: `rebuild_into` also allocates a `SaveHeader.Refusal` per gate and formats
`String` details, and `_capacity_refusal` can refuse on `RESIDENT_LIVING_CAP` — a rule
wholly unrelated to claims — under a preserved `SAVE_DIR_LIVING_CAP` code. The contract
says underlying Directory codes are preserved, which is right, but the evidence list should
name at least one such non-claim Directory refusal so the pass-through is witnessed rather
than assumed. No mutation of caller state was found: `Derived.clear()` touches only the
checker's private object, and `apply` / `restore_columns` are correctly excluded.

## 5. Missing reverse mirrors and unresolved high-level semantics

**M-1. Deliberate absences should be stated, not left silent.** There is no Expedition
component array, so no Directory→component bijection exists for `KIND_EXPEDITION`; and a
zone is never required to own patches. Both are correct, but an implementer reading
"This is a bijection, not only a forward check" will be tempted to add a spurious
live-Expedition mirror and an all-five-patch rule. Record both as explicit non-rules.

**M-2. The once-when-equal single count rests on one half of the pair.**
`_release_claim_row` debits the basin and the designation only when
`designation_slot != basin_slot`. The symmetric reserve side, `_may_reserve_quota` /
`_reserve_quota`, is not supplied. The rule is almost certainly right; it is currently
inferred from the release path alone and should be closed with that source.

**M-3. Aggregate-failure localization is unspecified.** On a habitat or zone total
mismatch, `owner` and `row` must identify the component row, not a claim; the draft's
"first offending claim or component row" leaves it to the implementer. Fix jointly with G-4.

**M-4. The shape gate is specified twice over.** `save_resource_claims_restore.gd` already
exposes pure statics `fishing_block_shape_refusal` / `forage_block_shape_refusal` whose
docstrings state the exact reason this ordering exists — `owner_refusal` "assumes a
well-shaped block and would index columns a hostile block need not have". Reusing them is
the honest move, but that module preloads `fishing.gd`, `forage.gd` and `sim_clock.gd`,
which a pure checker must not drag in. Decide and record: either lift the two shape gates
into the codec, or accept a documented duplicate. Leaving it unstated produces a silent
third copy of the same gate.

**M-5. Gate order pays the expensive step first.** "Directory structure/cursor" precedes
"section 7 block identity/shape", so a malformed §7 block still costs a full
352418-slot rebuild plus G-1's two duplicates. Correctness is unaffected; state whether the
order is deliberate (determinism of the first code) or should be cheapest-first.

## 6. Evidence and dispatch gaps

**E-1. No listed test drives the reverse Directory walk.** The test list covers wrong
kind/typed row and component domains, but not "a live Directory Habitat / HarvestZone / Job
entry whose component row is absent". Add it; it is the only witness for the bijection's
second direction.

**E-2. No mutant covers the bijection.** The four mutants (skip live provenance, skip
zero-claim aggregate rows, double-count equal designation/basin, reinterpret stale owner)
leave "skip the reverse Directory walk" unkilled — the exact mutation E-1 exists to catch.

**E-3. The 7-test / 95-assertion public fixture is correctly scoped.** It witnesses claim
row == Job typed row with a differing Directory slot, tick 1234, the exact PID, one patch
of five, basin- and designation-deletion release, the refused rebind of a claimed basin,
cancelled-then-released, and post-admission membership. The contract's statement that it
does not validate this unimplemented checker is accurate and should stay.

## 7. Verdict

The implementation-versus-binding split is sound and the §4 codec absence is handled
honestly: the projection classes are declared NEW, the omitted §4/§5 fields are disclaimed,
no binding token is manufactured, and SAVE-CLAIM-WORLD-BINDING retains ownership of
provenance, descriptor versions and coordinator invocation. The refusal to impose
`created_tick <= world_tick`, the stale-preserving provenance ladder, the
future-generation refusal, the terminal-retired-generation allowance, the partial-patch
subset rule and the all-128-rows zone comparison are all consistent with the supplied
calls. Draft1 is not acceptable as written: G-1 through G-7 are contract defects and S-1
would refuse a reachable healthy world. None requires new runtime work; all are resolvable
by amending draft1 and supplying `_may_reserve_quota`, `_check_claim_limits` and
`EFFORT_SLOTS_BY_TYPE`.

## 8. Explicit non-claims

No test was run, no file executed, no code edited, no overflow reproduced, no world loaded,
and no release-save, SAVE-CAPTURE, SAVE-ORCHESTRATOR or first-playable readiness is
asserted. Findings derive only from the supplied excerpts; where a body was not supplied
that is recorded as a gap, never as a defect.

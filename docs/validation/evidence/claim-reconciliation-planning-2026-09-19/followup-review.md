# SAVE-CLAIM-RECONCILIATION — follow-up bounded review

Read-only. Inputs: `followup-sources.md`, `followup-registry-snapshot.json`,
`followup-astra-questions.md`, `astra-audit-disposition.md`, `feasibility-review.md`.
Nothing was written, run, executed or tested by this reviewer. No gameplay rule is
invented; where the supplied source is silent the item is listed in §5 instead of
answered. This review closes no blocker and does not authorize implementation.

## 1. Proposed rules CONFIRMED by the new source

**C-1. FISH-ID-R01 repair is visible in the schema.** Section 7 `fishing` is
`owner_schema_version: 2` and carries both `_effort_claim_expedition_slot`
(ordinal 7) and `_effort_claim_expedition_generation` (ordinal 1). D3 is not
reopened here.

**C-2. Destroy-before-purge stays legitimate.** `jobs.gd destroy_job` (914–942)
refuses only on a held worker or on a coordinator with members, unlinks a member,
then calls `_directory.destroy(ref)`. It touches no claim table. `purge_stale_claims`
(forage 2483–2500) and `purge_stale_effort_claims` (fishing 1785–1803) remain the
only release paths. Preserving dead-owner claims as stale continuation is correct.

**C-3. A claim-holding Job can legitimately become a member.** `set_coordinator`
(jobs 1520–1537) refuses a member only for `remaining_mwu != 0`, an existing party,
self-coordination and coordinator/member role conflicts. A Job holding a forage
claim with `remaining_mwu == 0` can be attached afterwards. No refusal may be
invented for membership. The same holds for `JOB_STATE_CANCELLED`: no supplied path
couples cancellation to claim release, and `_should_release_cancelled_claim` is
recorded absent, so a saved cancelled-owner claim is not evidence of corruption.

**C-4. Fishing ecology refs: "absent ⇒ incoherent" holds.** `destroy_habitat`
(fishing 1050–1074) refuses with `REFUSE_EFFORT_SLOTS_RESERVED` while
`_habitat_effort_used[slot] > 0`, so the ordinary owner API cannot orphan an effort
claim's habitat. A saved effort claim whose habitat ref fails
`habitat_slot_of_into` therefore indicates owner/Directory incoherence (e.g. a
direct low-level `Directory.destroy`), exactly as Astra proposes — for fishing only.

**C-5. "Wrong typed row with a fully live pair is malformed" holds for fishing.**
`_refuse_stored_effort_claim` (1767–1784) and `purge_stale_effort_claims` both
require `get_typed_row(expedition_ref) == row`; `FISHING_EFFORT_CLAIM_CAPACITY` is
512, matching the Directory's Expedition extent, so the claim row IS the owner's
typed row. A live ref's typed row is immutable, so a live pair with a mismatched row
is unreachable through the shown API. Note the *stale* case is ordinary staleness,
not malformation: `purge_stale_effort_claims` releases it silently by design.

**C-6. No current-quota fit, but saved capacity bounds totals.** Confirmed from the
registry: `_habitat_effort_slots` (§4 fishing ord 5) and `_habitat_effort_used`
(ord 12) are both saved, and `_refuse_stored_effort_claim` requires
`_effort_claim_slot_count[row] > 0`. Forage's `_zone_quota_reserved_milli` (§4
forage ord 12) is saved with `MANUAL_QUOTA_MAX_MILLI = 1180000` bounding admission.

## 2. Counterexamples — rules that CANNOT be adopted as written

**X-1 (blocking). The forage order-key rule contradicts the public claim path.**
`_write_claim` (forage 2282–2305) sets
`_claim_created_tick[row] = _jobs.created_tick_of(row).value` — indexed by the
**claim row**, not by the owning Job's typed row. `_refresh_claim_order_key`
(2776–2785) does it correctly via `_directory.get_typed_row(job_ref)`. Because
`created_tick_of` returns `_read(code, 0)` on refusal (`_check_job_slot`, jobs
806–814), a freshly admitted claim stores either 0 or an unrelated live Job's tick.
A later `rebuild_reservation_aggregates` would overwrite it with the true value, so
the saved column legitimately holds either number depending on world history.
Therefore "live Forage order keys must match created_tick" would refuse reachable
healthy worlds. The persistent-ID half is unaffected: `_claim_persistent_id` is read
from `get_persistent_id(job_ref)` and is sound.

**X-2 (blocking for forage). "Absent ecological refs are malformed" is false.**
`_claim_is_over_allowance` (forage 2579–2589) begins by resolving basin and
designation and returns `true` when **either** is `NULL_SLOT` — "its zone is gone".
The engine's own ordinary path therefore expects live claims whose zone refs no
longer resolve and disposes of them through the normal over-allowance release, not
through refusal. A save captured before that pass legitimately contains them.
Second, `destroy_zone` (878–908) calls `_release_claims_of_zone_slot(slot)` — whose
body was not supplied — and the accompanying docstring speaks only of "its
outstanding claims", i.e. claims this designation owns. Claims held by a *different*
designation that name the destroyed zone as **basin** (`_claim_basin_slot/
_claim_basin_generation` are separate saved columns) are not shown to be released.
Until `_release_claims_of_zone_slot` is supplied, absent forage ecology must be
classified as deferred-stale, never as refusal.

**X-3. Rebinding strands live claims on a patch-less basin.** `set_basin`
(forage 1239–1266) refuses a zone that owns patches and refuses a *target* basin
that is itself bound elsewhere, but nothing shown refuses rebinding a zone that
**other** zones already use as their basin. Given X→D (D self-bound, with patches?
no — D must be patch-free to be rebound), rebinding D to B2 leaves X's stored
`basin_ref = D` fully live while `basin_slot_of_into` resolves only one hop, so
`patch_row_for_zone_into(X, kind)` (1408–1423) refuses with
`REFUSE_PATCH_NOT_PRESENT`. Consequently a reconciler must not assert "a claim's
basin ref names a self-bound basin" nor "the (basin, kind) patch row is present".
Also note `set_basin` releases only `_release_claims_of_zone_slot(slot)`.

**X-4. Patch presence is not a usable invariant yet.** Claims store
`_claim_patch_kind`, not a patch row. `create_patch_set` (1364–1385) pre-validates
every kind and then calls `create_patch` in a second loop, returning early on a
failure there; whether that early return can leave a partially populated basin
depends on `_refuse_create_patch`, which was not supplied. Do not assert
"all five patches present or none".

## 3. Answers to the specific questions

**A-1. Can the read-only math/identity contract be accepted now?** Yes, restricted
to rules that depend only on frozen semantics: (a) the ARCH-ID-003 predicate as
written in `is_valid_of_kind` (261–278) including the reverse-owner check; (b) sum
of active effort-claim `slot_count` per resolved habitat row == saved
`_habitat_effort_used`, and `<=` saved `_habitat_effort_slots`; (c) sum of active
`_claim_remaining_milli` per **resolved** basin row == saved
`_zone_quota_reserved_milli`, counted once when designation and basin resolve to one
row (D-8 preserved); (d) `slot_count >= 1`; (e) stored persistent ID in
`[1, _next_persistent_id)` for a claim whose owner ref is live; (f) dead-owner
claims classified stale and deferred, never released by the checker. Rules X-1..X-4
must be dropped or deferred. Implementation stays blocked on §4/§5 decode surfaces.

**A-2. Implementation vs activation prerequisites.** *Implementation* needs only a
decoded, immutable record view of the fields in A-3 plus §3 Directory columns — no
coordinator, no disk loader, no typed-owner snapshot. *Activation* additionally
needs: a single-file/single-world binding proof across §1/§3/§4/§7; a deferral
channel that reaches the normal pipeline after publication; and disposition of X-1
(either repair `_write_claim` or permanently drop the created_tick rule) and X-2
(supply `_release_claims_of_zone_slot`).

**A-3. Sufficient section 1/3/4 fields.** §1 `entity_directory._next_persistent_id`
(PID bound). §3 `_active`, `_generation`, `_retired`, `_persistent_id`, `_kind`,
`_typed_row`. §4 fishing: `_habitat_present`(0), `_habitat_effort_slots`(5),
`_habitat_ref_slot`(10), `_habitat_ref_generation`(11), `_habitat_effort_used`(12).
§4 forage: `_zone_present`(0), `_zone_ref_slot`(7), `_zone_ref_generation`(8),
`_zone_basin_slot`(9), `_zone_basin_generation`(10),
`_zone_quota_reserved_milli`(12). §4 jobs: `_job_present`(0), `_job_ref_slot`(16),
`_job_ref_generation`(17). §7 both claim owners in full.

**A-4. Unrelated — do not bind.** §1 `forage._tile_link_head`; all §5 forage link
fields (`_link_*`, `_zone_link_head`, `_zone_tile_count`); §5 jobs coordinator
fields (`_coordinator_slot/_generation`, `_member_head`, `_member_next`) — C-3 makes
membership non-refusable; §4 jobs scheduling/agent fields (`_priority`, `_urgency`,
`_state`, all gates, all `_agent_*`, `_job_scan_cursor`, `_continuation_bucket`);
§4 fishing stock/environment fields; §4 forage `_patch_*`, `_zone_type`,
`_zone_danger`, `_zone_quota_milli`, `_zone_protected`, `_zone_enabled`,
`_zone_harvested_today_milli`, `_zone_quota_mode`. `_created_tick`(15) and
`_patch_present`(1) / `_zone_patch_count`(5) become relevant only if X-1 / X-3–X-4
are resolved in favour of those rules.

**A-5. Input API.** Do not name or assume any codec, snapshot or orchestrator
symbol. Specify the contract as pure predicates over caller-supplied immutable
column views with an explicit caller-provided binding token, plus a written
precondition that the caller has proven all views came from one file and one world.
That keeps the contract authorable today and implementation blocked until the §4/§5
codecs exist with an owner.

## 4. Result for Astra

One concrete missing prerequisite lane, not a generic re-audit: **forage claim
release scope and order-key provenance**. It comprises X-1 (`_write_claim` row
indexing) and X-2 (`_release_claims_of_zone_slot` scope: designation-only or
designation+basin). Everything else in the proposal is either confirmed (§1) or can
be finalized now with the X-3/X-4 assertions simply omitted.

## 5. Exact source still required

1. `forage.gd _release_claims_of_zone_slot` and `_release_claim_row` (full bodies).
2. `forage.gd _typed_zone_row_of` and `_zone_is_over_allowance`.
3. `forage.gd _refuse_create_patch`, `_release_zone_patches`, and any public
   per-patch removal entry point.
4. `fishing.gd _release_effort_claim_row`, `_refuse_effort_claim_job`, and the
   reserve/release effort-slot entry points that maintain `_habitat_effort_used`.
5. `entity_directory.gd create` / `_publish_row` (generation bump on slot reuse and
   the initial `_next_persistent_id`), to close the aliasing argument in C-5 from
   source rather than from the historical witness alone.
6. `jobs.gd` cancellation/state transition path, to confirm C-3's cancelled half.
7. §4 and §5 wire order for the A-3 fields once those codecs are authored.

## 6. Explicit non-claims

No runtime execution, no test run, no code edit, no overflow reproduction, no world
coordination, no disk loading, and no release-save readiness is asserted here. The
counterexamples in §2 are derived from the supplied excerpts only; where a body was
not supplied that is stated as a gap, not as a defect.

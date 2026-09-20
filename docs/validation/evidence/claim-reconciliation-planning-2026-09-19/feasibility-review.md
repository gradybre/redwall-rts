# SAVE-CLAIM-RECONCILIATION — feasibility review

Read-only audit, 2026-09-19. No source was written, run or tested. Inputs: the four
immutable source excerpts in this folder, `docs/planning/resource_claim_columns_contract.md`
(SAVE-CLAIMS-R01 v2), `docs/rulings/2026-09-11_save_codec_contract.md`,
`docs/planning/save_implementation_matrix.md` and `architecture-excerpts.md`.
Everything below is either cited to those texts or labelled as an open question.
This review does not authorize implementation and closes no blocker.

## 1. Demonstrable defects and hard facts in the supplied source

**D-1. The legacy "read-only half" is not read-only.** `validate_effort_aggregates()`
(fishing 1610–1820) delegates to `_accumulate_effort_totals()`, which does
`_effort_total_scratch.fill(0)`, accumulates into it and assigns
`_effort_claim_count = counted` before any comparison. A caller that only wanted to
know whether a snapshot is self-consistent has already overwritten scratch and the
native count. It therefore cannot serve as the pre-activation checker, exactly as
`astra-source-notes.md` suspected, and SAVE-CLAIMS-R01 already forbids it.

**D-2. `rebuild_reservation_aggregates()` rewrites canonical fields.** Forage
2712–2790 zeroes the whole `_zone_quota_reserved_milli` column and calls
`_refresh_claim_order_key(row)`, which overwrites `_claim_created_tick` and
`_claim_persistent_id` from the *current* Jobs/Directory state. Under the exact-save
contract those two columns are restored verbatim and must not be reinterpreted as
caches; any reconciler that calls this helper destroys the evidence it was meant to
check. `rebuild_effort_aggregates()` (fishing 1610–1820) likewise publishes
`_habitat_effort_used` from scratch, i.e. repairs the saved section 4 column.

**D-3. Fishing claim ownership is not uniquely identified by what is saved.**
`effort_claim_expedition_ref_of(row)` rebuilds the owner as
`(owner_slot_of_typed_row(KIND_EXPEDITION, row), _effort_claim_expedition_generation[row])`
(fishing 1610–1820). Directory generations are **per slot**: `_publish_row()` starts
every fresh slot at 1 and increments on reuse (`entity_directory` excerpt,
ARCH-ID-002). So if the claiming Expedition is destroyed and its typed row is later
allocated to a *different directory slot* whose generation happens to equal the
stored generation — generation 1 is the common case — the reconstructed pair passes
`is_valid_of_kind()` **and** the `get_typed_row(expedition_ref) == row` check in
`_refuse_stored_effort_claim()`/`purge_stale_effort_claims()`. A stale claim is then
indistinguishable from a live one, and the stale sweep will not release it. This is
structural, not hypothetical: nothing in the saved seven columns records the owning
slot or a persistent ID. Forage does not share this defect — it stores
`_claim_job_slot` and `_claim_job_generation`, the full directory reference
(forage 2265–2308), and `claim_row_of_into()` compares both.

**D-4. Unbounded indexing by typed row.** `_refuse_effort_owner()` reads
`_effort_claim_active[row]` (fishing 1435–1568) and `_check_claim_owner()` reads
`_claim_active[job_slot]` (forage 2070–2225) immediately after `get_typed_row()`,
with no range check. `claim_row_of_into()` *does* bound-check against
`FORAGE_CLAIM_CAPACITY`, which shows the authors knew the row and the capacity are
not the same domain. Whether this is reachable depends on `KIND_CAPACITY[KIND_JOB]`
and `KIND_CAPACITY[KIND_EXPEDITION]`, which were not supplied (§4 below). If either
exceeds 8192 / 512 this is a live out-of-range read, not merely a review note.

**D-5. Destroy leaves claims behind.** `Jobs.destroy_job()` (jobs 914–975) calls
`_directory.destroy(ref)` and clears the job row; it touches no claim table. The
directory `destroy()` frees the typed row back onto the free heap immediately. The
only paths that release an orphaned claim are `purge_stale_claims()` /
`purge_stale_effort_claims()` and the cancelled sweeps. A save taken between the
destroy and the next sweep therefore legitimately contains claims with dead owners.

**D-6. Silent zeroes on refusal.** `created_tick_of()`/`job_id_of()` return
`_read(code, 0)` on refusal (jobs 1019–1137) and `get_persistent_id()` returns 0 for
a stale reference (directory excerpt). `_write_claim()` stores `.value` directly
(forage 2265–2308). A stored `persistent_id == 0` is thus either a refused read or a
real ID, and the two are not separable from the claim columns alone — the
zero-PID anomaly SAVE-CLAIMS-R01 flags for coordinator provenance checking.

**D-7. Missing referents are skipped, not reported.** `_release_claim_row()` and
`rebuild_reservation_aggregates()` resolve zones through `_typed_zone_row_of()` and
simply omit `NULL_SLOT` results (forage 2400–2560, 2712–2790);
`_release_effort_claim_row()` skips the debit when `habitat_slot_of_into()` fails
(fishing 1435–1568). No legacy path distinguishes "claim against a destroyed zone"
from "claim correctly accounted". A checker built by analogy with these helpers
would pass a save whose ecological state is missing.

**D-8. Identity of basin and designation is tested on resolved typed rows.**
`_may_reserve_quota`/`_reserve_quota` (forage 2265–2308), `_release_claim_row` and
the rebuild all guard with `designation_slot != basin_slot` **after** resolution,
while `_release_claims_of_zone_slot()` matches on `(slot, generation)` reference
pairs (forage 2400–2560). The new checker must count once on the *resolved row*, or
a claim whose two references resolve to one zone will be double-counted.

**D-9. Checked arithmetic is asymmetric.** The admission path uses
`IntMath.checked_add_into` (forage 2265–2308); the rebuild uses raw `+=`. With the
declared fixed bounds (`8192 * 1180000 = 9666560000` in i64; `512 * 6 = 3072` in
i32, per SAVE-CLAIMS-R01) claim-only sums cannot overflow. **No public-API overflow
is demonstrated here and none may be inferred from forged codec input.** Checked
arithmetic in the reconciler is an integration requirement, not a bug report.

## 2. Probable constraints Astra should treat as binding

- **P-1.** Because of D-5, "every restored claim must have a live owner" would reject
  reachable, valid worlds. A save-boundary policy must admit destroy-before-purge
  continuation while still refusing incoherent snapshots.
- **P-2.** ARCH-ID-003 requires a stale *mandatory* reference to cancel its dependent
  job through the normal release pipeline with one grouped notice. That pipeline is
  gameplay, not loading; SAVE-CLAIMS-R01 forbids `purge_*`, `release_cancelled_*`,
  `reconcile_claims` and `run_midnight` at the load boundary. So the reconciler can
  only *classify and defer*, never release, and the deferral must reach the normal
  pipeline after publication.
- **P-3.** The exact-save prohibition forbids hidden repair: no clamp, no re-derived
  order key, no zeroing of a mismatched aggregate. A mismatch is a refusal or a
  recorded deferral, never a silent fix.
- **P-4.** Totals must be compared across the **whole** saved column, including zones
  and habitats with zero claims; otherwise a nonzero saved total no claim accounts
  for survives. `validate_effort_aggregates()` iterates all `FISH_HABITAT_CAPACITY`
  rows and is the right shape, minus its mutations (D-1).
- **P-5.** Fishing's per-habitat capacity check (`slot_count > free`) exists only on
  the live path; `restore_effort_claim()` checks against `_habitat_effort_slots` but
  the new structural restore checks only `1..6`. Per-habitat capacity is therefore a
  coordinator obligation, as SAVE-CLAIMS-R01 already states.

## 3. Decisions Astra must make before authoring the contract

1. **Input form.** Does the checker consume decoded section records or post-apply
   typed owner snapshots? Section 4 and 5 codecs do not exist
   (`save_implementation_matrix.md` §1, §4), and Job `created_tick`, persistent ID,
   state and member flag live there. Comparing against *saved* §4 columns, as the
   review disposition requires, is gated on `SAVE-S4-CODEC`, which has no owner.
2. **World binding.** How are §1/§3/§4/§7 records proven to come from one file and
   one world? No orchestrator exists; the header/§12/§1 cross-checks of
   SAVE-REPLAY-R01 are not a coordinator. Do not assume world coordination exists.
3. **Stale-owner policy.** Which of {refuse load, admit and defer to the first
   normal sweep, admit and quarantine} applies to each of: dead Job/Expedition;
   live entity of the wrong kind; live owner whose typed row disagrees; live Job
   whose `created_tick`/persistent ID disagree with the stored order key.
4. **Fishing owner identity (D-3).** Accept typed-row+generation as structural only
   and require an independent binding (Expedition store's own job reference, or a
   persistent ID cross-check), or accept a documented aliasing exposure. This cannot
   be resolved from the claim columns alone.
5. **Zero order keys.** Is `persistent_id == 0` on a claim with a live Job always an
   anomaly? Depends on the directory's initial `_next_persistent_id` (§4).
6. **Missing ecology.** Refusal versus recorded deferral for a claim naming a zone or
   habitat that no longer exists, and whether a zeroed legacy aggregate elsewhere may
   ever excuse it. The notes say it must not; the contract should say so explicitly.
7. **Queue gating.** Whether SAVE-CLAIM-RECONCILIATION may be dispatched before
   `SAVE-S4-CODEC`/`SAVE-S5-CODEC`, and what it is permitted to assert if not.
8. **Deferral channel.** Where a classified stale claim is recorded so the normal
   pipeline can act on it after publication without the loader mutating claim state.

## 4. Source still required for a complete audit

- `KIND_CAPACITY` / `_kind_base` and `KIND_JOB`, `KIND_EXPEDITION`,
  `KIND_HARVEST_ZONE` constants, and the initial `_next_persistent_id` (D-4, D-6).
- The Expedition store: creation, destruction, its `Directory.destroy` caller, and
  whether it holds its own job/coordinator reference usable for D-3.
- Fishing `habitat_slot_of_into`, `_habitat_effort_slots`, `EFFORT_SLOTS_BY_TYPE`,
  `destroy_habitat`, `FISH_HABITAT_CAPACITY`.
- Forage `zone_slot_of_into`, `is_zone_present`, `destroy_zone`,
  `patch_row_for_zone_into`, `_claim_is_over_allowance`, `PATCHES_PER_ZONE`,
  `MANUAL_QUOTA_MAX_MILLI` and the zone/patch save owners (§1/§4/§5).
- `jobs.gd` `_check_job_slot`, `is_member`, `state_into`, and the job capacity.
- Section 4 and 5 owner schemas for Jobs and for the habitat/zone aggregate columns
  the checker is required to read.
- `IntMath.checked_add_into` and `IntMath.IntResult` refusal semantics.

## 5. Concrete test witnesses the contract should demand

- **W-1 (D-3).** Real public world: create Expedition A, claim effort, destroy A,
  create B such that B occupies A's typed row from a different directory slot with
  generation equal to A's stored generation. Snapshot, restore, assert the checker
  reports a stale/aliased owner rather than accepting B as the owner.
- **W-2 (D-5).** Public `Jobs.destroy_job()` on a claim-holding Job with no sweep
  before capture; assert the save is classified as legitimate continuation and that
  the claim is released only by the normal pipeline after publication.
- **W-3 (D-1/D-2).** Assert `_effort_claim_count`, `_effort_total_scratch`,
  `_habitat_effort_used`, `_zone_quota_reserved_milli`, `_claim_created_tick` and
  `_claim_persistent_id` are byte-identical before and after every checker call, on
  both passing and refusing inputs.
- **W-4 (P-4).** Saved habitat/zone totals nonzero with zero matching claims, and
  zero with claims present; both must refuse, per column, for every row.
- **W-5 (D-8).** A claim whose designation and basin references resolve to the same
  zone row: counted once. A second claim whose distinct references resolve to two
  rows: counted twice.
- **W-6 (D-7).** Claim naming a destroyed zone / destroyed habitat: distinct outcome
  from a live but mismatched total, and never silently skipped.
- **W-7 (D-6).** Live Job whose `created_tick`/persistent ID differ from the stored
  order key; and a live Job with a stored `persistent_id == 0`. Both reported as
  provenance anomalies with the saved columns unchanged.
- **W-8.** Claim referencing a live entity of the wrong kind, and one referencing a
  live unrelated entity that passes bare `is_valid()` but not `is_valid_of_kind()`.
- **W-9 (D-9).** Full-table maxima (512x6 fishing, 8192 x MANUAL_QUOTA_MAX_MILLI
  forage) summed through checked arithmetic, with the test title stating this is a
  bound exercise and not an overflow reproduction.
- **W-10.** Forged-codec inputs admitted by the codec but refused by the owner
  domains: assert refusal, unchanged store, unchanged input, and no repair. These
  are test-only fixtures and must not be titled as healthy public witnesses.

## 6. Explicit non-claims

No public-API overflow, no world coordination, no orchestrator, no disk loading and
no release-save readiness is asserted here. `release_save_ready` remains false. This
review neither shrinks nor tightens any product rule; where the source is silent the
question is recorded in §3 rather than answered.

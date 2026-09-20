# Independent source review — SAVE-CLAIM-CHECK-R01 v2 / decision 0168

Reviewer: Claude (independent source/contract review lane). Date: 2026-09-20.
Scope: `godot/scripts/core/save_resource_claims_reconcile.gd` against
`docs/planning/resource_claim_reconciliation_contract.md` and ADR 0168, plus the
three test files and `save_section_directory.gd` supplied as source references.
This review reads source only. No suite, static pass, editor or CI run is claimed
here; the parent's first-focus figures (51 tests / 2253 assertions / 0 failures)
and the in-flight full suite are reported by the parent, not by me.

## Verdict

The implementation is a faithful mapping of the accepted contract. I found no
behavioural defect that contradicts a contract clause. I record three MEDIUM
follow-ups (two imported preconditions, one allocation caveat), three LOW notes,
and five meaningful missing tests. None of them is the separately gated
SAVE-CLAIM-WORLD-BINDING integration, which I deliberately do not count.

## What I checked and confirmed

* Exact API. `validate(directory, next_persistent_id, fishing, forage, components)`
  -> `Result` matches character for character. `Components._init` creates all three
  subrecords. `Result` carries `code/detail/owner/row_space/row`, the two counts,
  the three stale counts and `is_ok()`. Counts are published only through
  `_succeed`, so no refusal path can publish a partial count; `_refuse` leaves all
  five at zero. Success sets code `SaveHeader.REFUSE_NONE`, empty detail, empty
  owner/row_space, row -1. Result is constructed per call and stored nowhere.
* Field spellings. All five Fish, nine Forage and four Job members match the
  contract's exact spellings with no stored underscore prefix.
* Refusal order. `validate` runs null (incl. the three subrecords) -> component
  extents -> Fishing then Forage block shape -> `rebuild_into` -> cursor -> codec
  owner domains Fishing then Forage -> components (fish rows, zones, patches, jobs,
  reverse Directory slots) -> Fishing claims ascending -> Forage claims ascending
  -> Fishing aggregates -> Forage aggregates. That is the contract's gate list in
  the contract's order, with the diagnostics table's owner/row_space/row triples
  honoured at every site I traced.
* Preflight localization. `_refuse_preflight` always emits empty owner, empty
  row_space and row -1, and forwards underlying Directory and codec `code`/`detail`
  unchanged. `SaveSectionDirectory` refusal codes are not rewritten.
* New classes and private allocation. One `SaveSectionDirectory.Derived` is
  allocated privately and passed to `rebuild_into`; no caller Derived is borrowed
  or mutated, and `apply`/`agrees_with_directory`/the legacy Fishing and Forage
  rebuilders are never called.
* Allocation arithmetic, recomputed rather than trusted. Fish 32 + 4x32x4 = 544.
  Forage zones 128 + 4x128x4 + 128x8 = 3200; patches 640 + 2x640x4 = 5760; 8960.
  Jobs 8192 + 2x8192x4 + 8192x8 = 139264. Total 148768, as stated. `Derived` is
  352418x4 + 2x18x4 = 1409816. `Sums` is 32x8 + 128x8 = 1280. The two charged
  1409672 sort copies are real: `_domain_refusal` duplicates `generation` and
  `_persistent_id_refusal` duplicates `persistent_id`, both inside the single
  `rebuild_into` call, sequentially. 1409816 + 1280 + 2x1409672 = 4230440 holds as
  a conservative bound. Native object overhead is correctly excluded from the
  packed-payload figures and is documented as separately unmeasured.
* Read-only discipline. Every component and claim access is a read. The only
  writes are to the module's own `Result`, `Sums` and the caller-supplied
  `IntMath.IntResult` scratch. No canonical total, aggregate, scratch or ordering
  key is written; no cleanup, purge or release is invoked.
* Identity predicate. `_live_typed_row` checks bounds, active, generation, kind,
  typed range and reverse owner through the rebuilt map, and never reconstructs an
  owner reference from a claim's typed row.
* Future / stale / live. `_pair_state` refuses only `generation > saved`; an older
  generation or an inactive slot is stale regardless of the slot's current kind,
  which is exactly the "dead historical ownership" rule, including the terminal
  retired generation on an inactive slot. Stale never short-circuits ecology,
  provenance, quantity or accumulation.
* Mirrors and the bijection. Forward self-mirrors for habitat, zone and job rows,
  plus `_reverse_component_gate` walking live Directory slots ascending for those
  THREE kinds only. No Expedition component is invented. Patch ownership is
  `row / PATCHES_PER_ZONE` with an exact pair mirror, and no zone is required to
  own all five patches.
* Provenance. `_forage_provenance_gate` orders lower bound, upper `MAX_INT32`,
  cursor, then live PID, then live tick — the contract's order. The live-tick
  comparison indexes `jobs.created_tick[row]`, which is sound only because the
  live branch has already refused `job_row != row`; that dependency is real and I
  verified it rather than assuming it.
* Ecology. Both refs resolve to present zones; designation's saved basin pair must
  equal the claim's; the basin must be self-bound; the specific patch at
  `basin_row * 5 + patch_kind` must be present and mirror the basin.
* Aggregates. All 32 habitat rows and all 128 zone rows are compared, including
  rows with no claim. The designation total is added only when the resolved rows
  differ, so a shared designation/basin is counted exactly once.

## Findings

F1 (MEDIUM, imported precondition). `_pair_state` indexes
`directory.generation[slot]` and the claim gates later index
`directory.generation[expedition_slot[row]]` in detail strings without a local
bounds check. The contract states the section 7 codec domains already refuse
out-of-range slots and zero generations, and the module relies on that. The codec
`SaveSectionInventories.owner_refusal` source was not supplied to this review, and
`test_resource_claim_columns.gd` demonstrates the codec is deliberately WEAKER
than the owner column validator for at least two fields (it admits fishing
`slot_count` 7 and forage `remaining_milli` 1180001/0). The slot-bounds assumption
therefore cannot be confirmed from the supplied sources. If the codec does not
bound claim slots to `[0, DIRECTORY_CAPACITY)`, this is an out-of-range index, not
a refusal. Recommend an explicit assertion of that codec precondition.

F2 (MEDIUM, imported precondition). Same class, higher exposure:
`patch_row = basin_row * PATCHES_PER_ZONE + patch_kind[row]` is computed and used
to index `zones.patch_present` with no local domain check on `patch_kind`. The
owner column validator refuses -1 and 5 (`COLUMN_FORAGE_CLAIM_KIND`), but that
validator is not what the checker calls. A `patch_kind` of, say, 40 admitted by
the codec would index past the row's zone and, at the last zone, past the array.

F3 (MEDIUM, allocation). The contract asserts "no copy of the claim arrays". The
implementation calls `block.u8_column/i32_column/i64_column` once per column per
gate. That claim holds only if those accessors return copy-on-write views. If any
of them returns `.duplicate()`, the Forage gate alone materializes roughly 420 KiB
of claim columns that the stated bound does not charge. Confirm the accessors.

F4 (LOW, unreachable predicate). In `_fishing_total_gate`, the
`total > habitat_effort_slots[row]` branch is unreachable for a present row: the
component gate already proved `used <= slots`, and this branch runs only after
`total == used`. The contract's "AND total <= capacity" is therefore implied. No
test can kill a mutant that deletes this comparison.

F5 (LOW, unreachable predicate). Both "absent row is claimed for N" branches
(habitat and zone) are unreachable, because the ecology gates refuse any claim
naming a row that is not present before accumulation. They are correct defence in
depth, but they are not mutant-covered either.

F6 (LOW, confirmed safe). The parent's substitution of
`ForageScript.HARVEST_ZONE_CAPACITY` for the literal 128, and the removal of the
false "no module publishes it" comment, are safe: `_extent_gate` cross-checks
habitat, zone, job and expedition capacities against `KIND_CAPACITY` before any
indexing, so a drift between the owner constant and the Directory kind table
refuses with `CLAIM_CHECK_SHAPE` rather than mis-indexing.

## Meaningful missing tests

M1. Forage live Job whose Directory typed_row differs from the claim row. The
fishing analogue exists (`test_fully_live_owner_must_map_to_the_claim_row`), but
the forage `job_row != row` branch has no test, although "claim row IS owning Job
typed row" is the central forage provenance rule.
M2. Claim-independent present-patch `CLAIM_CHECK_COMPONENT` at
`forage/patch/row`: both the absent-owning-zone case and the mirror-mismatch case.
The suite only clears a patch and observes the claim-side ECOLOGY refusal, so the
contract's explicit "COMPONENT at that patch row" diagnostic is unproven.
M3. `JobComponents` inactive-blank violations at `jobs/job/row`: nonzero
`created_tick` and non-blank ref slot/generation on an absent row. Only the
habitat and zone blank rules have tests.
M4. Present zone with an out-of-bounds or zero-generation basin pair
(`CLAIM_CHECK_COMPONENT` at `forage/zone/row`). Only the occupancy byte is tested
there. This is also the guard that proves a never-bound zone is refused, which
matters because the public `create_zone` path currently satisfies it (the
source-backed world in `test_checker_accepts_real_stale_claim_snapshots...`
validates ok with a freshly created interloper zone); keep that test as the
empirical witness of that assumption.
M5. A codec-precondition test pinning F1/F2: out-of-range claim slot and
`patch_kind` must be refused by `owner_refusal` before the checker indexes.

## Mutants

All five planned mutants already have a killing assertion:
skip live provenance -> `test_forage_live_tick_and_pid_provenance_refuse_without_repair`;
skip zero-claim aggregate rows -> `test_every_zone_total_is_checked_even_without_any_claim`;
count equal designation/basin twice -> `test_shared_designation_and_basin_counts_the_amount_once`;
reinterpret stale owner through reverse mapping -> `test_dead_expedition_is_preserved_and_never_reconstructed_from_reused_row`;
omit the reverse walk -> `test_reverse_directory_walk_requires_each_component_kind`.

## Budget

The 1155-line output against the 950-line packet budget is a real overrun. Having
inspected the file, the excess is documentation density, not duplicated logic or
scope creep: every class, gate and constant maps to a named contract clause. I
concur with the parent's bounded acceptance and record it as an exception, not a
precedent. Activation remains gated on SAVE-CLAIM-WORLD-BINDING; nothing in this
lane may mark release_save_ready, SAVE-CAPTURE, SAVE-ORCHESTRATOR or
first-playable acceptance complete.

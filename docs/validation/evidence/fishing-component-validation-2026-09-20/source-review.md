# Fishing section 4 source review (independent)

FISHING-S4-VALIDATE-R01 v1, ADR 0181. This reviews the candidate bytes held in this
folder: `candidate-fishing.gd` and `candidate-save_owner_fishing.gd`. Production is
still untouched pending the PR 171 merge, so nothing below is acceptance of applied
source. A later raw intake must prove byte identity (sha256) against these candidates
before this review covers what ships. The owner block is stated at 392 raw lines and
the bridge at 390; the earlier 376-line worker self-estimate is superseded and should
not be re-quoted. No source was edited and nothing was executed for this review.

## Verdict

No production defect found in the section 4 block or the bridge.

- Gate order matches the contract: shape, global bytes in canonical field order,
  ascending habitats, ascending stocks, per-habitat species then quota, then self-slot
  and zone-pair uniqueness as two separate passes.
- `columns_refusal` is argument-only: no live store, directory, forage, jobs, catalog,
  clock, callback, diagnostic, float or per-row allocation, and the image is never
  written. The bridge projects by assignment and discards the cold Columns.
- Indexing is safe. The habitat enum gate runs over all 32 rows before any stock row
  subscripts `HABITAT_SPECIES_ROWS`, and `is_sized()` precedes every index.
- Reference domains are right: present self requires slot 0..352417 and generation > 0;
  present zone accepts exact (-1,0) or the same nonnull domain, so a stale but
  well-formed zone pair stays legal; inactive requires both exactly null.
- Inactive habitats retain type, pollution, danger and protected_fraction with zero
  capacity, effort_used and intensive, and effort_slots 0 or the source-table value;
  inactive stocks are entirely blank. Broad retained history versus blank stock is
  therefore distinguished, not conflated.
- Values are bounded before any sum: capacity from `SPECIES_CAPACITY_U * 1000`,
  population in 10%..K, harvest in 0..parent capacity/40. The three-term quota sum and
  the 100*P cross multiplications cannot overflow i64 at these bounds. No float.
- Item IDs stay arbitrary nonnegative i32, subscript nothing, and are only required
  distinct within one habitat; same IDs across habitats remain legal.
- The bridge pins owner 4 key/version/32/0/22 and all 22 key/type/count triples, the
  source scalars, `CLAIM_COLUMN_BLANK_*`, `CLAIM_COLUMN_DIRECTORY_SLOT_MAX`,
  `COLUMN_BLANK_SPECIES_ID`, the Directory constants through the existing Fishing
  preload, and all three table lengths before any entry. Section 7's schema 2 is
  neither pinned nor reinterpreted.

## Isolation: honest, but narrower than its own wording

The metadata clone is acceptable and its limits are declared, with two caveats to
record rather than repair:

1. The probe exercises static bridge functions only and disables autoloads, so no
   Fishing instance is constructed. Preserving the three constructor assertions with
   local-variable indexes avoids a parse-time rejection; it does not keep them running.
   The counterfactual proves the bridge's table pin fires, not that an unmodified
   constructor would reach the bridge.
2. `metadata.log` records the production `project.godot` hash while the clone ran with
   its autoload section stripped. That is stated in the harness note but is easy to
   misread as shipped configuration; keep the two facts adjacent wherever cited.

## Required witnesses still outstanding

- The 63-unit code campaign is in progress. No `mutation-results.json` is present here;
  do not report kills, and keep equivalent rewrites excluded rather than mislabelled.
- The public lifecycle probe (actual creation of all three types, quota sharing and
  reset, closure independence, both hysteresis directions, hard-floor atomicity,
  destruction and recreation, stale versus new zone generations) is asserted at 106
  assertions in the contract and ADR but has no log in this folder.
- Counts disagree across documents: focus 7/16230/0, the pin note 123/8555/0, metadata
  31 cases/279 assertions including 8 bypass catches. Reconcile which suite each figure
  belongs to before any summary quotes a single number.

Optional, not blocking: broader projection-omission variants beyond the 22 already
planned, and additional inactive-history permutations.

10688 is conservative logical packed bytes (5344 caller plus 5344 default image), not a
measured RSS. FISHING-SAVED-BINDINGS, bulk capture/apply and the gameplay loop remain
separate and unaddressed by this milestone.

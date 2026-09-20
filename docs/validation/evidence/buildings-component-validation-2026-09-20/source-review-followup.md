# Buildings source review — bounded follow-up (M1 / M2 / M3 / count mapping)

Independent reviewer follow-up, same role as `source-review.md`, distinct from every author
session. Scope is strictly the four dispositioned items plus material findings arising from the
supplied final bridge, room-pin patch and v2 metadata engine. The unchanged owner predicate,
contract and original helpers are not re-reviewed and their findings stand as written. Nothing
was executed for this document; the 75-case engine has no run, and the 75-functional campaign is
still running. The measured report length is 154 lines / 1584 words per the erratum.

## Verdict

M1 withdrawn. M2 verified and closed. M3 withdrawn as a must-fix, downgraded to annotation. The
89-shape mapping reconciles exactly and needs no count change. Two material findings remain, one
coverage gap and one evidence-provenance gap, neither requiring a contract change.

## M1 — withdrawn

The packet now supplies `candidate-focus.gd`, which returns a single-element list containing
`res://test/test_save_owner_buildings.gd`, and `witness-identity.json` records
`godot/test/buildings_validation_focus.gd` at that same sha256 and
`godot/test/test_save_owner_buildings.gd` at `d602cfa7…`, byte-identical to
`parent-test-draft.gd`. `run_mutants.py` therefore counts `^func test_` in the same file the
runner discovers, `EXPECTED` is 6, and `focus.log` shows `6 test(s), 19242 assertion(s), 0
failure(s)`. The 65-test owner probe is a separate intentional run over 59 legacy plus 6 owner
tests and is not fed to the mutation harness. My counterexample cannot occur against these
artifacts; the finding was a packet-context omission on my side, not a defect, and I retract it.

Residual, advisory only: the discovery list and the `EXPECTED` source path are two independent
literals that currently agree by construction rather than by assertion. One line in
`run_mutants.py` asserting that the focus runner's discovered suite set equals exactly the path
used for `EXPECTED` would make a future divergence loud instead of silently invalidating every
mutant row. Not an acceptance blocker.

## M2 — verified closed

`_source_room_type_refusal` in the final bridge does what the disposition requires and does it in
the right order. It pins `SOURCE_ROOM_TYPE_KEYS.size()` before indexing that array, then
`Catalog.ROOM_TYPE.size()`, then per ordinal `has(key)`, `typeof(...) != TYPE_INT` and exact
ordinal equality. It is chained after `_source_state_refusal` and before `_tier_two_refusal`, so
it runs inside gate 4 and before gate 5 ever projects or indexes a column. Bounds precede every
read. My original counterexample — appending `"SCRIPTORIUM": 8` to `Catalog.ROOM_TYPE` — now
refuses `SAVE_COMPONENT_METADATA` at the size check, and the converse drift (the owner's
`ROOM_TYPE_COUNT` literal moving while the catalog stays at 8) is still caught by the existing
`Buildings.ROOM_TYPE_COUNT != SOURCE_ROOM_TYPE_COUNT` pin. The domain is now covered from both
directions and is symmetric with `BUILDING_STATE`.

The owned-clone isolation is minimal and faithful. Replacing
`const ROOM_TYPE_CORRIDOR: int = Catalog.ROOM_TYPE["CORRIDOR"]` with the equal-valued `7` only
for the `missing` and `last-id-type` room faults preserves the exact numeric behaviour of the one
runtime use (`_countable_rules_pass`'s default branch) and touches no production alias. It is
necessary: both faults would otherwise fail the constant fold before the cold gate could execute,
which is a parse failure and not a catch. Worth recording honestly in the evidence: because every
room key is aliased in production, those two counterfactuals could not occur in a real build
without a prior compile failure, so the new gate's production value is shape and type checking on
a catalog reached at runtime, not ordinal checking that the alias pins already perform.

The 69 → 75 / 621 → 675 arithmetic reconciles: the `BUILDING_STATE`/`ROOM_TYPE` loop in
`parent-metadata-v2.py` now emits `last-ordinal` plus `missing`, `extra` and `last-id-type` for
both dictionaries, i.e. 8 cases where 2 stood, and `metadata-cases-v2.json` carries 75 entries
with `assertions_per_case` 9. The bypass-kill total stays 10, correctly, since no new bypass
expression was added.

## M3 — withdrawn as a must-fix

I accept the disposition. I could not construct a current counterexample in which the frozen
`16384` / `81920` literals and the named `SOURCE_ROOM_CAPACITY` / `SOURCE_FURNITURE_CAPACITY`
constants diverge without some earlier gate refusing first: those constants are themselves pinned
against `Buildings.ROOM_CAPACITY` / `FURNITURE_CAPACITY` in `_source_refusal`, which runs before
any acceptance, so a real owner-capacity change refuses `SAVE_COMPONENT_METADATA` rather than
being silently accepted, and the detail strings print values identical to the compared literals.
The literals are additionally load-bearing: `expressions['child_room']` and
`['child_furniture']` in the metadata engine perform exact-string replacement on those
expressions, so rewriting them would invalidate two frozen bypass mutants and require engine
requalification for no correctness gain. Keep the expressions, add the rationale comment. The
optional observed-value additions to the domain detail in `_source_refusal` remain a readability
suggestion only.

## Count mapping — accepted

89 reconciles exactly against the draft suite: one pure `null` refusal, one unallocated typed
`Columns.new(false)` view refused `COLUMN_SHAPE` in the layout test, and 29 fields x 3 extents =
87 resize cases. The five malformed bucket shapes plus the bridge `null` and wrong-owner checks
are bridge-side and correctly counted separately. 87 sampled physical faults is 29 x
first/midpoint/last with no exhaustive per-row claim. Publish this mapping as written; do not
adjust 89.

## Remaining material findings

**F1 (medium) — the `has()` membership branch has no witness.** In both `_source_state_refusal`
and `_source_room_type_refusal`, every supplied counterfactual is intercepted before membership
is ever exercised: `missing` and `extra` are caught by the preceding `size()` check, and
`last-id-type` by the `typeof` check. Counterexample: mutate `if not
Buildings.Catalog.ROOM_TYPE.has(key)` (or its state twin) to `if false`. No case among the 75
kills it as a clean semantic failure; the subsequent lookup of an absent key yields a null that
the type check would refuse, but via an engine error the harness would classify as invalid
execution rather than a kill. Add one size-preserving `rename-key` fault per dictionary — rename
the last key while keeping its integer value — which reaches `has()` with the size and type gates
both satisfied. That is 2 more cases and 18 more assertions on top of 75/675 and needs a
disposition, not a silent edit.

**F2 (medium) — all green evidence predates the final bridge.** `allocation.log` records
`save_owner_buildings.gd` at `9bb57843…`; the supplied final bridge is `d6a44702…`, and
`focus.log` and the 69-case metadata run are from the same superseded generation. The delta is
metadata-only and cannot reach the column predicate, so I expect no behavioural change, but the
artifacts as filed do not attest the shipped source. Regenerate focus, allocation and the 75-case
engine against the final hash before acceptance. One allocation note so the re-run is not
misread: the new gate allocates one short `String` per ordinal on the metadata path, eight in
total, inside the probe's measured region — the identical pattern already exists in the six-key
state loop, whose measured baseline increment was 6636 bytes against a 1048576 bound, so the
margin is not in question.

## Open acceptance items (not new findings)

* `witness-identity.json` asserts `full_generated_case_content_equal` and suite-equals-draft as
  hand-maintained claims. The disposition already accepts an executable deterministic check; make
  it compare the suite's `CASES` against `frozen-witnesses.json` content, since suite-equals-draft
  alone only proves the copy was not edited afterwards.
* No runtime result exists for the 75-case metadata version.
* Final metadata, focus, allocation, static, import, full suite, applicable mutation coverage and
  exact-head CI remain Astra obligations. No milestone acceptance is implied by this follow-up.

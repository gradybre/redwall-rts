# Movement policy register — Cycle 3's adopted policy applied to the Q2 matrix

Task: 05_movement_first_playable.md
Date: 2026-09-15

Lane: MOVE-POLICY-REGISTER. Base `origin/master` at `50e78ce`.
Binding contract: [MOVE-C3-R01](../../../rulings/2026-09-14_cycle03_movement_policy.md).
Engineering record: [decision 0149](../../../decisions/0149-a-prohibited-entry-and-a-preserved-rescue-are-different-rows.md).

## What landed

Four files:

- `docs/planning/movement_profile_readiness.json` — the 288-row register, revised. Schema string
  bumped to `redwall.movement.profile_readiness/2` for this planning file's own shape change.
- `docs/planning/movement_profile_authoring.md` — its companion prose, with a new §2.3.1/§2.3.2,
  a rewritten §2.4, a new §5.1 disposition table, a rewritten ford finding in §6.4, and a new §9
  listing exactly which of PR123's source interpretations the ruling corrected.
- `tools/test_movement_profile_policy.py` — 148 checks, negative cases first, enforcing the
  register's own `validator_rules` as executable predicates.
- `docs/decisions/0149-…` and this record.

**This lane authored no value.** `invented_values` is still `0`, all 35 `q2_slots` still hold
`value: null`, and every one of the 288 rows is still `admission_qualified: false`. No row is
`ENABLED`. `answers_q2` is still `false` and `closes_gates` is still `[]`, and the test refuses the
file if any of those changes.

## The register before and after

Both columns are a recount over `rows` × `row_classes`, not a copied figure. The "after" column is
what `recount()` in the test produces independently of the script that wrote the file.

| Figure | Before | After |
|---|---:|---:|
| rows (leaves) | 288 | **288** |
| adopted | 8 | **8** |
| explicitly_disabled | 0 | **32** |
| unresolved_q2 | 280 | **248** |
| admission_qualified | 0 | **0** |
| adult_rows | 96 | 96 |
| adult_connected_rows_not_ready | 64 | 64 |
| adult_ground_ford_adopted | 8 | 8 |
| child_rows | 96 | 96 |
| child_explicitly_disabled | — | **32** |
| child_unresolved_q2 | — | **64** |
| child_climb_conditional | — | **16** |
| elder_rows | 96 | 96 |
| elder_explicitly_disabled | — | **0** |
| ordinary_access_policy_rows | — | **144** |

The recount, shown rather than asserted:

- **32** = 16 species × {`SWIM_SURFACE`, `DIVE`} at `CHILD` → `RC_CHILD_WATER_PROHIBITED`. This is
  MOVE-C3-R01 §2's "32 CHILD species/mode rows have a definite prohibition", exactly.
- **16** = 16 species × `CLIMB` at `CHILD` → `RC_CHILD_CLIMB_CONDITIONAL`, reported separately and
  **not** counted as disabled. 32 + 16 = the 48 rows the ruling forbids marking wholly disabled.
- **248** = 288 − 8 adopted − 32 disabled.
- **144** = 16 species × 3 stages × {`GROUND_WALK`, `FORD_WALK`, `TUNNEL_WALK`}, the rows carrying
  MOVE-C3-R01 §3's ordinary-access policy permission. All 144 remain `unresolved_q2`: a policy
  permission is not the catalog state `ENABLED`.
- **0** qualified. No measured envelope exists.

`totals` was rebuilt from the rows, never edited, and nine separate off-by-one mutations of it are
refused by the test.

## Which Q2 slots Cycle 3 closed, and which did not

All 35 remain empty. 13 now carry a `cycle3_disposition` recording an adopted policy with its
`decision_source`, `settled` text and `still_open` text — and the validator refuses a disposition
containing any numeric leaf.

**Answered (4):** Q2-32 child hazardous entry prohibited with recovery preserved · Q2-33 no elder
veto · Q2-34 eligibility is declared in versioned profiles, not learned · Q2-35 the GDD §5.2 caps
are retained resident ceilings, not an auto-copied per-mode row.

**Answered in part (3):** Q2-24 ford semantics · Q2-31 the ordinary-access policy and the child
prohibitions · Q2-15 ordinary needs, no travel WU or XP, and the arithmetic-units correction.

**Baseline retained (1):** Q2-04 — `(+256,+256)` was already the production baseline, not an
unanswered preference. Per-record measurement verification still owed.

**Binding bound, artifact open (5):** Q2-16, Q2-18, Q2-19, Q2-21, Q2-23 — each now names the exact
HAZ rule it must use instead of requesting a number, and each still owes a concrete artifact.

**Untouched, still open (22):** Q2-01–03, Q2-05–14, Q2-17, Q2-20, Q2-22, Q2-25–30. Real
measurement, geometry and cost authoring, keeping their units, owners and emptiness.

### The one correction of an existing value

Q2-15's units said all `need_and_work_effects` sit on "the signed denominator-750 remainder in the
single health owner". MOVE-C3-R01 §4 corrects it, and `godot/scripts/core/needs.gd` confirms both
numbers: `NEED_DENOMINATOR = TICKS_PER_HOUR (750) * MILLI_PER_POINT (1000)` = **750000** for needs,
`HEALTH_DENOMINATOR = TICKS_PER_HOUR` = **750** for health, and work retains its own arithmetic.
Both are read out of committed GDScript. Neither is authored here.

## What the ruling corrected in PR123's source interpretations

Astra retained PR123's snapshot as a Cycle 3 review input and says Cycle 3 "corrects several of its
source interpretations". The full table is §9 of the companion document. In short:

1. **The ford is geometry, not movement policy** — wrong. GDD §5.1's explicit walkability *is* a
   movement policy, and `FORD_WALK` is authored supported walking enforced per segment.
2. **"Not stated anywhere"** whether the child prohibition reaches non-work travel — wrong. DEC-032
   forbids "hazardous **expeditions**", the clause PR123 omitted when it narrowed the policy to
   hazardous work and excavation.
3. **`RC_CHILD_HAZ` grouped `CLIMB` unconditionally with swim and dive** — replaced. Climb is
   conditional on the connection's protection case, and all 48 rows must not be marked disabled.
4. **`PROHIB-SITUATIONAL` filed missing definitions with prohibited actions** — split. A missing
   definition is `AUTHORED_PROFILE_NOT_READY`; lack of authoring is not an authored inability.
5. **`EV-LIFE-STAGE-COLUMN`: "travelling as one is not [legal]"** — unqualified and wrong. Today's
   refusal is a missing-profile refusal, and ordinary child access is policy-permitted.
6. **Q2-15's single denominator-750** — needs use 750000, health 750, work its own.
7. **Q2-04 listed as an open slot** — the baseline is already `(256,256)`.
8. **"Every value must remain null" as a validator rule** — that constraint belonged to PR123's
   proposal lane. Replaced with "a supplied policy or binding value must cite an adopted ruling;
   unresolved numeric and measurement fields remain explicitly empty". Nothing was supplied in this
   revision, so every slot is still null and the old form still holds too.
9. **Tunnel walking left adjacent to excavation capability** — completed ordinary access is not
   exclusive to a digging specialist.
10. **Q2-33/Q2-34 posed as open** — no blanket elder veto, no learned-ability progression.

## Verification

```
python3 tools/test_movement_profile_policy.py
test_movement_profile_policy: PASS -- 148 check(s), 0 failure(s)

godot --headless --path godot --editor --quit      # fresh worktree import, exit 0
./tools/run_tests.sh
4517 test(s), 157577 assertion(s), 0 failure(s)
ok: 4517 tests, 157577 assertions, 0 failures.
```

The three neighbouring tool suites were run to confirm nothing regressed:
`test_movement_envelopes` 191 checks / 0 failures, `test_registry_capacity_audit` 135 / 0,
`review_packet` 67 cases / 0.

### Mutation testing

Twenty mutants, **one line per run**, each restored and byte-compared by `shasum` against a pristine
copy afterwards. **Zero survived.**

- **13 checker mutants** — each `_rNN` rule function neutered to `return` in turn (R13 via removing
  it from the `RULES` tuple, because the neutering rewrite there would have removed more than one
  line). Every one produced failures: R01 4, R02 2, R03 2, R04 1, R05 7, R06 8, R07 3, R08 22,
  R09 4, R10 7, R11 6, R12 5, R13 4.
- **7 register mutants** applied to the real committed JSON: a child dive row reclassified as
  non-hazardous, `totals.explicitly_disabled` set back to 0, `BC-RIG` relabelled `admission`, an
  invented depth `128` put in Q2-24's `value`, the prohibited water class downgraded to
  `unresolved_q2`, the tunnel row's ordinary-access permission removed, and `answers_q2` set true.
  All seven refused.
- **The tautology check**: `validate()` stubbed to `return []` fails 93 of the 148 checks. The 55
  that still pass are the P02–P08 structural assertions, which read the register directly and do
  not route through `validate` — deliberately, so the two halves of the file cannot fail together
  silently.

## Not done here, and why

- **`tools/test_movement_profile_policy.py` is not wired into CI.** `.github/workflows/tests.yml` is
  outside this lane's allowlist. It runs cleanly as `python3 tools/test_movement_profile_policy.py`
  and exits 1 on failure, so adding one line after the existing `tools/test_movement_envelopes.py`
  invocation is all it needs.
- **Ford per-segment enforcement is authored, not implemented.** `movement.gd` still writes
  `_cursor_mode` once at `_attach_route()` and reads it back only via `admitted_mode_of()`. The
  explicit field, API and version change is Movement/G02's, and old saved route-wide labels must not
  be silently reinterpreted as new per-edge state.
- **`docs/planning/astra_cycles/cycle_03_inputs/` is not tracked at `50e78ce`.** The ruling links to
  it and the working tree contains it with the SHA-256 values the ruling cites — but it is untracked
  and outside this allowlist, so the ruling's two links will not resolve until its owner commits it.
- **No inventory, canonical-state-registry or work-queue file was touched**, per the lane boundary.

## The gate this does not close

**MOVE-G01 / Q2 remains OPEN.** Still owed: complete mode and species cost rows; **ADULT and ELDER
permissions for surface swimming, voluntary diving and unprotected climbing**; real source-bound
measured envelopes; support and contact producers; and the associated G02 contracts. A policy
matrix, a tool test and sixteen rig identities cannot close those gates, and this lane claims none
of them.

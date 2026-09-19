# Independent review — FAMILY-RULES-R01 v1

2026-09-19 · reviewer: independent (no tools, no execution, no source changes)

Scope reviewed: `docs/planning/family_rules_api_contract.md`,
`godot/scripts/core/family_rules.gd`, `godot/test/test_family_rules.gd`,
`docs/validation/evidence/family-rules-2026-09-19/focus-first.log`.
Nothing was run; every statement below is a reading of the supplied bytes plus
hand arithmetic. No activation claim and no whole-world claim is made or implied.

## Verdict

No blocking defect in the helper source or its dedicated tests. One process
blocker on evidence freshness (B1). Everything else is advisory.

## What I checked and confirmed

**All 36 values, re-derived independently.** I recomputed
`base * stage * size * season / 1e9` for every stage/size/season triple without
reusing the helper's loop, and compared against (a) the contract table and (b) the
test's literal arrays. All 18 hunger and 18 demand values agree in all three
places. Spot anchors: adult small non-winter 250000/6000; adult large winter
480000/11520; child small non-winter 187500/4500; child medium winter 6480;
child large winter 360000/8640; elder rows identical to adult rows.

**Products then one floor.** `_compute_value_into` performs three
`checked_mul_into` steps and exactly one `floor_div_into`; no intermediate
truncation. Each checked result is copied into a local (`step1`, `step2`,
`product`) before `out` is reused as scratch, which matches the aliasing
discipline the contract cites. The largest intermediate in the whole domain is
250000·750·1600·1200 = 4.8e14, roughly four orders of magnitude below INT64_MAX,
so the checked path never actually refuses here — it is a guard, not a live branch.

**Index bijection.** `stage*6 + size*2 + winter` over 3x3x2 covers 0..17 exactly
once; build and both queries use the identical expression, and `TABLE_COUNT = 18`
matches. See A2 for the limit of the test's coverage of this.

**Readiness timing and failed construction.** `_ready` is assigned only from
`_build_tables()` after both tables are fully written; `_build_tables` returns
`false` on the first refusal, so a partially filled private array can never be
read successfully — both queries check `_ready` first. Arrays are resized before
the build, so a failed build leaves zeros that are unreachable rather than
queryable. Correct per the contract's "missing rows are a build defect" rule.

**Domain refusal before big-int arithmetic.** Both queries test `_ready`, then
`life_stage` bounds, then `size_class` bounds, and only then compute `index`.
Neither caller input is multiplied or used to index before both are validated, so
INT64_MAX / INT64_MIN inputs refuse without arithmetic. The test exercises exactly
those two extremes on both parameters, and `-9223372036854775807 - 1` is used for
the minimum, avoiding the unary-minus literal parse trap.

**Stale value clearing on a reused out.** The test seeds a success at (2,2,winter)
before each invalid request, then asserts `ok == false`, `value == 0` and the
expected error string, then re-establishes a success. That pins the parent's
verified `refuse()`/`succeed()` semantics (ok/value/error, bool return) at the
call site rather than restating them.

**Query purity.** No query allocates, resizes, writes a table, reads a world, or
derives stage from species. The payload test performs 100 successful queries plus
a refusal and re-reads both arrays afterwards; because Godot packed arrays are
value-typed, re-fetching after the loop (rather than comparing the original
handle) is the correct way to detect mutation, and the test does it correctly.

**Preload hygiene.** `family_rules.gd` preloads only `int_math.gd`. The
Residents/Needs identity and sign comparisons live in the test file, which is
exactly how the future preload cycle is avoided.

**Byte census.** 18 x 8 x 2 = 288 bytes; the test asserts the sum of both
`to_byte_array().size()` values equals 288 and explicitly scopes that to the
packed payload excluding object overhead. Consistent with the contract.

## Blockers

**B1 — Evidence does not correspond to the reviewed bytes.** The packet states the
186-test / 21561-assertion / 0-failure focus run was captured *before* the parent
added explicit `int` types to three construction loop variables, and the source I
reviewed already carries those annotations (`for stage: int in range(3)` etc.).
The typing is semantically inert — `range()` already yields ints and the loop
variables are only used in arithmetic and as constant-array indices — so I expect
no behavioural change, but the packet currently ships no passing evidence produced
from the final source. Reproduce by diffing the three loop headers against the
run's source. Remedy: re-run the focus suite against the final bytes and replace
`focus-first.log`, and land the in-flight full headless run, before merge.

## Advisories (no code supplied, no change demanded)

**A1 — `REFUSE_TABLE_UNAVAILABLE` is unreachable and unpinned.** With a valid
build `_ready` is always true, and the contract rightly forbids adding a
corruption hook, so no test reaches that branch. The other two diagnostic strings
are pinned as literals in the domain test, but this one is pinned nowhere, yet the
contract says future family consumers will import it. A constant-value assertion
from the test (alongside an `is_ready()` assertion) would close the gap without
touching the helper.

**A2 — The test's index expression mirrors the helper's.** The literal arrays are
indexed with the same `stage*6 + size*2 + season` formula the helper uses, so the
test pins the public (stage, size, winter) -> value mapping, not the private slot
layout. That is the right thing to pin, and the layout claim is separately carried
by the 18-row and 288-byte assertions plus the adult/elder-vs-Needs cross-check
and the distinct child fractions. Worth stating plainly in the packet so the
evidence is not read as a stronger bijection proof than it is.

**A3 — Floor semantics are never exercised.** Every one of the 36 products is an
exact multiple of 1e9, so `floor_div_into` never truncates in this domain. Any
future change to a base or multiplier makes rounding observable and will need a
fixture that actually truncates; today's table cannot detect a wrong rounding mode.

**A4 — Outside my input set.** `needs.gd`, `residents.gd`,
`persistence_state_registry.gd` and the memory ownership ledger were not supplied,
so I did not source-verify the positive-magnitude sign convention shared with
Needs, the category-2 classification of the two arrays and the readiness scalar,
the 288-byte ledger row, or the parent's fix of the new readiness row to the
required section 2. Those rest on the parent's statement and the passing
comparison test, not on my reading. I saw no weakening of any audit in the files
I did review, and no canonical field-count or version change appears anywhere in
the helper.

**A5 — Minor, non-actionable.** `_build_tables` allocates two `IntResult` objects
per cell (72 at construction, none per query); harmless and construction-scoped.
The two queries duplicate the identical three-step validation block; the
duplication keeps the declared precedence visible at each entry point and I am not
asking for a shared helper. `focus-first.log` prints the engine banner and the
autoload ready lines twice, which is cosmetic log noise only.

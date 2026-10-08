# 1731 — The balance harness watches the hearths and the apiary, and gains a third scripted player who preserves and brews
Date: 2026-10-07 · Status: Accepted (harness only; no game number or rule is changed)

**Numbering.** The packet MEASURE-BAL (`docs/handoff/BACKLOG.md`) assigns 1511–1520. The lead gave this rerun
**1731–1739** instead, because the digging branch's range (0991–1217) keeps growing. 1731 was checked free on every
local and remote ref (`git ls-tree` of each one's `docs/decisions/`).

## Approval

MEASURE-BAL (Brendan selected it on 2026-10-07): "Files: `docs/balance/` only, unless a harness fix is needed
(`godot/tools/balance/*`)". Hives (1601), preserving (1611), brewing (1621), the hall's fuel (1652) and the new recipes
(1625) are all approved "to be tuned after a balance run". This record is the harness fix that run needed.

## What the harness could not see (on master at `6970830e`)

- **Preserving and brewing never ran.** Both are "ordered by the player" from the Water panel (1611 P3 and 1621 P6,
  approved as built), and no routine orders them. The two scripted players never ordered them either: `hands_off` orders
  nothing, and `light_touch_policy.gd` farms, saws, fells and fishes only. So dried fruit, rations, mead, the cordial and
  (#234's) jam, cheese, ale, cider, vinegar and pickles could never appear in a run.
- **The hearths' wood was invisible.** `balance_events.gd` books the stores' wood as one in/out pair, so the hearths' burn
  was mixed with the kitchen's fire and the sawing. `hearth_fuel.gd` already keeps the counters "the balance sim reads"
  (decision 0571: `burned_milli`, `heated_hours`, `cold_hours`), but nothing read them.
- **The apiary's books were invisible.** Honey reaches the pantry's ledger only when hauled from the baskets. What the hive
  made, ate and lost, its strength and whether it died over the winter were not recorded.

Honey is pantry item 25, so it was already in the food ledger once hauled. The apiary's routine services the hive on
its own (1601), so `hands_off` exercises it.

## Decision

1. **`balance_supplies.gd`**: a watch read once at each day's close. Every figure is the movement of a cumulative
   counter its owner keeps, or a level read at the close. Nothing in game code changes. Eight of the figures go into
   the CSV.
   - **`hearths`**:
     - wood burned;
     - source-hours heated, and source-hours out of fuel;
     - the hall's tier;
     - fuel-days (`_min` and `_end`), written only while heat is demanded. hearth_fuel.gd's NO_DEMAND is -1, so
       writing it would make every winter roll up to -1: a day ends at the midnight into the next day.
   - **`apiary`**: 1601's books in full.
     - Honey made = in the hives + released + fed from the hive + lost.
     - Feed = in the hives + eaten.
     - Wax made, and missed service days.
     - The weakest hive's strength (`_min`, `_end`), the honey and the feed in the hives, and the days any hive stood
       abandoned.
2. **A third policy, `provisioning`** (`provisioning_policy.gd`). It extends the light-touch player and changes none of
   its rounds. At 06:00 it adds a **stores round**.
   - **Recipes.** A batch of every row of the recipe table, in the table's own order, when the fishery would take it
     (`batch_refusal` is empty) and no batch of that row is waiting to be worked.
     - A passive batch curing in its slot or vat has closed its job, so several of one row can be curing at once; the
       slots bound them.
     - A row not ordered is counted as `Not ordered: <verb> (<refusal code>)`, so a report can say why a product never
       appeared.
     - Any appended row (#234's six) is ordered with no harness change.
   - **Rations' inputs, gathered in their chain's order.** Each is gathered only once every input before it is free
     (no planned meal holds it):
     - dried fish, from the rack's own row;
     - then nuts: one forager, while the free nuts are short of a batch's, no trip is out and the woods allow it;
     - then flour: one mill batch, while the free flour is short and the mill takes it.
   - **Why that order.** The mill grinds grain the kitchen would cook. An earlier draft ground whenever the pantry held
     less flour than a batch, and the review measured meals missed rising from 22 to 30 over 26 days, with no ration
     ever possible. So the player takes nothing for a batch that cannot be made.
   - **The game's refusals stand.** A batch takes only food no planned meal holds, so the player preserves the surplus
     and does not take what the village would cook.
3. **`hands_off` and `light_touch` are left exactly as they were**, so they stay comparable with the 2026-10-01
   baseline. A 3-day run of each on clean `6970830e` and on this harness gave identical day records once the new keys
   were set aside.

## Why

- **Why a new policy, not a richer light-touch player.** Changing `light_touch` would break the comparison with the
  baseline that MEASURE-BAL asks for. A third policy answers the new question, "does the preserving and drink economy
  run?", separately.
- **Why no reserve guard** (for example, "only while Ready food is 2 days or more"). The kitchen already reserves its
  next two days of planned meals before anyone else can take that food (`ingredient_takes.gd`). A guard would add a
  rule of the harness's own on top of the game's.
- **Why the hall upgrade is not ordered.** The tier-2 package costs stone 40, wood 20 and cloth 8, and the village opens
  with stone 20. Its only stone income is digging and the waterplay's one find, which no scripted player does. A
  planned upgrade would stand half-delivered all year and keep 20 U of wood out of the hearths. The report states the
  ×0.75 saving from the measured hall burn instead.
- **What was rejected.** A hearth figure in `balance_events.gd`: that watch books material stocks frame by frame, while
  the hearths are a per-hour accumulator with its own counters.
- **Found in passing (not the harness's to fix).**
  - With nothing staged, the demo's cast is `demo_cast.gd PLACEHOLDER_COUNT` = 6 placeholder residents, not the nine
    named ones. A run on an unstaged checkout therefore measures a different village from the 2026-10-01 baseline
    (staged, nine). The JSON's `meta.staged_assets` and `meta.residents` say which.
  - The harness refuses `--stress-residents`, so it cannot ask for nine placeholders. Nine placeholders would not be
    the nine anyway: they have no species or trades.

## Tests and gates

- `godot/test/test_balance_harness.gd`, 9 new tests (the fuel-days test includes a hearth with demand and no wood:
  0 is written, not left out):
  - every counter's movement, from non-zero baselines (so a total cannot pass for a movement), and the rebase;
  - the levels at the close, a tier-2 hall, and an abandoned hive flagged;
  - fuel-days written only with demand, and a season's roll-up keeping its last heated figure;
  - missing parts read nothing;
  - every recipe the stations take is ordered in order, and a refusal is counted with its code;
  - rations' inputs in their chain's order, one milli-U either side of each need;
  - a trip out or refused, and a refusing mill, hold their orders;
  - live rack and station batches are open; a take-down and a closed row are not; no fishery counts none;
  - the runner accepts `provisioning`.
- Focused suite (final): `31 test(s), 143 assertion(s), 0 failure(s)`; `diagnostics: 0 unexpected error(s), 0
  unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)`.
- CI-style full suite (no staged assets, `godot/.godot` deleted and re-imported, `./tools/run_tests.sh`), on the final
  harness code: `9279 test(s), 648744 assertion(s), 0 failure(s)` · `diagnostics: 0 unexpected error(s), 0 unexpected
  warning(s), 272 expected, 371 tolerated; leaked at exit: 0 object(s), 0 resource(s)` · `log: 0 unexpected error(s),
  0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).` The re-review's zero-fuel-days assertions were
  added to the test file afterwards (test only; the focused suite above).
- Mutation (one mutant a run, the focused suite): **22 mutants, 21 killed**, and the re-review's `days > 0` mutant is
  killed by the zero-fuel-days assertion. The survivor, taking the last hive's
  strength instead of the weakest, is equivalent while `hive_rules.gd APIARY_COUNT` is 1. The first test set was
  weaker (the review's 10 mutants: 8 survived); every test above was written or rewritten against those survivors.
- Analyzer: `python3 tools/gdscript_warnings.py --max 0` → `0 GDScript warning(s) in 0 of 1054 file(s)`.
  - One earlier run printed 37 warnings in 8 untouched `scripts/core` files ("should be Record but is Record", a
    language-server cache artefact).
  - The next two runs were clean.

## Review (independent `code-reviewer`, waited for)

- **HIGH 1**: the mill guard read total flour and ground even when rations were impossible, diverting the kitchen's
  wheat (meals missed 22 → 30 over 26 days). **Fixed**: the chain order above, on free amounts.
- **HIGH 2**: `fed_from_hive_milli` and the feed level were not watched, so 6 U of honey a year was unaccounted for.
  **Fixed**.
- **MEDIUM 3**: winter's fuel-days rolled up to the -1 sentinel. **Fixed**: written only with demand, plus `_min`.
- **MEDIUM 4**: 8 of 10 mutants survived. **Fixed**: the tests above.
- **MEDIUM 5**: refusals were invisible. **Fixed**: the `Not ordered` counts.
- **LOW**:
  - `open_batches` had no null guard. **Fixed**.
  - "One batch" wording. **Fixed** in the header and here.
  - The `.uid` files are committed with their scripts.
  - Game-side, noted for the report: `order_batch` checks the butt's water but does not reserve it.
- **Confirmed by the reviewer**: every read is pure, so `hands_off` and `light_touch` are unchanged; no key clash in
  the day record; `j_recipe` is NONE for every non-recipe kind.

## Re-review (the same reviewer, on the fixes; waited for)

- **Every finding above: resolved.** The reviewer reran a provisioning year and found:
  - the apiary books close exactly (honey 70.46 U made = 2 in the hive + 60.46 released + 6 fed from the hive + 2
    lost);
  - winter's fuel-days roll up to 9.17 days;
  - the run first differs from light_touch on day 7 (the first mead), not day 0.
- **No CRITICAL, HIGH or MEDIUM.** Four LOWs:
  1. **The rations code names the first missing input in table order.** That is flour, so "Not ordered: Pack rations
     (NO_FLOUR)" shows even when the real blocker is dried fish. The policy gathers in chain order, so **read the
     rations line with the "Not ordered: Dry fish (...)" line** (the dated report does).
  2. **Zero fuel-days was untested.** Fixed (the test above).
  3. **The forage hook in `balance_run.gd` is reached only from the real village.** No year run sent a forager,
     because dried fish was never free, so it is unexercised. Left as it is; this record says so.
  4. **The CSV writes a missing figure as 0.** On a day with no heating demand, `hearths/fuel_days_hundredths_end`
     therefore reads 0 in the CSV, which looks like "out of wood". **The JSON leaves the key out**, so read fuel-days
     from the JSON. Not changed, so that the CSV keeps its one rule.

## Addendum (2026-10-07, after #234's new recipes merged): nuts for any batch that waits on them alone

- **The problem.** #234 (decision 1625) added the nut cheese (nuts 2 + water → 2). Nuts come only from a foraging trip,
  and the provisioning player sent one only for rations, once their dried fish was free. Rations never got their dried
  fish, so the cheese could never run.
- **The change.** `provisioning_policy.gd` now sends one forager while **any batch waits on nuts alone**:
  - `waits_only_on(recipe, CAT_NUTS)`: the row's nuts are short, and every other input is free;
  - or rations, once their dried fish is free, because their flour waits on the nuts.
- **Unchanged.** The mill still grinds only once a ration batch's dried fish and nuts are both free.
- **Tests:**
  - a row waits on one input only when every other is free (one milli-U either side);
  - one forager for nuts while a batch waits on them, and none once the largest need is met, a trip is out, or the
    woods refuse;
  - flour is ground only once rations lack nothing else.
- **Focused suite** (after the review below): `33 test(s), 166 assertion(s), 0 failure(s)`, 0 unexpected, 0 leaked.
- **Mutation:** 11 mutants on the new logic, 10 killed; then 5 on the review's fixes, all killed.
  - **The survivor** removes the rations branch of `wants_nuts`. It is equivalent under the current table: the cheese
    takes more nuts (2 U) than rations (1 U) and no other food, so whenever rations wait on nuts the cheese does too.
    The branch is kept, so that rations do not depend on the cheese row existing.
  - **A second survivor** showed an `!= R_RATION` exclusion was redundant; it was removed.
  - **The reviewer's own run** found one more equivalent mutant, dropping the dried-fish condition from that same rations
    branch, for the same reason.

### Review of `beb3bb3b` (independent `code-reviewer`, waited for)

- **No CRITICAL or HIGH.**
- **Selectors confirmed safe.** `SELECT_ITEMS` is `1 << 62`, so no selector can equal `CAT_NUTS`.
- **MEDIUM, the forager went out when the cheese could not be ordered** (a batch already waiting, or every crock taken).
  **Fixed**: `could_order(recipe)` gates `wants_nuts`. The header now says plainly that the trips add food and take a
  forager off the board, so the "Forage (nuts)" count should be read with the food figures.
- **MEDIUM, no test reserved food**, so "free (no planned meal holds it)" was untested: replacing the takes with a fresh
  one survived. **Fixed**: two reservation assertions, and that mutant is now killed.
- **LOWs:**
  - **Fixed:** the mead assertion now stocks honey first; a stale docstring; two lines over 120 characters; blank lines.
  - **Documented, not changed:**
    - Nuts named by an item selector would not be seen. The header says nuts are named by category.
    - The mill check runs before the recipe loop. With 2–2.9 U of free nuts, the mill can grind for rations in the same
      round that the cheese reserves 2 U, which delays the rations until the next trip. Nothing is lost: the flour stays
      free for the kitchen.

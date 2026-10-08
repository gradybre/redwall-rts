# 1740 — A batch of rations' dried fish is kept from raw eating
Date: 2026-10-08 · Status: Accepted

## The ruling

Brendan, 2026-10-08, on decision 1739's question F5 (`docs/balance/2026-10-07-year-matrix-rerun.md`, "Follow-up: fish
for the rack"): **"Both"**, relayed by the coordinator.
- **(a):** dried fish is not eaten raw while a ration batch lacks it. It is close to 1611 P3's option (b), a ration
  reserve the cook keeps topped up, and to the GDD's WorldPolicy `ration_reserve_milli`. Built here.
- **(b):** the rack may also take fish already fetched to the kitchen for meals beyond the next. Built in 1739.

**The evidence.** With the rack tried every hour (1739's probe), 21–24 U of dried fish was made a year, and every unit
was eaten raw (1800 NP, directly edible) before a batch of rations could use it. With no dried fish ever free at the
06:00 round, no flour was ground either (decision 1731's chain order), so rations were never made.

## Decision

- **What is kept: one batch's dried fish.** `fishery.gd ration_keep_milli(category)` returns, for dried fish, what one
  batch of rations takes (§5.7 `ration`: flour 2, dried fish 1, nuts 1, water 1, so **1 U**). It returns 0 for every
  other category, the rations' flour and nuts among them.
  - The ruling reads "while a ration batch lacks it": the next batch's dried fish is kept, and anything beyond it may
    be eaten.
  - It is read from the recipe row (`preserve_rules.gd input_milli`), so a change to the row changes it, and the field
    guide's words with it ("all but the 1.0 U a batch of rations takes").
- **When it is kept: only while rations wait on it alone. A PROPOSAL** (the coordinator's call of 2026-10-08, for
  Brendan to overturn). As first built (`ae137794`), the keep held 1 U all year, even when rations could never be made.
  Now `fishery.gd rations_wait_on_dried_fish()` must hold, and it needs all three of:
  - the rations' nuts free (1 U);
  - their flour free (2 U) or on its way: a mill batch grinding, or grain enough for one (3 U), free or the kitchen's
    beyond its next meal (decision 1741);
  - no ration batch queued (live, not started) with its own dried fish set aside.

  Otherwise nothing is kept, and dried fish is eaten raw as before (REQ-SET-013).
  - **A limit.** The provisioning player forages nuts only while a batch waits on nuts alone. A morning with no free
    nuts keeps nothing, so dried fish made then may be eaten before the nuts come.
- **Who it is kept from: raw eaters only.** `kitchen.gd` FOOD KEPT FROM RAW EATING:
  - `raw_keep: Callable`, which the village binds to the fishery's `ration_keep_milli`;
  - `raw_kept_milli(category)`, which is 0 when nothing is bound;
  - a raw meal (`_reserve_raw`, REQ-SET-013) takes only what is free beyond the kept amount. A lot of a category with
    nothing beyond it is not a candidate, and the amount reserved is capped at what is beyond.
  - **Which lot** (`_raw_lot`, after the review's HIGH):
    - the lot that spoils first among those the keep leaves a whole meal in, meaning its room covers the lot's own
      free amount or a full meal (`_raw_want`: RAW_NP_CAP at its NP);
    - only when there is none, the lot that spoils first among those it cuts short.

    As first built, 1.001 U of dried fish with 1 U kept made a 1-milli, 1-NP raw meal while 3 U of nuts sat beside it.
    With nothing kept, every lot is whole, so the choice is the old one.
  - **The room** is worked out once a category per raw meal (`_raw_room`, reset by `_raw_rooms_unknown`), with no
    allocation once sized.
- **Nothing is reserved.** The dried fish stays free in the pantry's books. So:
  - the kitchen may still cook it (the biscuit soup), which the ruling does not forbid;
  - the provisioning player's flour gate (`ration_input_free`) and the rations' own refusal see it as there;
  - a batch of rations ordered takes it as usual.
- **The HUD.** The raw reserve beside Ready food (1736) needs no change. Ready food already counts dried fish (the
  biscuit soup is a plain dish), so the raw reserve never counted it.

## Against the GDD

REQ-SET-013 lets a hungry resident eat any non-reserved raw-edible food. This keeps 1 U of dried fish from that, by
Brendan's ruling.
- **What the GDD has nearest.** WorldPolicy `ration_reserve_milli`, default 0, a reserve of rations themselves.
- **Proposal, for Brendan.** If the rule stays, amend REQ-SET-013 to name food kept for a preserving batch, or model
  it as the GDD's ration reserve once winter planning lands (1611 P3 (b)).
- **Status.** A PROPOSAL; nothing in the GDD is changed here.

## Tests

- `test_demo_kitchen.gd`:
  - `test_a_raw_meal_leaves_the_rations_dried_fish`:
    - with 1.5 U in store and 1 U kept, a raw eater takes 0.5 U;
    - with none beyond, there is no raw meal of it;
    - nuts are not kept;
    - unbound, the kept unit is eaten.
  - `test_a_raw_meal_is_never_a_crumb_of_kept_dried_fish`: the review's repro. Nuts are eaten first, then nuts, and
    only when nothing else is left the 1-milli crumb.
  - `test_a_raw_meal_eats_what_spoils_first_and_a_whole_kept_lot_counts_as_whole`: berries before nuts; a 0.3 U dried
    fish lot within the 0.5 U beyond the kept unit is eaten whole. The raw meal's spoil order had no test before this.
- `test_demo_balance_tuning.gd`:
  - the keep is the ration row's dried fish (1 U), and 0 for flour, nuts, fish and dried fruit; the row is read by
    `input_milli`; the guide's words;
  - `test_the_dried_fish_is_kept_only_while_rations_wait_on_it_alone`:
    - no nuts: nothing kept;
    - nuts but neither flour nor grain: nothing kept;
    - 2 U of grain: nothing kept; with the kitchen's 1 U beyond its next meal: kept;
    - 3 U of grain: kept;
    - a mill batch grinding: still kept;
    - a ration batch queued: nothing kept.
- `test/live/demo_food_live.gd`: the built village's kitchen keeps what the fishery says, and keeps no nuts.

- **Mutation** (all against the suites above; the live harness for the binding):
  - **Mine:** 19 of 19 killed on `ae137794` (the keep, the rack's fetched fish, the table drink).
  - **`_raw_lot` on `6fcdec12`:** 8 mutants; 2 survived (spoil order reversed; "whole" ignoring the lot's own free
    amount), both killed by `3c9e8d6e`'s test.
  - **The conditional keep on `b21acaf8`:**
    - the nuts clause removed and started batches counted as queued both survived; both are killed by `3550260f`;
    - the job-kind check dropped also survived. It is **equivalent** for rations: `open_job` resets `j_recipe`, and
      only a passive row's take-down sets it again.
  - **The reviewer's:**
    - 25 of 26 on `ae137794`. The survivor, M06 (`raw_kept_milli` without its clamp at 0), is equivalent: the bound
      keep is never negative.
    - 23 of 31 on `b21acaf8`. Of the 8 survivors, `_raw_lot`'s boundaries, its short-lot order and its zero-room skip,
      the keep switched off by another recipe's queued batch, and the live grain pair bound to fish are killed by
      `dab332ab`. The other two are killed by `3550260f`.

## Review (independent `code-reviewer`, waited for)

- **On `ae137794`:**
  - **HIGH, fixed in `6fcdec12`:** the keep turned a full raw meal into a crumb (1 milli-U of dried fish while 3 U of
    nuts sat by). `_raw_lot` now picks lots by the whole meal they leave.
  - **MEDIUM, fixed:** Cook now can start a feast's supper before 15:00, so a feast cancelled or a regatta skipped then
    would pour nothing. `called_feast.gd cancel_refusal` (`6fcdec12`) and `regatta.gd skip_refusal` (`b21acaf8`) now
    refuse once the supper is under way (decision 1733).
  - **LOWs:**
    - fixed: the keep's comments, `_reserve_raw`'s docstring, and the field guide's dried fish words;
    - recorded, not fixed:
      - the drink reads `meal_under_way` at its next update, not at the clear; no realistic path was found;
      - the keep's declarations sit in its own section mid-file, so the kitchen edit stays a section of its own;
      - M06, which is equivalent.
- **On `6fcdec12` and `b21acaf8`:** no CRITICAL or HIGH. The test gaps it found are closed (`3550260f`, `dab332ab`).
  - **MEDIUM, a design question for Brendan, not a defect (F9).** The keep's nuts clause makes it fall apart under
    hunger. Nuts are raw-edible (1600 NP) and are not kept, and nuts and dried fish both keep 720 h, so raw eaters
    take them interchangeably. Once hungry residents eat the nuts below 1 U, the keep switches off and the last unit of
    dried fish is eaten. It protects the rations' fish only when nobody is hungry enough to need it. Options:
    - (a) also keep the rations' nuts while the rations wait;
    - (b) drop the nuts clause;
    - (c) accept it as the intent.
  - **LOW, accepted:** a raw meal with a dried-fish candidate now asks the fishery a few free-amount questions. That
    happens at a meal's end only, never per frame.

## The measurement

Staged provisioning, 9 residents, 3 seeds (the report's follow-up section, "F5 and F6 built, re-measured").

- **Rations: none made in any run.** That holds with the keep unconditional (`ae137794`), conditional (`b21acaf8`,
  with F6), and in a probe where the scripted player grinds whenever flour is not free.
- **What the keep did.**
  - **Unconditional:** 1 U of dried fish stayed in store all year, and the rest was eaten.
  - **Conditional:** every unit was eaten, because grain was to be had only on days 12–14 and dried fish came at other
    times.
- **Meals missed: 216–235 with the final build**, against 190–226 for 1739 and 210–225 before it. The increase comes
  from F5 (b): the rack takes more fish from the meals.
- **New questions for Brendan:** F7 (rations and the player) and F8 (this keep's condition) are in the report. F9
  (the nuts clause) is above.

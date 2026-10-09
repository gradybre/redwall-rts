# 1742 — A ration reserve holds one batch's inputs back from the kitchen and from raw eating
Date: 2026-10-08 · Status: Accepted

## The rulings

Brendan, 2026-10-08, on 1741's questions (`docs/balance/2026-10-07-year-matrix-rerun.md`; relayed by the coordinator):
- **F7 (b), "Add a ration reserve".** Hold a ration reserve back from both the kitchen and raw eating.
- **F9 (c), accept.** Under hunger, 1740's keep may switch off through its nuts clause.
- **F8: not ruled separately.** 1740's conditional keep stays as its PROPOSAL. Where the reserve replaces it, this
  record says so (below).

The coordinator's brief:
- base the reserve on the GDD's model (`ration_reserve_milli`, REQ-SET-013) and build it faithfully;
- where the GDD is silent, choose PROVISIONAL values and list them as proposals;
- the reserve holds what one ration batch needs (grain or flour, nuts and dried fish) from the kitchen's planning and
  from raw eating, while it is below target.

**Brendan's later rulings (2026-10-08, relayed by the coordinator):**
- **F10 (c), leave it:** rations may be eaten at any time, so the reserve does not hold rations themselves.
- **R5, add the controls:** a field to set the target and a Release button for emergencies, per UI-SET-099 and §5.10.
  Built (The controls).
- **Merge #240 after the controls, the extra missed meals included.** The merge decision accepts R1–R4 as built,
  provisional.
- **Still a PROPOSAL:** the REQ-SET-117 amendment (Against the GDD).

## What the GDD says

- **The policy.** §4.2 WorldPolicy `ration_reserve_milli:int64`, default 0. ui_ux_controls.md UI-SET-099 ("Keep N
  rations in reserve", the BR food policy, M2) is how the player sets it. So **by default there is no reserve**, and its
  size is the player's choice.
- **Its size.** BAL-SUPPLY-004 sizes a full reserve as 18 winter days of plain rations, `ceil_div(18*winter_NP,2400)*500`
  g: 335 kg for the 12-resident starter, hundreds of rations. That is a settlement's, after M2 (BAL-RUN-004: "after M2
  raise targets to 18 winter days").
- **What a reserve holds back.** REQ-SET-117: "minimum reserves per item, with emergency meal access overriding
  ordinary production minimums but never seed classification". `scripts/core/store_policy.gd` builds that as a
  withdrawal floor for ordinary production.
- **Who may break it.** Two things:
  - REQ-SET-117's emergency meal access, which overrides the floor;
  - §5.10's emergency action "release ordinary production food reserves", offered with the critical food alert and
    never applied by itself (REQ-SET-146).
- **What it is of.** The GDD's reserve is of rations. It says nothing about holding a ration's inputs; that part is
  Brendan's ruling.

## Decision

- **The module.** `godot/demo/preserve/ration_reserve.gd`:
  - `target_milli` is WorldPolicy `ration_reserve_milli`, default 0 (the GDD's), so nothing is held.
  - **The demo village sets `DEMO_TARGET_MILLI` = 6 U, two batches (PROVISIONAL).**
- **When it holds.** While the rations the village owns are below the target and the reserve is not released. Owned
  means in store plus the 3 U of each live ration batch being packed (`fishery.gd rations_owned_milli`), so a batch on
  the board does not draw a second batch's inputs early.
- **What it holds** (`wanted_milli`), in a take of its own in the kitchen's takes:
  - one batch's dried fish (1 U), nuts (1 U) and flour (2 U), read from §5.7's `ration` row (`input_milli`);
  - while the flour it holds is short of a batch, one mill batch's grain (3 U), to grind it.

  The kitchen's planning and a raw meal take only food nobody has reserved, so neither can take it. Water comes from
  the butt (1737).
- **How it gathers** (`top_up`, flour before grain, so held flour ends the grain's need; no grain while a mill batch
  grinds, as its flour is on the way):
  - free food first, the lots that spoil last (`reserve_into(..., latest_first)`), so the kitchen still cooks what
    spoils first;
  - then what the kitchen planned for meals beyond its next one (`kitchen_give`, the kitchen's
    `release_beyond_next_meal`: the rule of 1739 and 1741, never the next meal's and never what the cook has in hand);
  - food no longer wanted goes back free.

  It runs each game hour (`fishery.gd _follow_hours`) and **whenever flour or dried fish is stored** (`_book_stored`),
  so the mill's flour is held before the kitchen's next hour can plan it (1741's probe: the kitchen cooked all 12 U).
- **Who uses it.**
  - The rations' refusal counts it (`input_available_milli`, for the rations' inputs only; the nut cheese counts only
    free nuts). The rations' order takes it first (`_take_from_reserve`).
  - The mill counts its grain (`grain_available_milli`) and takes it before asking the kitchen.
- **Who may break it.**
  - **§5.10's emergency action** is `fishery.gd release_ration_reserve(on)`: everything goes free until it is restored.
    It is never taken by itself.
  - **The player offers it** with Release food reserves in the Water panel's Preserves section (Brendan's R5; see The
    controls, below).
- **The scripted provisioning player** (`tools/balance/provisioning_policy.gd ration_input_free`) counts food the
  reserve holds as the rations', as the panel's refusals do.

## The controls (Brendan's R5, 2026-10-08; `72817b34`)

Built demo-side, in the panel that already orders rations: the Water panel's Preserves section
(`waterplay/water_panel.gd`, `fishery/demo_fishery.gd`), after the preserving table's rows. Nothing is in the
settlement UI or `scripts/core`.
- **The readout** (the `reserve` line):
  - **the head:** "Ration reserve: keep 6.0 U (0 U owned)", or, with no target, "Ration reserve: none" and how to
    keep one;
  - **then what is withheld:** "Holding 1.0 U dried fish, 1.0 U nuts, 2.0 U flour", including "… dried fish kept from
    raw eating" for 1740's keep; or "Holding nothing now"; or "Released: nothing held until kept again".
  - **Height.** The line holds three lines, so the row never jumps between states.
- **The target (UI-SET-099), a stepper.**
  - "◀ Keep fewer" and "Keep more ▶" move it one batch (3 U) a press, from none to ten batches (30 U). Both values are
    PROVISIONAL (R6, R7).
  - Each button is disabled at its end. A press says the new target beside the selection.
  - `fishery.gd set_ration_reserve_target` clamps the target; the reserve gathers or lets go at once.
- **Release food reserves (§5.10), never taken by itself.**
  - Its action card says what it frees before it is pressed ("Frees 1.0 U dried fish, 1.0 U nuts, 2.0 U flour at
    once…"), 1740's kept dried fish included.
  - With a reserve kept but nothing held now, it is still offered: a release lasts, so food arriving later is not held
    back. The card then says "Nothing is held now; nothing will be held back until you keep them again".
  - It is refused, and the button disabled, only with no reserve and nothing kept from raw eating.
  - The press frees the food and says what it freed.
  - The button then reads "Keep food reserves again"; pressed, the reserve holds again.
- **Looked at:** frames at 1280x720 and 1920x1080, before and after a release. The live harness clicks Keep more, Keep
  fewer, Release and Keep again for real.

## Against the GDD (for Brendan)

- **REQ-SET-117's override.** REQ-SET-117 lets emergency meal access break a production minimum. This reserve also
  holds against raw emergency meals (REQ-SET-013), by Brendan's F7 (b).
  - **What it costs a hungry resident:** at most one batch's dried fish and nuts (1 U each, 3400 NP). The flour and
    grain are not raw-edible.
  - **PROPOSAL:** amend REQ-SET-117 (and REQ-SET-013's "nonreserved") to name the ration reserve as held from
    emergency meals, breakable only by §5.10's release.
- **A reserve of inputs, not only of rations.** The GDD's reserve counts rations. This one holds their inputs while the
  rations are short, so that the reserve can fill. It follows Brendan's ruling.
- **Ready food.** The kitchen's Ready-food estimate still counts the reserve's grain and flour as cookable, because it
  sums the pantry by category. REQ-SET-115 would remove food set aside from available reserves. A limit, at most 3 U of
  grain or 2 U of flour.

## Against 1740's keep

**The reserve replaces the keep wherever a target is set,** as the demo village sets one:
- the reserve holds the next batch's dried fish in its take, held from raw eating unconditionally, with its nuts and
  flour or grain beside it;
- `fishery.gd ration_keep_milli` keeps nothing while the reserve has a target, so the two never stack (the review);
- it keeps nothing while the reserve is released either, so §5.10's release frees everything withheld.

The keep stays bound. In a village with no target (the GDD's default 0) it is the only protection the rations' dried
fish has, and it remains 1740's PROPOSAL, with F9 (c) accepted.

## PROVISIONAL values and proposals

| # | Value | Why | Options |
|---|---|---|---|
| R1 | Demo target 6 U (two batches) | The GDD leaves the target to the player (UI-SET-099); BAL-SUPPLY-004's 18 winter days is a settlement's hundreds | **Accepted as built, provisional** (Brendan's merge decision, 2026-10-08). The player can now step it |
| R2 | One batch's inputs held at a time | Brendan's ruling ("what one ration batch needs") | **Accepted as built, provisional** |
| R3 | Grain held only while the flour held is short (and no mill batch grinds) | Flour is the input; grain is how to get it | **Accepted as built, provisional** |
| R4 | Gathered from the kitchen's meals beyond the next | Free food alone was never there (1739–1741) | **Accepted as built, provisional** |
| R5 | The controls | UI-SET-099 and §5.10's release need a player's hand | **Ruled: "add the controls"** (Brendan, 2026-10-08). Built: see The controls |
| R6 | The stepper's step: one batch, 3 U | A batch packs 3 U; a step of anything else leaves a part-batch target | PROVISIONAL |
| R7 | The stepper's cap: ten batches, 30 U | A demo village of 9 cannot gather more than a few batches a year (the measurement: 3–6 U); BAL-SUPPLY-004's full reserve is a settlement's | PROVISIONAL |

## Tests

- `test_demo_ration_reserve.gd` (new):
  - with no target, nothing is held; an unconfigured reserve, or one with no takes, holds and gives nothing;
  - one batch's inputs are held (the 1 U of flour there, plus grain to grind the rest), so the free food is less by
    them; with the flour there the grain is let go; never more than a batch;
  - at the target (one milli-U either side) everything goes back, and below it is gathered again;
  - released, everything goes back; restored, it is gathered again;
  - the kitchen is asked for exactly the shortfall, and nothing again once held;
  - `give` lets go what is asked, no more than is held.
- `test_demo_preserve.gd`:
  - rations are packed from what the reserve holds alone: the refusal counts it, the order takes it, and the packing
    batch counts as owned;
  - only the rations count the reserve's nuts: the cheese counts the free nuts;
  - the mill grinds the reserve's grain, and the stored flour is held at once;
  - §5.10's release lets everything go free and moves the revision; restored, it holds again.
- `test_balance_harness.gd`: the provisioning player counts the reserve's food as the rations', and a meal's hold
  still is not.
- `test/live/demo_food_live.gd`: the built village keeps a 6 U reserve, bound to the kitchen.

- **Mutation (mine), 23 mutants on `4e896e64` and 8 on the review fixes (`b7707bff`)** against the reserve, the takes,
  the fishery, the village and the provisioning player. All 8 on the fixes are killed, two of them after
  `ae0e1143`'s cases: the release with no target, and a cordial batch is not rations. The 23 on `4e896e64`:
  - 19 killed at once, and 2 more by `1cb0e4cf` (the hourly top-up and the top-up on stored dried fish);
  - 2 are equivalent:
    - the rations' input range taken one past its end: the next recipe's first input is a category the reserve never
      holds;
    - the owned count taking any job of the rations' recipe: only a ration batch job carries it, because rations are
      not a passive row.

## Review (independent `code-reviewer` on `c9f67f16` and `4e896e64`, waited for)

No CRITICAL or HIGH. Four MEDIUMs, three of them reproduced:
- **Fixed in `b7707bff`:**
  - **The reserve gathered a second mill batch's grain while its first was grinding,** from the kitchen's later meals
    too. Now no grain is wanted while a mill job is live (`top_up(..., milling)`).
  - **1740's keep stacked on the reserve (2 U of dried fish withheld), and §5.10's release left the keep in place.**
    The keep now keeps nothing while a reserve has a target or is released (see Against 1740's keep).
  - **The reserve held the lots that spoil soonest,** withholding from the kitchen what it would cook first.
    `ingredient_takes.gd reserve_into` gains `latest_first`, and the reserve holds the lots that spoil last.
- **Recorded, then resolved by Brendan's R5:**
  - **In the live demo the reserve could not be broken.** `release_ration_reserve` had no UI, so REQ-SET-146's
    "offered" was not met. The controls (`72817b34`) offer it now.
- **LOWs:**
  - **Recorded:** the takes table holds 96 entries, and the reserve uses at least 4. A full table reserves short, and
    `_add_entry` fails quietly, as for every take.
  - **Recorded:** `_follow_hours`'s early return only saves a frame's top-up. It changes no behaviour, so no test pins
    it.
- **Its mutants:** 28 run, 19 killed. Of the 9 survivors:
  - four were behaviour gaps: the hourly top-up, the top-up on stored dried fish, the rations in store, and any batch
    counted as rations. They are killed by `1cb0e4cf`, `b7707bff` and `ae0e1143`;
  - R26 is the performance guard above;
  - three are equivalent or harmless: a 0 shortfall asked, the input range one past its end, and the whole 3 U given
    to the mill.

**The CI-style gate at `ae0e1143` caught two problems, both fixed in `db297ac2`:**
- The regatta suite builds a fishery with no takes. The reserve's `configure` called `new_take()` on null, failing 28
  tests. It is now inert with no takes, and a test pins it.
- The analyzer flagged a local `packing` shadowing a fishery function.

Neither changes the built village, so the measurement below (on `ae0e1143`) stands.

**The independent review of the controls (`72817b34`, waited for).** No CRITICAL or HIGH. Its 3 MEDIUMs and its
LOWs are fixed in `6f492de0`, `0840fd16` and the commit after it:
- **Release was refused when nothing was held.** A release lasts, so food arriving later would have been held back,
  and 1740's kept dried fish could not be freed from the card. Now it is refused only with no reserve and nothing
  kept.
- **After a release, the line, the card and the stepper's answer disagreed with the state.** The released state is now
  read first everywhere.
- **Nothing would catch `_on_reserve` swallowing other actions.** Tested now.
- **The LOWs:**
  - the released-with-nothing answer has its own words;
  - the row no longer jumps;
  - the stepper's steps are clamped before the multiply;
  - the live checks can fail, and the panel's own refresh is read;
  - the owned figure and the tooltips are tested.

**My mutants on the fixes:** 16 of 16 killed, two of them after `0840fd16`.

## The measurement

Staged provisioning, 9 residents, 3 seeds, on the final `ae0e1143` (the report's "Latest: the ration reserve").
- **Rations made: 3–6 U a year,** one batch in one seed and two in the others. They are packed on day 14 (and day 17)
  from the harvest's grain, ground at the mill (3–6 U of flour). They are the first rations any measured year made.
- **All of them eaten.** In two seeds 3 U were still in store when winter began, eaten on days 37–38; in the third, the
  one batch was gone by day 21. Rations are directly edible, and the reserve holds only their inputs. That is F10 in
  the report.
- **Meals missed: 211–239 (winter 65–91),** against 216–235 (winter 79–91) without the reserve. No sharp fall either
  way.
- **The porridge gave up 3–6 U of grain to the flour.** Breakfasts are within the earlier runs' ranges.
- **No more after the harvest.** The stores never again held a mill batch's 3 U of grain.
- **An earlier run on `c9f67f16`, before the review's fixes, made 6 U in every seed.** Missed meals were 213–246
  (winter 67–84). Its summaries were replaced by the final run's.

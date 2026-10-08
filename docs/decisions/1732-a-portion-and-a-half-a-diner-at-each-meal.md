# 1732 — A portion and a half a diner at each meal: every diner a portion, half of them a second, by turns
Date: 2026-10-07 · Status: Accepted (the ruling's figure); **the turns rule is a PROPOSAL**

## The ruling

Brendan, 2026-10-07, on the balance rerun's proposal P1 (decision 1731; `docs/balance/2026-10-07-year-matrix-rerun.md`):
**(b), "1.5 portions per diner at each meal"; not a third meal.** Relayed by the coordinator.

The evidence was that two meals of one 1800 NP portion give 3600 NP a day, against §5.2's 6000 NP day
(`family_rules.gd`). Residents were HUNGRY 86–89% of their hours under every policy, even when they ate 85% of their
meals. Decision 0381 had already said so: "Two meals are 3600 NP, 60% of a small resident's 6000. The rest is left to
later food work."

## Decision

- **Planning.** The kitchen plans `ceil(residents × 3 / 2)` portions for each meal (`meal_rules.gd portions_for`, from
  `PORTIONS_PER_DINER_HALVES` 3), less the leftovers as before. `daily_portions()`, Ready food's divisor, is two meals of
  that. The harvest plan's daily use (`farm_harvest_plan.gd daily_use_milli`) follows the same rule.
- **Eating: every diner eats a portion, then half the diners take a second.** The meal store counts whole portions, so
  "1.5 a diner" is met in whole portions by turns. **PROPOSAL, the turns rule:** resident `i` has seconds at meal key `k`
  when `(i + k)` is even (`entitled_to_seconds`). So each resident has seconds at one of the day's two meals and eats
  three portions a day, 5400 NP.
- **A second helping is food only** (`kitchen.gd _eat_seconds`):
  - **What it counts as:** its NP (`nourishment.gd eat`), one more in `portions_eaten`, and the new `seconds_eaten`.
  - **What it never touches:** the meal's event (`MealFinal.diners`), its tally (`meal_ate`), the variety history, and
    the outcome.
  - **It is never taken from a first.** It is taken only while a portion is out beyond one for every resident who has not
    yet had that meal (`_seconds_spare`, `_firsts_owed`). That counts those not yet at the table too: in the water,
    carrying, on duty, or called on a later frame.
  - **The count is taken once a calendar tick.** A waiting diner asks every frame, so a pass over the residents each time
    would cost n × n a frame. Within a tick the count only falls as residents eat, which keeps the guard on the safe
    side.
  - **A diner already counted.** One holding a second helping is never counted again among a meal's holders
    (`_holding`), and does not go without if it gives the portion back after the meal ends (`_clear_role`,
    `_holds_seconds`). `_ate_first` is the precise test: the resident's last recorded meal is this one, and it ate.
  - **Waiting for it.** A diner whose turn it is waits at the table while more of the meal is still to come, as a
    two-course occasion's diner waits for its other course. It leaves when nothing more is coming.
- **No seconds at an occasion's meal.** The feast's courses are unchanged.
- **`kitchen.portion_halves`** (default 3, the ruling) is per kitchen. At 2 it is one portion a diner with no seconds:
  - the kitchen, dishes and kitchen-UI suites set 2 in their builders, because their scenarios are about other
    mechanics (raw meals, leftovers, dish choice, refusals) and are sized for one portion each;
  - the portion and a half itself has its own tests.

## Why the turns rule (options for Brendan)

- **(a) As built:** by turns, by resident and meal parity. Integer, deterministic, and no new kind of stock. Each
  resident has exactly one second helping a day.
- **(b) The hungriest first:** seconds to the residents with the lowest hunger, while portions remain. This takes from
  whoever comes to the table first, so seconds need the same guard and favour the early diners.
- **(c) Half-portions in the meal store:** a diner eats 1.5 portions every meal. This changes `meal_store.gd`'s unit,
  its books and every reader of portions.

**Recommendation: (a).** The first measurement of P1 is in the balance report's follow-up section.

## Shared files touched

| File | Hook |
|---|---|
| `godot/demo/kitchen/kitchen.gd` | `_seconds_at`, `seconds_eaten` and `portion_halves`. Planning in `_portions_wanted` and `daily_portions`. The three diner sites ask `_wants_more` (the other course or seconds). `_reserve_for` guards a second. `_eat_portion` books a second as food only. The cook's `_cook_meal_to_eat`. Also `_pooled`/`_draw_pool` for decision 1735. |
| `godot/demo/kitchen/meal_rules.gd` | A PORTION AND A HALF A DINER: `PORTIONS_PER_DINER_HALVES`, `portions_for`, `entitled_to_seconds` |
| `godot/demo/farm/farm_harvest_plan.gd` | `daily_use_milli` plans a portion and a half |

The FEAST lane edits `kitchen.gd` too. These are narrow, additive hooks, and none touches an occasion's code path.

## Review (independent `code-reviewer` on 7076a86d, waited for)

- **HIGH-1, fixed.** The guard counted only residents already at the table, so a second could take the first portion of
  one held away (the reviewer reproduced it with a resident held at the water). It now counts everyone who has not had
  the meal.
- **HIGH-2, fixed.** The guard's pass over all residents ran for every waiting diner every frame: 11–17 ms a frame at
  256 residents. It is now counted once a calendar tick.
- **Found in this branch's own measurement.** The tally counted a diner holding its second helping twice (the year's
  meals summed to 866 of 864). Fixed with `_holds_seconds` in `_holding` and `_clear_role`.
- **MEDIUM, fixed.** Tests now cover the surviving mutants on the guard, the give-back, a cancelled batch's water and the
  HUD stamp; each of those mutants is now killed.

## Tests

`test_demo_kitchen.gd`:
- four residents: 6 portions a meal, everyone fed, the two whose turn it is take seconds at each meal, 5400 NP a
  resident, one history entry and a tally of four a meal, the portions' books;
- food for exactly one portion each: no seconds, and nobody goes without;
- `portions_for` and `entitled_to_seconds` at their boundaries; an occasion and two halves have no seconds;
- a resident held at the water through the serving keeps its first portion, and nobody takes a second;
- a second helping held is never counted twice among the holders;
- a second helping given back after the meal has closed leaves the tally and the outcome unchanged.
- the cook's own path takes its second on its turn, once, and not off it (K7);
- a second helping eaten gives up its seat, which matters for a cook whose part goes on (K5).

Also, for decisions 1733 and 1735:
- a pour that cannot be reserved after free cordial was seen is a dry supper (D4, `test_demo_balance_tuning.gd`);
- Ready food's hotpot draws greens before roots, so a salad still counts (K12, `test_demo_dishes.gd`).

All four mutants, which the second review left surviving, are now killed.

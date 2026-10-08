# 1739 — Dry fish may take the fish the kitchen planned for meals beyond the next one
Date: 2026-10-08 · Status: Accepted

## The ruling

Brendan, 2026-10-08, on the balance rerun's follow-up question F3 (decision 1738;
`docs/balance/2026-10-07-year-matrix-rerun.md`, "Follow-up: after the tuning"): **(a)**, Dry fish may take fish the
kitchen has planned beyond the next meal, **never the next meal's fish**. Relayed by the coordinator.

The evidence: even fishing to 12 U, Dry fish was refused NO_FISH on 47 of 48 mornings and rations were never made. The
kitchen plans two days of meals ahead and reserves every fish for them, so the rack never saw a free one.

## Decision

- **The kitchen** (`kitchen.gd` FISH FOR THE RACK; three functions, nothing else in it changed):
  - `fish_beyond_next_meal_milli()`: the fish still in store that the takes of meals beyond the next one hold.
  - `release_fish_beyond_next_meal(milli)`: gives up to `milli` of that fish back to the pantry, free, from the latest
    meal holding fish first.
  - **Which meals are protected** (`_rack_may_take`, `_next_meal_for_rack`):
    - the next meal: the later of the earliest planned meal and the meal the **calendar** is serving now (read from the
      calendar, so an hour the kitchen has not yet run cannot expose it);
    - an occasion's meal (the feast);
    - a meal with a batch cooked or at the cauldron;
    - fish in the cook's hand. As first built, fish at the kitchen was protected too; F5 (b) below opened it to the
      rack.
  - **The meal that gave fish up** tops itself up again from what is free at the kitchen's next hour (THE CHOICE,
    unchanged). Never inside the release: topping up there could take back the freed fish before the rack sets it
    aside.
- **The fishery** (`fishery.gd`):
  - `bind_spare_fish(spare, give)`.
  - `input_available_milli(input)`: what a batch may take, which for fish is the free fish plus the kitchen's beyond
    the next meal. Dry fish's refusal and its card use it.
  - `order_batch` first asks the kitchen for exactly what the free fish lacks (`_take_spare_fish`), then sets its food
    aside as before. If the free fish is still short afterwards, the order is refused NO_FISH and opens nothing:
    never a short batch (ARCH-AUTH-003).
  - The Dry fish card (`dry_card`) counts the same fish as the refusal.
  - Only fish inputs ever ask, and unbound the fishery counts the free fish only.
- **The village** (`demo_village.gd`, one call in `_build_fishery`) binds the kitchen's two functions to the fishery.

`kitchen.gd` is also the FEAST lane's (#239). The change there is three new functions in a section of their own,
touching no existing line.

## Tests

- `test_demo_kitchen.gd`, with every planned meal holding fish:
  - the rack may take only what the meals beyond the next one hold;
  - giving it up takes the latest fish meal's first, never more than is beyond, never the next meal's, and moves the
    kitchen's revision;
  - an occasion's meal keeps its fish;
  - a later meal cooked, cooking, or with its fish in the cook's hand keeps its fish, however much is asked (put down
    at the kitchen, it is given: F5 (b));
  - the next meal is read from the calendar itself (at supper's end before the kitchen has run, tomorrow's breakfast
    keeps its fish), and the earliest planned meal is protected whatever the hour reads;
  - a slot with no take counts nothing.
- `test_demo_preserve.gd`, with the kitchen's side as Callables over a real take:
  - 1 U free and 3 U beyond the next meal make a batch, and the kitchen is asked for exactly 3 U;
  - free fish enough asks nothing;
  - one milli-U short in all is refused, and unbound counts the free fish only;
  - a fruit batch never asks for fish, and only a fish input counts the kitchen's fish;
  - a kitchen that gives nothing back gets the order refused NO_FISH with nothing opened.
- `test/live/demo_food_live.gd`: the built village binds the kitchen to the rack, and the Dry fish card counts the
  kitchen's fish.
- **Mutation:** 19 mutants run against these suites; 18 killed. The survivor:
  - **What it was:** dropping `_slot_take[s] != 0`.
  - **Why it survived:** the guard was redundant, since take ids start at 1 and take 0 holds no entries.
  - **What was done:** the guard was removed. Its test stays, and pins the behaviour.
- **The first test set was weak.** The review of `f86d79c2` found 10 of 12 mutants surviving. Every test above beyond
  the first five was written against those survivors.

## Review (independent `code-reviewer` on `f86d79c2`, waited for)

- **H1, fixed.** The Dry fish card went through `dry_card`, not `batch_card`, and still showed only the free fish.
- **H2, fixed.** The guards were untested. See Tests.
- **M1, fixed.** "The meal being served" read the kitchen's last hour; it now reads the calendar.
- **M3.**
  - **Recorded:** the top-up waits for the kitchen's next hour, by design.
  - **Fixed:** the wording of this record.
- **M4, fixed.** A short give-back is now a refusal.
- **LOWs, fixed.**
  - The earliest meal is computed once per call.
  - The section moved after `cookable_portions`.
  - The test's job index.
- **M2, a question for Brendan.** Ruled 2026-10-08: **keep as built** (see Brendan's rulings below).
  - **What happens now.** At the 06:00 round breakfast is the next meal, so today's supper counts as "beyond the next
    meal" and is open to the rack. The same holds during supper's serving for tomorrow's breakfast.
  - **Whether it fits the ruling.** This follows the ruling's wording, but Brendan may have meant only later days'
    meals.
  - **Options:**
    - (a) as built;
    - (b) only meals of a later day.
  - **Recommendation:** (a), which is the ruling as worded; the measurement below shows the next point matters more.

**Re-review of `61d2da9b` (the same reviewer, waited for).**
- **Every finding above confirmed fixed.** No CRITICAL, HIGH or MEDIUM remains.
- **Its 16 mutants, adapted to the new code, all killed.**
- **Four LOWs.** Left as they were in `61d2da9b` and #240's first push; two fixed with F5 in `ae137794`:
  - **fixed:** `_take_spare_fish` built its refusal words and dropped them, and `order_batch` repeated them as a
    literal. It now returns the words once;
  - **commented:** a refused order may leave fish the kitchen gave back free until the kitchen's next hour, which is
    harmless; the reviewer found no path to it. `_take_spare_fish`'s docstring now says so;
  - **kept:** the take-0 test can no longer fail now that the guard is gone; it stays as documentation;
  - **fixed:** one assertion in the calendar test (`the village ran`) checked only the set-up. It is gone.

## The measurement (staged; 3 seeds; the report's follow-up section, "Fish for the rack")

Provisioning rerun on `f86d79c2`; the review's fixes after it change nothing at the 06:00 round: **rations still never made; Dry fish refused NO_FISH on 47 of 48 mornings; missed
meals unchanged** (190–226 against 210–225). The same at `--fish-high 12`.

**Why.** The cook fetches the day's food for the next day as soon as it is reserved. Logged hour by hour (seed 1,
fish-high 12):
- **When fish lands** (12:00 or 13:00), the kitchen reserves it for meals beyond the next: 6–8 U of spare fish for that
  hour.
- **Within the hour** the cook fetches it to the kitchen, and the spare is 0 again.
- **At the 06:00 round,** when the scripted player orders preserving, the later meals' fish is at the kitchen
  (8 U on day 3). That is never the rack's under this ruling, which takes only fish still in its store.

So the rule works as ruled, but its window is about one game hour after each catch.

**A probe of the window** (uncommitted: the scripted player also tries Dry fish every hour). The rack ran 7–8 batches a
year, making 21–24 U of dried fish:
- **Every unit was eaten.** Dried fish is directly edible, and the residents were hungry.
- **No flour was ground.** Flour waits for dried fish and nuts to be free together.
- **So rations were still 0,** and meals missed were still 210–242.

**F5, a question for Brendan.** It is in the report and asks whether dried fish should be kept for rations. The options:
- (a) keep it for rations: recommended;
- (b) let the rack take fish already fetched;
- (c) leave it.

## Brendan's rulings (2026-10-08) on F5 and M2

Relayed by the coordinator:
- **F5: "Both".** Build (a) and (b) together.
  - **(a):** dried fish is not eaten raw while a ration batch lacks it. Built in decision **1740**.
  - **(b):** the rack may also take fish already fetched to the kitchen for meals beyond the next meal. Built here
    (below).
- **M2: keep as built.** At the 06:00 round, today's supper counts as beyond the next meal.

## F5 (b): fish at the kitchen (`ae137794`)

- **What the rack may take** (`fish_beyond_next_meal_milli`): the fish of meals beyond the next, in store **or at the
  kitchen** (`AT_KITCHEN`). Fish in the cook's hand (`IN_HAND`) is never counted or taken: the cook is carrying it.
- **What is given back first** (`release_fish_beyond_next_meal`, `_release_rack_fish`): every such meal's fish still in
  store, latest meal first; only then fish at the kitchen, latest meal first.
- **`ingredient_takes.gd`:** `release_milli` and `_latest` take an optional `where` (the default, -1, is anywhere, so
  every other caller is unchanged).
- **The protections are unchanged:** the next meal, an occasion's, a meal cooked or at the cauldron. The next meal's
  fish at the kitchen is never the rack's.
- **The kitchen's larder is not the rack's.** It holds fetched food planned for no meal, which the ruling does not name;
  the kitchen draws it into its meals at its next top-up.
- **A limit.** The takes never move food's books out of its store (ingredient_takes.gd WHERE THE FOOD IS). So fish the
  cook had carried to the kitchen is set aside by the rack's job from its lot like any other, and the rack hand walks to
  the fish pickup point as for every rack batch. Nothing is counted twice; only the walk is the store's, not the
  kitchen's.
- **Tests** (`test_demo_kitchen.gd`):
  - fish put down at the kitchen for a later meal is still counted;
  - the next meal's fish at the kitchen is not counted;
  - every meal's fish in store is given before any at the kitchen, and then the kitchen's is given;
  - the next meal's fish at the kitchen is never given;
  - fish in hand is still never counted or given (the renamed `test_a_later_meal_cooked_cooking_or_in_hand_keeps_its_fish`),
    and once put down it is given.

## Generalised for the mill (decision 1741, `b21acaf8`)

Brendan's F6 gave the mill the same rule for grain. The kitchen's functions now take a category
(`beyond_next_meal_milli`, `release_beyond_next_meal`), and this decision's fish functions wrap them unchanged. The
fishery's fish give-back and the mill's share `_ask_kitchen`.

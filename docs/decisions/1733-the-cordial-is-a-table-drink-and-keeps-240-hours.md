# 1733 — The cordial is poured at every supper as a table drink, and keeps 240 h
Date: 2026-10-07 · Status: Accepted

## The ruling

Brendan, 2026-10-07, on the balance rerun's P2 (decision 1731): **both (a) and (c)**, "Approve both and have cordial
keep longer as well". Relayed by the coordinator.
- (a): the cordial is poured at ordinary suppers as a table drink;
- (c): its shelf goes from 72 h to 240 h.

The evidence: all of it spoiled (48–56 U a year), because it kept 72 h and was poured only at the regatta's feast.

## Decision

- **(c) The shelf.** `farm_catalog.gd GOODS_SHELF_HOURS` (the cordial's entry) and `dish_book.gd`'s `cordial` row both
  go to 240 h. A test pins the two together (`test_demo_brew.gd`).
- **(a) The table drink** (`godot/demo/kitchen/table_drink.gd`, ticked by `demo_kitchen.gd` after the kitchen):
  - **When.** It reads the kitchen's published meal events (`finals`, by serial, as `people_taps.gd` does), so the
    kitchen gains no hook.
  - **How much.** At each ordinary supper somebody ate, it pours ceil(diners/4) U of cordial nobody has set aside,
    soonest-spoiling first. That is the feast's measure (`regatta_menu.gd drink_need_milli`).
  - **What it skips.** Breakfast pours nothing. An occasion's supper (the feast) pours its own drinks: the occasion's
    meal is noted while `occasion_key` is set, so the feast is still known if the occasion is cleared before its event
    is published.
  - **What it does.** A drink has no NP and no effect (DEC-007; 1621 P4). The books: `poured_milli`, `pours`,
    `dry_suppers`.
- **The words.** `preserve_text.gd`: the guide's CORDIAL_USE ("A table drink: poured at every supper …") and the card's
  "poured at supper and at feasts".

## Known limit (the review of 7076a86d)

- **A skipped regatta.** A regatta planned and then skipped stays noted as an occasion, so its ordinary supper pours no
  cordial that one evening.
- **Why it is left.** Telling a skipped feast from a served one belongs to the FEAST lane's `regatta/*`.
- **Fixed in the review:** `pours` and `dry_suppers` count what was actually poured.

## The limit fixed (2026-10-08, `ae137794` on `feat/demo-rack-fish`)

The FEAST lane (decision 1701, #239) found the same limit for a called feast cancelled before its supper, and noted it
for this decision's owner. The coordinator asked for it fixed with 1739's F5 work.
- **The rule now.** An occasion the kitchen clears before any batch of its meal is at the cauldron or cooked is
  forgotten, so that supper pours the cordial as any other.
  - That covers a cancelled called feast (`called_feast.gd cancel`, allowed only before the kitchen starts cooking
    the supper) and a regatta skipped while planned (`regatta.gd _release_plan`).
  - In both cases the kitchen gives the meal back to the alternation (`kitchen.gd clear_occasion`).
- **A held feast still pours nothing.** It is cleared only after its supper is cooked and served (`_tally`), so it stays
  noted. One cleared with a batch at the cauldron is still served as the occasion (nothing cooked is undone), and stays
  noted too.
- **How.**
  - `table_drink.gd` keeps the occasion it saw last (`_live`). When the kitchen's `occasion_key` moves off it, the drink
    asks `kitchen.meal_under_way(key)`: true when a batch of that meal is at the cauldron or cooked (`cooked_keys`).
  - When it is not under way, the key is forgotten.
  - Dishes are not compared: the bean hotpot is both an ordinary supper and the Hearth and regatta feasts' main course.
- **Cancelling and skipping wait on the kitchen too** (the review of `ae137794`; `6fcdec12`, `b21acaf8`).
  - Cook now can start a feast's supper before 15:00. A called feast cancelled then, or a planned regatta skipped then,
    would have its food partly cooked and its supper skipped by the drink.
  - So `called_feast.gd cancel_refusal` and `regatta.gd skip_refusal` both refuse ("the kitchen is cooking it" / "the
    kitchen is cooking its feast") once `kitchen.meal_under_way` holds for the feast's supper.
- **Tests:**
  - `test_demo_feasts.gd test_a_feast_whose_batch_is_under_way_early_cannot_be_cancelled` and `test_demo_regatta.gd
    test_a_plan_whose_feast_is_cooking_cannot_be_skipped`: a batch at the cauldron, or one cooked, refuses.
  - `test_demo_balance_tuning.gd`: an occasion cleared with nothing cooked pours at its supper (2 U for 8 diners); one
    cleared with a batch at the cauldron pours nothing. The existing feast-supper test now marks its meal cooked before
    clearing, as a served feast is.
  - `test_demo_feasts.gd`: a Hearth feast held and then cancelled, run to its supper in a real village: the table
    cordial is poured at ceil(diners/4) U.

## Tests

`test_demo_balance_tuning.gd`:
- the shelf in both tables, and the words;
- the measure at its boundaries (0, 1, 4, 5 and 9 diners);
- a supper pours once and a breakfast never does;
- a feast's supper (its occasion already cleared), an empty supper and earlier events pour nothing;
- only free cordial is poured, and a supper with none free is counted dry.

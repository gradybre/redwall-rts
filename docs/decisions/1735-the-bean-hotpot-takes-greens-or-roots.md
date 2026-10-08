# 1735 — The bean hotpot takes beans and greens or roots
Date: 2026-10-07 · Status: Accepted

## The ruling

Brendan, 2026-10-07, on the balance rerun's P5 (decision 1731): **(a)**, the hotpot takes beans plus greens or roots.

The evidence: E5's default rotation (0886: wheat → pea → carrot) sows 38–47 U of peas a year. The only bean dish, §5.7's
`bean_hotpot`, takes beans 2 + cabbage-row greens 2, and nothing sows greens. So the peas were never eaten: about 36 U
were still in store at every year's end, while winter went hungry.

## Decision

- **The row.** `dish_book.gd`'s hotpot takes beans 2 + `GREENS_OR_ROOTS` 2: every greens item and every root, by pantry
  key. This is the GDD's row widened by the ruling, as E2 opened the fish stew.
- **The words.** `meal_rules.gd` words an input whose items span more than one category in their categories' words:
  "greens or roots" (`categories_words`).
- **The input's categories.** Each input now records the categories it spans (`IN_CATEGORIES`, one bit a category).
- **Whether it is plain.** An input is whole (`IN_WHOLE`) when it is a category, or its items are a union of two or more
  whole categories. So the hotpot stays a PLAIN dish, which Ready food counts. An item list within one category (the
  scones' nuts) stays as it was: not plain.
- **Ready food's estimate** (`kitchen.gd _estimate_dish`) pools an input across its categories (`_pooled`) and draws
  greens before roots (`_draw_pool`). Beans with roots count as hotpots before the roots' own soup, as
  multi-input dishes always came first.

## A seam left to the FEAST lane (the review of 7076a86d)

- **The feast is still cabbage-only.** The regatta's Hearth feast cooks the bean hotpot as its main course, but
  `demo/regatta/regatta.gd` (its reservation and its NO_CABBAGE refusal) and `demo_regatta.gd` still ask for the
  cabbage row's greens.
- **Not a regression.** The feast needed cabbage before this change too.
- **Not edited here.** `regatta/*` is the FEAST lane's.
- **The fix, for that lane:** reserve and check the dish's own selector, `meal_rules.gd input_selector(DISH_BEAN_HOTPOT,
  1)`, so that the feast takes greens or roots like the everyday hotpot.

Also recorded:
- **Freshness.** The hotpot's `FRESHEST_HOURS` (`fresher_first`'s ranking) is the greens' 144 h, the shortest of its
  categories, even when the hotpot is cooked from roots (240 h).
- **Planning.** The harvest plan reads the rule's portion and a half (`portions_for` at its default), not a kitchen's
  `portion_halves`.

## Tests

`test_demo_dishes.gd`:
- the hotpot's second input takes every greens item and every root and nothing else;
- its words are "greens or roots";
- it stays plain, and the scones' nuts do not become plain;
- Ready food counts 4 U of peas and 7 U of carrots as 2 hotpots and 1 soup (8 portions).

The existing tests' wording ("greens or roots", "takes … in its categories") was updated.

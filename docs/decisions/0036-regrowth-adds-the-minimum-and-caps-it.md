# 0036 — Forage regrowth adds the 1 U minimum, and the result is capped at K
Date: 2026-09-09 · Status: Accepted — planner ruling received 2026-09-09
**This changes numbers the store already shipped.** Every forage regrowth value
moves; the ecology hashes move with them.

## The decision
`forage.gd`'s `daily_regrowth_milli_into()` now implements

```text
if S == 0 or P == K:
    growth = 0
else:
    growth = min(K - P, floor((K - P) * r * S / 1000000) + 1000)
P_next = P + growth
```

and **refuses** a stored `P > K` with `STOCK_ABOVE_CAPACITY` instead of reporting
zero growth.

It previously computed `max(1000, floor((K - P) * r * S / 1000000))`, capped to
`K - P`. The cap is unchanged. **The 1 U is now added rather than used as a
floor**, which is the part that moves every number.

## Why
GDD §5.5 writes "Daily regrowth=`floor((K−P)*r*season/1000000)` plus a minimum
1 U when season>0 and P<K". Two separate questions live in that one sentence,
and `docs/gameplay_balance.md`'s BAL-CONFLICT-012 named the second one on its
own: whether "plus a minimum 1 U" is a floor or a term, and whether the result
may carry a patch above its own capacity column.

`docs/rulings/2026-09-09_ready06_open_item_answers.md` §8A settles both, and
chooses the **additive** reading. Three things agree with it: the words "plus",
BAL-CONFLICT-012's own note that `max(1000,growth)` "would be a separate source
clarification", and decision 0030 §4.6's already-approved automatic-quota
allowance, which this file has been computing additively since it landed. The
module was reading one sentence two different ways in two functions.

The ruling supplies two fixtures that separate the two questions, and both are
named tests:

| Fixture | Old value | Ruled value |
|---|---:|---:|
| 500 milli-U gap, `r=60`, `S=300` (nuts, winter) | 500 | 500 — the cap binds either way |
| 100000 gap, same factors | 1800 | **2800** |

The first proves only the capacity cap; the second is the only one that can tell
the two readings apart, which is why keeping both matters.

## Consequences
**This is a deliberate behaviour change and must never be reported as
optimization parity.** Any recorded ecology hash taken before this date is not
comparable with one taken after it.

Values that moved in the suite, all restated from §5.5's own columns:

| Case | Old | New |
|---|---:|---:|
| Berries, summer, `K−P` 60000 | 7200 | 8200 |
| Nuts, autumn, `K−P` 48000 | 3456 | 4456 |
| Herb, winter, `K−P` 32000 | 1000 | 1512 |

`docs/gameplay_balance.md`'s BAL-CONFLICT-012 resolution column is updated to
record the choice. **No probe in `docs/validation/` or `validation-results/`
pinned a regrowth number**, checked by grep at the time of writing, so no
recorded measurement had to be re-taken; the only pinned values were in
`godot/test/test_forage.gd`.

The `P > K` refusal is **unreachable through the public API today**:
`create_patch()` writes 80% of K, `harvest()` only debits, and regrowth is
capped. It is exercised through a subclass in the suite and kept because a
save/load path is coming and a loaded column cannot be trusted. The
`P == K` early return is a shortcut, not a rule: with `room == 0` the cap
already yields 0, and a mutation removing it survives for that reason.

## Source
`docs/rulings/2026-09-09_ready06_open_item_answers.md` §8A, adopted by Brendan
as part of the whole READY_06 handoff. GDD §5.5; `docs/gameplay_balance.md`
BAL-CONFLICT-012; decision [0030](0030-forage-quotas-are-daily-and-shared.md) §4.6.

## Evidence
`./tools/run_tests.sh` on this change: **1264 tests, 36408 assertions, 0 failures**
(the branch's HEAD before it was 1224 / 35844 / 0). 40 mutations, one per run,
each restored and `shasum` byte-compared: 38 killed, two survivors, both proved
equivalent — the `P == K` shortcut here and the duplicate branch recorded in
[0036](0037-fishing-effort-is-claimed-by-the-cycle.md).

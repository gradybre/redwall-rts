# 0096 — Published need rates copy the selector's answer, not its formula

Date: 2026-09-12 · Status: **Accepted**

## Decision

`needs.gd` gains four public readers — `rest_rate_milli_per_hour_into()`,
`comfort_rate_milli_per_hour_into()`, `social_rate_milli_per_hour_into()` and
`purpose_rate_milli_per_hour_into()` — implemented as a single private helper that
validates the row with `_check_live_slot()`, runs the existing `_fill_need_rates(slot)`
selector, and copies one named `_rate_scratch` entry by value into the caller-owned
`IntMath.IntResult`. No formula is written twice, no column is added, no schema version
moves, no rate is cached and the per-tick sweep is untouched.

`hunger_rate_milli_per_hour()` is deliberately **not** changed to match. It keeps its
established positive decay magnitude and all its existing callers; the display adapter
forms `R = -magnitude` itself.

## Why

UXV-020 needs the same continuous rate the integrator is about to apply. The three ways
to get it that were rejected:

1. **UI recomputes the §5.2 table.** That is a second copy of a balance-authoritative
   formula in a file whose owner is not the needs owner. It drifts silently the first
   time a restoration constant moves.
2. **Cache the rate per resident with a dirty flag.** A cache needs an invalidation rule
   covering every one of the seven setters plus season and size changes. The rate is
   pure with respect to columns that are already stored, so the cache would buy nothing
   and owe a correctness argument for every future mutation.
3. **Replace `_fill_need_rates()` with five public reader calls per resident per tick.**
   That converts one pass into five validated calls on the hottest loop in the module,
   for the benefit of a panel that reads one resident.

Copying the selector's own output is the only option with no second formula, no
invalidation rule and no hot-path cost. Reusing `_rate_scratch` is safe here for a
reason that is stated rather than assumed: this module invokes no callback and emits no
signal, so `_tick_resident()` cannot be re-entered, and the array itself is never handed
out — `succeed()` takes the int64 by value.

**Sign is the whole hazard.** The four new rates are already net and already signed;
hunger's published reader is a magnitude. Negating a signed one again, or subtracting a
baseline `_fill_need_rates()` already subtracted, produces a plausible number. The
seventeen-row fixture table alone cannot catch the hunger case, because the table pins
the magnitude the mutation leaves correct — mutation `M2` (dropping the `-` in
`_rate_scratch[NEED_HUNGER] = -_hunger_rate_milli[...]`) leaves
`test_every_hunger_fixture_row_matches_its_positive_decay_magnitude` green and is killed
only by the 750-tick comparison against the real integrator. That is why both halves of
the test are kept.

## Consequences

- A refused read returns `false` with `ok == false`, the real refusal code and a cleared
  value. Callers must inspect `.ok`: **0 is also a legitimate success** (mild outdoors
  nets exactly zero), so the cleared zero of a refusal is not distinguishable on the
  value channel and was never meant to be. This is finding H4's rule, not a sentinel.
- A dead row is refused rather than answered. Its columns still describe a context, but a
  corpse has no continuous rate and answering from them is the stale-row read the ruling
  forbids.
- These readers are cold-path and must be called between completed simulation updates.
  Calling one from inside a tick, or from a callback a future version of this module
  might invoke mid-sweep, would read a scratch slot the integrator is still using.
- Adding a sixth need, or a new restoration source, requires touching only
  `_fill_need_rates()`. The readers inherit it with no change.

## Source

`docs/rulings/2026-09-12_resident_header_and_need_rates.md` § NEED-RATE-R01, whose rate
fixtures are inherited from GDD §5.2 and the existing selectors rather than new balance.

That ruling file was **not yet on `origin/master`** when this was written — it existed
only in a worktree — so this record was careful not to let a reader assume the citation
resolved. It has since landed, so the link is live; the caution is kept because it is why
the record is scoped the way it is. This record deliberately covers only the implementation
choice inside `needs.gd`, which is what this branch changes; the resident-header half of the
ruling is a separate lane and is not implemented here.

This record was filed as 0095 and renumbered to 0096: 0095 was free on the base this branch
was cut from, and the resident life-stage column took it before this landed. The
`decision_numbers.py` gate is what makes that a caught collision rather than a silent one.

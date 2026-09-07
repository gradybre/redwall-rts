# 0015 — Result objects allocate on hot paths; measured, tracked, not yet fixed
Date: 2026-09-06 · Status: **Closed 2026-09-06 by task 2.7** · Measured, not assumed

## Decision
The `core/` modules return a freshly allocated `RefCounted` result object from
every checked operation. This is **known to violate** CLAUDE.md's ban on hot-loop
allocation. It is recorded with its measurement and deferred to task 2.7 rather
than refactored in the same session the modules were written.

## Why the pattern exists
GDScript has no exceptions. ARCH-AUTH-003 requires overflow and invalid input to
be **refused**, never wrapped or truncated. A typed result carrying
`ok`/`value`/`error` makes ignoring a refusal a type-visible mistake, which a
`push_error`-plus-sentinel scheme does not — and sentinel returns are exactly
what caused finding H4, where `_age_hours_ceil()`'s `-1` bypassed a merge gate
and wrote a negative age.

## Measured cost (adversarial review, 2026-09-06)
| Path | Cost | Consequence |
|---|---|---|
| `sim_clock.advance()` | 2.14 µs/frame (3 `IntResult`s) | Negligible today |
| `inventory.transfer()` | **17.2 µs/op** | ~116 transfers exhaust the <2 ms economy-tick budget on their own |
| `calendar()` | 1 `Calendar` per call | A polling HUD makes this per-frame |

The budget is REQ-SET-163's p99 ≤2 ms simulation tick at 1x. 116 transfers per
tick is well above realistic hauling volume at 256 residents, so this is **not
yet binding** — but it scales the wrong way and the rubric bans it outright.

## Why not fixed now
The fix is an API change across `int_math.gd`, `inventory.gd` and `sim_clock.gd`
simultaneously — reusing a per-instance result struct (as `TransferPlan` already
does) or returning `(bool, int)` via out-params on hot paths. Doing that in the
same pass that stabilised 224 tests risks trading a measured, bounded cost for
unmeasured correctness regressions in the refusal paths that findings H1, H2 and
H4 just closed. A half-applied allocation refactor is worse than a tracked one.

## Consequences
- **Do not extend the pattern to new hot paths.** New per-tick code returns
  primitives or reuses a caller-owned struct.
- Task 2.7 owns the fix. It must re-measure `transfer()` afterwards, not assume.
- If an economy tick is ever measured above budget before 2.7 lands, this is the
  first thing to look at.

## Source
Adversarial review finding H7, 2026-09-06, with executed measurements.
Corroborating findings H1/H2/H4 explain why the result-object shape is kept.

## Outcome (task 2.7, 2026-09-06)

Fixed by removing **internal** allocation while leaving the public
`OpResult`/`IntResult` return shape untouched, so no caller changed and no
existing test was weakened. Every `int_math` operation now also exists in an
`_into(a, b, out) -> bool` form writing into a caller-owned result; the
allocating forms remain for cold paths and delegate to them.

Measured on the same script before and after, median of 3 runs:

| Path | Before | After | Change |
|---|---|---|---|
| `inventory.transfer()` | 21.13 µs/op | **8.53 µs/op** | −60% |
| `sim_clock.advance()` | 2.19 µs/frame | **1.06 µs/frame** | −52% |
| `inventory_capacity_debit_g_into()` | 1.67 µs (allocating) | **0.46 µs** | −72% |
| `calendar_into()` | 0.71 µs (`calendar()`) | **0.23 µs** | −68% |

Live-object census: 100 transfers allocate exactly 100 objects (only the
escaping `OpResult`); 200 `advance()` frames allocate **zero**. Transfers before
the 2 ms tick budget is exhausted rose from ~116 to **~235**.

### The H4 lesson held
Refusal codes and values travel on **separate channels** — a refusal is built as
`(false, code, NULL_REF, 0)` and `IntResult.refuse()` zeroes the value, so an
ignored refusal cannot surface a plausible number from a reused scratch. No
sentinel was reintroduced. One pre-existing sentinel read was removed along the
way: `_move_lot_checked` took its debit from `lot_debit_g()`, which returns `0`
on overflow.

### Aliasing
Module scratches are never live across a re-entry point: `sim_clock`'s is dead
across the only callback site, and `inventory` invokes no callback and emits no
signal, so no public operation can re-enter. Anything that escapes is freshly
allocated — including the day-boundary `Calendar`, which a callee may retain.

### Deliberately not done
Inlining `checked_mul`+`ceil_div` would save a further ~16% but duplicates
overflow logic in two places, a DRY violation for a modest gain. `calendar()`
still allocates; `calendar_into()` is the polling path.

### Worth knowing
Two new tests state in their own docstrings that they do **not** prove
allocation-freedom: `Performance.OBJECT_COUNT` is a *live*-object census and
cannot see a transient `RefCounted` freed inside the call. That was
mutation-tested and confirmed — a naive "allocates nothing" assertion does not
bite. The allocation claim rests on the benchmark, which is a timing property.

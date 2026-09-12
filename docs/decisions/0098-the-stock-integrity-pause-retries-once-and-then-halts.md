# 0098 — The stock integrity pause retries once, revalidated, and then halts

Date: 2026-09-12 · Status: **Accepted**

[STOCK-SEED-R01](../rulings/2026-09-12_alerts_and_seed_expiry.md) routes arithmetic,
ledger and schema failure in the hourly stock-age sweep "through the existing
critical-pause path", with "an explicitly revalidated retry of that SAME expiry
transaction", exactly once. Decision
[0093](0093-expired-seed-converts-to-compost-by-floored-nominal-mass.md) recorded
that half as **not built**, and named its owner: `stock_age.gd` counts and names a
refusal with every collaborating store byte identical and invents neither a pause
nor a retry ledger, because ARCH-SYS-001 gives both to the dispatcher. This record
is that dispatcher's judgements, in `godot/scripts/systems/settlement_system.gd`.

## Decision

### 1. The existing critical-pause path is `SimClock.CRITICAL`, reached through the scheduler queue

It already exists and it already has an owner. `sim_clock.gd` has held CRITICAL as
one bit of its independent pause-reason mask since task 02; REQ-SET-008's overload
ladder raises it through `apply_overload_target()`; `scheduler_events.gd` (decision
0054) owns its producers and applies events at the boundary pump between ticks.
**No second pause concept was created, and `set_pause()` is not called directly.**

The hold is submitted with `submit_safety_hold_into(SimClock.CRITICAL, …)` — that
queue's own INTERNAL-producer path, which is reserve-eligible, so ordinary traffic
cannot crowd a safety pause out of the 250-record normal cap, and which coalesces an
identical pending hold rather than consuming a sequence. Submitted from inside tick
k the record is stamped k while `completed_tick()` still reads k-1, so the clock's
per-tick barrier applies it **after k commits** rather than midway through a tick,
and this node never pumps the queue itself. That is the property
`game_manager.gd`'s header already states and relies on, not a new claim.

### 2. Which failures are integrity faults, and which are deliberately not

Two sets, and both are read off the owning module rather than enumerated by hand:

- **Hour level**: exactly `stock_age.gd`'s three `_preflight()` refusals —
  `INVENTORY_NOT_BOUND`, `ITEM_CATALOG_NOT_BOUND`, `INVENTORY_TRANSACTION_OPEN`.
  `is_stock_integrity_refusal()` compares against those three constants.
- **Lot level**: any hour with `refused_lots > 0`. Every path in `stock_age.gd`
  that increments that count is a checked-arithmetic refusal, an inventory
  `begin()` refusal or a poisoned `commit()`, which is precisely the ruling's
  "arithmetic, ledger or schema" set. **The count is the classification**, so no
  list of inventory refusal codes is copied here to drift out of date.

`INVALID_TICK`, `NOT_AN_HOUR_BOUNDARY` and `STOCK_AGE_HOUR_ALREADY_RUN` are **not**
integrity faults. They mean the hour was never owed and nothing changed;
ARCH-TICK-002's idempotence latch produces the third at every midnight that the
tick path already consumed. Pausing the game for a cadence refusal would fabricate
an integrity fault out of the mechanism that exists to prevent double aging.

### 3. Exactly-once is keyed to the transaction and spent before the attempt

`_stock_retry_pending` is armed once, at the raise, and **cleared as the first
statement of `_retry_stock_hour()`** — before the attempt, not after it — so a
repeated dispatch, a re-entrant frame or a second stage call cannot spend it twice.

Its lifetime is the **faulted expiry transaction**, which is what the two rejected
alternatives get wrong. A counter reset per sweep would hand the same unrecovered
fault a fresh retry every hour, which is the "periodic aging retries" the ruling
forbids by name. A flag that never clears would leave a settlement that recovered
perfectly unable to ever fault again, turning one bad hour into permanent
degradation. Keyed to the transaction, a fault at a **later** hour is a different
expiry transaction and earns its own single retry, while the faulted hour never
gets a second — `test_a_later_hours_fault_earns_its_own_single_retry` pins exactly
that difference.

### 4. Revalidated means the hour is re-derived, not a captured verdict re-applied

Nothing about the failed attempt is stored. The retry calls
`run_hour_into(_stock_fault_tick, …)` again, which re-runs `_preflight()`,
re-resolves the `spoiled_food` and `compost` ids **by catalog key**, re-decodes both
calendars and re-reads every declared container and every lot from live state. A
fault that is still present therefore refuses **again**, which is the whole point:
a retry that replayed a captured decision would either resume an unsafe world or
spin against the same bad snapshot.

**It retries the faulted TICK, not the tick it runs on.** The hold stops the clock
at the end of tick k, so the first tick that can carry the retry is k+1 — which is
not an hour crossing. Running `run_hour_into(k+1)` would refuse
`NOT_AN_HOUR_BOUNDARY` and age nothing; running `run_hour_into(k)` lands the owed
hour at the correct tick index, with ARCH-TICK-003's correct elapsed-interval
season. This is why the retry is attempted **before** the `is_hour_boundary()`
predicate rather than inside it.

It adds no age and duplicates no sink or source because the hour-level class
refuses inside `_preflight()`, which runs **before** `stock_age.gd` consumes
`_last_hour_tick` and before any container is swept. The faulted hour committed
nothing and is owed in full — which is also why re-running it is legal at all.

### 5. When the retry also fails, the simulation halts

`run_tick()` refuses `STOCK_AGE_INTEGRITY_HALT`, dispatches no stage, counts the
refusal and **re-asserts the hold**. The player sees a clock held at CRITICAL with
the fault code in `stock_integrity_fault()` and one `push_error` naming the code,
the hour tick and the retries attempted.

Silently continuing was rejected: an hour of §5.8 aging would be skipped in a world
that still holds the stock it failed to age, which is exactly the correctness hole
the ruling closes. Halting *forever* was rejected too — **the exit is `reset()`**,
a new or loaded settlement, which empties every store so the world the skipped hour
would have corrupted no longer exists. There is deliberately **no public
"clear the fault" call**: that would be the sentinel-shaped escape hatch that lets
the skipped hour through after all.

**The tick that declares the halt still commits**, exactly as the tick that raised
the fault does. This stage is fourth; ARCH-SYS-003's needs sweep for that tick has
already committed, and the queued hold lands at the barrier after the tick either
way. Discarding a committed sweep to make the refusal land one tick earlier would
trade a real half-tick for a cosmetic one.

## What this did NOT implement

1. **A per-lot fault gets the pause but no retry.** `stock_age.gd` reports
   `refused_lots` and `last_lot_refusal` and **names no lot ref**, and publishes no
   per-lot expiry entry point. There is no handle to revalidate and re-commit.
   Re-running the hour is forbidden by the ruling ("does not rerun completed hourly
   work") and by StockAge's own consumed latch; re-deriving the conversion in
   `settlement_system.gd` would duplicate the transformation ARCH-SYS-004 owns and
   is forbidden by decision 0093. So such a fault raises the pause and halts at
   once. **Closing it needs two additions to `stock_age.gd`, another owner's
   file**: a `last_refused_lot()` reader, and a
   `retry_refused_lot_into(lot_ref, out)` that re-derives quantity, item, masses and
   age and re-runs that one expiry transaction without touching the hour latch.
2. **CRITICAL is a shared bit.** REQ-SET-008's overload ladder produces it too and
   `sim_clock.gd` offers no sub-reason space or hold count, so
   `acknowledge_without_catchup()` clears an integrity hold and this file's clear
   can lift an overload hold. A sub-reason space belongs to `sim_clock.gd` /
   `scheduler_events.gd`. What this file can do, and does, is re-submit the hold on
   every refused tick, so a wrongly cleared integrity pause costs **one refused
   tick** rather than resuming an unsafe world.
   `test_a_halted_tick_runs_no_stage_and_re_asserts_the_shared_critical_bit` drives
   that acknowledgement and proves the re-assertion.
3. **Nothing is persisted.** A save taken while the world is halted is a save of an
   unsafe world, and the save owner has no section for the fault ledger. The
   ruling's "save continuation" acceptance item is therefore **not** met here.
4. **No notice is issued.** UI-SET-085 sends critical integrity faults to a
   blocking stop modal; `ui_notices.gd` and the shell are another owner's files and
   nothing is wired to `stock_integrity_fault()`. The `push_error` is the only
   player-facing signal today, and that is stated rather than dressed up.

## Consequences

- **No tick stage was added.** The retry runs inside `TICK_STAGE_STOCK_AGE`'s
  existing measurement window, so `tick_stage_count()` is still 8 and the test that
  names all eight needs no bump.
  `test_the_retry_runs_inside_the_existing_stock_age_stage_and_adds_no_ninth`
  asserts the stage was measured once per tick, retry included.
- **No packed column and no persistent counter were added**, so
  `docs/systems_architecture.md` §2.2/§2.3 and
  `docs/persistence_state_registry.md` gain no row. Nine scalars describe at most
  one open fault — a second cannot exist, because the first stops the simulation
  before another hour can run — and all nine are cleared by `reset()`.
- **No autoload was added.** The queue is reached through the existing
  `GameManager` autoload, as `_ready()` and `_ensure_command_clock()` already do.
- A per-lot arithmetic refusal is reachable today only through inventory's age
  ceiling: every shipped food mass divides `spoiled_food`'s 250 g/U exactly, and
  the seed product is nowhere near an int64, so neither conversion refusal can be
  induced through the public API. A lot created at `MAX_AGE_MILLI_HOURS` overflows
  on its next §5.8 hour, and that is what
  `test_a_per_lot_arithmetic_failure_pauses_and_halts_without_a_retry` uses.
- `stock_age.gd` is **byte-untouched**. Its header gap 4 now has a built owner, but
  correcting that sentence is its owner's edit, not this one's.

## Source

- [STOCK-SEED-R01](../rulings/2026-09-12_alerts_and_seed_expiry.md).
- Decisions [0093](0093-expired-seed-converts-to-compost-by-floored-nominal-mass.md)
  (what StockAge did and did not build),
  [0085](0085-stock-aging-runs-hourly-and-declares-its-store.md) (the hourly
  cadence), [0059](0059-allocate-before-consume-is-a-repository-wide-rule.md) (byte-identical refusal) and
  [0054](0054-the-scheduler-event-queue-drains-before-every-tick.md) (the pause queue).
- ARCH-SYS-001/004, ARCH-TICK-002/003, REQ-SET-007, REQ-SET-008, UI-SET-085.

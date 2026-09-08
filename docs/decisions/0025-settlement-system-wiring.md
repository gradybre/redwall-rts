# 0025 — SettlementSystem wires the tick loop, direct call not signal
Date: 2026-09-08 · Status: **Accepted** (Brendan, 2026-09-08)

## Decision
A new `SettlementSystem` autoload composes needs, schedule, priorities, jobs,
work and reservations once and becomes `GameManager`'s bound simulation via
`bind_simulation(step, day_boundary)` — a **direct call**, not a signal. Each
completed tick, `GameManager` calls `run_tick(completed_tick() + 1)`, reading the
index from the clock rather than counting a second one. Each day boundary it
calls `run_day_boundary(absolute_day, season)` **before** re-emitting the
existing `day_advanced` signal to the HUD.

## Why direct call, not a signal
`GameManager`'s four existing signals all terminate at a HUD label; nothing
downstream of them may depend on connection order, and Godot does not guarantee
one. Simulation ordering is not optional here: the day boundary's season
handover must be committed before the HUD's date readout is drawn from it, and a
signal gives no ordering contract between two listeners. A direct call makes the
order an explicit two-line function (`run_day_boundary()` then `day_advanced.emit()`)
instead of an implicit property of connection sequence.

`bind_simulation()` refuses a second binding rather than silently replacing the
first — two simulations sharing one clock would each run a partial tick, and a
silent swap would leave a live settlement receiving no ticks while the game
still looked like it was running. Nothing is bound by default, so a bare
`GameManager` test instance still runs the clock and drives no simulation.

## Why activity resolution moved to immediately before job selection
`schedule.resolve_into()` (ARCH-SYS-008, partial) had no fixed placement of its
own in the three-stage subset this milestone implements. It is called inside
`_select_jobs()`, immediately before the eligibility pass that reads the
resolved activity, rather than as a separate stage earlier in the tick or at the
day boundary. Placing it earlier would let a stale hour's activity answer an
eligibility check made on a later hour whenever a resident's 30-tick evaluation
stagger crosses an hour boundary; placing it at the day boundary would resolve
the activity once for the whole day and defeat §5.3's hourly slot model
entirely. Resolving it in the same pass that consumes it is the only placement
that cannot go stale between resolution and use.

## Why the day boundary does only the season handover
REQ-SET-007 names five daily stages: age stocks, update ecology, advance
crops/weather, process immigration/departures, evaluate progression. Four have
no owning store in this milestone (`systems_architecture.md` §11 step 6 has not
reached them). Implementing a placeholder for any of them would invent behavior
the architecture does not yet own. `run_day_boundary()` therefore does exactly
one thing — call `residents.set_winter(season == SEASON_WINTER)` — placed per
ARCH-TICK-003 ("aging uses the season in the elapsed interval; ecology uses the
new calendar day's season") and driving REQ-SET-143's already-implemented x1.20
winter hunger multiplier. `absolute_day` is validated but drives nothing further
because no day-counting system (departure, progression streaks, candidate
events) exists yet.

## Mutation testing: the one survivor was a duplicated guard, not a missing test
Sixteen single-line mutations were applied to `settlement_system.gd`, one per
run, each restored and hash-verified before the next. Fifteen were killed by the
existing suite. The survivor was a redundant emptiness guard in
`create_initial_settlement()` that duplicated a refusal `residents.gd` already
owns: `spawn_initial_settlement()` refuses `REFUSE_SETTLEMENT_NOT_EMPTY` on a
non-empty store (`residents.gd:524`), so a second check of the same condition in
the caller could be mutated to always pass without any test noticing, because
the callee's refusal still fired and produced the same observable result.

The fix taken was to **delete the duplicate check**, not to add a test
defending it. A test that only exists to keep two copies of one rule in sync is
a maintenance burden pointed at the wrong target: the next person to change the
emptiness rule has to remember to change it in two files and would have no
signal if they changed only one. `residents.gd` is the sole owner of that
refusal (`create_initial_settlement()`'s own docstring states this explicitly);
`settlement_system.gd` now trusts it and passes the refusal through unmodified.

## Known coverage gap, left open
`needs.tick_all()`'s refusal branch inside `_integrate_interval()` is
unreachable from `settlement_system.gd`'s own test suite without corrupting
needs state through `needs.gd` directly, and this task does not own or edit
`needs.gd`. That branch is untested here and is not claimed otherwise;
closing it belongs to whichever task next touches `needs.gd`.

## Consequences
- Every performance figure taken across the four `work.gd`/`needs.gd`
  optimisation steps (decisions 0016/0024, tasks through "WU tick optimisation
  step 7") described a benchmark fixture with no production caller. This is the
  first tick-cost measurement of the actual autoload composition: mean 82 µs,
  max 135 µs at the twelve-resident starting cohort, editor debug build, macOS.
  Not REQ-SET-163 evidence — that needs an exported release build on the
  Windows reference floor at 256 residents, and twelve is not the target
  population.
- The job queue is empty and stays empty: no production order, recipe,
  construction, care request, hauling policy or harvest zone creates a job.
  `SettlementSystem` was deliberately not given a fabricated job source to make
  the loop look busy.
- Eighteen of the twenty-three `systems_architecture.md` §5 stages remain
  unwired; each is named individually in `settlement_system.gd`'s header
  comment with the store it is blocked on, so the next task that closes one of
  them has an exact list rather than a re-derivation.
- Two gaps mean a job could not complete even once a source exists:
  `jobs.gd` eligibility implements 6 of 7 steps (no pathfinder for the legal-
  destination check), and `assign_worker()` leaves a job at
  `JOB_STATE_RESERVED` because the `RESERVED -> TRAVEL -> WORK` transition is
  movement's responsibility (ARCH-SYS-011/012), which does not exist yet.

## Source
Brendan, 2026-09-08. Independently verified twice with identical numbers: 696
tests / 24800 assertions / 0 failures, exit 0; editor import exit 0; a 300-frame
boot reaching `[Main] boot complete: PLAYING food-days 5.48 ready 408000 NP
fuel-days --` with zero ERROR lines.

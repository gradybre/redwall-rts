# 0222 — Harvests reserve their room, a cancel lets the carrier deliver, and the Pantry counts calendar hours
Date: 2026-09-30 · Status: Accepted

The external review of the live demo (written against 157a3a4) found five conservation and readout faults in the
farm and the woods: **F19** (a full store destroyed a harvest), **F24** (cancelling a harvest, or a woods job,
credited its load to the store wherever the carrier stood), **F25** (sapling compost paid again after an
interruption and a change of hands), **F27** (the Pantry's "spoils in N h" was base shelf life, not calendar hours)
and **F28** (fractional stock truncated to "0 U", and the total summed after truncation). All five were reproduced
on this branch (feat/live-demo at 43d9654) before any fix, through the production verbs and normal stepping.

Numbered 0222 -- the highest record on the branch was 0211, plus 10 -- so that branches working in parallel on the
same review do not collide.

## Decision

### 1. A harvest reserves its room before it is cut (F19)

`farm_pantry.gd` keeps **reservations** ("holds"): a packed table of (location, milli-U) rows that follow their
store by id across `refresh_locations`, as lots do, and answer STORAGE_LOCATION_GONE once it is filled in. Room a
hold keeps is not free: `add_into`, `location_for_into` and `location_near_into` all count it as taken
(`room_milli_of`).

`farm_crew.gd` reserves the expected yield (`farm_sim expected_yield_into`) at the store the harvest would go to,
**as the cutting starts**. With room nowhere the crop is **not cut**: the job goes back on the board blocked for
room, its worker is freed, and the shortage is said once -- in the order's answer, in the feed, and in the bed
panel's own clay line ("Waiting: no store has room for 5.1 U of carrot — make room in the Pantry (K)") with a
**Make room… (Pantry, K)** button that opens the Pantry. The crew's pickup, a resident's resume and a re-order all
check for room first, so nobody walks out to a harvest that cannot be stored; the job is handed out as soon as there
is room.

**Partial acceptance is explicit.** A store can still shrink under a reservation (a cellar's racks taken out;
`room_fixtures.gd` only stops them going below what is *stored*). At the store the carrier puts down **what fits**
(`store_upto`: free room plus its own hold) and keeps the rest carried: it reserves again from where it stands and
walks the rest on, or -- with room nowhere -- waits there with it, trying again every drop (1 WU), keeping its spent
reservation to follow that store by id (or walking to the covered store if its own has gone). The feed says what
the store took and what is carried on.

A store is only offered (for a reservation or a hand-out) where the delivery's **item can also be kept as a lot**
-- a free lot row, or a lot of that item there to merge into (`_lot_row_for`). Without it, a full lot table made a
store with room accept nothing, and the carrier re-reserved the same store forever. A delivery with no reservation
of its own gets only free room (`store_upto_into` with FREE never reads another hold's row), and that function now
refuses a bad item, quantity or store explicitly instead of answering "nothing fitted".

Rejected: checking room only when the order is given (a store fills between order and cut); cutting anyway and
dropping a recoverable ground bundle (a second physical-stock system, and it would still need a destination); and
over-filling the store (breaks the capacity the Pantry shows).

### 2. Cancelling production is not delivering its load (F24, Brendan's ruling)

Brendan ruled that **cancelling a harvest lets the carrier finish the delivery**. So "Cancel jobs" on a bed closes
its production only; a harvest already cut becomes a **delivery** (`farm_jobs.gd KIND_DELIVER`, not an orderable
kind): at the very point of the carry walk or the drop it had reached, so a walk under way simply carries on, and
the store is credited **on arrival**. A delivery no longer stands on its bed's harvest (a new one can be ordered
there), and a second cancel leaves it alone.

The woods keep the same rule with their own table (`forest_jobs.gd KIND_CARRY_LOGS`, `KIND_CARRY_PLANKS`): a
cancelled haul or gather with logs in hand walks them to the log stack; a sawing with logs taken carries them
**back** to the log stack (they were never sawn); a sawing with planks walks them on to the plank stack.
`cancel_all` leaves deliveries running and counts only the production it cancelled.

**A job never closes holding a load**, in either crew: a walk that cannot get through (`couldn't get there`, `no way
through`) puts the job back on the board with its load, blocked for a way, and the next hour lifts the block for
another try (the farm's `assign` now starts the walk's tries afresh, as the woods' did, so a retried delivery does not
stand further off each time; a woods resume does not take a job still waiting for a way). The old `_deliver_load` /
`_finish`-credits-the-store path is gone from both crews.

**Interruption and reassignment keep the load.** Every job now carries a **serial** for its whole life (through
rewinds, reassignment, a fell turned haul and a harvest or haul turned delivery), and `take_back` is bound to (row,
serial) instead of (row, kind, target), so a resident ordered away mid-delivery comes back to the delivery through
its resume queue (`resident_brain.gd` RESUMING) even though the job changed kind meanwhile; released, the routine
crew takes it. The farm's carry view draws the carried harvest for deliveries too.

### 3. Planting's compost is paid once per job (F25)

`forest_jobs.gd` has a `paid` column. `_begin_planting` takes the 0.25 U only when the job has not paid; it stays
paid through `rewind_to_walk`, `unassign`, a new planter and every retry, and is cleared only when the row is reset
for a new job. The **work** restarts after an interruption (the woods' rewind already zeroes elapsed work; kept as
it was) -- the input is not charged again either way. A planting cancelled after it paid does not refund: the
compost went into the ground at the productive start, as sowing's seed does (REQ-SET-071); the next planting on that
spot is a new job and pays.

### 4. The forecast is calendar hours, and names the next lot (F27)

`farm_pantry.gd lot_spoil_hours(lot, hour_index)` counts the **hour crossings** until a lot spoils, at its store's
factor and at each crossing's season -- exactly the integer sum `age_hour` will make, remainder included, season by
season (the crossing into hour h ages at the season of hour h, which is the order `demo_farm.advance_calendar` runs:
midnight's `run_day` sets the new season before that hour's ageing). `demo_farm.advance_calendar` now ages each
crossing at **its own** season (`season_of_hour`), not the season at the end of the frame, so a frame that crosses a
season change (a long frame, or a test's big step) ages exactly as forecast. `first_to_spoil_into` picks the lot that spoils
first across stores, not the oldest by effective age. The Pantry row reads "Carrot — 5.1 U · spoils in 551 h in the
root cellar" (one lot) or "Carrot — 5.1 U · first to spoil: 2.0 U in the covered store, in 200 h" (several), and a
note under the stores line states the assumption. `hours_left_into` stays, documented as base shelf life at the base
rate, for the tests that read it.

The forecast is **exact, not "about"**: tests age a lot hour by hour at each crossing's season and it spoils at the
forecast crossing and not the one before (160 summer hours for roots in the covered store; 100 spring + 94 summer
across a season change).

### 5. One units form, summed first (F28)

`farm_text.gd units_text(milli)`: tenths of a unit, **floored** (a figure never claims food that is not there), "0 U"
only for nothing, "<0.1 U" for less than a tenth. It is used for the Pantry's total, rows, store line (stock and
capacity), spoiled food, the bed panel's yield, the crop picker's base yield, the harvest notices, a carrier's task
line ("Carrying 5.1 U of carrot to the covered store") and the HUD's Food cell, which now takes the pantry's
**milli-U** total (`total_milli`, summed before formatting; `total_units`, which summed truncated per-item units, is
removed). The woods' `forest_rules.units_text` already used the same tenths; its "0.25 U needed" compost cost stays
a literal (it is exact, and one decimal cannot state it).

The instruction suggested "<1 U" for non-empty stock under one unit; with tenths everywhere that case reads e.g.
"0.9 U", so the "less than the precision" form is "<0.1 U".

## Consequences

- Anything that adds food to the pantry must respect reservations (`add_into` does). A future producer that must
  never fail at its destination should reserve first, the way the harvest does.
- `farm_crew.take_back` and `forest_crew.take_back` take (row, serial); a resume bound to the old (row, kind, target)
  shape no longer exists.
- Spoil carried to a bed for Raise/Bank/Compost-from-spoil is still dropped if that job is cancelled mid-carry (it is
  not stock in the pantry or the stores); out of this review's scope and recorded here as open.
- A carrier waiting for room holds its load in place until the player makes room or orders it away; nothing times it
  out.
- Mutation testing (46 mutants of the new logic in the pantry, both crews, both job boards, the text and the
  Pantry panel, one at a time, sources shasum-checked after each): every one killed after the tests listed below were
  added for the 8 that first survived.
- Tests: `godot/test/test_demo_conservation.gd` (full before cutting, fills en route, cancel mid-carry, interruption
  and resume, reassignment to the routine crew, cancel before the cut, the woods' cancels and interruption, planting
  interrupted and transferred twice, the calendar forecast, the units), a root-cellar cancel in
  `test_demo_integration.gd`, and the earlier instant-credit tests (`test_demo_farm_ui.gd`, `test_demo_forestry.gd`)
  rewritten to the new contract.

## Source

The external review (`REVIEW.md` F19, F24, F25, F27, F28, and P2's "Lifecycle work detail"); Brendan's ruling on
F24 (a cancelled harvest's carrier finishes the delivery); GDD §5.7 (shelf hours), §5.8 (store and temperature
factors, lots), §5.9 (planting's compost), REQ-SET-071 (the productive start), REQ-SET-074 (harvest); decisions 0196
(the live demo), 0205 (resuming), 0209/0210 (root cellars as stores, carried in).

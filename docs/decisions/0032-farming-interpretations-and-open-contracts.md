# 0032 — Farming: five open contracts and the readings taken meanwhile
Date: 2026-09-09 · Status: **SUPERSEDED IN PART — all five items ruled on 2026-09-09**
Source: task 03 increment 6, `godot/scripts/core/farming.gd`

## Resolution, 2026-09-09

All five open contracts below were answered by
[the READY_06 ruling](../rulings/2026-09-09_ready06_open_item_answers.md) §6 and §7, which
Brendan adopted, and the answers are implemented in `godot/scripts/core/farming.gd`. **The
original findings are left standing below, unedited**, because what was observed and why still
matters; this section records only what the ruling changed and what it ratified.

| Item | Ruling | Outcome for the shipped code |
|---|---|---|
| 1 `SOWN` vs `GROWING` | §6.1 | **RATIFIED and extended.** The reading was correct. Added: seed is committed only at *productive start* (the plot is EMPTY while a sowing job is queued, reserved or travelling); a post-commitment cancellation (`cancel_sowing()`) discards seed and WIP with **no refund** and preserves soil, family, compost history and earned XP; a worker change calls nothing here and cannot commit seed twice. |
| 2 `family_streak` counts harvests | §6.2 | **RATIFIED and extended.** Harvests, not sowings, was right. Added: a different family resets to 1; withering, fallow time, unfinished sowing and redraw neither reset nor advance it; the count **saturates at `INT32_MAX`** instead of overflowing — the one stated exception to this codebase's refuse-rather-than-wrap rule. |
| 3 `FarmPlot.compost_milli` | §6.3 | **CHANGED.** It is not a lifetime quantity ledger; it is a **current-season mirror**, 0 or 2000, derived at creation, redraw and load from the authoritative `TileHistory.compost_season`, and reset at a season boundary without touching tile history or fertility. `create_plot_at_tile()` therefore now takes a calendar day. |
| 4 The 48-hour grace and the withering share one instant | §6.4 | **RATIFIED, with the decay schedule tightened.** Both windows run from `ripe_tick` and withering is at **120** hours, not 168 — the shipped `RIPE_WITHER_DAYS = 5` already gave that and is unchanged. Changed: there is **no third harvestable decay step**; `MAX_HARVEST_DECAY_DAYS` is 2, `spoiled_yield_milli()` refuses a third, and `harvest()` refuses at or past 120 hours with `RIPE_EXPIRED` whether or not the expiry sweep has run. |
| 5 No crop-family enum exists | §6.5 | **Already corrected before the ruling, in `cc20c42`.** The finding below was wrong: §4.2's closing paragraph and BAL-CAT-002 already numbered CropFamily. The module reads `Catalog.CROP_FAMILY` (CEREAL=0, FIBER=1, LEAF=2, LEGUME=3, ROOT=4), and the ruling confirms `TileHistory` and every family-indexed lookup use that compiled domain. Verified again during this pass: nothing in the module carries a local family ordinal. |

**The ARCH-STATE-003 shortfall below is closed, not merely reported.** READY_06 §7 adds
`TileHistory.family_streak: I32[16384]`. That group is now seven I32 columns and **458752 bytes,
from 393216 — +65536**, with `systems_architecture.md`'s auxiliary sum, ledger total, one-world
total, headroom and two-world peak all moved by the same delta. The tile owns the
`(last_family, family_streak)` pair, plot rows mirror it, both halves move together on a
completed harvest and both are restored on redraw. The exploit is closed: a third-or-later 700
stays 700 across an erase-and-recreate, where it previously became 850. `_rotation_factor()`'s
`maxi(streak, 1) + 1` compensation for the lost count is gone with the shortfall that needed it.
A populated family paired with a zero count is now **refused** by `restore_tile_family_history()`
rather than reinterpreted, which is the ruling's "explicit migration or rejection".

**Still open, and not closed by this ruling:** there is no soil-type column, so a redrawn plot may
declare a soil the tile did not carry and this store cannot detect it. That remains blocked on
REQ-SET-009 world generation, exactly as recorded below, and the ruling says so explicitly.

**Not built, with its blocking dependency named:** the sowing *producer* — the job that queues,
reserves, travels and accumulates the 4000 milli-WU, and the pre-commitment cancellation regime
that releases its reservations while the plot is still EMPTY — is READY_06 item 1 (R06-JOB-004).
`jobs.gd` is still not called from `farming.gd`, and nothing is stubbed for it.

## Why this record exists
§5.6 is unusually complete on arithmetic and unusually silent on state
transitions. Every number in the growth, yield, compost and fallow formulas is
stated and was transcribed. **Five contracts are not stated, and three of them
govern persisted columns**, so getting them wrong later breaks saves rather than
just behaviour.

## Needing a ruling *(the original 2026-09-09 finding; all five now ruled — see above)*

**1. `SOWN` versus `GROWING`.** §4.3 numbers both, and §5.6 never says what
separates them. Read as: `SOWN` = seed committed with the 4 WU sowing
outstanding; `GROWING` = REQ-SET-072 integrating hourly. `state` is persisted.

**2. `family_streak` counts harvests, not sowings.** §5.6 says "a second
consecutive same-family **harvest**", so a crop that withers unharvested does not
advance the streak. Defensible from the wording, but not stated outright.

**3. What `FarmPlot.compost_milli` holds.** `TileHistory.compost_season` is
already the once-per-season eligibility gate, which leaves the §4.2 column
without an obvious job. Used as the quantity ledger (0, then 2000). A
partial-application buffer has no support in §5.6's flat "2 U/tile".

**4. The 48-hour grace and the 5-day withering share one instant** (`ripe_tick`).
The alternative reads the five days as running *after* the grace expires. **The
two readings differ by two whole days of yield decay** — this is the one with the
largest balance consequence.

**5. No crop-family enum exists.** §4.3 numbers no family, so `FAMILY_*` are
module-local ordinals in §5.6's printed order and deliberately **not** added to
`PROTECTED_ENUM_DOMAINS` — decision 0018 covers enums §4.3 *numbers*, and this it
does not list. `last_family` is persisted. **This is the third instance of the
same gap**, after `HabitatType` and `WeatherEvent`.

## ARCH-STATE-003 is satisfied except in one place, and the shortfall is the architecture's *(closed; see the resolution above)*
Directly tested: a redraw does **not** restore fertility and does **not** reset
compost eligibility, and last family, last legume day, ripe tick, growth
remainder and the tending flag all survive `destroy()`.

**`family_streak` has no `TileHistory` column.** §4.2 puts the streak *length* on
the `FarmPlot` row, and §2's `TileHistory` carries only `last_family`. A redraw
therefore restores the family but not the count.

The direction of that error matters and was checked: `_rotation_factor()` reads a
restored family with a zero count as a **second** consecutive harvest (850),
never a first (1000), **so a redraw can never fabricate a rotation bonus** — which
is BAL-SAFE-014's actual concern. It can still *lose* a penalty: a third-or-later
700 becomes 850 across a redraw. Closing it needs a seventh I32 column, **+65536
bytes** over the budgeted 393216.

There is also no soil-type column. Soil is not time-dependent, so its absence
fits ARCH-STATE-003's wording, but a redrawn plot may declare a different soil
than the tile previously carried and this store cannot detect it. §5.1's soil
bands belong to REQ-SET-009 world generation, which does not exist.

## Interpretations taken, each labelled in the module header
- **Temperature bands are whole degrees** (thresholds 0 / 80 / 270 in tenths).
  Every temperature §5.10 can produce is a whole degree, so no reachable world
  state distinguishes this from a strict "above 26.0 °C" reading.
- **"Within 2000 outside range" is inclusive** — ≤ 2000 gives factor 500.
  BAL-PROBE-001 corroborates the shape (9400→500, 9600→0) but not the endpoint.
- **A LEGUME as the very first crop scores 1000, not 1100**, because 1100
  requires "after a *different* family" and a first crop follows none.
- **`compost_season` stores an absolute season index** `(day-1)/12`, not §4.3's
  repeating 0–3 ordinal — which would have made the once-per-season gate
  permanent after the first year.
- **Fertility is clamped 0–10000 everywhere.** §5.6 states the cap only for
  compost, but beans' −800 gain and the fallow rates also add.
- **The legume fallow bonus runs on `last_legume_day + 1 … + 12`** — the twelve
  days following the harvest, not including it.
- **Clearing a plot cancels the tile's tending flag**, so a same-day replant does
  not inherit the previous crop's tending. Found by mutation, not by design.

## Independent corroboration
The growth integrator reproduces **BAL-PROBE-001 test-for-row**: all 19 published
`moisture_factor` values, the whole 18-day cumulative-growth column, and its
"first ripe day is 19" conclusion at exactly 192000 milli-hours. That fixture was
published before this module existed, so it is a genuine external check rather
than the code agreeing with itself.

## Two mutation survivors, both proven unreachable
- Widening the ripe-grace comparison to `<=` is **equivalent**: both forms return
  0 for every input, since the floor branch also returns 0 across [49, 72). The
  48-hour boundary itself is covered — mutating 48 to 47 is killed.
- Not resetting `growth_remainder` on plant is **unreachable** under the stated
  tables: every §5.6 factor is a multiple of 100, so `1000 * tf * mf` is always an
  exact multiple of 10^6 and the retained fraction is always 0. A test asserts
  that directly. The reset stays as defence for a loaded save or a later inexact
  factor.

Three other mutants survived the first sweep and were **real test gaps**, now
closed: tending was never probed at exactly the crop's minimum moisture, and
clearing a plot left both `ripe_tick` and `tended_today` stale.

## Source
Task 03 increment 6, 2026-09-09. 1161 tests / 34543 assertions / 0 failures; 90
mutations, one per run, with paired variants for the six killed only by `_init`
drift asserts — none of which proved vacuous.

Resolution pass, 2026-09-09: **1247 tests / 36091 assertions / 0 failures**; 43 mutations, one
per run, all killed, each on a value mismatch rather than an `_init` drift assert, with the
production file byte-compared against a pristine copy after every restore.

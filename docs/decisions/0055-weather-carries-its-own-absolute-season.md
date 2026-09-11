# 0055 — Weather carries its own absolute season, ARCH-SYS-006 is the only writer of `FishStock.closed`, and the CropWeather latch is retired
Date: 2026-09-11 · Status: **Accepted** ·
Implements [ruling 2026-09-11 §4](../rulings/2026-09-11_ready07_open_item_answers.md) ·
Depends on decisions [0028](0028-weather-event-selection-mapping.md),
[0046](0046-ecology-runs-one-leg-of-the-daily-boundary.md),
[0047](0047-cropweather-has-two-cadences.md),
[0050](0050-ready07-source-audit-and-ledger-reconciliation.md),
[0051](0051-hive-service-is-a-third-owner-class.md)

## Decision

Three things, all of which ruling 2026-09-11 §4 settled and none of which this
implementation chose for itself.

1. **§4.2 — the Weather row gains a temporal identity.** `weather.gd` keeps GDD
   §4.2's eight I32 columns exactly as they are, including `forecast[3]` read as
   `(event_id, start_season_day, duration_days)`, and adds **two I64 columns**:
   `scheduled_absolute_season` and `forecast_absolute_season`, both empty at
   **-1**. `absolute_season = floor((absolute_day - 1) / 12)`; the matching §4.3
   ordinal is `absolute_season % 4`. That is **+16 payload bytes**, taking the
   Weather row from 32 to 48.
2. **§4.1 — ARCH-SYS-006 owns the weather-to-fishery join.** `crop_weather.gd`
   writes `FishStock.closed`, at every midnight, after the new day's weather and
   before job planning. ARCH-SYS-005 writes it never.
3. **§4.3 — every row operation takes the absolute season.** `schedule_*`,
   `disclose_forecast`, `is_forecast_due`, `refresh_daily`, `end_event`,
   `is_event_active`, `active_event_on` and `is_blight_active` now take
   `absolute_season` and derive the 0–3 ordinal from it. No caller supplies both.

Seven things were decided along the way and each could be undone by accident.

## 1. The season column was the gap `weather.gd` itself had recorded

That file's header carried two `NEEDS A RULING` paragraphs: "THE SEASON IS NOT
IN THE ROW" and "WHAT `forecast: int32[3]` HOLDS IS NOT STATED". Both are now
closed, and closed the way the file had already argued for — the forecast tuple
interpretation was **adopted**, not replaced, and the missing identity was
supplied as new columns rather than by transforming §5.10's stated day 6 into an
absolute day index.

The old guard was `REFUSE_EVENT_NOT_ELIGIBLE`: a caller who handed the wrong
season was caught only when §5.10 did not admit the stored row there. The file
described that guard as **partial**, and it was. Ideal spell and calm days are
eligible in all four seasons, so a spring ideal spell asked about a summer day
was silently reported as active. `test_refresh_daily_refuses_a_stored_row_the_season_does_not_admit`
asserted that hole as a documented limit. It is now
`test_refresh_daily_never_applies_another_seasons_event`, and the hole is closed
in both directions: a day of any other absolute season simply has no active
event and carries its own season's baseline. **The behaviour change is
deliberate and the test was rewritten to state it, not weakened.**

## 2. The scheduled-once latch has ONE owner, by migration and not by agreement

Ruling §4.2: "The existing CropWeather latch must agree with it on load, or be
replaced by this single owner in one migration. No independent extra latch
allocation is implied."

**The second option was taken.** `crop_weather.gd`'s private
`_last_scheduled_season` is **deleted**. `last_scheduled_season()` now reads
`weather.scheduled_absolute_season()`, and `CropWeather.NO_SEASON_SCHEDULED` is
defined as `WeatherScript.ABSOLUTE_SEASON_NONE` rather than restated as `-1`, so
the two cannot even disagree about what "empty" looks like. The reconciliation
problem is therefore **structurally absent** rather than checked on load: there
is nothing to reconcile.

`weather.schedule_season_event()` refuses `SEASON_ALREADY_SCHEDULED` for a season
it has already scheduled, **before** touching the stream, so the enforced latch
costs zero draws when it fires. §5.10's "exactly one major event occurs per
season" stopped being the caller's discipline.

The latch survives event expiry — `end_event()` deliberately does not clear it —
because clearing it would let a season that had already spent its one draw take a
second. It moves only inside `_write_schedule()`.

## 3. A scheduled event is not an active one

Activity now requires **both** a matching `scheduled_absolute_season` **and** the
half-open interval `[start, start + duration)`. The interval is written as
`season_day < start_day + duration_days` rather than `<= last_day()`, so the
half-open reading is the literal code rather than an arithmetic identity a reader
has to re-derive. `last_day()` survives as a reader and is no longer load-bearing.

## 4. The twelve `AFFECTS_*` bits are a versioned effect mask, derived every time

Ruling §4.2 keeps the existing bit positions 0–11 — temperature, rain, moisture,
crop growth, crop damage, outdoor work, boats, exposure, lake ice, mussel
harvest, orchard water, frost — and makes them a **versioned effect mask**
(`EFFECT_MASK_VERSION`), not a new system enum. `effect_mask_for(event, season)`
derives it from the event id, the season and the typed tables, and **nothing
stores it**, so it can never become a second independently writable truth.

`MUSSEL_HARVEST` is **stripped for non-summer blight**: §5.10 states the closure
as "summer mussel harvest closes", and §5.10's own eligibility column admits
blight in autumn as well, where it damages crops and closes nothing. The strip
removes exactly one bit — `test_the_effect_mask_strips_mussel_harvest_for_non_summer_blight`
asserts `autumn == summer & ~AFFECTS_MUSSEL_HARVEST`, so a wider strip fails.

A coarse reading is forbidden: `AFFECTS_TEMPERATURE` and `AFFECTS_RAIN` reach
orchards, storage aging and heating/exposure as well as crops, and
`test_a_temperature_or_rain_event_is_never_reported_as_crops_only` proves every
such row sets a bit outside the two crop bits. Calm days states no modifier and
still receives its required forecast.

## 5. The closure has one writer, one cause, and no reason mask

`crop_weather.gd` step 4 sets every **present** mussel stock's bit to
`new_season == SUMMER && active_new_day_event == BLIGHT`, through
`weather.closes_mussel_harvest_on()` — a single expression that reads the ruled
effect mask, so the strip in §4 above and the closure cannot drift apart.

It writes **unconditionally**, open as well as closed. "Set it false otherwise,
including autumn blight and the day after expiry" is as much a write as the
closure is; a sweep that only ever closed would leave a bed shut for a year.
`fishing.apply_mussel_event_closure_into()` is that sweep: allocation-free, mussel
only, and reporting a count rather than refusing when a world has no coast.

§5.4's calendar closures stay a **separate** derived predicate.
`is_harvest_closed()` is `calendar_closed || event_closed`, and both halves are
now published by name (`is_calendar_closed()`, `is_event_closed()`). **No typed
reason mask is added.** Ruling §4.1 says a future additional cause would need one
and that adding it now is unnecessary; inventing a column for a cause nobody has
stated would be exactly the kind of guess AGENTS.md forbids.

**Both contradictory comments in `fishing.gd` were amended.** The header said the
join was "ARCH-SYS-006's job (increment 10)"; `set_closed()` said "ARCH-SYS-005
owns any daily orchestration that would write the bit". The ruling settles it for
006, and `ecology.gd` now says so in its own header and leg docstring — with
`test_the_ecology_day_writes_no_fish_closure_bit_at_all` driving four days past a
deliberately-closed stock and a deliberately-open one, so a blanket write in
either direction fails.

## 6. The boundary is preflighted, because a refusal is a failure

Ruling §4.1: "Preflight required season identity, RNG and catalog inputs before a
boundary can partially advance. A scheduling refusal is a failure requiring a
diagnostic, not permission to clear some state and publish an apparently
completed tick."

`_preflight_day()` runs **before the day latch is consumed**: it proves the
absolute season decodes and that `absolute_season % 4` is the season the clock
decoded for the same tick, that both catalogs still compile the ids the tables
are subscripted by, and — only when the boundary would actually draw — that the
WEATHER stream is bound and seeded. The forced first spring still opens an
unseeded world, because it takes no Rng at all.

**This changed a tested behaviour and the test was rewritten to state it.**
`test_a_refused_day_carries_no_counts_from_the_steps_that_already_ran` asserted
that an unseeded summer draw still consumed day 13 — the latch was raised before
the steps, so earlier steps stayed committed and the day was unrepeatable. It is
now `test_a_preflight_refusal_advances_nothing_at_all_and_can_be_retried`, which
asserts the day is untouched, the plot's moisture is unmoved, the refusal carries
`rng.gd`'s **own** `RNG_NOT_SEEDED` code rather than a local restatement, and the
very same day 13 runs to completion once the world is seeded.

The absolute season is computed twice on purpose — by `weather.gd` in the
preflight and by `farming.gd` in the schedule step — because the two stores
subscript different tables with it. A disagreement refuses.

## 7. The codec rule exists; the codec does not

Ruling §4.2 requires the tuple, the new fields and the latch to be versioned and
preserved, and an ambiguous old snapshot to be **rejected**.
`adopt_snapshot_identity(version, scheduled, forecast)` is that rule written where
the columns live. A `SCHEMA_VERSION_NO_SEASON_IDENTITY` payload is refused
**unconditionally**: its eight I32 columns carry no year at all, so even an event
eligible in exactly one season fixes only the 0–3 ordinal. "Never infer it solely
from an event eligible in multiple seasons" is the weaker half of a rule this
store satisfies completely by proving that nothing is provable.

**No save module was written and none is implied.** ARCH-SYS-022 still has no save
stream, so full save parity for these columns remains **blocked on the codec**
and is reported as such, not stubbed.

## Memory ledger

`docs/systems_architecture.md` §2.2 gains **one** field row,
`8 * 2 * 1 = 16 bytes`, checked individually rather than by its total. No §2.3
allocation row is added: the Fixed registry payload row **is** the §2.2 sum and
moves with it.

| Metric | Before | After |
|---|---:|---:|
| Fixed-field payload sum (§2.2) | 25028946 | **25028962** |
| Printed §2.2 field rows | 140 | **141** |
| Planned allocated payload | 60292646 | **60292662** |
| One live world plus reserve | 68681254 | **68681270** |
| Headroom below 100000000 | 31318746 | **31318730** |
| Rejected two-world peak | 122758316 | **122758348** |
| Carried ARCH-MEM-009 total | 59855014 | **59855030** |

ARCH-MEM-010's **437632** gap is reproduced a **fourth** time, not re-applied:
both halves moved by the same +16. `docs/validation/ready07_arithmetic.py` has its
pinned expectations **advanced**, never loosened — the row and allocation counts
are still pinned exactly, the Weather I64 row is pinned as printed so a silent
revert fails there, and the carried-basis figures are checked as identities.

## What this decision refuses to invent

- **No typed reason mask** for `FishStock.closed`. Ruling §4.1 says one would be
  needed for a second cause and that adding it now is unnecessary.
- **No save/codec module.** The ambiguity rule is implemented; the format is not.
  Full save parity for the two new columns is **BLOCKED** on ARCH-SYS-022.
- **No production claim that any seed selects blight.** Every §4.3 fixture
  **injects** its event by advancing the WEATHER stream until the module's own
  published `event_for_roll()` maps the next draw to it, and then asserts which
  event the boundary actually scheduled. `_arm_event()` can only reach an event
  §5.10 admits in that season.
- **No new refusal that a standalone fixture cannot satisfy.** The daily leg does
  **not** refuse a boundary whose preceding hour was never simulated; it
  **reports** the consumed hour on `DayResult.elapsed_hour_tick` instead, which is
  what `test_the_hour_before_tick_427500_still_uses_summer_climate` asserts.

## Ruling §4.3's exact fixtures, as named tests

All in `godot/test/test_crop_weather.gd`, each typing its tick as a literal and
checking it against `(D-1)*18000-4500` computed independently.

| Tick | Day | Test |
|---:|---|---|
| 247500 | summer day 3 | `test_summer_day_three_tick_247500_discloses_the_forecast` |
| 301500 | summer day 6 | `test_summer_day_six_tick_301500_closes_the_mussel_harvest` |
| 337500 | summer day 8 | `test_summer_day_eight_tick_337500_remains_closed` |
| 355500 | summer day 9 | `test_summer_day_nine_tick_355500_reopens_the_mussel_harvest` |
| 427500 | autumn day 1 | `test_tick_427500_does_not_reuse_the_summer_schedule`, `test_the_hour_before_tick_427500_still_uses_summer_climate` |
| 463500 | autumn day 3 | `test_autumn_day_three_tick_463500_carries_absolute_season_two` |
| 517500 | autumn day 6 | `test_autumn_day_six_tick_517500_permits_mussels_during_a_blight` |

Repeats are covered by `test_the_closure_repeats_in_the_following_year` (year 2's
summer day 6, absolute day 66, tick 1165500),
`test_a_duplicate_boundary_call_changes_no_closure` and
`test_hours_without_a_boundary_never_move_the_closure`.

## Mutation testing, and the one mutant that is provably equivalent

**47 mutations, one per run**, each applied to a pristine copy, restored, and the
restored file byte-compared by sha256. The failure count is parsed as an
**integer** from the runner's summary line, because a substring test such as
`"0 failure(s)" not in summary` matches `"10 failure(s)"` and would report a
survivor as killed. Every ruling fixture tick, the season-crossing argument, both
ends of the half-open interval, the `MUSSEL_HARVEST` strip, every `-1` sentinel,
the scheduled-once latch, the codec's ambiguity rule, the preflight and the two
ledger rows were mutated. **46 killed.**

The first pass left four survivors, and **three were real gaps in the tests, not
equivalences**:

- `identity-preflight` — the season-identity comparison was unreachable, because
  `run_day_into()` derives both sides from one decoded tick. Fixed by publishing
  `preflight_refusal_for(absolute_day, season)`, a pure reader that takes the
  season as an argument and writes nothing, and testing every wrong season.
- `farm-cross-check` — a duplicate comparison of two derivations of the same
  `floor((day-1)/12)`, which no test could ever enter. **The branch was removed**
  rather than shipped untested; the invariant it guarded is asserted directly by
  `test_the_two_stores_derive_the_same_absolute_season` over four years.
- `sentinel-forecast-clear` — nothing read `forecast_absolute_season` after a new
  schedule cleared the forecast. Fixed by asserting it returns to **-1**.

The fourth, `elapsed-blight-arg`, **survives and is equivalent**, with a proof
rather than an assertion: `completed_day` is always `absolute_day - 1`, so the
elapsed and new absolute seasons differ **only** on a season crossing, where the
completed day is always **season day 12** — and no §5.10 event's window reaches
day 12, the latest being early frost's days 10–11. The completed-day blight leg
therefore cannot observe the difference **while that table holds**. Rather than
declare equivalence and stop, the enabling invariant is now itself a test,
`test_no_stated_event_ever_covers_the_last_day_of_its_season`, and that test is
mutation-killed (moving `EARLY_FROST_START_DAY` to 11 fails six tests). A future
table change that lets an event reach day 12 will fail there and put the elapsed/
new distinction back under scrutiny. The distinction is separately observable and
asserted regardless: `DayResult.completed_absolute_season` is derived from
`completed_day` and checked to be **1** while `absolute_season` is **2** at tick
427500, and mutating that derivation is killed.

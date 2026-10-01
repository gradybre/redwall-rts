# 0421 — A game day lasts ten real minutes in the demo, and the village's day is re-timed to fit it
Date: 2026-10-01 · Status: Accepted

Numbered 0421: the highest record on any branch or worktree was 0411, and the brief asked for the next free number
above 0420.

## The ruling

**Brendan, 2026-10-01: at 1x one game day lasts ten real minutes, as the adopted GDD says.** `docs/game_gdd.md` §5.1:
"At 1×: day 10 minutes, season 120 minutes, year 8 hours"; its §4.1 time row: "30 ticks/real second at 1×; 18000
ticks/day; 750 ticks/game hour". The review had noted the demo ran ten times faster (REVIEW.md, phase 2 C, "Time
boundary": "The live demo advances one day per minute at 1×").

Until now the demo calendar ran a game hour every 2.5 s (decision 0196, `HOUR_USEC` 2 500 000). Walking and work run in
real seconds, so at normal pace (about 0.72 m/s) a resident covered only about 2 m a game hour. A cook's 3 m pot carry
took 2-3 game hours, suppers came after their window, a harvest took 1.5-5 game days to reach the store, and a walk
across the village took 6-8 game hours, so the night had to start very early. Brendan accepted that seasons now pass
ten times slower in real time; players use 2x and 4x.

## The calendar: one source, the GDD's rate

- **`demo_calendar.gd HOUR_USEC` = 25 000 000** demo microseconds: 25 s a game hour, ten minutes a game day
  (`DAY_USEC` = 600 000 000), at 1x.
- **The tick math.** The calendar converts a frame's demo microseconds to ticks as before, integer with the remainder
  kept: `ticks = (remainder + usec x 750) div 25 000 000`. That is exactly `usec x 30 / 1 000 000`: 30 ticks a real
  second at 1x, 60 at 2x, 120 at 4x -- the settlement's own fixed tick. A tick is 33 333.3 us, so the remainder
  carries the third. Integer authoritative state stays integer; nothing new is a float.
- **One source.** Everything on the calendar reads its time from it and keeps no conversion of its own:
  - the kitchen's action cards convert their tick work through `demo_calendar.gd usec_for_ticks` (new), not their own
    `HOUR_USEC / TICKS_PER_HOUR`;
  - the fixture crew's keep is `CalendarScript.DAY_USEC`, not 60 s written out;
  - the Kitchen tab's note is filled from `meal_rules.gd`'s hours (`kitchen_text.gd tab_note`), not typed into text;
  - the tests read `HOUR_USEC` from the calendar rather than eleven copies of 2 500 000;
  - the dig readout's `TICKS_PER_CALENDAR_HOUR` was already derived from `HOUR_USEC` (now 750).
- **The settlement's clock** (GameManager) still runs apart and is not written. Both now run at 30 ticks a second, but
  they are two counters (the demo's starts and pauses with the demo).

## Every time constant: kept or re-tuned

Walking and work stay in real seconds at the resident speeds of decision 0205 (0.72-3.00 m/s; 0361's route desk is
unchanged). Each constant measured in game time was checked: is it a game-time rule (keep it), or tuned around the old
one-minute day (re-tune it)?

### Kept: game-time rules, unchanged in game time

| Constant | Where | Why kept |
|---|---|---|
| Crop growth, grace 48 h, withering 120 h, fallow days, the 12-day season, the 48-day year | `farm_sim.gd`, `scripts/core/farming.gd`, `sim_clock.gd` | GDD §5.6 / REQ-SET-006 values in game hours and days. A 120-hour crop now takes 50 real minutes at 1x (12.5 at 4x) |
| Weather spells: `SPELL_DAYS` 3, `SPELL_WET_DAY` 2; first-spring frost the night into day 11, blight day 12 (0205) | `weather/demo_weather.gd`, `farm/farm_weather.gd` | game days by design; day 11 is now about 100 real minutes at 1x, 25 at 4x |
| Spoilage: GDD §5.8 factors per game hour; `SOON_HOURS` 48; the spoil forecasts in calendar hours (0222) | `farm/farm_pantry.gd`, `farm_pantry_rows.gd`, `meal_store.gd` | game time; food now lasts ten times longer in real time |
| Hunger: 250 NP a game hour for a small resident (§5.2) | `kitchen/nourishment.gd` | game time |
| Drying walls over a game day; seam healing 3 game days (0211) | `burrow/room_view.gd`, `tunnel/bore_view.gd`, `tunnel/warren_signs.gd` | read the calendar's day; checked, none is real time |
| Tree regrowth 48 game days; stumps fresh 12 days; a deadfall pile a midnight | `forestry/forest_rules.gd`, `forest_view.gd` | game days |
| Farm re-alert `REARM_HOURS` 2 (0331); the Next-weather skip of at most 48 h | `farm/farm_alerts.gd`, `demo_farm.gd` | game hours: conditions change on hour crossings |
| Kitchen step rate: 80 milli-WU a calendar tick, 60 WU a game hour; eating 12 WU, a draw a WU a unit (§5.2) | `meal_rules.gd` | the GDD's rate. It was credited per calendar tick, so it ran ten times faster than real; now a batch of porridge is 150 ticks, 5 s at 1x -- the GDD's "one game minute" WU exactly (0.42 s) |
| Fishery days | `water/fishing_driver.gd` | follows the calendar tick; its unbound fallback (30 ticks a second) now agrees with it |
| `STAND_IN_HOURS` 4 | `kitchen.gd` | a stand-in may start the round within four game hours of a call; still sensible |

### Kept: real-time rules

| Constant | Where | Note |
|---|---|---|
| Walk, carry, wade and swim speeds | `demo_actor.gd`, `resident_brain.gd`, `swim_rules.gd` | real metres a second (0205) |
| A WU on screen: forestry 0.1 s (`USEC_PER_WU`), the farm 1.5 s (`DEMO_USEC_PER_WU`), fit-out 0.15 s (`INSTALL_USEC_PER_WU`), tunnel ticks at 30 Hz | their rules files | real seconds, as the brief rules. They now read as game minutes: a felling (120 WU, 12 s) is about 29 game minutes, a farm compost (8 WU, 12 s) 29, a bed 7, a hearth 22. The GDD's WU is 0.42 s; the kitchen runs at it, forestry and fit-out faster, the farm slower (open below) |
| The news strip's 12 s and 30 s, incident linger and snooze (0331) | `demo_news_strip.gd`, `demo_incidents.gd` | real time by UI §7 |
| Threat schedule: first at 6 min, then every 9 min (±2), 40 s long | `events/demo_events.gd` | real time; a threat now comes about once a game day rather than once every nine (open below) |
| Hazard build-up, rescue wash-ashore, bridge and spoil retries, the work board's 0.5 s claims, the crews' 0.5 s pick-ups | their files | real time |
| The stall banner's `CLEAR_TICKS` 300 | `ui/demo_stall_banner.gd` | the settlement clock's ticks (10 s at 1x), not the calendar's |

### Re-tuned

| Constant | Before | After | Why |
|---|---|---|---|
| `demo_calendar.gd HOUR_USEC` | 2 500 000 (2.5 s) | **25 000 000 (25 s)** | the ruling |
| `night_routine.gd DUSK_HOUR` | 18 | **20** | a walk home now takes under a game hour (18-26 m an hour against a 15-20 m village), so 18:00 sent everyone to bed four hours early. 20:00 is the end of the GDD schedule's social hours (§5.3: SLEEP 22:00-06:00, SOCIAL 18:00-20:00, ANYTHING 20:00-22:00): in bed by about 21:00, before its 22:00 sleep. `DAWN_HOUR` stays 06:00 |
| `night_routine.gd HEARTH_FROM_HOUR` | 17 | **19** | an hour before dusk, as before; `HEARTH_TO_HOUR` stays 07:00 |
| `night_routine.gd RESEND_TICKS` | 375 (half a game hour: 1.25 s) | **38** (1.27 s, about 3 game minutes) | a retry throttle for the player's responsiveness: keeps its real seconds |
| `kitchen.gd PICKUP_TICKS` | 150 (0.5 s) | **15** (0.5 s) | the hand-out cadence: keeps its real half second, as the other crews' `PICKUP_USEC` |
| `kitchen.gd RESEND_TICKS` | 375 | **`NightScript.RESEND_TICKS`** (38) | the diners' re-call throttle; keeps its real seconds |
| `fixture_crew.gd KEEP_USEC` | 60 s ("a game day") | **`CalendarScript.DAY_USEC`** (600 s) | it meant a game day; at 60 s the keep would lapse halfway through the night, before its installers came back in the morning |
| `meal_rules.gd CALL_HOUR` | [06, 13] | **[07, 17]** | see the meals below |
| `meal_rules.gd END_HOUR` | [13, 17] | **[09, 19]** | |
| `meal_rules.gd COOK_RISE_HOUR` | 01 | **05** | |
| `meal_rules.gd COOK_FROM_HOUR` | [01, 09] | **[05, 15]** | |
| `action_card.gd hours_text` | tenths of a game hour | **whole game minutes under an hour** (rounded up), tenths from an hour | most work is now minutes of a game hour: "about 0.3 game hours" reads worse than "about 18 game minutes" |
| `dig_readout.gd` time | tenths of an hour | **`time_text`: minutes under an hour**, tenths (floored, at least 1.0) from one | short digs read "0.0 h" otherwise |

## The meals, re-timed (decision 0381's hours)

0381's hours were tuned so that slow walking still fitted: breakfast 06:00-12:59, supper 13:00-16:59, the cook up at
01:00, supper cooked from 09:00. Now walking fits, so the day looks like a day:

- **Breakfast is called at 07:00 and served until 08:59**: 07:00 is the GDD schedule's work start (§5.3).
- **Supper is called at 17:00 and served until 18:59.** Its end is an hour before dusk (20:00), as 0381 required, so a
  raw emergency meal started at its end is eaten before bed.
- **The cook rises at 05:00**, an hour before the village. Breakfast for nine is five batches of porridge, 60 WU: a
  game hour at the step rate, plus the fetch.
- **Supper is cooked from 15:00**, two hours before its call.
- **Summer on the table.** A portion ages at the open-pile factor times summer's, 10.7 game hours of its 24. A breakfast
  put out at 06:00 lasts to about 16:40, and a supper put out at 16:00 to about 02:40: both outlast their windows. The
  suite pins it (`test_meals_are_cooked_close_to_their_calls_and_last_their_windows_in_summer`). A summer breakfast's
  leftover spoils just before supper's call, so it is not counted against supper there.

### Two kitchen fixes the new hours exposed

- **The cook eats breakfast.** With supper's food already fetched to the cauldron, the cook counted as "on duty" all
  morning (`_food_at_cauldron`), so it was never called to the table, and its round had nothing to do until supper's
  cooking time. Under the old hours supper could be cooked during breakfast, so this never showed. Food counts now only
  for a meal whose cooking time has come (or one ordered cooked now).
- **A raw meal's walk is retried.** Eating now takes real seconds (12 WU is 5 s), so a second raw eater can find the
  first eating at its spot at the store, or be blocked on its way. A raw meal comes after the serving's end, when no
  call repeats it, so one failed walk meant going without. Now a raw meal whose walk was given up (blocked, not an
  order) stays reserved and sets off again once its resident is free and `RESEND_TICKS` have passed, up to `MAX_FAILS`
  walks, to a spot clear of everyone standing still (`kitchen.gd _hold_raw_meal`, `_retry_raw_meals`,
  `_store_spot`). While held it is kept for the meals (the work board claims nothing for it, and the kitchen hands it
  no water to draw), and a player's order is waited out, never overridden. Taken to bed meanwhile, or not to be taken
  once free (the water, an emergency), it goes without and its food is given back -- it is not kept reserved all
  night. Called to the next meal while still held, its raw food is given back and the meal it missed is tallied
  "went without".

### Cooking only for the diners who will eat

This was not built. The kitchen already cooks for every resident less the leftovers still good at the call, and with
the meals now inside their windows nearly everyone comes (see Measured). Predicting who will not come (a resident far
off at work, or held by an emergency) is not cheap and would be wrong whenever a diner arrives after all.

## The UI

- **The date and the clock**: unchanged. The HUD prints the calendar's day ("Spring 3") and its tooltip the hour; it now
  turns every 25 s at 1x. There is no day-progress bar and no "Run until" in the demo (checked).
- **Action cards** (0332): work under a game hour reads in whole game minutes: "Work: about 29 game minutes, plus the
  walk" (a compost); an hour and more in tenths: "about 1.3 game hours". The Work screen's "left" uses the same text.
- **The dig readout** (0208) prints its time on the calendar's 750 ticks, by the cards' rule: whole minutes under an
  hour ("35 min"), hours to the tenth from one (a 12 m bore at one digger is "2.1 h"; it was "21.0 h").

## Speeds 2x and 4x

The calendar now crosses ten times fewer hours per real second, so the hourly work (pantry ageing, the kitchen's
planning, the farm's alerts, the weather) runs ten times less often. Walking and work are unchanged in real time.
See Measured for the 4x run.

## Tests

- **New:** `test_demo_clock.gd test_a_game_hour_is_25_seconds_at_1x_and_a_day_ten_minutes` (25 s = 750 ticks, a
  second 30 ticks, a day 18000; 60 Hz frames through the demo clock give 30, 60 and 120 ticks a second at 1x, 2x
  and 4x); `test_demo_night.gd test_a_walk_of_18_m_takes_about_a_game_hour` (the slowest walker, 0.72 m/s, 18 m in
  720-810 calendar ticks) and `test_a_resident_15_m_from_home_is_in_bed_within_an_hour_of_dusk`;
  `test_demo_kitchen.gd test_the_day_s_hours_follow_decision_0421` and
  `test_meals_are_cooked_close_to_their_calls_and_last_their_windows_in_summer`; the kitchen fixes' tests
  (`test_food_fetched_for_a_later_meal_does_not_keep_the_cook_on_duty`,
  `test_a_raw_meal_whose_walk_was_given_up_sets_off_again_after_a_pause`,
  `test_a_raw_meal_given_up_by_an_order_or_the_night_is_gone_without`,
  `test_a_held_raw_meal_waits_out_an_order_and_is_kept_from_the_work_board`,
  `test_a_held_raw_meal_not_to_be_taken_when_free_is_gone_without`,
  `test_a_held_raw_eater_called_to_the_next_meal_went_without_the_last`,
  `test_a_store_walk_that_failed_goes_to_a_spot_clear_of_those_standing`); `test_demo_graph.gd
  test_the_readout_says_minutes_under_an_hour`; and pins of the re-tuned intervals, the tab note and the fixture keep.
- **Updated:** every test that wrote the old rate out, or timed itself on the old hours. The kitchen's loop tests now
  step at the demo clock's 1/30 s with one calendar tick a frame (they stepped five ticks a 1/60 s frame), so walking
  and the calendar keep the ruling's ratio.

## Measured

Two scripted runs (before and after the review's fixes; the same results to within a few minutes) of the real
nine-resident village, staged assets, headless at 1920x1080, at 4x from boot (spring 1, 06:00) for 51 game hours, to
09:00 on day 2. As in 0381's runs the harness tops the kitchen pantry up with 40 U of wheat and 50 U of carrots, and
time-skips one roots bed to ripe; unlike them it does **not** place the fieldworker beside the bed: the harvest is
ordered from wherever it stands. Its log is the group's report; the numbers:

- **Meals inside their windows.** Each meal's portions were on the table at its call: 07:00 for the breakfasts of days
  1 and 2, 17:00 for both suppers (17:03 in the second run). The opening breakfast (day 0: the demo starts at 06:00
  with nothing fetched) went out at 08:40, inside its window.
- **Diners in time.** Every diner sat down to eat inside the window: the latest at 08:04 (breakfast, window to 08:59)
  and 18:24 (supper, window to 18:59).
- **Who ate.** Breakfast day 0: 8 ate, 1 went without (the fieldworker, carrying the harvest: 0222's load-first rule).
  Every other meal: 9 of 9. 44 portions eaten from 22 batches; no raw meals were needed.
- **The harvest reached the store the same day:** 5.1 U in store at 10:37, 4 h 37 min after the order at 06:00
  (0381 measured 1.5-5 game days).
- **Home before deep night.** Dusk is 20:00; everyone was asleep by 21:26 on night 0 (the first at 20:08) and by
  21:14-21:21 on night 1.
- **Spoiled portions: 0** in the two days (0381 counted about 20 in four).
- **4x held its budget.** All 46 189 frames ran at an effective 4x: no step-down to 2x, no stall pause. The calendar
  advanced 38 245 ticks in 318.7 real seconds -- 120.0 a second, exactly four times 30.

## Open

- **The demo's work rates differ from the GDD's WU.** A WU is "one game minute of base-speed productive labor"
  (§4.1), now 0.42 s. The kitchen runs at it; forestry (0.1 s) and fit-out (0.15 s) run faster, and the farm (1.5 s)
  slower. They were kept in real seconds as ruled; bringing them to the GDD's rate is a separate decision.
- **Threats come once a game day.** The demo's flood and fire (`demo_events.gd`) are on a real-time schedule of about
  nine minutes; on the new calendar that is about a game day apart, rather than nine. Left in real time as a demo
  showcase; a calendar schedule would put them ten times further apart in real time.
- **Seasons are slow at 1x.** A season is two real hours at 1x and 30 minutes at 4x, as the GDD intends; the first
  frost (the night into spring 11) is about 25 minutes into a 4x session.

## Superseded

- 0196 §6 (the one demo compression, `HOUR_USEC` 2 500 000): the calendar now runs at the GDD's rate.
- 0210 §6's hours (dusk 18:00, the hearths from 17:00, the resend of 375 ticks) and the fixture keep's 60 s.
- 0381's hours (breakfast 06:00-12:59, supper 13:00-16:59, the cook up at 01:00, supper from 09:00) and the kitchen's
  hand-out and re-call intervals.
- 0332's "work in game hours" wording: game minutes under an hour.

## Quality

- `./tools/run_tests.sh`: **7082 test(s), 562004 assertion(s), 0 failure(s)**.
- The live harnesses: `demo_input_live.gd` LIVE-SUMMARY 182 0 (1280x720) and 190 0 (1920x1080); `demo_layout_live.gd`
  LIVE-SUMMARY 145 0 (1280x720) and 211 0 (1920x1080).
- **Mutation testing**: 40 mutants of the changed logic (the calendar's rate and conversions, the night's hours and
  resend, the meal hours, the kitchen's intervals, the cook's duty, the raw-meal retry and its guards, the store
  spot, the card and readout time texts, the fixture keep, the tab note), each run against the clock, farm, night,
  kitchen, kitchen UI, action card, news and graph suites. All 40 are killed. Nine survived a first pass and were
  killed after tests were added for them; one (a redundant `task is SleepTaskScript` clause, equal to `resting`) was an
  equivalent mutant, and the clause was removed.

## The review (code-reviewer, 2026-10-01), fixed

- **H1** a resident holding a raw meal for a retry was not kept for the meals, so the work board claimed it first and
  the retry rarely fired: `kept_for_meals` now keeps it, and the kitchen's own `_free_for` does not hand it water.
- **H2** a held raw eater called to the next meal hid the meal it missed in the old tally: `_call_diners` now ends the
  old part (charging the missed meal) before it sets the new meal.
- **M1** at night a held raw meal stayed reserved and was eaten at dawn: it is given up once its resident is resting
  for the night; the test now uses the real dusk.
- **M2** the retry's guards are tested (an order waited out, three failed walks, the water's hold).
- **M3, M4** the cooking-time check is one function (`_cook_time_come`), and the part's reset one (`_reset_part`).
- **M5** the dig readout says minutes under an hour too (`dig_readout.gd time_text`).
- **Left as they are (LOW):** some new tests pin constants (the intervals, the hours, the keep) rather than behaviour;
  `_store_spot` allocates a small array once per walk issued, not per frame; the int32 tick columns wrap after about
  207 real days at 4x; a kept fixture place now blocks other installers for a game day (ten minutes) when its keeper
  is called away by daytime work too.


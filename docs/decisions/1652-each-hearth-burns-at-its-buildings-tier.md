# 1652 — Each hearth burns at its building's tier: the great hall at ×0.75 and 20 °C

Date: 2026-10-07 · Status: Accepted

Handoff packet HALL-FUEL (`docs/handoff/BACKLOG.md`). Branch `feat/demo-small-leftovers`.

## The rule and the ruling

- GDD §5.9, tier 2 upgrade packages: "residence/hall … heat fuel×0.75 and room comfort target+1000" (REQ-SET-136).
  `docs/gameplay_balance.md` gives the hall row's fuel as 3/4. Decision 0771 built the hall's tier-2 upgrade with
  `hall_rules.gd FUEL_PERMILLE [1000, 1000, 750]`, but nothing burned at it.
- REQ-SET-130: "maintain 18°C indoors at tier 1 or 20°C at tier 2".
- Brendan's batch-7 ruling 5 (decision 0902, 2026-10-02): "The hall's tier-2 fuel factor goes to a follow-up: a
  per-source tier factor in `hearth_fuel.gd`." This record is that follow-up; 0902 is not edited.

Both values are adopted GDD, so nothing here is a proposal. The packet asked to record whether REQ-SET-130's 20 °C is
added: **it is**, in the same rule row.

## Decision

- **`winter_rules.gd`**: `TIER_1`, `TIER_2`, `HEATED_TIER2_TENTHS` (200); `tier_fuel_permille(tier)` (×0.75 at tier 2,
  from the existing `TIER2_FUEL_PERMILLE`), `heated_tenths(tier)`, and `projection_of_milli(winter_day_milli, cook)`
  (twelve winter days over a demand summed hearth by hearth; `projection_milli(hearths, cook)` now delegates to it).
- **`hearth_fuel.gd`** (THE TIER): a per-source column `tier` (tier 1 unless told; `set_tier`, clamped to 1–2).
  `rate_of(s)` is today's demand at the source's tier, `day_demand_milli`'s own scaling of the tier-1 rate;
  `winter_rate_of(s)` the same on a winter day. The accumulator burns `rate_of(s)`, so over a day exactly 3 U (winter)
  or 1.5 U (a cold spring or autumn day) is taken at tier 2. A heated tier-2 room holds 20 °C.
  `heating_day_milli()` and the new `winter_day_milli()` sum the burning sources' own rates, so the fuel-days (the
  HUD's "Heating fuel: N days"), the last heated hour, the twelve-day projection (`projection_milli`) and the
  Firewood order's target all follow the per-source burn. `day_rate_milli` stays the tier-1 rate (the consolidation
  preview's per-home saving reads it; homes are tier 1).
- **`demo_winter.gd`**: `bind_hall_tier(() -> int)`, applied at once and read into the hall's row each hour
  (`_refresh_hearths`); unbound, tier 1. M4's fuel part (`fuel_winter_days_milli`, 0902 item 9) reads
  `winter_day_milli()`.
- **`winter_text.gd`**: the breakdown names a tier-2 hearth at its own rate: "Burning 7.0 U a day: 1 hearth at 4.0 U,
  the hall at 3.0 U, …" and "Winter needs 84.0 U (12 days: 1 hearth at 4.0 U, the hall at 3.0 U, …)".
- **`demo_village.gd`** (shared file; the hook): one line in `_build_hall()`, `_winter.bind_hall_tier(_hall.tier)`.

The winter reads the hall's tier, not its `fuel_permille`, so the room's 20 °C follows from the same input; a test
pins `winter_rules.tier_fuel_permille(t) == hall_rules.fuel_permille(t)` for both tiers so the two tables cannot
drift. The infirmary and the homes stay tier 1 (the demo has no residence upgrade).

An upgrade finished mid-hour shows in the figures at the next game hour, when the winter reads the tier; the burn
accumulator carries on at the new rate (no wood owed or lost).

## Tests and gates

- `test_demo_winter.gd`: `test_the_tier_factor_is_the_gdds_and_the_halls` (both tables, 18/20 °C, clamping),
  `test_a_tier_two_hall_burns_three_quarters_and_holds_twenty_degrees` (boundary at each tier: 4 U / 3 U a winter day,
  2 U / 1.5 U a cold spring day, nothing owed), `test_the_figures_sum_each_hearth_at_its_own_rate` (today's demand,
  fuel-days, last heated hour, projection, the words, summer's winter-day demand, a banked tier-2 hearth),
  `test_the_winter_reads_the_halls_tier_each_hour` (bound at once, a winter day at ×0.75, a change read at the hour,
  unbound tier 1), `test_the_tiered_hour_allocates_no_objects`.
- Live: `demo_winter_live.gd` gains `_the_great_hall_burns_three_quarters` (the hall at tier 2, the next hour: rate 3 U,
  20 °C, the breakdown's words); `demo_hall_live.gd` checks the winter reads tier 2 once the real upgrade completes.
  `LIVE-SUMMARY 44 0` (winter) and `LIVE-SUMMARY 42 0` (hall) at 1920x1080 and 1280x720.
- Frames (looked at): `scratchpad/hallfuel_check/breakdown_great_hall_{1920x1080,1280x720}.png` -- "Heating fuel: 6.7
  days" over 47.3 U at 7.0 U a day (the HUD and the burn agree), "the hall at 3.0 U", "The hall: heated, 20 °C".
- Mutation: 20 mutants, **20 killed** (the tier factor and the 20 °C dropped or misbounded; the room, the burn,
  `rate_of`, the winter rate, the projection and M4 at the full rate; banked hearths counted in either sum; the clamp
  on either side; the reduced count and both word paths; the tier not read each hour, not applied at bind, tier 2
  unbound; and `demo_village.gd`'s binding removed, killed by the hall harness). One first survived (a banked hearth
  counted in today's demand) and was killed by an added winter assertion.
- The full suite (CI-style), the analyzer, the contracts and the independent review are run once the branch's three
  packets are in; their lines are added below under "Branch gates" and "Review".

## Review (independent `code-reviewer`, on 2b9c0597)

Nothing CRITICAL or HIGH. The reviewer's probe confirmed the accumulator conserves wood exactly across a tier change at
every hour of a 48-hour run, and that every consumer of the old single rate now reads the per-source sums.

- **MEDIUM, fixed: six more mutants survived** the five related suites (the "20/20" above was this lane's own list):
  a tier-2 hearth OUT giving back the tier-1 rate; the words always at the winter rate, or the demand line's full rate
  at winter's; a banked tier-2 hearth still listed; the two revision bumps. New assertions: a cold spring day's words
  ("1 hearth at 2.0 U, the hall at 1.5 U") beside the projection's winter words, a banked hall absent from both lines,
  and `test_a_tier_two_hearth_out_of_fuel_owes_nothing` (five hours OUT at tier 2, nothing owed, then 3 U a day; the
  revision bumps). **All six now killed (6/6)**, so the lane's total is 26 mutants, 26 killed.
- **MEDIUM, fixed: player text with tier-1 figures only.** The field guide's wood and hearth entries
  (`field_guide.gd`) and the planner's winter rule (`farm_season.gd _fuel_rule`) now also give the great hall's 3.0 U
  (and its 20 °C), from the rules' own constants.
- **LOW, answered: `Rules.projection_milli(hearths, cook)`** has no production caller now; it is kept as the all-tier-1
  reference formula that `test_demo_winter.gd` checks the per-source projection against.
- **LOW, fixed:** the stale "18 °C" docstrings and an over-long header line.
- **LOW, answered:** the allocation test is a guard against an Object made per hour (OBJECT_COUNT does not see packed
  arrays or ints); its docstring now says so.
- **LOW, fixed:** the hall harness now also passes a game hour after the real upgrade and checks the hearth's row is
  tier 2 (`LIVE-SUMMARY 43 0` at both sizes).

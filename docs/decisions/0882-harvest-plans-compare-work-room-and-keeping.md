# 0882 — Harvest plans: a strategy, a projection against hands, room and keeping, and one booked order
Date: 2026-10-01 · Status: Accepted

Brendan approved the review's **ECO-003** ("Harvest plans for available hands", REVIEW.md 2228): "Extend the P4
calendar with a chosen farm strategy: 'steady table,' 'one large preserving harvest,' or custom dates. Compare
projected harvest work against scheduled hands and preserving capacity. A projected overload suggests a later sowing
date or smaller area, never silently changes crops. Batch the chosen plan as one farm order." Numbering: see 0881.

## Decision

A **Harvest plan** tab in the seasonal planner (decision 0451; `farm_planner.gd` TAB_HARVEST,
`farm/farm_harvest_page.gd`) over `farm/farm_harvest_plan.gd`.

- **Strategies**, for the laid, empty, unrested beds with a crop chosen (Plant…): **Steady table** sows the k-th bed of
  a crop `k × gap` days after its first legal day, the gap its growth days shared among its beds (at least one day);
  **One preserving harvest** sows every bed on its first legal day; **Custom dates** is the player's Earlier / Later for
  a picked bed. A legal day is one §5.6's planting window and the bed's soil allow (`farm_soil_plans.gd`
  `first_window_day`), within a season ahead; a day is never moved past the window's last legal day nor before today.
- **The projection** uses a full growth rate (the soil plans' stated assumption): a planned bed ripens
  `ceil(growth hours / 24)` days after sowing; a growing crop when the bed panel says, at this hour's rate; a ripe one
  today. Its harvest is REQ-SET-074's formula at full health (`farm_text.gd sown_estimate_milli`, the picker's).
- **Each harvest day** is judged three ways:
  * **Work against hands**: each harvest's own work (`farm_jobs.gd plan_work_usec`: cutting and the drop, the walks not
    counted, as the action cards) against the field crew (`farm_crew.gd crew`) for GDD §5.3's ten work hours a day, on
    the demo's clock (25 s a game hour);
  * **Room**: the day's food against the stores' free room now;
  * **Keeping**: each row's food against what the kitchen eats of it before it spoils -- the kitchen's daily use
    (`meal_rules.gd dish_for_meal`, the batches nine mouths need, each dish's inputs) times the days it keeps in the
    slowest-spoiling store at the harvest season's temperature (GDD §5.8). A row no dish takes (the leaf row, beans) is
    all at risk -- the "preserving capacity" the review means, in the demo's terms.
- **An overloaded day** is drawn in clay with its words ("about 18.0 U would spoil before the kitchen eats it") and a
  **suggestion**: the last bed planned to ripen that day, sown later by what its window allows -- or "leave it empty
  this time" (a smaller area). Nothing changes until the player edits or books. Crops are never changed.
- **Book this plan** is one farm order: beds planned for today have their sowing ordered now; later ones are **booked**
  for their day and crop and ordered (ORIGIN_ROUTINE) on the first farm hour of that day the bed can be sown
  (`run_hour`, from `demo_farm.gd _hourly`); it is cleared only once its job is on the board, so an order the board
  refuses (a full board) waits, said once, and is ordered the next hour there is room. Following R06-JOB-005's wording
  for field cycles: a booking whose crop the player changed, or whose bed was sown or taken up, is dropped, said once;
  one whose window is missed waits, warned once, for its next legal window or an edit -- it never substitutes a crop.
  Earlier / Later on a bed with no sowing day this season ahead is refused and says when the crop is sown.

## Why

The review's problem is "discovering too late that all harvests need the same hands". At demo scale the field crew's
day (two hands, ten work hours) dwarfs a harvest's 7 WU of work, so the binding constraints a player actually meets
are room and spoiling; all three are shown, from adopted numbers, with no hidden factor.

## Brendan's ruling (2026-10-01)

The harvest-plan defaults are **approved as built** (proposals 1–3 below). Recorded at the batch 7 integration (decision 0902); nothing changed in behaviour.

## Proposals for Brendan

1. **Hands** are the field crew's two for ten work hours, the walks not counted. Options: count walking (an estimate
   from bed to store); count every resident whose crew priority allows farm work. **Recommendation:** keep until crew
   intents (SOC-004) exist.
2. **Keeping** uses the kitchen's ordinary days (porridge at breakfast, soup at supper) and ignores the fish stew's
   substitution and raw emergency meals. **Recommendation:** keep -- it errs toward warning.
3. **The steady gap** (growth days shared among the crop's beds, at least one) is a demo value. **Recommendation:** keep.

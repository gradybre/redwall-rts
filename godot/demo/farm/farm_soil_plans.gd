extends RefCounted
## ECO-005's THREE SOIL-RECOVERY PLANS for one bed, side by side (decision 0451; review P4): COMPOST, a LEGUME in
## rotation, or FALLOW -- each a one-season plan with the harvest it brings, the soil it leaves, what the bed's next
## crop would then yield, and the staff time it takes. PRESENTATION ONLY: nothing here changes the farm, and no rule is
## new. Every figure is GDD §5.6's (around GDD:469), through scripts/core/farming.gd's own constants and static rules:
##   compost       +1500 fertility (COMPOST_FERTILITY_GAIN), capped 10000, 2 U from the farm's compost store, at most once
##                 a tile a season (REQ-SET-076: `is_compost_eligible`);
##   legume        the LEGUME row's -800 fertility cost (CROP_FERTILITY_COST: a harvest of peas or beans GIVES 800), its
##                 1100 rotation after a change of family (`_rotation_factor`), and REQ-SET-078's +50 a day for the 12 days
##                 after a legume harvest on top of the fallow 50;
##   fallow        REQ-SET-078's 50 a day on an empty bed (the bonus above when a legume was the last crop);
##   a harvest     REQ-SET-074's formula at full health and neutral pollination (farm_text.gd `estimate_milli`, the crop
##                 picker's own), with the fertility factor 500 + fertility / 20 (FERTILITY_FACTOR_*), and the crop's own
##                 fertility cost taken at its harvest.
##
## THE SEASON. A plan runs SEASON_DAYS days from the day the bed is next empty: today for an empty bed; for a crop still
## standing, the day it is harvested -- today when ripe, else its ripening at this hour's rate (farm_plan_rows.gd, an
## estimate) -- with that crop's fertility cost taken and its family banked first (farming.gd `_record_rotation`). A crop
## is sown on the first day of the plan its planting window and the bed's soil allow, and ripens growth-hours later at a
## FULL growth rate -- the planner's stated assumption: cold, a dry or waterlogged bed, frost and blight slow or spoil it.
## The fertility at a harvest is the fertility it was sown at (fallow gain runs only on an empty bed).
##
## THE NEXT CROP the plans are compared for: the bed's chosen crop, else the one standing in it, else the first crop its
## soil takes (catalog order). STAFF TIME is the demo's own work for each job the plan orders (farm_jobs.gd
## `plan_work_usec`, the action cards' work: the walks not counted) -- compost, sow and harvest -- in game time on the one
## calendar, and in STAFF-DAYS of WORK_HOURS_PER_STAFF_DAY game hours (GDD §5.3's default schedule: WORK 07:00-12:00
## and 13:00-18:00). Watering is not counted: the demo waters a bed only when it is dry.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const Rows := preload("res://demo/farm/farm_plan_rows.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")

const PLAN_COMPOST: int = 0
const PLAN_LEGUME: int = 1
const PLAN_FALLOW: int = 2
const PLAN_COUNT: int = 3
const PLAN_NAMES: Array[String] = ["Compost, then sow", "A legume in rotation", "Rest it fallow"]
## One season: §5.10's twelve days.
const SEASON_DAYS: int = SimClock.DAYS_PER_SEASON
## GDD §5.3's default schedule works 10 hours a day (07:00-12:00, 13:00-18:00).
const WORK_HOURS_PER_STAFF_DAY: int = 10

const NO_DAY: int = 0


## Where a plan starts: the day the bed is next empty and the soil's state then.
class Start extends RefCounted:
	var day: int = 1
	var fertility: int = 0
	var last_family: int = FarmingScript.FAMILY_NONE
	var streak: int = 0
	var legume_day: int = 0
	var estimated: bool = false
	var tile: int = -1


## One plan's outcome (see the header).
class Plan extends RefCounted:
	var kind: int = 0
	var start_day: int = 1
	var end_day: int = 1
	var crop: int = Catalog.NO_ITEM
	var sow_day: int = NO_DAY
	var harvest_day: int = NO_DAY
	var harvest_milli: int = 0
	var fertility_end: int = 0
	var next_crop: int = Catalog.NO_ITEM
	var next_milli: int = 0
	var work_usec: int = 0
	## The fertility just after this season's harvest (its cost taken; 0 with no harvest).
	var after_harvest: int = 0
	## Why it cannot be done now ('' when it can) and what it needs that is short ('' when nothing).
	var refusal: String = ""
	var needs: String = ""


static func reference_crop(sim: SimScript, bed: int) -> int:
	"""The next crop the plans are compared for (see THE NEXT CROP)."""
	if Catalog.is_item(sim.chosen_of(bed)):
		return sim.chosen_of(bed)
	if Catalog.is_item(sim.item_of(bed)):
		return sim.item_of(bed)
	for item: int in Catalog.ITEM_COUNT:
		if sim.farming().is_soil_compatible(Catalog.crop_of(item), Catalog.BED_SOILS[bed]):
			return item
	return Catalog.NO_ITEM


static func start_of(sim: SimScript, bed: int, read: IntMath.IntResult) -> Start:
	"""The bed's starting point (see THE SEASON)."""
	var start := Start.new()
	var farming: FarmingScript = sim.farming()
	var slot: int = sim.slot_of(bed)
	start.tile = farming.tile_of(slot).value
	start.day = sim.absolute_day()
	start.fertility = sim.fertility_of(bed)
	start.last_family = farming.last_family_of(slot).value
	start.streak = farming.family_streak_of(slot).value
	start.legume_day = farming.tile_last_legume_day_of(start.tile).value
	var stage: int = sim.stage_of(bed)
	if stage == SimScript.STAGE_RIPE or stage == SimScript.STAGE_SOWN or Rows.is_growing_stage(stage):
		_after_harvest(sim, bed, start, read)
	return start


static func _after_harvest(sim: SimScript, bed: int, start: Start, read: IntMath.IntResult) -> void:
	"""Move a start past the standing crop's harvest: its day, its fertility cost, its family banked."""
	var crop: int = Catalog.crop_of(sim.item_of(bed))
	if sim.stage_of(bed) != SimScript.STAGE_RIPE:
		start.estimated = true
		var ripe_tick: int = sim.calendar.tick + FarmingScript.CROP_GROWTH_HOURS[crop] * SimClock.TICKS_PER_HOUR
		if Rows.ripe_estimate_tick_into(sim, bed, read):
			ripe_tick = read.value
		start.day = SimClock.Calendar.new(ripe_tick).absolute_day
	start.fertility = clampi(start.fertility - FarmingScript.CROP_FERTILITY_COST[crop], FarmingScript.FERTILITY_MIN,
		FarmingScript.FERTILITY_MAX)
	var family: int = FarmingScript.CROP_FAMILY[crop]
	start.streak = start.streak + 1 if start.last_family == family else FarmingScript.STREAK_FIRST
	start.last_family = family
	if family == FarmingScript.FAMILY_LEGUME:
		start.legume_day = start.day


static func plans_for(sim: SimScript, bed: int, read: IntMath.IntResult) -> Array[Plan]:
	"""The three plans for the bed, PLAN_* order."""
	var start: Start = start_of(sim, bed, read)
	var next: int = reference_crop(sim, bed)
	var plans: Array[Plan] = [compost_plan(sim, bed, start, next), legume_plan(sim, bed, start, next),
		fallow_plan(start, next)]
	return plans


static func compost_plan(sim: SimScript, bed: int, start: Start, next: int) -> Plan:
	"""Compost on the first day, then the next crop sown at its first window (see the header)."""
	var plan: Plan = _plan(PLAN_COMPOST, start, next)
	plan.work_usec = JobsScript.plan_work_usec(JobsScript.KIND_COMPOST, 0)
	if not sim.farming().is_compost_eligible(start.tile, start.day):
		plan.refusal = "Composted this season already: once a season per bed (REQ-SET-076)"
		return plan
	if sim.compost_milli < FarmingScript.COMPOST_MILLI_PER_TILE:
		plan.needs = "%s; the store holds %s (clear a withered crop, or compost spoiled food in the Pantry)" % [
			Measures.need(&"compost", FarmingScript.COMPOST_MILLI_PER_TILE), Measures.amount_cell(&"compost", sim.compost_milli)]
	var fertility: int = mini(start.fertility + FarmingScript.COMPOST_FERTILITY_GAIN, FarmingScript.FERTILITY_MAX)
	_grow(plan, bed, next, fertility, start)
	plan.next_milli = plan.harvest_milli
	return plan


static func legume_plan(sim: SimScript, bed: int, start: Start, next: int) -> Plan:
	"""A legume sown at its first window and harvested, the bed then resting with the legume bonus; the next crop's
	harvest after it (see the header)."""
	var legume: int = next if Catalog.is_item(next) and Catalog.crop_of(next) == FarmingScript.CROP_BEANS \
		else first_legume()
	var plan: Plan = _plan(PLAN_LEGUME, start, next)
	if not sim.farming().is_soil_compatible(FarmingScript.CROP_BEANS, Catalog.BED_SOILS[bed]):
		plan.refusal = "Peas and beans need %s; this bed is %s" % [Text.soils_text(FarmingScript.CROP_BEANS),
			Text.SOILS[Catalog.BED_SOILS[bed]]]
		plan.fertility_end = start.fertility
		return plan
	_grow(plan, bed, legume, start.fertility, start)
	if plan.sow_day == NO_DAY:
		plan.refusal = "No legume planting window in this season (%s)" % Text.window_text(FarmingScript.CROP_BEANS)
	var soil: int = plan.fertility_end if plan.harvest_day <= plan.end_day else plan.after_harvest
	plan.next_milli = _next_after(next, soil, plan.harvest_day != NO_DAY, start)
	return plan


static func fallow_plan(start: Start, next: int) -> Plan:
	"""The bed rests the whole season: fallow gain every day, no harvest, no work; the next crop's harvest after it."""
	var plan: Plan = _plan(PLAN_FALLOW, start, next)
	plan.fertility_end = rest(start.fertility, start.day, plan.end_day, start.legume_day)
	if Catalog.is_item(next):
		plan.next_milli = Text.estimate_milli(FarmingScript.CROP_BASE_YIELD_MILLI[Catalog.crop_of(next)],
			fertility_factor(plan.fertility_end), FarmingScript._rotation_factor(Catalog.family_of(next), start.last_family,
			start.streak))
	return plan


static func _plan(kind: int, start: Start, next: int) -> Plan:
	"""A plan of `kind` over the season from `start`, comparing for `next`, nothing in it yet."""
	var plan := Plan.new()
	plan.kind = kind
	plan.start_day = start.day
	plan.end_day = start.day + SEASON_DAYS
	plan.next_crop = next
	plan.fertility_end = start.fertility
	return plan


static func _grow(plan: Plan, bed: int, item: int, fertility: int, start: Start) -> void:
	"""Sow `item` at its first window day in the plan (resting until then), harvest it growth-hours later at a full rate,
	and rest the bed to the season's end; fill the plan's harvest, its fertility at the end and the sowing's work."""
	if not Catalog.is_item(item):
		return
	var crop: int = Catalog.crop_of(item)
	plan.crop = item
	plan.sow_day = first_window_day(crop, Catalog.BED_SOILS[bed], plan.start_day, plan.end_day)
	if plan.sow_day == NO_DAY:
		plan.fertility_end = rest(fertility, plan.start_day, plan.end_day, start.legume_day)
		return
	var sown_at: int = rest(fertility, plan.start_day, plan.sow_day, start.legume_day)
	@warning_ignore("integer_division") plan.harvest_day = plan.sow_day + (FarmingScript.CROP_GROWTH_HOURS[crop] + SimClock.HOURS_PER_DAY - 1) / SimClock.HOURS_PER_DAY
	plan.harvest_milli = Text.estimate_milli(FarmingScript.CROP_BASE_YIELD_MILLI[crop], fertility_factor(sown_at),
		FarmingScript._rotation_factor(Catalog.family_of(item), start.last_family, start.streak))
	plan.work_usec += JobsScript.plan_work_usec(JobsScript.KIND_SOW, 0) + JobsScript.plan_work_usec(JobsScript.KIND_HARVEST, 0)
	plan.fertility_end = sown_at
	plan.after_harvest = clampi(sown_at - FarmingScript.CROP_FERTILITY_COST[crop], FarmingScript.FERTILITY_MIN,
		FarmingScript.FERTILITY_MAX)
	if plan.harvest_day <= plan.end_day:
		var legume_day: int = plan.harvest_day if crop == FarmingScript.CROP_BEANS else start.legume_day
		plan.fertility_end = rest(plan.after_harvest, plan.harvest_day, plan.end_day, legume_day)


static func _next_after(next: int, fertility: int, legume_harvested: bool, start: Start) -> int:
	"""What the next crop would yield sown after the legume plan's season (its family history moved by the legume)."""
	if not Catalog.is_item(next):
		return 0
	var last: int = FarmingScript.FAMILY_LEGUME if legume_harvested else start.last_family
	var streak: int = start.streak
	if legume_harvested:
		streak = start.streak + 1 if start.last_family == FarmingScript.FAMILY_LEGUME else FarmingScript.STREAK_FIRST
	return Text.estimate_milli(FarmingScript.CROP_BASE_YIELD_MILLI[Catalog.crop_of(next)], fertility_factor(fertility),
		FarmingScript._rotation_factor(Catalog.family_of(next), last, streak))


static func first_legume() -> int:
	"""The legume the plan sows when the next crop is not one: the first LEGUME-row ingredient (the pea)."""
	return Catalog.ITEM_CROP.find(FarmingScript.CROP_BEANS)


static func first_window_day(crop: int, soil: int, from_day: int, to_day: int) -> int:
	"""The first absolute day in [from_day, to_day] the crop may be sown in this soil (NO_DAY: none)."""
	if (FarmingScript.CROP_ALLOWED_SOILS[crop] & (1 << soil)) == 0:
		return NO_DAY
	for day: int in range(from_day, to_day + 1):
		if FarmingScript._is_plant_window(crop, season_of_day(day), season_day_of(day)):
			return day
	return NO_DAY


static func rest(fertility: int, from_day: int, to_day: int, legume_day: int) -> int:
	"""Fertility after the bed lies empty from `from_day` to `to_day`: REQ-SET-078's gain on each day after the first,
	through the last (the farm applies it at each midnight to the new day), capped at each step."""
	var value: int = fertility
	for day: int in range(from_day + 1, to_day + 1):
		value = mini(value + fallow_gain(day, legume_day), FarmingScript.FERTILITY_MAX)
	return value


static func fallow_gain(day: int, legume_day: int) -> int:
	"""REQ-SET-078's gain on `day`: 50, and 50 more on the 12 days after a legume harvest (farming.gd
	`fallow_gain_into`'s rule, for a legume day that may not have happened yet)."""
	var gain: int = FarmingScript.FALLOW_FERTILITY_PER_DAY
	if legume_day != FarmingScript.NO_LEGUME_DAY and day > legume_day \
			and day <= legume_day + FarmingScript.LEGUME_FALLOW_DAYS:
		gain += FarmingScript.LEGUME_FALLOW_BONUS_PER_DAY
	return gain


static func fertility_factor(fertility: int) -> int:
	"""§5.6's fertility factor at a fertility (farming.gd's FERTILITY_FACTOR_* constants)."""
	@warning_ignore("integer_division") return clampi(FarmingScript.FERTILITY_FACTOR_BASE + fertility / FarmingScript.FERTILITY_FACTOR_DIVISOR,
		FarmingScript.FERTILITY_FACTOR_MIN, FarmingScript.FERTILITY_FACTOR_MAX)


static func season_of_day(day: int) -> int:
	"""The season (0 spring .. 3 winter) of an absolute calendar day."""
	@warning_ignore("integer_division") return ((day - 1) / SimClock.DAYS_PER_SEASON) % SimClock.SEASONS_PER_YEAR


static func season_day_of(day: int) -> int:
	"""The season-local day (1..12) of an absolute calendar day."""
	return (day - 1) % SimClock.DAYS_PER_SEASON + 1


static func staff_hundredths(usec: int) -> int:
	"""Work in demo microseconds as hundredths of a staff-day (see the header), rounded up."""
	var per_day: int = CalendarScript.HOUR_USEC * WORK_HOURS_PER_STAFF_DAY
	@warning_ignore("integer_division") return (usec * 100 + per_day - 1) / per_day

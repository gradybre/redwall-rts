extends RefCounted
## The farm's words: what the bed panel, the crop picker and the pantry say. Decision 0196. Pure
## functions of the sim's readouts, so test_demo_farm_ui.gd reads them without a scene.
##
## THE NEEDS LINE (the bed panel's second line): a bed's own most pressing condition and the verb that
## answers it, in the order the right-click's most pressing work takes them (demo_farm.gd
## `pressing_kind_into`): clear a withered or blighted crop, harvest a ripe one, drain a waterlogged
## growing bed, water a parched one, cover one before a frost. Nothing pressing, no line. Every need
## is a warning but a ripe crop still in its grace (need_is_warning; the alerts call that a NOTE).
##
## UNITS (decision 0222, the review's F28). A farm quantity is milli-U; the player reads it through ONE
## formatter, `units_text`, wherever it appears -- stock, totals, capacity, yield and a carried load:
## tenths of a unit, floored, so a figure never claims food that is not there; and never "0 U" for
## something -- below a tenth reads "<0.1 U". Totals are summed in milli-U first.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Weather := preload("res://demo/farm/farm_weather.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const SEASONS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const SOILS: Array[String] = ["loam", "clay", "sand"]
const ROWS: Array[String] = ["beans", "cabbage", "flax", "grain", "roots"]
const NEED_CLEAR_WITHERED: int = 0
const NEED_CLEAR_BLIGHT: int = 1
const NEED_HARVEST: int = 2
const NEED_HARVEST_LATE: int = 3
const NEED_DRAIN: int = 4
const NEED_WATER: int = 5
const NEED_COVER: int = 6
const REFUSE_NOTHING_PRESSING: String = "NOTHING_PRESSING"
const MILLI_PER_U: int = 1000
const MILLI_PER_TENTH: int = 100


static func units_text(milli: int) -> String:
	"""A quantity (milli-U, never negative) as the player reads it (see UNITS): '5.1 U', '400.0 U',
	'<0.1 U', '0 U'."""
	if milli == 0:
		return "0 U"
	if milli < MILLI_PER_TENTH:
		return "<0.1 U"
	return "%d.%d U" % [milli / MILLI_PER_U, (milli % MILLI_PER_U) / MILLI_PER_TENTH]


static func clock_line(sim: SimScript) -> String:
	"""'Y1 Spring 3, 14:00 · 12 °C' -- the demo's one calendar date (the HUD's date shows the same
	string) and the real weather's temperature."""
	return "%s · %s °C" % [sim.calendar.date_text(), _tenths(sim.air_tenths())]


static func _tenths(tenths: int) -> String:
	"""Tenths of a degree as whole degrees when whole, else one decimal."""
	if tenths % 10 == 0:
		return "%d" % (tenths / 10)
	return "%d.%d" % [tenths / 10, absi(tenths % 10)]


static func window_text(crop: int) -> String:
	"""A crop row's planting windows, 'Spring 1–4; Summer 1–4'."""
	var parts := PackedStringArray()
	for k: int in FarmingScript.PLANT_WINDOWS_PER_CROP:
		var index: int = crop * FarmingScript.PLANT_WINDOWS_PER_CROP + k
		var season: int = FarmingScript.CROP_WINDOW_SEASON[index]
		if season == FarmingScript.NO_WINDOW:
			continue
		parts.append("%s %d–%d" % [SEASONS[season], FarmingScript.CROP_WINDOW_FIRST_DAY[index],
			FarmingScript.CROP_WINDOW_LAST_DAY[index]])
	return "; ".join(parts)


static func soils_text(crop: int) -> String:
	"""The soils a crop row takes, 'loam or sand'."""
	var parts := PackedStringArray()
	for soil: int in FarmingScript.SOIL_COUNT:
		if FarmingScript.CROP_ALLOWED_SOILS[crop] & (1 << soil):
			parts.append(SOILS[soil])
	return " or ".join(parts)


static func rotation_text(factor: int) -> String:
	"""§5.6's rotation factor for the player: the yield it gives and why."""
	match factor:
		FarmingScript.ROTATION_FACTOR_SECOND:
			return "same family again: yield ×0.85"
		FarmingScript.ROTATION_FACTOR_THIRD_PLUS:
			return "3rd of a family in a row: yield ×0.70"
		FarmingScript.ROTATION_FACTOR_LEGUME_AFTER_CHANGE:
			return "legume after a change: yield ×1.10"
	return "fresh rotation: yield ×1.00"


static func pick_row(sim: SimScript, bed: int, item: int) -> String:
	"""One crop-picker row: the item, its row's numbers, and its rotation effect in this bed."""
	var crop: int = Catalog.crop_of(item)
	var line: String = "%s · %d h · %s · %s" % [
		Catalog.FAMILY_NAMES[Catalog.family_of(item)], FarmingScript.CROP_GROWTH_HOURS[crop],
		units_text(FarmingScript.CROP_BASE_YIELD_MILLI[crop]), rotation_text(sim.rotation_preview(bed, item))]
	if FarmingScript.CROP_FERTILITY_COST[crop] < 0:
		line += " · feeds the soil +%d" % (-FarmingScript.CROP_FERTILITY_COST[crop] / 100)
	return line


static func pick_reason(sim: SimScript, bed: int, item: int) -> String:
	"""Why an item cannot be sown in the bed now ('' when it can), in the player's words."""
	var code: StringName = sim.sow_refusal(bed, item)
	var crop: int = Catalog.crop_of(item)
	match code:
		&"":
			return ""
		FarmingScript.REFUSE_SOIL_INCOMPATIBLE:
			return "needs %s (this bed is %s)" % [soils_text(crop), SOILS[Catalog.BED_SOILS[bed]]]
		FarmingScript.REFUSE_OUTSIDE_PLANT_WINDOW:
			return "sow in %s" % window_text(crop)
		FarmingScript.REFUSE_NOT_EMPTY:
			return "the bed is not empty"
		SimScript.REFUSE_FALLOW:
			return "the bed is resting fallow"
	return String(code).to_lower().replace("_", " ")


static func stage_line(sim: SimScript, bed: int, read: IntMath.IntResult) -> String:
	"""The bed's stage with its timing: growth and hours to ripe, or how long it has stood ripe."""
	var stage: int = sim.stage_of(bed)
	var growth: int = sim.growth_permille(bed) / 10
	if stage == SimScript.STAGE_RIPE and sim.ripe_hours_into(bed, read):
		var left: int = FarmingScript.RIPE_WITHER_HOURS - read.value
		if read.value < FarmingScript.RIPE_GRACE_HOURS:
			return "Ripe — full yield for %d h more, withers in %d h" % [FarmingScript.RIPE_GRACE_HOURS - read.value, left]
		return "Ripe — losing 10%% a day, withers in %d h" % left
	if stage == SimScript.STAGE_SPROUTING or stage == SimScript.STAGE_GROWING or stage == SimScript.STAGE_BLIGHTED:
		var what: String = "Blighted, growing" if stage == SimScript.STAGE_BLIGHTED else "Growing"
		if sim.hours_to_ripe_into(bed, read):
			return "%s %d%% — ripe in about %d h" % [what, growth, read.value]
		return "%s %d%% — stalled, %s" % [what, growth, _stall_reason(sim.band_of(bed))]
	return ["Empty", "Being sown", "", "", "", "Withered — clear it", ""][stage]


static func _stall_reason(band: int) -> String:
	"""Why a growing crop has stopped: §5.6's moisture factor is 0 only when parched or waterlogged,
	so otherwise it is the temperature's."""
	if band == SimScript.BAND_DRY:
		return "too dry"
	if band == SimScript.BAND_WATERLOGGED:
		return "waterlogged"
	return "too cold"


static func moisture_line(sim: SimScript, bed: int) -> String:
	"""'Moisture 6600 — good (2500–7000)'."""
	var band: int = sim.band_of(bed)
	return "Moisture %d — %s (%d–%d)" % [sim.moisture_of(bed), SimScript.BAND_NAMES[band],
		sim.band_min_of(bed), sim.band_max_of(bed)]


static func soil_line(sim: SimScript, bed: int) -> String:
	"""'Loam · fertility 63% (yield ×0.81) · health 82%'."""
	var line: String = "%s · fertility %d%% (yield ×%s)" % [SOILS[Catalog.BED_SOILS[bed]].capitalize(),
		sim.fertility_of(bed) / 100, _permille(sim.fertility_factor_of(bed))]
	if sim.stage_of(bed) != SimScript.STAGE_EMPTY:
		line += " · health %d%%" % (sim.health_of(bed) / 100)
	return line


static func _permille(value: int) -> String:
	"""A factor per 1000 as '0.85'."""
	return "%d.%02d" % [value / 1000, (value % 1000) / 10]


static func works_line(sim: SimScript, bed: int) -> String:
	"""What has been done to the bed and its ground: drained or irrigated by a tunnel, ditched (the
	Drain job), raised, banked, covered, resting, watered."""
	var parts := PackedStringArray()
	if sim.is_irrigated(bed):
		parts.append("tunnel-irrigated")
	elif sim.is_drained(bed):
		parts.append("tunnel-drained")
	if sim.is_ditched(bed):
		parts.append("ditched")
	if sim.is_raised(bed):
		parts.append("raised")
	if sim.is_banked(bed):
		parts.append("banked")
	if sim.is_covered(bed):
		parts.append("covered tonight")
	if sim.is_fallow(bed):
		parts.append("resting")
	if sim.is_tended_today(bed):
		parts.append("watered today")
	return ("Ground: " + ", ".join(parts)) if not parts.is_empty() else "Ground: as dug"


static func yield_line(sim: SimScript, bed: int, read: IntMath.IntResult) -> String:
	"""'Harvest now: 5.1 U of carrot' / 'Expected: ...' ('' with nothing standing)."""
	var item: int = sim.item_of(bed)
	var stage: int = sim.stage_of(bed)
	var standing: bool = stage == SimScript.STAGE_RIPE or stage == SimScript.STAGE_GROWING \
		or stage == SimScript.STAGE_SPROUTING or stage == SimScript.STAGE_BLIGHTED
	if not Catalog.is_item(item) or not standing or not sim.expected_yield_into(bed, read):
		return ""
	var what: String = "Harvest now" if sim.stage_of(bed) == SimScript.STAGE_RIPE else "Expected yield"
	return "%s: %s of %s" % [what, units_text(read.value), Catalog.ITEM_LABELS[item].to_lower()]


# --- the needs line ------------------------------------------------------------------------------

static func need_of_into(sim: SimScript, bed: int, out: IntMath.IntResult) -> bool:
	"""The bed's most pressing NEED_* into `out` (see the header); refuses NOTHING_PRESSING."""
	match sim.stage_of(bed):
		SimScript.STAGE_WITHERED:
			return out.succeed(NEED_CLEAR_WITHERED)
		SimScript.STAGE_BLIGHTED:
			return out.succeed(NEED_CLEAR_BLIGHT)
		SimScript.STAGE_RIPE:
			if sim.ripe_hours_into(bed, out) and out.value >= FarmingScript.RIPE_GRACE_HOURS:
				return out.succeed(NEED_HARVEST_LATE)
			return out.succeed(NEED_HARVEST)
		SimScript.STAGE_SPROUTING, SimScript.STAGE_GROWING:
			return _growing_need_into(sim, bed, out)
	return out.refuse(REFUSE_NOTHING_PRESSING)


static func _growing_need_into(sim: SimScript, bed: int, out: IntMath.IntResult) -> bool:
	"""A growing bed's need: out of its band far enough to stop growing, or a frost due uncovered."""
	var band: int = sim.band_of(bed)
	if band == SimScript.BAND_WATERLOGGED:
		return out.succeed(NEED_DRAIN)
	if band == SimScript.BAND_DRY:
		return out.succeed(NEED_WATER)
	var hour: int = sim.calendar.calendar_at(sim.calendar.tick).hour
	if Weather.frost_due(sim.season(), sim.season_day(), hour) and not sim.is_covered(bed) \
			and not sim.is_raised(bed):
		return out.succeed(NEED_COVER)
	return out.refuse(REFUSE_NOTHING_PRESSING)


static func need_text(sim: SimScript, bed: int, need: int, read: IntMath.IntResult) -> String:
	"""'Needs: Drain — waterlogged, not growing' for a NEED_* on this bed."""
	match need:
		NEED_CLEAR_WITHERED:
			return "Needs: Clear — withered, gives compost"
		NEED_CLEAR_BLIGHT:
			return "Needs: Clear — blighted, spreads at midnight"
		NEED_HARVEST, NEED_HARVEST_LATE:
			return _harvest_need_text(sim, bed, read)
		NEED_DRAIN:
			return "Needs: Drain — waterlogged, not growing"
		NEED_WATER:
			return "Needs: Water — too dry to grow"
	return "Needs: Cover — frost tonight"


static func _harvest_need_text(sim: SimScript, bed: int, read: IntMath.IntResult) -> String:
	"""A ripe bed's need, with the time left: before it spoils, or before it withers."""
	if not sim.ripe_hours_into(bed, read):
		return "Needs: Harvest — ripe"
	if read.value < FarmingScript.RIPE_GRACE_HOURS:
		return "Needs: Harvest — ripe, %s before it spoils" % span_text(FarmingScript.RIPE_GRACE_HOURS - read.value)
	return "Needs: Harvest — spoiling, withers in %s" % span_text(FarmingScript.RIPE_WITHER_HOURS - read.value)


static func needs_line(sim: SimScript, bed: int, read: IntMath.IntResult) -> String:
	"""The bed's Needs line ('' when nothing is pressing)."""
	if not need_of_into(sim, bed, read):
		return ""
	return need_text(sim, bed, read.value, read)


static func need_is_warning(need: int) -> bool:
	"""Whether a need is a warning (clay in the panel): all but a ripe crop still in its grace."""
	return need != NEED_HARVEST


static func span_text(hours: int) -> String:
	"""Game hours as the player reads them: whole days as days ('2 days'), else hours ('47 h')."""
	if hours >= 24 and hours % 24 == 0:
		return "1 day" if hours == 24 else "%d days" % (hours / 24)
	return "%d h" % hours

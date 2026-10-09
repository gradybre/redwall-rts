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
## something -- below a tenth reads "<0.1 U". Totals are summed in milli-U first. SUPERSEDED for the player by
## decision 1801 (natural measures, decision 1011): every farm amount is now worded by scripts/ui/goods_measures.gd in
## its good's own measure ("5 bunches of carrots"), and `units_text` stays only until its last caller is converted.
##
## PLAYER TERMS (decision 0251, review finding F34). The sim keeps moisture, fertility and health on 0..10000 and
## its factors per 1000; the panel says them as a player reads them: percentages of the whole scale, "points" of
## it for a change (Rest: "+0.5 fertility points a day" -- 50 on the 10000 scale), a factor as a percentage change
## ("Fertility effect on yield: −15%"), and ONE expected harvest for the bed; the multiplication behind it and the
## raw readings are the Details view's (`harvest_breakdown`, `raw_line`). A reading is whole percent, floored --
## except ABOVE the crop's range, where it is rounded up, so a wet bed never prints as its range's top
## (`moisture_percent`; every band edge is a whole percent, so neither side can print on the wrong side of one).

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Weather := preload("res://demo/farm/farm_weather.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")

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
	@warning_ignore("integer_division") return "%d.%d U" % [milli / MILLI_PER_U, (milli % MILLI_PER_U) / MILLI_PER_TENTH]


static func clock_line(sim: SimScript) -> String:
	"""'Y1 Spring 3, 14:00 · 12 °C' -- the demo's one calendar date (the HUD's date shows the same
	string) and the real weather's temperature."""
	return "%s · %s °C" % [sim.calendar.date_text(), _tenths(sim.air_tenths())]


static func degrees_text(tenths: int) -> String:
	"""A temperature in tenths of a degree as the clock line says it: '12', '-3', '0.5' (no unit)."""
	return _tenths(tenths)


static func _tenths(tenths: int) -> String:
	"""Tenths of a degree as whole degrees when whole, else one decimal. The sign is written apart: -5 tenths is
	"-0.5", which the whole part alone (0) cannot carry (decision 0501)."""
	if tenths % 10 == 0:
		@warning_ignore("integer_division") return "%d" % (tenths / 10)
	var sign_text: String = "-" if tenths < 0 else ""
	@warning_ignore("integer_division") return "%s%d.%d" % [sign_text, absi(tenths) / 10, absi(tenths) % 10]


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
	"""§5.6's rotation factor for the player: why, and its effect on the harvest as a percentage."""
	match factor:
		FarmingScript.ROTATION_FACTOR_SECOND:
			return "same family again: harvest %s" % change_text(factor)
		FarmingScript.ROTATION_FACTOR_THIRD_PLUS:
			return "3rd of a family in a row: harvest %s" % change_text(factor)
		FarmingScript.ROTATION_FACTOR_LEGUME_AFTER_CHANGE:
			return "legume after a change: harvest %s" % change_text(factor)
	return "fresh rotation: no change to the harvest"


static func pick_row(sim: SimScript, bed: int, item: int) -> String:
	"""One crop-picker row: the family, when it matures, its harvest in THIS bed (and the table's base), and its
	rotation effect here -- 'root crop · matures in 5 days · this bed: about 5 bunches (base 6 bunches) · fresh
	rotation...'. The row sits beside its crop's name, so both amounts are in the crop's measure without naming it
	again (goods_measures.gd's cell form, decision 1801): the estimate rounded down, the table's base exact."""
	var crop: int = Catalog.crop_of(item)
	var good: StringName = Catalog.ITEM_KEYS[item]
	var line: String = "%s crop · matures in %s · this bed: about %s (base %s) · %s" % [
		Catalog.FAMILY_NAMES[Catalog.family_of(item)], span_text(FarmingScript.CROP_GROWTH_HOURS[crop]),
		Measures.amount_cell(good, sown_estimate_milli(sim, bed, item)),
		Measures.exact_cell(good, FarmingScript.CROP_BASE_YIELD_MILLI[crop]), rotation_text(sim.rotation_preview(bed, item))]
	if FarmingScript.CROP_FERTILITY_COST[crop] < 0:
		line += " · feeds the soil: %s fertility points" % points_text(-FarmingScript.CROP_FERTILITY_COST[crop], true)
	return line


static func sown_estimate_milli(sim: SimScript, bed: int, item: int) -> int:
	"""What `item` sown in this bed now would harvest at full health: REQ-SET-074's formula at the bed's fertility
	and the rotation it would take here, neutral pollination (milli-U). Its 125% cap never binds here: fertility's
	factor is at most 1000 and rotation's 1100, so this is at most 110% of base."""
	return estimate_milli(FarmingScript.CROP_BASE_YIELD_MILLI[Catalog.crop_of(item)], sim.fertility_factor_of(bed),
		sim.rotation_preview(bed, item))


static func estimate_milli(base_milli: int, fertility_factor: int, rotation_factor: int) -> int:
	"""REQ-SET-074's formula at full health and neutral pollination: base x fertility x rotation (factors per 1000),
	floored once (milli-U)."""
	@warning_ignore("integer_division") return base_milli * fertility_factor * rotation_factor / 1000000


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
	@warning_ignore("integer_division") var growth: int = sim.growth_permille(bed) / 10
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
	"""'Soil moisture: Good · 66%' -- the band's word first, then the reading (see PLAYER TERMS)."""
	var band: int = sim.band_of(bed)
	return "Soil moisture: %s · %d%%" % [SimScript.BAND_NAMES[band].capitalize(),
		moisture_percent(sim.moisture_of(bed), sim.band_max_of(bed))]


static func moisture_percent(moisture: int, band_max: int) -> int:
	"""A 0..10000 moisture reading as whole percent: floored, but rounded up above the range's top (PLAYER TERMS).
	10000 rounds up to 100, so a full scale never reads past 100%."""
	if moisture > band_max:
		@warning_ignore("integer_division") return (moisture + 99) / 100
	@warning_ignore("integer_division") return moisture / 100


static func range_line(sim: SimScript, bed: int) -> String:
	"""'Suitable for this crop: 25–70%' -- the range the moisture is judged by (an empty bed's when none is chosen)."""
	var whose: String = "this crop"
	if not Catalog.is_item(sim.item_of(bed)) and not Catalog.is_item(sim.chosen_of(bed)):
		whose = "an empty bed"
	@warning_ignore("integer_division") return "Suitable for %s: %d–%d%%" % [whose, sim.band_min_of(bed) / 100, sim.band_max_of(bed) / 100]


static func soil_line(_sim: SimScript, bed: int) -> String:
	"""'Soil: Loam'."""
	return "Soil: %s" % SOILS[Catalog.BED_SOILS[bed]].capitalize()


static func fertility_line(sim: SimScript, bed: int) -> String:
	"""'Fertility: 63%'."""
	return "Fertility: " + percent_text(sim.fertility_of(bed))


static func fertility_effect_line(sim: SimScript, bed: int) -> String:
	"""'Fertility effect on yield: −19%' (§5.6's fertility factor as a change)."""
	return fertility_effect_text(sim.fertility_factor_of(bed))


static func fertility_effect_text(factor: int) -> String:
	"""§5.6's fertility factor per 1000 as the line says it: 810 -> '...: −19%', a full 1000 -> '...: none'."""
	return "Fertility effect on yield: %s" % ("none" if factor == FarmingScript.FACTOR_DENOMINATOR else change_text(factor))


static func health_line(sim: SimScript, bed: int) -> String:
	"""'Crop health: 82%' ('' for an empty bed: nothing is growing to be healthy)."""
	if sim.stage_of(bed) == SimScript.STAGE_EMPTY:
		return ""
	return "Crop health: " + percent_text(sim.health_of(bed))


static func percent_text(scale_value: int) -> String:
	"""A 0..10000 reading as a whole percent, floored: 6399 -> '63%', 10000 -> '100%'."""
	@warning_ignore("integer_division") return "%d%%" % (clampi(scale_value, 0, 10000) / 100)


static func change_text(factor: int) -> String:
	"""A factor per 1000 as the change it makes: 810 -> '−19%', 815 -> '−18.5%', 1100 -> '+10%', 1000 -> '±0%'."""
	var delta: int = factor - FarmingScript.FACTOR_DENOMINATOR
	var sign_text: String = "+" if delta > 0 else ("−" if delta < 0 else "±")
	return "%s%s%%" % [sign_text, points_text(absi(delta) * 10, false)]


static func points_text(scale_value: int, signed: bool) -> String:
	"""An amount on a 0..10000 scale in percentage points: 50 -> '0.5', 1500 -> '15', 1550 -> '15.5' (with
	`signed`, a leading '+' or '−'). Tenths are floored; a whole number drops its '.0'."""
	@warning_ignore("integer_division") var magnitude: int = absi(scale_value) / 10
	@warning_ignore("integer_division") var words: String = "%d" % (magnitude / 10) if magnitude % 10 == 0 else "%d.%d" % [magnitude / 10, magnitude % 10]
	if not signed:
		return words
	return ("−" if scale_value < 0 else "+") + words


static func factor_text(factor: int) -> String:
	"""A factor per 1000 as a multiplier: 850 -> '0.85', 815 -> '0.815', 1000 -> '1.00'."""
	if factor % 10 == 0:
		@warning_ignore("integer_division") return "%d.%02d" % [factor / 1000, (factor % 1000) / 10]
	@warning_ignore("integer_division") return "%d.%03d" % [factor / 1000, factor % 1000]


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
	"""'Harvest now: 5 bunches of carrots' / 'Expected harvest: ...' -- the ONE figure ('' with nothing standing)."""
	var item: int = sim.item_of(bed)
	if not Catalog.is_item(item) or not _standing(sim, bed) or not sim.expected_yield_into(bed, read):
		return ""
	var what: String = "Harvest now" if sim.stage_of(bed) == SimScript.STAGE_RIPE else "Expected harvest"
	return "%s: %s" % [what, Measures.amount(Catalog.ITEM_KEYS[item], read.value)]


static func _standing(sim: SimScript, bed: int) -> bool:
	"""Whether a crop stands in the bed that a harvest could take (sprouting, growing, blighted or ripe)."""
	var stage: int = sim.stage_of(bed)
	return stage == SimScript.STAGE_RIPE or stage == SimScript.STAGE_GROWING or stage == SimScript.STAGE_SPROUTING \
		or stage == SimScript.STAGE_BLIGHTED


static func harvest_breakdown(sim: SimScript, bed: int, read: IntMath.IntResult) -> String:
	"""The Details view's multiplication behind the expected harvest: 'Base 6 bunches × fertility 0.85 × health 1.00 ×
	rotation 1.00 = 5 bunches' (in the crop's measure, below the yield line that names it: the base exact, the
	products rounded down), and for a ripe crop past its grace the daily loss that brings it to the harvest now ('' with
	nothing standing)."""
	var item: int = sim.item_of(bed)
	if not Catalog.is_item(item) or not _standing(sim, bed) or not sim.expected_yield_into(bed, read):
		return ""
	var harvest: int = read.value
	var good: StringName = Catalog.ITEM_KEYS[item]
	var base: int = FarmingScript.CROP_BASE_YIELD_MILLI[Catalog.crop_of(item)]
	@warning_ignore("integer_division") var health: int = sim.health_of(bed) / FarmingScript.HEALTH_FACTOR_DIVISOR
	@warning_ignore("integer_division") var formula: int = base * sim.fertility_factor_of(bed) * health * sim.rotation_preview(bed, item) / 1000000000
	var line: String = "Base %s × fertility %s × health %s × rotation %s = %s" % [Measures.exact_cell(good, base),
		factor_text(sim.fertility_factor_of(bed)), factor_text(health), factor_text(sim.rotation_preview(bed, item)),
		Measures.amount_cell(good, formula)]
	if harvest < formula and sim.ripe_hours_into(bed, read):
		line += "; ripe %s: −10%% a day after the first %s, so %s" % [span_text(read.value),
			span_text(FarmingScript.RIPE_GRACE_HOURS), Measures.amount_cell(good, harvest)]
	return line


static func raw_line(sim: SimScript, bed: int) -> String:
	"""The Details view's raw readings on the sim's 0..10000 scale: 'Readings (of 10000): moisture 6600 (range
	2500–7000) · fertility 6300 · health 8200'."""
	return "Readings (of 10000): moisture %d (range %d–%d) · fertility %d · health %d" % [sim.moisture_of(bed),
		sim.band_min_of(bed), sim.band_max_of(bed), sim.fertility_of(bed), sim.health_of(bed)]


static func rest_tip() -> String:
	"""The Rest button's effect: 'Rest the bed fallow: nothing is sown; +0.5 fertility points a day (+1 a day for
	12 days after a legume)'."""
	return "Rest the bed fallow: nothing is sown; %s fertility points a day (%s a day for %d days after a legume)" % [
		points_text(FarmingScript.FALLOW_FERTILITY_PER_DAY, true),
		points_text(FarmingScript.FALLOW_FERTILITY_PER_DAY + FarmingScript.LEGUME_FALLOW_BONUS_PER_DAY, true),
		FarmingScript.LEGUME_FALLOW_DAYS]


static func verb_tip(sim: SimScript, bed: int, kind: int) -> String:
	"""What an enabled verb will do to the bed, in points ('' for a verb without a figure to state)."""
	match kind:
		JobsScript.KIND_WATER:
			return "Water: %s moisture points while below this crop's range (and a watered bed loses less to blight " \
				% points_text(FarmingScript.TEND_MOISTURE_RESTORE, true) + "and frost today)"
		JobsScript.KIND_DRAIN:
			@warning_ignore("integer_division") return "Drain: dig a ditch; the moisture drops to the top of this crop's range (%d%%)" % (sim.band_max_of(bed) / 100)
		JobsScript.KIND_COMPOST:
			return "Compost: %s fertility points" % points_text(FarmingScript.COMPOST_FERTILITY_GAIN, true)
	return ""


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
		@warning_ignore("integer_division") return "1 day" if hours == 24 else "%d days" % (hours / 24)
	return "%d h" % hours


static func keeps_text(slower_than_permille: int, permille: int) -> String:
	"""How many times as long food keeps at store factor `permille` as at `slower_than_permille` (§5.8's factors; decision
	0611), to the tenth, floored: '2.8×' for a cool cellar (350) against the covered store (1000), '1.0×' for the same."""
	@warning_ignore("integer_division")  # floored tenths by intent
	var tenths: int = slower_than_permille * 10 / maxi(permille, 1)
	@warning_ignore("integer_division")  # whole times by intent
	var whole: int = tenths / 10
	return "%d.%d×" % [whole, tenths % 10]

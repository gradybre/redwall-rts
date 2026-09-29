extends RefCounted
## The farm's words: what the bed panel, the crop picker and the pantry say. Decision 0196. Pure
## functions of the sim's readouts, so test_demo_farm_ui.gd reads them without a scene.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const SEASONS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const SOILS: Array[String] = ["loam", "clay", "sand"]
const ROWS: Array[String] = ["beans", "cabbage", "flax", "grain", "roots"]


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
	var line: String = "%s · %d h · %d U · %s" % [
		Catalog.FAMILY_NAMES[Catalog.family_of(item)], FarmingScript.CROP_GROWTH_HOURS[crop],
		FarmingScript.CROP_BASE_YIELD_MILLI[crop] / 1000, rotation_text(sim.rotation_preview(bed, item))]
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
		return "%s %d%% — growth stopped (too cold, dry or wet)" % [what, growth]
	return ["Empty", "Being sown", "", "", "", "Withered — clear it", ""][stage]


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
	"""What has been done to the bed and its ground: drained, irrigated, raised, banked, covered."""
	var parts := PackedStringArray()
	if sim.is_irrigated(bed):
		parts.append("irrigated by a tunnel from the water")
	elif sim.is_drained(bed):
		parts.append("drained by a tunnel")
	if sim.is_raised(bed):
		parts.append("raised with spoil")
	if sim.is_banked(bed):
		parts.append("banked with spoil")
	if sim.is_covered(bed):
		parts.append("covered tonight")
	if sim.is_fallow(bed):
		parts.append("resting fallow")
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
	return "%s: %d.%d U of %s" % [what, read.value / 1000, (read.value % 1000) / 100, Catalog.ITEM_LABELS[item].to_lower()]

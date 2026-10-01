extends RefCounted
## The legend scales of the layers the village already has (decision 0581): for each, which of its swatches form an
## ordered ramp, a threshold line per ramp entry with its units, what the ramp measures, and the ground its areas are
## painted over. Data only; `apply` writes it onto the rows demo_farm.gd and demo_village.gd added, found by group
## and label, so their registration lines are not touched. A NEW layer carries its own scale in its record
## (lens_def.gd) instead of a row here.
##
## Every figure is the rules' own: the moisture margins are farming.gd's MOISTURE_NEAR_MARGIN (20 points) and §5.6's
## crop ranges (25-40% at the low side, 70-85% at the high); the ripeness hours are farm_look.gd's 48-hour grace and
## §5.6's 120-hour expiry; the leat's are farm_sim.gd's LEAT_PER_DAY (15 points a day) and WET_ABOVE_TOP (10 over);
## the woods' floors are §5.9's 20% and 10% (forest_rules.gd). The Water range's depths follow the painted body and
## come from its probe (water_lens_probe.gd `legend_ticks`).

const LensesScript := preload("res://demo/map_lenses.gd")
const Palette := preload("res://demo/lenses/lens_palette.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Farming := preload("res://scripts/core/farming.gd")
const Look := preload("res://demo/farm/farm_look.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")

## One row per layer: group, label, ramp_from, ramp_count, caption, the ground (OVER_*), the ticks, and which
## swatches are areas (the probe's classes; absent: the ramp's).
const GROWING: String = "Growing"
const ROWS: Array[Dictionary] = [
	{"group": GROWING, "label": "Soil moisture", "from": 0, "count": 5, "over": Palette.OVER_SOIL,
		"caption": "Points of moisture from the crop's good range",
		"ticks": ["<−20", "<0", "in range", "≤+20", ">+20"]},
	{"group": GROWING, "label": "Ripeness", "from": 0, "count": 3, "over": Palette.OVER_SOIL,
		"caption": "Hours since the crop ripened (lost at 120 h)",
		"ticks": ["not yet", "<48 h", "48–120 h"], "areas": [0, 1, 2, 3]},
	{"group": GROWING, "label": "Water service", "from": 1, "count": 3, "over": Palette.OVER_SOIL,
		"caption": "Moisture points the leat adds a day (Beds 2, 4, 6)",
		"ticks": ["+0", "+15, to mid-range", "+15, to 10 over"],
		"areas": [0, 1, 2, 3]},
	{"group": "Getting there", "label": "Water range", "from": 0, "count": 3, "over": Palette.OVER_WATER,
		"caption": "", "ticks": [], "areas": [0, 1, 2, 7, 8]},
	{"group": "Woods", "label": "Zones and trees", "from": 0, "count": 0, "over": Palette.OVER_GRASS,
		"caption": "Forestry zones keep 20% of trees mature (10% intensive); conservation zones are never cut.",
		"ticks": [], "areas": [0, 1]},
]


static func apply(lenses: LensesScript) -> int:
	"""Write each row's scale onto its layer; returns how many layers were found."""
	var found: int = 0
	for row: Dictionary in ROWS:
		var lens: int = lenses.find(row["group"], row["label"])
		if lens == LensesScript.OFF:
			continue
		lenses.set_scale(lens, row["from"], row["count"], PackedStringArray(row["ticks"]), row["caption"], row["over"])
		lenses.set_areas(lens, PackedInt32Array(row.get("areas", [])))
		found += 1
	return found


static func check_figures() -> PackedStringArray:
	"""Where a row's words disagree with the rules they quote (the tests call it): empty when they agree."""
	var out := PackedStringArray()
	@warning_ignore("integer_division")
	var margin: int = Farming.MOISTURE_NEAR_MARGIN / 100
	if margin != 20:
		out.append("moisture margin is %d points" % margin)
	if Look.GRACE_HOURS != 48 or Farming.RIPE_WITHER_HOURS != 120:
		out.append("grace %d h, lost at %d h" % [Look.GRACE_HOURS, Farming.RIPE_WITHER_HOURS])
	var lows: Array[int] = Farming.CROP_MOISTURE_MIN
	var highs: Array[int] = Farming.CROP_MOISTURE_MAX
	if lows.min() != 2500 or lows.max() != 4000 or highs.min() != 7000 or highs.max() != 8500:
		out.append("crop ranges %d-%d / %d-%d" % [lows.min(), lows.max(), highs.min(), highs.max()])
	@warning_ignore("integer_division")
	var per_day: int = SimScript.LEAT_PER_DAY / 100
	@warning_ignore("integer_division")
	var over: int = SimScript.WET_ABOVE_TOP / 100
	if per_day != 15 or over != 10:
		out.append("leat %d a day, %d over" % [per_day, over])
	if ForestRules.RETAIN_PERCENT != 20 or ForestRules.INTENSIVE_RETAIN_PERCENT != 10:
		out.append("woods floors %d%% / %d%%" % [ForestRules.RETAIN_PERCENT, ForestRules.INTENSIVE_RETAIN_PERCENT])
	return out

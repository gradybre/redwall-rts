extends RefCounted
## THE FARM OVERVIEW'S ROWS and the beds' COMPARE table (decision 0451; review F45, P4's "Farm overview work detail",
## UX-008). Pure functions of the farm's model and crew, so test_demo_planner.gd reads them without a scene; the
## seasonal planner (farm_planner.gd) and the bed panel's Compare view (farm_compare_view.gd) draw them.
##
## ONE ROW A BED, seven cells and no more -- the bed panel keeps the detail (decision 0251's readings, the harvest's
## multiplication, the verbs): BED, CROP, STAGE (with the one need that makes it urgent), HARVEST (when and how much),
## MOISTURE in the bed panel's own words ("Good · 66%", farm_text.gd), WORK (each job on the bed and who has it, or that
## it is queued, paused or blocked) and NEXT (the next sowing plan).
##
## WHAT IS CERTAIN AND WHAT IS AN ESTIMATE. A ripe crop's dates are the rules' (REQ-SET-075: full yield for 48 hours from
## the tick it ripened, withered at 120) and are said plainly. A growing crop's ripening is the bed panel's own figure --
## farm_sim.gd `hours_to_ripe_into`, at THIS hour's growth rate -- dated on the one calendar and said with "≈" and
## "about": a frost night, rain or a change of season moves it, and the planner's footnote says so. Its amount is the
## bed panel's expected harvest (`expected_yield_into`, today's health and fertility). An empty bed with a crop chosen
## shows what it would bring if sown now, at today's rate (the crop picker's `sown_estimate_milli`).
##
## FILTERS. NEEDS ATTENTION: a bed whose Needs line is a warning (farm_text.gd: clear, a harvest past its grace, drain,
## water, cover), a harvest waiting for store room, or a job on it nobody can reach. HARVEST SOON: ripe, or ripening
## within HARVEST_SOON_HOURS at this hour's rate.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const CrewScript := preload("res://demo/farm/farm_crew.gd")
const Weather := preload("res://demo/farm/farm_weather.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## "Harvest soon": ripe, or ripening within a game day at this hour's rate (a demo presentation value: ten minutes at
## 1x, decision 0421).
const HARVEST_SOON_HOURS: int = 24
const FILTER_ALL: int = 0
const FILTER_ATTENTION: int = 1
const FILTER_SOON: int = 2
const FILTER_NAMES: Array[String] = ["All beds", "Needs attention", "Harvest soon"]
const FILTER_EMPTY: Array[String] = ["", "No bed needs attention now.", "No bed ripens within a day at today's rate."]
const COLUMN_TITLES: Array[String] = ["Bed", "Crop", "Stage", "Harvest: when · how much", "Soil moisture", "Work",
	"Next sowing"]
const COLUMN_COUNT: int = 7
## The verb each farm_text.gd NEED_* asks for (the overview names the verb; the bed panel says why).
const NEED_VERBS: Array[String] = ["Clear", "Clear", "Harvest", "Harvest", "Drain", "Water", "Cover"]
const NONE: String = "—"
## A sort key for "never" (nothing ripening): after every real number of hours.
const NEVER: int = 1 << 40
## The compare table's sorts.
const SORT_HARVEST: int = 0
const SORT_READY: int = 1
const SORT_MOISTURE: int = 2
const SORT_FERTILITY: int = 3
const SORT_BED: int = 4
const SORT_NAMES: Array[String] = ["Harvest", "Ready", "Moisture", "Fertility", "Bed"]
const SORT_WORDS: Array[String] = ["biggest harvest first", "soonest ripe first", "furthest from its range first",
	"most worn first", "bed number"]


static func cells_into(sim: SimScript, crew: CrewScript, bed: int, read: IntMath.IntResult, out: PackedStringArray) -> void:
	"""The bed's seven cells, in COLUMN_TITLES order, into `out` (resized to COLUMN_COUNT)."""
	out.resize(COLUMN_COUNT)
	out[0] = "Bed %d" % (bed + 1)
	out[1] = crop_text(sim, bed)
	out[2] = stage_text(sim, crew, bed, read)
	out[3] = harvest_text(sim, bed, read)
	out[4] = moisture_text(sim, bed)
	out[5] = work_text(crew, bed)
	out[6] = next_text(sim, bed)


static func crop_text(sim: SimScript, bed: int) -> String:
	"""'Carrot', 'Carrot (to sow)' or 'Empty'."""
	var item: int = sim.item_of(bed)
	if Catalog.is_item(item):
		return Catalog.ITEM_LABELS[item]
	if Catalog.is_item(sim.chosen_of(bed)):
		return "%s (to sow)" % Catalog.ITEM_LABELS[sim.chosen_of(bed)]
	return "Empty"


static func stage_text(sim: SimScript, crew: CrewScript, bed: int, read: IntMath.IntResult) -> String:
	"""'Growing 45%', with a second line naming the verb when the bed needs attention ('Needs: Drain')."""
	var stage: int = sim.stage_of(bed)
	@warning_ignore("integer_division") var growth: int = sim.growth_permille(bed) / 10
	var words: String = ["Empty", "Being sown", "Growing %d%%" % growth, "Growing %d%%" % growth, "Ripe", "Withered",
		"Blighted, %d%%" % growth][stage]
	if stage == SimScript.STAGE_EMPTY and sim.is_fallow(bed):
		words = "Empty, resting"
	var need: String = attention_verb(sim, crew, bed, read)
	return words if need.is_empty() else "%s\nNeeds: %s" % [words, need]


static func attention_verb(sim: SimScript, crew: CrewScript, bed: int, read: IntMath.IntResult) -> String:
	"""What makes the bed need attention, in a word or two ('' when nothing does): see FILTERS."""
	if Text.need_of_into(sim, bed, read) and Text.need_is_warning(read.value):
		return NEED_VERBS[read.value]
	if crew != null and not crew.shortage_text(bed).is_empty():
		return "store room"
	if crew != null and _blocked_job(crew, bed):
		return "a way to the job"
	return ""


static func _blocked_job(crew: CrewScript, bed: int) -> bool:
	"""Whether a job on the bed waits because nobody can get to it."""
	for row: int in JobsScript.MAX_JOBS:
		if crew.jobs.is_live(row) and crew.jobs.bed[row] == bed and crew.jobs.blocked[row] == JobsScript.BLOCK_WAY:
			return true
	return false


static func harvest_text(sim: SimScript, bed: int, read: IntMath.IntResult) -> String:
	"""When the bed's harvest comes and how much (see WHAT IS CERTAIN AND WHAT IS AN ESTIMATE)."""
	match sim.stage_of(bed):
		SimScript.STAGE_RIPE:
			return _ripe_text(sim, bed, read)
		SimScript.STAGE_SPROUTING, SimScript.STAGE_GROWING, SimScript.STAGE_BLIGHTED:
			return _growing_text(sim, bed, read)
		SimScript.STAGE_WITHERED:
			return "Lost — clear it for compost"
		SimScript.STAGE_SOWN:
			return "Being sown"
	return _sow_now_text(sim, bed, read)


static func _ripe_text(sim: SimScript, bed: int, read: IntMath.IntResult) -> String:
	"""'Ripe now: 5 bunches · full yield until Spring 9, 14:00' (or past its grace: losing, and when it withers)."""
	var ripe_tick: int = ripe_tick_of(sim, bed)
	var amount: String = harvest_cell(sim.item_of(bed), read.value) if sim.expected_yield_into(bed, read) else NONE
	if not sim.ripe_hours_into(bed, read) or ripe_tick < 0:
		return "Ripe now: %s" % amount
	var grace_end: int = ripe_tick + FarmingScript.RIPE_GRACE_HOURS * SimClock.TICKS_PER_HOUR
	if read.value < FarmingScript.RIPE_GRACE_HOURS:
		return "Ripe now: %s · full yield until %s" % [amount, date_text(sim, grace_end)]
	var withers: int = ripe_tick + FarmingScript.RIPE_WITHER_HOURS * SimClock.TICKS_PER_HOUR
	return "Ripe now: %s, losing 10%% a day · withers %s" % [amount, date_text(sim, withers)]


static func _growing_text(sim: SimScript, bed: int, read: IntMath.IntResult) -> String:
	"""'≈ Spring 9, 14:00 · about 5 bunches' at this hour's rate, or 'Stalled (too cold) · about 5 bunches'."""
	var amount: String = harvest_cell(sim.item_of(bed), read.value) if sim.expected_yield_into(bed, read) else NONE
	if not ripe_estimate_tick_into(sim, bed, read):
		return "Stalled (%s) · about %s" % [_stall_word(sim, bed), amount]
	return "≈ %s · about %s" % [date_text(sim, read.value), amount]


static func _stall_word(sim: SimScript, bed: int) -> String:
	"""Why growth stands still: parched, waterlogged, else the cold (farm_text.gd's reasons)."""
	var band: int = sim.band_of(bed)
	return "too dry" if band == SimScript.BAND_DRY else ("waterlogged" if band == SimScript.BAND_WATERLOGGED else "too cold")


static func _sow_now_text(sim: SimScript, bed: int, read: IntMath.IntResult) -> String:
	"""An empty bed with a crop chosen and sowable now: when and how much if sown now, at today's rate."""
	var item: int = sim.chosen_of(bed)
	if not Catalog.is_item(item) or sim.sow_refusal(bed, item) != SimScript.REFUSE_NONE:
		return NONE
	var amount: String = harvest_cell(item, Text.sown_estimate_milli(sim, bed, item))
	if not sown_hours_into(sim, bed, item, read):
		return "If sown now: stalled today · about %s" % amount
	var tick: int = CalendarScript.next_hour_crossing(sim.calendar.tick) + (read.value - 1) * SimClock.TICKS_PER_HOUR
	return "If sown now: ≈ %s · about %s" % [date_text(sim, tick), amount]


static func harvest_cell(item: int, milli: int) -> String:
	"""A bed's harvest in its crop's measure, for a row whose CROP cell names the crop (goods_measures.gd's cell form,
	rounded down; decision 1801), its number and measure kept on one line with a no-break space: '5\u00a0bunches',
	'1½\u00a0sacks'. Mixed food's measure for a bed with no crop."""
	var good: StringName = Catalog.ITEM_KEYS[item] if Catalog.is_pantry_item(item) else &"food"
	return Measures.amount_cell(good, milli).replace(" ", "\u00a0")


static func ripe_tick_of(sim: SimScript, bed: int) -> int:
	"""The tick a ripe bed ripened at (farming.gd's TileHistory.ripe_tick), -1 when it is not ripe."""
	if sim.stage_of(bed) != SimScript.STAGE_RIPE:
		return -1
	var tile: IntMath.IntResult = sim.farming().tile_of(sim.slot_of(bed))
	if not tile.ok:
		return -1
	var tick: IntMath.IntResult = sim.farming().tile_ripe_tick_of(tile.value)
	return tick.value if tick.ok else -1


static func ripe_estimate_tick_into(sim: SimScript, bed: int, out: IntMath.IntResult) -> bool:
	"""The tick a growing crop ripens at, at THIS hour's rate (`hours_to_ripe_into`: it ripens at the crossing that
	completes it, the first crossing being the next one). Refuses a stalled crop or a bed with nothing growing."""
	if not sim.hours_to_ripe_into(bed, out):
		return false
	return out.succeed(CalendarScript.next_hour_crossing(sim.calendar.tick) + (out.value - 1) * SimClock.TICKS_PER_HOUR)


static func sown_hours_into(sim: SimScript, bed: int, item: int, out: IntMath.IntResult) -> bool:
	"""Game hours `item` sown in this empty bed now would take to ripen at this hour's growth rate (the bed's own
	temperature and moisture, farm_sim.gd's own factors); refuses a zero rate."""
	var crop: int = Catalog.crop_of(item)
	var tenths: int = Weather.bed_tenths(sim.air_tenths(), sim.is_covered(bed), sim.is_raised(bed))
	if not sim.farming().moisture_factor_into(crop, sim.moisture_of(bed), out):
		return false
	if not sim.farming().growth_step_milli_hours_into(FarmingScript.temperature_factor_of(tenths), out.value, out):
		return false
	if out.value <= 0:
		return out.refuse(String(SimScript.REFUSE_STALLED))
	var target: int = FarmingScript.CROP_GROWTH_HOURS[crop] * FarmingScript.MILLI_HOURS_PER_HOUR
	@warning_ignore("integer_division") return out.succeed((target + out.value - 1) / out.value)


static func moisture_text(sim: SimScript, bed: int) -> String:
	"""'Good · 66%' -- the bed panel's band word and reading (farm_text.gd `moisture_line`, decision 0251)."""
	return "%s · %d%%" % [SimScript.BAND_NAMES[sim.band_of(bed)].capitalize(),
		Text.moisture_percent(sim.moisture_of(bed), sim.band_max_of(bed))]


static func work_text(crew: CrewScript, bed: int) -> String:
	"""Each job on the bed and who has it: 'Harvest: Mouse fieldworker; Water: queued' ('—' for none)."""
	if crew == null:
		return NONE
	var parts := PackedStringArray()
	for row: int in JobsScript.MAX_JOBS:
		if crew.jobs.is_live(row) and crew.jobs.bed[row] == bed:
			parts.append("%s: %s" % [JobsScript.KIND_NAMES[crew.jobs.kind[row]], _who_words(crew, row)])
	return "; ".join(parts) if not parts.is_empty() else NONE


static func _who_words(crew: CrewScript, row: int) -> String:
	"""A job's worker, or why it waits: paused, blocked, queued."""
	if crew.is_paused(row):
		return "paused"
	var who: String = crew.worker_name(row)
	if not who.is_empty():
		return who
	return "blocked" if not crew.blocked_words(row).is_empty() else "queued"


static func next_text(sim: SimScript, bed: int) -> String:
	"""The bed's next sowing plan: the crop chosen and when it can go in, resting, or what to decide."""
	var stage: int = sim.stage_of(bed)
	if stage == SimScript.STAGE_WITHERED:
		return "Clear it first"
	if stage != SimScript.STAGE_EMPTY:
		return "Choose after the harvest"
	if sim.is_fallow(bed):
		return "Resting (Rest is on)"
	var item: int = sim.chosen_of(bed)
	if not Catalog.is_item(item):
		var sowable: int = sowable_count(sim, bed)
		return "Choose a crop: %d sowable now" % sowable if sowable > 0 else "Nothing sowable here now"
	var why: String = Text.pick_reason(sim, bed, item)
	return "Sow %s now" % Catalog.ITEM_LABELS[item] if why.is_empty() else "%s: %s" % [Catalog.ITEM_LABELS[item], why]


static func sowable_count(sim: SimScript, bed: int) -> int:
	"""How many ingredients could be sown in the bed now."""
	var count: int = 0
	for item: int in Catalog.ITEM_COUNT:
		if sim.sow_refusal(bed, item) == SimScript.REFUSE_NONE:
			count += 1
	return count


static func date_text(sim: SimScript, tick: int) -> String:
	"""A tick on the one calendar as the HUD names its day, with the hour: 'Spring 9, 14:00' (the year added when it is
	not this one: 'Y2 Spring 1, 06:00')."""
	var year: int = sim.calendar.now().year
	var at: SimClock.Calendar = sim.calendar.calendar_at(tick)
	var day: String = "%s, %02d:00" % [CalendarScript.day_text(at.season, at.season_day), at.hour]
	return day if at.year == year else "Y%d %s" % [at.year, day]


# --- filters ----------------------------------------------------------------------------------------------------------

static func needs_attention(sim: SimScript, crew: CrewScript, bed: int, read: IntMath.IntResult) -> bool:
	"""The Needs attention filter (see FILTERS)."""
	return not attention_verb(sim, crew, bed, read).is_empty()


static func harvest_soon(sim: SimScript, bed: int, read: IntMath.IntResult) -> bool:
	"""The Harvest soon filter: ripe, or ripening within HARVEST_SOON_HOURS at this hour's rate."""
	if sim.stage_of(bed) == SimScript.STAGE_RIPE:
		return true
	return sim.hours_to_ripe_into(bed, read) and read.value <= HARVEST_SOON_HOURS


static func matches(sim: SimScript, crew: CrewScript, bed: int, filter: int, read: IntMath.IntResult) -> bool:
	"""Whether the bed shows under FILTER_* (a kitchen-garden site not laid out never does: it is no bed yet)."""
	if not sim.is_laid(bed):
		return false
	match filter:
		FILTER_ATTENTION:
			return needs_attention(sim, crew, bed, read)
		FILTER_SOON:
			return harvest_soon(sim, bed, read)
	return true


static func count_matching(sim: SimScript, crew: CrewScript, filter: int, read: IntMath.IntResult) -> int:
	"""How many beds show under FILTER_*."""
	var count: int = 0
	for bed: int in Catalog.BED_COUNT:
		if matches(sim, crew, bed, filter, read):
			count += 1
	return count


# --- compare (UX-008) -------------------------------------------------------------------------------------------------

static func compare_line(sim: SimScript, bed: int, read: IntMath.IntResult) -> String:
	"""A bed's compared figures on one line: 'Ripe · 5 bunches of carrots · Good · 66% · fertility 63%' ('Ripe in about
	30 h', 'Stalled', 'Nothing growing')."""
	var ready: String = "Nothing growing"
	if sim.stage_of(bed) == SimScript.STAGE_RIPE:
		ready = "Ripe"
	elif sim.hours_to_ripe_into(bed, read):
		ready = "Ripe in about %s" % Text.span_text(read.value)
	elif is_growing_stage(sim.stage_of(bed)):
		ready = "Stalled"
	var harvest: String = Measures.amount(Catalog.ITEM_KEYS[sim.item_of(bed)], read.value) \
		if standing_yield_into(sim, bed, read) else "no harvest"
	return "%s · %s · %s · fertility %s" % [ready, harvest, moisture_text(sim, bed), Text.percent_text(sim.fertility_of(bed))]


static func is_growing_stage(stage: int) -> bool:
	"""Whether a stage is a crop still growing (sprouting, growing or blighted)."""
	return stage == SimScript.STAGE_SPROUTING or stage == SimScript.STAGE_GROWING or stage == SimScript.STAGE_BLIGHTED


static func standing_yield_into(sim: SimScript, bed: int, out: IntMath.IntResult) -> bool:
	"""The expected harvest of a crop standing in the bed, growing or ripe (refuses an empty, sown or withered bed)."""
	var stage: int = sim.stage_of(bed)
	if stage != SimScript.STAGE_RIPE and not is_growing_stage(stage):
		return out.refuse("NOTHING_STANDING")
	return sim.expected_yield_into(bed, out)


static func sort_key(sim: SimScript, bed: int, sort: int, read: IntMath.IntResult) -> int:
	"""A bed's key under SORT_* -- the smaller first (see SORT_WORDS)."""
	match sort:
		SORT_HARVEST:
			return -read.value if standing_yield_into(sim, bed, read) else 1
		SORT_READY:
			if sim.stage_of(bed) == SimScript.STAGE_RIPE:
				return 0
			return read.value if sim.hours_to_ripe_into(bed, read) else NEVER
		SORT_MOISTURE:
			@warning_ignore("integer_division") return -absi(sim.band_of(bed) - SimScript.BAND_GOOD) * 100000 - absi(sim.moisture_of(bed) - (sim.band_min_of(bed)
				+ sim.band_max_of(bed)) / 2)
		SORT_FERTILITY:
			return sim.fertility_of(bed)
	return bed


static func sorted_beds(sim: SimScript, sort: int, read: IntMath.IntResult) -> PackedInt32Array:
	"""Every bed in SORT_* order, ties by bed number (a stable insertion sort of six)."""
	var keys := PackedInt64Array()
	var order := PackedInt32Array()
	for bed: int in Catalog.BED_COUNT:
		if not sim.is_laid(bed):
			continue
		var key: int = sort_key(sim, bed, sort, read)
		var at: int = order.size()
		while at > 0 and keys[at - 1] > key:
			at -= 1
		keys.insert(at, key)
		order.insert(at, bed)
	return order

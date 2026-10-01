extends "res://demo/lenses/lens_probe.gd"
## What the three Growing layers say about a point of the garden (decision 0581): the bed under it and its soil
## moisture, its ripeness, or what the garden leat brings it. Presentation only: reads farm_sim.gd, writes nothing.
##
## CACHED BY THE HOUR. The sim's readouts hand back small result objects, so the probe reads every bed once whenever
## the sim's revision moves (each game hour, and on any player change) into packed columns, and `read_into` is then a
## lookup -- the pointer allocates nothing. `field_revision` moves only when some bed's legend entry changes, so the
## compare outlines are redrawn only when a bed changes colour.
##
## THE NUMBERS are the sim's own. Moisture: 0..10000 shown as whole percent (farm_text.gd `moisture_percent`), against
## the bed's own band (`band_min_of`, `band_max_of`: the crop's §5.6 range, or the empty bed's) with farming.gd's
## MOISTURE_NEAR_MARGIN either side -- exactly where `band_at` splits dry, low, good, wet and waterlogged. Ripeness:
## the growth toward ripeness and the hours to ripen at this hour's rate (`hours_to_ripe_into`), or the hours since
## ripening against farm_look.gd's 48-hour grace and the 120-hour expiry. Service: weir_sluice.gd's state, with
## farm_sim.gd's LEAT_PER_DAY and WET_ABOVE_TOP.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Look := preload("res://demo/farm/farm_look.gd")
const FarmText := preload("res://demo/farm/farm_text.gd")
const Sluice := preload("res://demo/water/weir_sluice.gd")
const Farming := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const MODE_MOISTURE: int = 0
const MODE_RIPENESS: int = 1
const MODE_SERVICE: int = 2
## The Ripeness legend's entries (demo_farm.gd's order): growing, ripe, past its best or lost, empty.
const RIPENESS_GROWING: int = 0
const RIPENESS_RIPE: int = 1
const RIPENESS_LATE: int = 2
const RIPENESS_EMPTY: int = 3
## Hours since ripening at which a crop is lost (§5.6 as READY_06 §6.4 rules it: farming.gd's own figure).
const LOST_HOURS: int = Farming.RIPE_WITHER_HOURS
## Drawn just over the beds' overlay discs (farm_bed_visual.gd lifts them 0.42 m), on a finer grid than the water's.
const DISC_Y_M: float = 0.44
const BED_CELL_M: float = 0.25
## Packs a reading's stage, growth and hours into one value (hours below HOURS_SPAN, growth below 1001).
const HOURS_SPAN: int = 100000
const STAGE_SPAN: int = 1000000000
## The hours value a stalled crop reads.
const STALLED: int = HOURS_SPAN - 1

var mode: int = MODE_MOISTURE

var _sim: SimScript = null
var _centres: PackedVector2Array = PackedVector2Array()
var _bounds: Rect2 = Rect2()
var _entry: PackedInt32Array = PackedInt32Array()
var _value: PackedInt64Array = PackedInt64Array()
var _seen_revision: int = -1
var _area_revision: int = 0
var _read: IntMath.IntResult = IntMath.IntResult.new()


func _init(sim: SimScript, probe_mode: int) -> void:
	"""Read `sim`'s beds for the layer `probe_mode` (MODE_*)."""
	_sim = sim
	mode = probe_mode
	_entry.resize(Catalog.BED_COUNT)
	_entry.fill(-1)
	_value.resize(Catalog.BED_COUNT)
	for bed: int in Catalog.BED_COUNT:
		_centres.append(Catalog.bed_centre_m(bed))
		var square := Rect2(_centres[bed] - Vector2.ONE * Catalog.BED_HALF_M, Vector2.ONE * 2.0 * Catalog.BED_HALF_M)
		_bounds = square if bed == 0 else _bounds.merge(square)
	_bounds = _bounds.grow(BED_CELL_M * 2.0)


func bed_at(point_m: Vector2) -> int:
	"""The bed whose square holds the point (farm_catalog.gd `bed_at_into`'s footprint), -1 for none."""
	for bed: int in _centres.size():
		var d: Vector2 = (point_m - _centres[bed]).abs()
		if d.x <= Catalog.BED_HALF_M and d.y <= Catalog.BED_HALF_M:
			return bed
	return -1


func read_into(point_m: Vector2, out: Reading) -> bool:
	"""The bed under the point: its legend entry and value (see CACHED BY THE HOUR)."""
	out.clear()
	_sync()
	var bed: int = bed_at(point_m)
	if bed < 0:
		return false
	out.who = bed
	out.entry = _entry[bed]
	out.area = _entry[bed]
	out.value = _value[bed]
	return true


func can_outline() -> bool:
	"""The beds can be outlined over another layer."""
	return true


func field_bounds_m() -> Rect2:
	"""The garden's beds, with a margin."""
	return _bounds


func field_cell_m() -> float:
	"""A quarter metre: a bed is 3 m across."""
	return BED_CELL_M


func draw_y_m() -> float:
	"""Over the beds' discs."""
	return DISC_Y_M


func field_revision() -> int:
	"""Moves when some bed's entry changes."""
	_sync()
	return _area_revision


func _sync() -> void:
	"""Re-read every bed when the sim's revision has moved."""
	if _sim.revision == _seen_revision:
		return
	_seen_revision = _sim.revision
	for bed: int in Catalog.BED_COUNT:
		var entry: int = _entry_now(bed)
		if entry != _entry[bed]:
			_entry[bed] = entry
			_area_revision += 1
		_value[bed] = _value_now(bed)


func _entry_now(bed: int) -> int:
	"""A bed's legend entry in this probe's layer."""
	match mode:
		MODE_MOISTURE:
			return _sim.band_of(bed)
		MODE_SERVICE:
			return _sim.leat_service_of(bed)
	return ripeness_entry(_sim.stage_of(bed), _ripe_hours(bed))


static func ripeness_entry(stage: int, ripe_hours: int) -> int:
	"""The Ripeness legend's entry for a stage and its hours ripe (farm_look.gd `ripeness_overlay`'s split)."""
	if stage == SimScript.STAGE_RIPE:
		return RIPENESS_RIPE if ripe_hours < Look.GRACE_HOURS else RIPENESS_LATE
	if stage == SimScript.STAGE_WITHERED or stage == SimScript.STAGE_BLIGHTED:
		return RIPENESS_LATE
	return RIPENESS_EMPTY if stage == SimScript.STAGE_EMPTY else RIPENESS_GROWING


func _value_now(bed: int) -> int:
	"""A bed's exact value in this probe's layer: its moisture; its stage, growth and hours; its service."""
	if mode == MODE_MOISTURE:
		return _sim.moisture_of(bed)
	if mode == MODE_SERVICE:
		return _sim.leat_service_of(bed)
	var stage: int = _sim.stage_of(bed)
	var hours: int = _ripe_hours(bed) if stage == SimScript.STAGE_RIPE else _hours_to_ripe(bed)
	return stage * STAGE_SPAN + _sim.growth_permille(bed) * HOURS_SPAN + hours


func _ripe_hours(bed: int) -> int:
	"""Hours a ripe bed has stood (0 when not ripe)."""
	return _read.value if _sim.ripe_hours_into(bed, _read) else 0


func _hours_to_ripe(bed: int) -> int:
	"""Game hours to ripeness at this hour's rate; STALLED when it is not growing."""
	return mini(_read.value, STALLED - 1) if _sim.hours_to_ripe_into(bed, _read) else STALLED


# --- words ------------------------------------------------------------------------------------------

func describe(reading: Reading) -> String:
	"""The bed in words: two lines, the value first and its thresholds second."""
	match mode:
		MODE_MOISTURE:
			return moisture_text(_sim, reading.who)
		MODE_SERVICE:
			return service_text(reading.who, reading.value)
	return ripeness_text(_sim, reading.who, reading.value)


static func bed_title(sim: SimScript, bed: int) -> String:
	"""'Bed 3, Carrot', or 'Bed 3, empty'."""
	var item: int = sim.item_of(bed)
	return "%s, %s" % [Sluice.bed_word(bed), Catalog.ITEM_LABELS[item] if Catalog.is_item(item) else "empty"]


static func moisture_text(sim: SimScript, bed: int) -> String:
	"""'Soil moisture 62% · good', this bed's good range, and where its other bands begin (whole percent; a band the
	0..100% scale cannot reach is left out)."""
	var low: int = sim.band_min_of(bed)
	var high: int = sim.band_max_of(bed)
	@warning_ignore("integer_division")
	var first: String = "Soil moisture %d%% · %s\n%s: good %d–%d%%" % [FarmText.moisture_percent(sim.moisture_of(bed), high),
		SimScript.BAND_NAMES[sim.band_of(bed)], bed_title(sim, bed), low / 100, high / 100]
	return "%s\n%s" % [first, " · ".join(band_edges(low, high))]


static func band_edges(low: int, high: int) -> PackedStringArray:
	"""Where the bands other than good begin, as farm_sim.gd `band_at` splits them: 'dry <20%', 'low <40%',
	'wet ≤100%', 'waterlogged >100%' -- or 'wet above 80%' where waterlogging is past the scale's top."""
	var margin: int = Farming.MOISTURE_NEAR_MARGIN
	var out := PackedStringArray()
	if low - margin > 0:
		@warning_ignore("integer_division")
		out.append("dry <%d%%" % ((low - margin) / 100))
	@warning_ignore("integer_division")
	out.append("low <%d%%" % (low / 100))
	if high + margin < Farming.MOISTURE_MAX:
		@warning_ignore("integer_division")
		out.append("wet ≤%d%% · waterlogged >%d%%" % [(high + margin) / 100, (high + margin) / 100])
	else:
		@warning_ignore("integer_division")
		out.append("wet above %d%%" % (high / 100))
	return out


static func ripeness_text(sim: SimScript, bed: int, value: int) -> String:
	"""'Bed 3, Carrot · 62% grown' with the hours to ripen, or the hours ripe against the grace and the expiry."""
	@warning_ignore("integer_division")
	var stage: int = value / STAGE_SPAN
	@warning_ignore("integer_division")
	var growth: int = (value % STAGE_SPAN) / HOURS_SPAN
	var hours: int = value % HOURS_SPAN
	var title: String = bed_title(sim, bed)
	match stage:
		SimScript.STAGE_EMPTY:
			return "%s\nnothing growing" % title
		SimScript.STAGE_WITHERED:
			return "%s · withered\nlost: clear the bed" % title
		SimScript.STAGE_BLIGHTED:
			return "%s · blighted\nlost to blight" % title
		SimScript.STAGE_RIPE:
			var when: String = "best within %d h" % Look.GRACE_HOURS if hours < Look.GRACE_HOURS else "past its best"
			return "%s · ripe %d h\n%s · lost at %d h" % [title, hours, when, LOST_HOURS]
	@warning_ignore("integer_division")
	var grown: String = "%s · %d%% grown" % [title, growth / 10]
	if hours >= STALLED:
		return "%s\nnot growing now (stalled)" % grown
	return "%s\nripe in about %d h at this hour's rate" % [grown, hours]


static func service_text(bed: int, service: int) -> String:
	"""What the garden leat brings this bed, with the leat's own figures (percentage points a day)."""
	var title: String = Sluice.bed_word(bed)
	@warning_ignore("integer_division")
	var per_day: int = SimScript.LEAT_PER_DAY / 100
	match service:
		Sluice.SERVICE_DRY:
			return "%s · leat: dry\nthe leat runs empty: it adds nothing" % title
		Sluice.SERVICE_NORMAL:
			return "%s · leat: normal\nup to %d points a day toward its good range's middle" % [title, per_day]
		Sluice.SERVICE_WET:
			@warning_ignore("integer_division")
			var over: int = SimScript.WET_ABOVE_TOP / 100
			return "%s · leat: wet\nup to %d points a day, to %d over its good range" % [title, per_day, over]
	return "%s · not on the garden leat\nthe leat serves Bed 2, Bed 4 and Bed 6" % title

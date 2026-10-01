extends RefCounted
## What the farm warns the player about, and when. Decision 0196. Each warning names the response:
##   * FROST TONIGHT, from ALERT_HOUR the day before a frost night -- naming the night by the demo's one
##     calendar date, the one the HUD shows (demo_calendar.gd): cover or raise growing beds, harvest what
##     is ripe.
##   * RIPE: a bed ripened -- harvest within the 48-hour grace; then SPOILING once the grace is over
##     (10% a day), and WITHERS SOON in its last day (120 h).
##   * BLIGHT: an outbreak or its spread -- clear the bed before midnight, when it spreads.
##   * WITHERED: frost, blight or neglect killed a crop -- clear it for compost.
##   * DRY / WATERLOGGED: a growing bed out of its band far enough to stop growth (the moisture factor's
##     0) -- water it, or Drain it (the Drain job digs a ditch round it).
##   * WORN OUT: an empty bed below LOW_FERTILITY -- compost it or rest it fallow.
##   * SPOILED: food in store went off.
##   * The real weather's own three-day FORECAST (§5.10), when it discloses one.
## Each fires ONCE per occurrence -- per event; per bed and day for ripeness; per bed and SEASON for
## a standing condition (dry, waterlogged, worn out), which the bed's label and the overlays keep
## showing -- so the warnings that need a response tonight are not pushed out by ones already given.
## Pure logic: `collect_into()` is handed the sim, the pantry's spoiled items and the sim's events, and
## appends the lines to show -- and, in `levels`, each line's level in the demo's notice feed
## (demo_notices.gd): a WARNING for what needs doing soon (frost, blight, withering, a bed out of its
## band, a crop losing yield), a NOTE for the rest (ripe, forecast, worn out, spoiled).

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Weather := preload("res://demo/farm/farm_weather.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const LOW_FERTILITY: int = 4000
const GRACE_HOURS: int = 48
const LAST_DAY_HOURS: int = 96
const NOTE: int = NoticesScript.LEVEL_NOTE
const WARNING: int = NoticesScript.LEVEL_WARNING
const EVENT_NAMES: Array[String] = ["Blight", "Calm days", "Drought", "Early frost", "Hard freeze",
	"Heavy rain", "Ideal spell"]

var _said: Dictionary = {}
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _levels: PackedByteArray = PackedByteArray()


func collect_into(sim: SimScript, events: PackedInt32Array, spoiled_items: PackedInt32Array,
		out: PackedStringArray, levels: PackedByteArray = PackedByteArray()) -> void:
	"""Append every warning due now (see the header) to `out`, and its feed level to `levels`."""
	_levels = levels
	var day: int = sim.absolute_day()
	for k: int in range(0, events.size() - 1, 2):
		_event_line(sim, events[k], events[k + 1], day, out)
	_frost_line(sim, day, out)
	_forecast_line(sim, out)
	for bed: int in Catalog.BED_COUNT:
		_bed_lines(sim, bed, day, out)
	for item: int in spoiled_items:
		_once(out, "spoiled:%d:%d" % [item, day], "Some %s in store has spoiled" % _name(item), NOTE)


func _event_line(sim: SimScript, kind: int, bed: int, day: int, out: PackedStringArray) -> void:
	"""A line for one sim event."""
	var what: String = _bed_name(sim, bed)
	match kind:
		SimScript.EVENT_RIPENED:
			_once(out, "ripe:%d:%d" % [bed, day], "%s is ripe — harvest it within 2 days" % what, NOTE)
		SimScript.EVENT_WITHERED:
			_once(out, "withered:%d:%d" % [bed, day], "%s has withered — clear it for compost" % what, WARNING)
		SimScript.EVENT_BLIGHT:
			_once(out, "blight:%d:%d" % [bed, day], "Blight on %s! Clear it before midnight or it spreads" % what,
				WARNING)
		SimScript.EVENT_BLIGHT_SPREAD:
			_once(out, "blight:%d:%d" % [bed, day], "Blight has spread to %s — clear the blighted beds" % what,
				WARNING)


func _frost_line(sim: SimScript, day: int, out: PackedStringArray) -> void:
	"""Frost tonight, from ALERT_HOUR the day before, naming the night by its calendar date."""
	var hour: int = sim.calendar.calendar_at(sim.calendar.tick).hour
	if hour < Weather.ALERT_HOUR or not Weather.frost_tonight(sim.season(), sim.season_day()):
		return
	_once(out, "frost:%d" % day, frost_text(sim.season(), sim.season_day()), WARNING)


static func frost_text(season: int, season_day: int) -> String:
	"""'Frost tonight (Spring 4, 02:00–05:59)! …' for the night after this season day."""
	var night: Vector2i = Weather.next_day(season, season_day)
	return "Frost tonight (%s, %02d:00–%02d:59)! Cover growing beds (or raise them with spoil) and harvest what is ripe" \
		% [CalendarScript.day_text(night.x, night.y), Weather.FROST_FIRST_HOUR, Weather.FROST_LAST_HOUR]


func _forecast_line(sim: SimScript, out: PackedStringArray) -> void:
	"""The real weather's disclosed forecast, once per event."""
	var event: int = sim.forecast_event()
	if event < 0 or event >= EVENT_NAMES.size():
		return
	_once(out, "forecast:%d:%d" % [event, (sim.absolute_day() - 1) / SimClock.DAYS_PER_SEASON],
		"Forecast: %s coming in the next days" % EVENT_NAMES[event].to_lower(), NOTE)


func _bed_lines(sim: SimScript, bed: int, day: int, out: PackedStringArray) -> void:
	"""A bed's standing conditions: ripeness running out, dryness, waterlogging, worn-out soil."""
	var stage: int = sim.stage_of(bed)
	var what: String = _bed_name(sim, bed)
	if stage == SimScript.STAGE_RIPE and sim.ripe_hours_into(bed, _read):
		if _read.value >= LAST_DAY_HOURS:
			_once(out, "last:%d:%d" % [bed, day], "%s withers within a day — harvest now!" % what, WARNING)
		elif _read.value >= GRACE_HOURS:
			_once(out, "grace:%d:%d" % [bed, day], "%s is losing 10%% a day — harvest it" % what, WARNING)
	var growing: bool = stage == SimScript.STAGE_SPROUTING or stage == SimScript.STAGE_GROWING \
		or stage == SimScript.STAGE_BLIGHTED
	var band: int = sim.band_of(bed)
	var season: int = (day - 1) / SimClock.DAYS_PER_SEASON
	if growing and band == SimScript.BAND_DRY:
		_once(out, "dry:%d:%d" % [bed, season], "%s is too dry to grow — water it" % what, WARNING)
	if growing and band == SimScript.BAND_WATERLOGGED:
		_once(out, "wet:%d:%d" % [bed, season],
			"%s is waterlogged and has stopped growing — Drain it" % what, WARNING)
	if stage == SimScript.STAGE_EMPTY and sim.fertility_of(bed) < LOW_FERTILITY:
		_once(out, "worn:%d:%d" % [bed, season], "Bed %d is worn out (fertility %d%%) — compost it or rest it fallow"
			% [bed + 1, sim.fertility_of(bed) / 100], NOTE)


func _once(out: PackedStringArray, key: String, text: String, level: int) -> void:
	"""Append `text` (and its level) the first time `key` is seen."""
	if _said.has(key):
		return
	_said[key] = true
	out.append(text)
	_levels.append(level)


func _bed_name(sim: SimScript, bed: int) -> String:
	"""'Bed 3 (carrot)', or 'Bed 3' with nothing standing -- the number keeps two wheat beds apart."""
	var item: int = sim.item_of(bed)
	if Catalog.is_item(item):
		return "Bed %d (%s)" % [bed + 1, Catalog.ITEM_LABELS[item].to_lower()]
	return "Bed %d" % (bed + 1)


static func _name(item: int) -> String:
	"""An item's name in lower case."""
	return Catalog.ITEM_LABELS[item].to_lower() if Catalog.is_item(item) else "food"

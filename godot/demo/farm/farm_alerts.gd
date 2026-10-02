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
## Each fires ONCE per occurrence -- per event; per bed and day for ripeness; per OCCURRENCE of a standing
## condition (dry, waterlogged, worn out: see STANDING CONDITIONS), which the bed's label and the overlays
## keep showing -- so the warnings that need a response tonight are not pushed out by ones already given.
##
## STANDING CONDITIONS (decision 0331, review F37). Dry, waterlogged and worn out were said once per bed
## and SEASON, and the key was never cleared: a bed drained and then waterlogged again by the next rain in
## the same season stopped growing in silence. Each is now tracked per bed as a condition with transitions:
##   * it is ANNOUNCED when it becomes active, and not said again while it stays active;
##   * when it stops (the bed back in its band, or composted) it is ENDING, and once it has stayed gone for
##     REARM_HOURS it is RESOLVED -- cleared and re-armed (its incident resolves);
##   * back while ENDING (a bed hovering at its band's edge), it is the same occurrence still going on:
##     active again, nothing said -- REARM_HOURS is the cooldown that keeps one rainy day from flapping;
##   * back after it resolved, it is a NEW occurrence and is announced again, in the same season or not.
## A bed that stops growing (harvested, withered, cleared) ends dry and wet at once, and one sown ends worn
## out at once: there is nothing left to recover.
##
## INCIDENTS (decision 0331, review UX-011). Bound to the demo's incidents (`bind_incidents`), each
## standing condition, each blighted bed and tonight's frost is also an incident (demo_incidents.gd) that
## stays until it resolves: a condition when RESOLVED above, blight when the bed is no longer blighted, the
## frost once the night is over (`Weather.frost_due` false). A standing condition's state is read back by
## the incident (`condition_state`): ENDING is RECOVERING; a remedy job on the bed (the farm's `remedy`
## query: drain, water, compost; clear for blight) is ASSIGNED. Every line also carries its bed
## (`targets`, -1 for none) and its incident's serial (`serials`), for the feed's "Go to".
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
const IncidentsScript := preload("res://demo/demo_incidents.gd")

## The standing conditions (see STANDING CONDITIONS).
const COND_DRY: int = 0
const COND_WET: int = 1
const COND_WORN: int = 2
const COND_COUNT: int = 3
const COND_KEYS: Array[String] = ["dry", "wet", "worn"]
## Blight is no standing condition but has a remedy (Clear): `remedy(bed, COND_BLIGHT)`.
const COND_BLIGHT: int = 3
## A condition's phase.
const PHASE_IDLE: int = 0
const PHASE_ACTIVE: int = 1
const PHASE_ENDING: int = 2
## How long a condition must stay gone before it counts as resolved and re-arms (demo value, decision 0331).
const REARM_HOURS: int = 2
const FROST_KEY: String = "farm:frost"

## Each line's bed (-1: none) and incident serial (-1: none), filled alongside `out` by `collect_into`.
var targets: PackedInt32Array = PackedInt32Array()
var serials: PackedInt32Array = PackedInt32Array()

var _said: Dictionary = {}
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _levels: PackedByteArray = PackedByteArray()
var _incidents: IncidentsScript = null
## `(bed: int, cond: int) -> bool`: whether a remedy job is on the bed (COND_* or COND_BLIGHT).
var _remedy: Callable = Callable()
## Per bed x COND_*: PHASE_*, and the farm hour its ENDING began.
var _phase: PackedByteArray = PackedByteArray()
var _ending_since: PackedInt64Array = PackedInt64Array()
## Per bed: 1 while its blight incident is open.
var _blight_open: PackedByteArray = PackedByteArray()
## The condition being said's incident (`_once` raises it): its key and severity, or "".
var _line_key: String = ""
var _line_severity: int = IncidentsScript.SEVERITY_WARNING


func _init() -> void:
	"""Size the per-bed condition columns once."""
	_phase.resize(Catalog.BED_COUNT * COND_COUNT)
	_ending_since.resize(Catalog.BED_COUNT * COND_COUNT)
	_blight_open.resize(Catalog.BED_COUNT)


func bind_incidents(incidents: IncidentsScript, remedy: Callable = Callable()) -> void:
	"""Raise and resolve the farm's incidents in `incidents`; `remedy(bed, cond)` says whether a job that
	answers a condition is on its bed (see INCIDENTS)."""
	_incidents = incidents
	_remedy = remedy


func collect_into(sim: SimScript, events: PackedInt32Array, spoiled_items: PackedInt32Array,
		out: PackedStringArray, levels: PackedByteArray = PackedByteArray()) -> void:
	"""Append every warning due now (see the header) to `out`, its feed level to `levels`, and its bed and
	incident serial to `targets` and `serials`; and resolve the incidents that are over."""
	_levels = levels
	targets.clear()
	serials.clear()
	var day: int = sim.absolute_day()
	for k: int in range(0, events.size() - 1, 2):
		_event_line(sim, events[k], events[k + 1], day, out)
	_frost_line(sim, day, out)
	_forecast_line(sim, out)
	for bed: int in Catalog.BED_COUNT:
		_bed_lines(sim, bed, day, out)
	for item: int in spoiled_items:
		_once(out, "spoiled:%d:%d" % [item, day], "Some %s in store has spoiled" % _name(item), NOTE)
	_resolve_frost(sim)


func _event_line(sim: SimScript, kind: int, bed: int, day: int, out: PackedStringArray) -> void:
	"""A line for one sim event."""
	var what: String = _bed_name(sim, bed)
	match kind:
		SimScript.EVENT_RIPENED:
			_once(out, "ripe:%d:%d" % [bed, day], "%s is ripe — harvest it within 2 days" % what, NOTE, bed)
		SimScript.EVENT_WITHERED:
			_once(out, "withered:%d:%d" % [bed, day], "%s has withered — clear it for compost" % what, WARNING, bed)
		SimScript.EVENT_BLIGHT:
			_blight(bed)
			_once(out, "blight:%d:%d" % [bed, day], "Blight on %s! Clear it before midnight or it spreads" % what,
				WARNING, bed)
		SimScript.EVENT_BLIGHT_SPREAD:
			_blight(bed)
			_once(out, "blight:%d:%d" % [bed, day], "Blight has spread to %s — clear the blighted beds" % what,
				WARNING, bed)
	_line_key = ""
	if kind == SimScript.EVENT_BLIGHT or kind == SimScript.EVENT_BLIGHT_SPREAD:
		_keep_blight_open(bed, what)


func _keep_blight_open(bed: int, what: String) -> void:
	"""A blighted bed's incident is open even when today's line was already said (blight back the same day after
	a Clear): raised quietly, with no second line."""
	if _incidents == null or _incidents.is_unresolved(_incidents.serial_of(_blight_key(bed))):
		return
	_incidents.raise(_blight_key(bed), NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING,
		"Blight on %s! Clear it before midnight or it spreads" % what, NoticesScript.TARGET_BED, bed, blight_state.bind(bed))


func _frost_line(sim: SimScript, day: int, out: PackedStringArray) -> void:
	"""Frost tonight, from ALERT_HOUR the day before, naming the night by its calendar date."""
	var hour: int = sim.calendar.calendar_at(sim.calendar.tick).hour
	if hour < Weather.ALERT_HOUR or not Weather.frost_tonight(sim.season(), sim.season_day()):
		return
	_line_key = FROST_KEY
	_line_severity = IncidentsScript.SEVERITY_WARNING
	_once(out, "frost:%d" % day, frost_text(sim.season(), sim.season_day()), WARNING)
	_line_key = ""


func _resolve_frost(sim: SimScript) -> void:
	"""Tonight's frost incident is over once no frost is due (the night's last frost hour gone)."""
	if _incidents == null or not _incidents.is_unresolved(_incidents.serial_of(FROST_KEY)):
		return
	var hour: int = sim.calendar.calendar_at(sim.calendar.tick).hour
	if not Weather.frost_due(sim.season(), sim.season_day(), hour):
		_incidents.resolve(FROST_KEY)


static func frost_text(season: int, season_day: int) -> String:
	"""'Frost tonight (Spring 4, 02:00–05:59)! …' for the night after this season day."""
	var night: Vector2i = Weather.next_day(season, season_day)
	return "Frost tonight (%s, %02d:00–%02d:59)! Cover growing beds (or raise them with earth) and harvest what is ripe" \
		% [CalendarScript.day_text(night.x, night.y), Weather.FROST_FIRST_HOUR, Weather.FROST_LAST_HOUR]


func _forecast_line(sim: SimScript, out: PackedStringArray) -> void:
	"""The real weather's disclosed forecast, once per event."""
	var event: int = sim.forecast_event()
	if event < 0 or event >= EVENT_NAMES.size():
		return
	@warning_ignore("integer_division") _once(out, "forecast:%d:%d" % [event, (sim.absolute_day() - 1) / SimClock.DAYS_PER_SEASON],
		"Forecast: %s coming in the next days" % EVENT_NAMES[event].to_lower(), NOTE)


func _bed_lines(sim: SimScript, bed: int, day: int, out: PackedStringArray) -> void:
	"""A bed's standing conditions: ripeness running out, dryness, waterlogging, worn-out soil."""
	var stage: int = sim.stage_of(bed)
	var what: String = _bed_name(sim, bed)
	if stage == SimScript.STAGE_RIPE and sim.ripe_hours_into(bed, _read):
		if _read.value >= LAST_DAY_HOURS:
			_once(out, "last:%d:%d" % [bed, day], "%s withers within a day — harvest now!" % what, WARNING, bed)
		elif _read.value >= GRACE_HOURS:
			_once(out, "grace:%d:%d" % [bed, day], "%s is losing 10%% a day — harvest it" % what, WARNING, bed)
	var growing: bool = stage == SimScript.STAGE_SPROUTING or stage == SimScript.STAGE_GROWING \
		or stage == SimScript.STAGE_BLIGHTED
	var band: int = sim.band_of(bed)
	var hour: int = _farm_hour(sim)
	_condition(out, bed, COND_DRY, growing, growing and band == SimScript.BAND_DRY, hour,
		"%s is too dry to grow — water it" % what, WARNING)
	_condition(out, bed, COND_WET, growing, growing and band == SimScript.BAND_WATERLOGGED, hour,
		"%s is waterlogged and has stopped growing — Drain it" % what, WARNING)
	var empty: bool = stage == SimScript.STAGE_EMPTY
	@warning_ignore("integer_division") _condition(out, bed, COND_WORN, empty, empty and sim.fertility_of(bed) < LOW_FERTILITY, hour,
		"Bed %d is worn out (fertility %d%%) — compost it or rest it fallow" % [bed + 1, sim.fertility_of(bed) / 100],
		NOTE)
	if _blight_open[bed] == 1 and stage != SimScript.STAGE_BLIGHTED:
		_blight_open[bed] = 0
		if _incidents != null:
			_incidents.resolve(_blight_key(bed))


static func _farm_hour(sim: SimScript) -> int:
	"""The farm's hour count since its calendar began (what REARM_HOURS is measured in)."""
	@warning_ignore("integer_division") return sim.calendar.tick / SimClock.TICKS_PER_HOUR


func _condition(out: PackedStringArray, bed: int, cond: int, applies: bool, present: bool, hour: int,
		text: String, level: int) -> void:
	"""Move one standing condition on (see STANDING CONDITIONS): announce it when it starts, re-arm it once it
	has stayed gone REARM_HOURS (at once when it no longer `applies`), and say nothing in between."""
	var i: int = bed * COND_COUNT + cond
	if present:
		if _phase[i] == PHASE_IDLE:
			_line_key = _condition_key(bed, cond)
			_line_severity = IncidentsScript.SEVERITY_ROUTINE if level == NOTE else IncidentsScript.SEVERITY_WARNING
			_say(out, text, level, bed)
			_line_key = ""
		_phase[i] = PHASE_ACTIVE
		return
	if _phase[i] == PHASE_ACTIVE:
		_phase[i] = PHASE_ENDING
		_ending_since[i] = hour
	if _phase[i] == PHASE_IDLE or (_phase[i] == PHASE_ENDING and applies and hour - _ending_since[i] < REARM_HOURS):
		return
	_phase[i] = PHASE_IDLE
	if _incidents != null:
		_incidents.resolve(_condition_key(bed, cond))


func condition_phase(bed: int, cond: int) -> int:
	"""A standing condition's PHASE_* on a bed."""
	return _phase[bed * COND_COUNT + cond]


func condition_state(bed: int, cond: int) -> int:
	"""A standing condition's incident state (the incident's watch): RECOVERING while ENDING, ASSIGNED with a
	remedy job on the bed, else needing a decision; RESOLVED once re-armed."""
	match condition_phase(bed, cond):
		PHASE_ENDING:
			return IncidentsScript.STATE_RECOVERING
		PHASE_ACTIVE:
			return IncidentsScript.STATE_ASSIGNED if _remedy_on(bed, cond) else IncidentsScript.STATE_NEEDS_DECISION
	return IncidentsScript.STATE_RESOLVED


func blight_state(bed: int) -> int:
	"""A blighted bed's incident state (its watch): ASSIGNED with a Clear on it, else needing a decision."""
	if _blight_open[bed] == 0:
		return IncidentsScript.STATE_RESOLVED
	return IncidentsScript.STATE_ASSIGNED if _remedy_on(bed, COND_BLIGHT) else IncidentsScript.STATE_NEEDS_DECISION


func _remedy_on(bed: int, cond: int) -> bool:
	"""Whether the farm says a job answering `cond` is on `bed`."""
	return _remedy.is_valid() and bool(_remedy.call(bed, cond))


static func _condition_key(bed: int, cond: int) -> String:
	"""The incident key of a standing condition on a bed: 'farm:wet:1'."""
	return "farm:%s:%d" % [COND_KEYS[cond], bed]


static func _blight_key(bed: int) -> String:
	"""The incident key of a blighted bed."""
	return "farm:blight:%d" % bed


func _blight(bed: int) -> void:
	"""The next blight line raises the bed's blight incident."""
	_blight_open[bed] = 1
	_line_key = _blight_key(bed)
	_line_severity = IncidentsScript.SEVERITY_WARNING


func _once(out: PackedStringArray, key: String, text: String, level: int, bed: int = -1) -> void:
	"""Append `text` (and its level and bed) the first time `key` is seen."""
	if _said.has(key):
		return
	_said[key] = true
	_say(out, text, level, bed)


func _say(out: PackedStringArray, text: String, level: int, bed: int) -> void:
	"""Append one line, its level, its bed and -- when it raises one (`_line_key`) -- its incident's serial."""
	out.append(text)
	_levels.append(level)
	targets.append(bed)
	var serial: int = IncidentsScript.NO_SERIAL
	if _incidents != null and not _line_key.is_empty():
		var watch: Callable = Callable()
		if _line_key.begins_with("farm:blight:"):
			watch = blight_state.bind(bed)
		elif bed >= 0:
			watch = condition_state.bind(bed, COND_KEYS.find(_line_key.get_slice(":", 1)))
		serial = _incidents.raise(_line_key, NoticesScript.SOURCE_FARM, _line_severity, text,
			NoticesScript.TARGET_BED if bed >= 0 else NoticesScript.TARGET_NONE, bed, watch)
	serials.append(serial)


func _bed_name(sim: SimScript, bed: int) -> String:
	"""'Bed 3 (carrot)', or 'Bed 3' with nothing standing -- the number keeps two wheat beds apart."""
	var item: int = sim.item_of(bed)
	if Catalog.is_item(item):
		return "Bed %d (%s)" % [bed + 1, Catalog.ITEM_LABELS[item].to_lower()]
	return "Bed %d" % (bed + 1)


static func _name(item: int) -> String:
	"""An item's name in lower case."""
	return Catalog.ITEM_LABELS[item].to_lower() if Catalog.is_item(item) else "food"

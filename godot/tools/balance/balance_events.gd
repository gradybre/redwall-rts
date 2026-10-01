extends RefCounted
## THE BALANCE HARNESS'S VILLAGE WATCH (decision 0571): the stores' material flows, the threats, the incidents, the
## rescues and the pauses the harness lifted. Measurement only, read every frame.
##
## MATERIALS. The stores keep no ledger of their own (tunnel_stores.gd), so each frame's change of each stock is
## booked: a rise as IN, a fall as OUT. Two movements of one stock inside one frame net out (a frame is 4 calendar
## ticks at 4x and 30 frames a second); the end-of-day stock is exact.
##
## INCIDENTS (demo_incidents.gd), three counts on stated bases:
##   occurrences      every raise that is not a merged repeat -- a new incident or one that came back (its `occurrences`);
##   first_by_source  each NEW incident (a serial issued) by its key's first part ("water", "woods", "farm", ...): the
##                    serials between the last look and the store's own next serial (read, never written);
##   critical         every critical raise or recurrence, from the store's own `incident_cue` (each autopauses).

const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const EventsScript := preload("res://demo/events/demo_events.gd")
const RescueScript := preload("res://demo/waterplay/rescue.gd")

const MATERIALS: Array[String] = ["wood", "planks", "stone", "earth", "water"]

var _stores: StoresScript = null
var _incidents: IncidentsScript = null
var _events: EventsScript = null
var _rescue: RescueScript = null
var _last: PackedInt64Array = PackedInt64Array()
var _in: PackedInt64Array = PackedInt64Array()
var _out: PackedInt64Array = PackedInt64Array()
var _now: PackedInt64Array = PackedInt64Array()
var _occurrences_seen: int = 0
var _next_serial: int = 1
var _threats_seen: int = 0
var _rescued_seen: int = 0
## This day's tallies.
var _occurrences: int = 0
var _first_by_source: Dictionary = {}
var _critical: int = 0
var _threats: Dictionary = {}
var _pauses_lifted: int = 0


func bind(stores: StoresScript, incidents: IncidentsScript, events: EventsScript, rescue: RescueScript) -> void:
	"""Watch these (any but the stores may be null: that part then reads nothing)."""
	_stores = stores
	_incidents = incidents
	_events = events
	_rescue = rescue
	for column: PackedInt64Array in [_last, _in, _out, _now]:
		column.resize(MATERIALS.size())
	_read_stock(_last)
	_occurrences_seen = incidents.occurrences if incidents != null else 0
	_threats_seen = events.count if events != null else 0
	_rescued_seen = rescue.rescued if rescue != null else 0
	_next_serial = _store_next_serial()
	if incidents != null:
		incidents.incident_cue.connect(_on_incident_cue)
	reset_day()


func _read_stock(out: PackedInt64Array) -> void:
	"""The five stocks now, milli-U, in MATERIALS order."""
	out[0] = _stores.wood_milli_u
	out[1] = _stores.plank_milli_u
	out[2] = _stores.stone_milli_u
	out[3] = _stores.earth_milli_u
	out[4] = _stores.water_milli_u


func _store_next_serial() -> int:
	"""The serial the incident store will issue next (its own counter, read; 1 with no store)."""
	return int(_incidents.get(&"_next_serial")) if _incidents != null else 1


func _on_incident_cue(cue: int, _serial: int, _severity: int) -> void:
	"""A critical incident was raised or came back (the store's own cue)."""
	if cue == IncidentsScript.CUE_CRITICAL_RAISED:
		_critical += 1


func frame() -> void:
	"""One frame: the stocks' moves, a new threat, new incidents."""
	_read_stock(_now)
	for m: int in MATERIALS.size():
		var delta: int = _now[m] - _last[m]
		if delta > 0:
			_in[m] += delta
		elif delta < 0:
			_out[m] -= delta
		_last[m] = _now[m]
	if _events != null and _events.count != _threats_seen:
		_threats_seen = _events.count
		var threat: String = EventsScript.KIND_NAMES[_events.kind] if _events.kind < EventsScript.KIND_NAMES.size() else "?"
		_threats[threat] = int(_threats.get(threat, 0)) + 1
	if _incidents != null and _incidents.occurrences != _occurrences_seen:
		_occurrences += _incidents.occurrences - _occurrences_seen
		_occurrences_seen = _incidents.occurrences
		scan_new_incidents()


func scan_new_incidents() -> void:
	"""Each serial issued since the last scan, by its key's first part ("?" for one whose row was already reused)."""
	var upto: int = _store_next_serial()
	while _next_serial < upto:
		var key: String = _incidents.key_of(_next_serial) if _incidents.row_of(_next_serial) >= 0 else ""
		var head: String = key.get_slice(":", 0) if not key.is_empty() else "?"
		_first_by_source[head] = int(_first_by_source.get(head, 0)) + 1
		_next_serial += 1


func lifted_pause() -> void:
	"""The harness lifted a pause (a critical incident's autopause) this frame."""
	_pauses_lifted += 1


func close_day() -> Dictionary:
	"""This day's flows (milli-U in and out, and each stock at the close), threats, incidents and rescues."""
	var materials: Dictionary = {}
	for m: int in MATERIALS.size():
		materials[MATERIALS[m]] = {"in": _in[m], "out": _out[m], "end": _last[m]}
	var rescued: int = _rescue.rescued if _rescue != null else 0
	var day: Dictionary = {"materials": materials,
		"incidents": {"occurrences": _occurrences, "first_by_source": _first_by_source.duplicate(),
			"critical": _critical, "pauses_lifted": _pauses_lifted},
		"threats": _threats.duplicate(), "rescues": rescued - _rescued_seen}
	_rescued_seen = rescued
	reset_day()
	return day


func reset_day() -> void:
	"""Zero the day's tallies."""
	_in.fill(0)
	_out.fill(0)
	_occurrences = 0
	_first_by_source.clear()
	_critical = 0
	_threats.clear()
	_pauses_lifted = 0

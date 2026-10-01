extends RefCounted
## THE NIGHT: residents sleep at home. Decision 0210 (the underground revamp's P4; Brendan's ruling 3, design §10:
## "residents sleep at home at night"). Presentation only: it moves the demo cast, nothing else.
##
## ON THE DEMO CALENDAR (demo_calendar.gd, a game hour every 2.5 demo seconds). Night runs from DUSK_HOUR to
## DAWN_HOUR: twelve game hours, 30 demo seconds (the calendar opens at 06:00 on spring 1, so the demo opens by day). The day is a minute at 1x, so a walk home across the village --
## 15 m at a mouse's 1 m/s -- takes six game hours: dusk is early enough that most are in bed by midnight. Whoever is
## still on the way home at dawn turns back to its parked job (`work_done`) rather than going to bed to get up.
##
## AT DUSK every resident not held by an emergency (the water's rescue, an evacuation: a task's `urgent()`), not in
## the water and not on a crossing is handed a sleep task (sleep_task.gd). What it was doing is PARKED on its resume
## queue (resident_brain.gd RESUMING, decision 0205): a tunnel job, a dig, a farm, woods or spoil job are kept by
## their own owners as for any order; a work order at a spot is kept here (WorkBack). Through the night anyone free
## (wandering on its own) is sent to bed too -- someone the player released, an evacuee home again. It is RESTING all
## night, so the crews' routine pick-ups pass it by. A direct order still wakes a resident: it does the order, and once
## free again goes back to bed. In the morning the sleep tasks end and each takes up the job it parked.
##
## BEDS (REQ-SET-132, bed_allocation.gd) are allocated whenever the beds or the rooms change, and at dusk. A resident
## whose bed's home is not reachable through the network sleeps as one without a bed. WITHOUT A BED (REQ-SET-133: "safe
## floor sleep in a reachable heated hall and ... a housing deficit alert") it sleeps on the hall's floor, and at dusk
## the feed says who has no bed (a warning). Without a hall (a test's village) it stays up.
##
## NO BED IS AN INCIDENT (decision 0331, review UX-011): with the demo's incidents bound (`set_incidents`), the dusk
## warning is also the incident "village:no_bed" (demo_incidents.gd) on the first resident without one -- each dusk
## that still finds someone bedless merges into it, counting the nights -- RESOLVED once everyone has a bed
## (`bed_state`, read at the allocation each dusk makes).
##
## THE ALARM: while a threat is under way (the works' events) sleepers stand up by their beds (sleep_task.gd).
##
## THE HEARTHS burn from HEARTH_FROM_HOUR to HEARTH_TO_HOUR -- evenings and nights (fixture_view.gd: their glow, their
## chimneys' smoke).

const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const AllocationScript := preload("res://demo/burrow/bed_allocation.gd")
const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NO_BED_KEY: String = "village:no_bed"
const NoticesScript := preload("res://demo/demo_notices.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")
const Layers := preload("res://demo/demo_layers.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const DUSK_HOUR: int = 18
const DAWN_HOUR: int = 6
## The hearths burn through the evening and the night, until breakfast (fixture_view.gd: their glow and smoke).
const HEARTH_FROM_HOUR: int = 17
const HEARTH_TO_HOUR: int = 7
## The hall's door, where the bedless go in: its steps (world_layout.gd POINTS).
const HALL_POI: StringName = &"hall_steps"
## The mattress's top over a home's floor (m): the staged bed's, measured by the fixtures' view (`set_bed_top`).
const DEFAULT_BED_TOP_M: float = 0.45
## A free resident is sent to bed again at most every RESEND_TICKS of calendar time (half a game hour: 1.25 demo
## seconds), so one whose way home fails is not planned again and again; an attempt that finds nowhere to send it
## counts too.
const RESEND_TICKS: int = 375
## The bedless go in at the hall's door side by side, this far apart (m), so none waits on another.
const HALL_SPACING_M: float = 0.9
const DUSK_NOTE: String = "Dusk: the village goes home to bed"
const NO_BED_WARNING: String = "No bed for %s: they sleep on the hall's floor. Fit beds in a burrow home (a home's panel)"
## What a bedless resident lacks, by its size (bed_allocation.gd SIZE_*).
const BED_WORDS: Array[String] = ["bed (too big for any bed)", "bed", "large bed (a big resident: fit one in a home's alcove)"]

## Per resident: its bed (room_fixtures.gd bed id; -1 none), and its size -- the beds it may have (bed_allocation.gd
## SIZE_*: a burrow bed, a large bed, none).
var bed_of: PackedInt32Array = PackedInt32Array()
var permitted: PackedByteArray = PackedByteArray()
var bed_top_m: float = DEFAULT_BED_TOP_M

var _graph: RefCounted = null
var _brains: Array[BrainScript] = []
var _names: PackedStringArray = PackedStringArray()
var _calendar: CalendarScript = null
var _notices: NoticesScript = null
var _incidents: IncidentsScript = null
var _alarm: Callable = Callable()
var _hall: Vector2 = Vector2.INF
var _night: bool = false
var _seen: Vector2i = Vector2i(-1, -1)
var _beds: PackedInt32Array = PackedInt32Array()
var _at_u: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()
## Per resident: the calendar tick it was last sent to bed at (see RESEND_TICKS).
var _sent_tick: PackedInt32Array = PackedInt32Array()


func configure(graph: RefCounted, brains: Array[BrainScript], names: PackedStringArray, heights_u: PackedInt32Array,
		calendar: CalendarScript, notices: NoticesScript) -> void:
	"""The night for these residents (by index; their names and heights in u) on this network's rooms, by this
	calendar, saying so in this feed (null: silent)."""
	_graph = graph
	_brains = brains
	_names = names
	_calendar = calendar
	_notices = notices
	bed_of.resize(brains.size())
	bed_of.fill(AllocationScript.NO_BED)
	permitted.resize(brains.size())
	for i in brains.size():
		permitted[i] = AllocationScript.size_of(heights_u[i])
	_at_u.resize(2 * brains.size())
	_sent_tick.resize(brains.size())
	_sent_tick.fill(-RESEND_TICKS)


func set_incidents(incidents: IncidentsScript) -> void:
	"""Raise the no-bed warning as an incident in `incidents` (see NO BED IS AN INCIDENT)."""
	_incidents = incidents


func bed_state() -> int:
	"""The no-bed incident's state: RESOLVED once everyone has a bed, else needing a decision."""
	return IncidentsScript.STATE_RESOLVED if first_bedless() < 0 else IncidentsScript.STATE_NEEDS_DECISION


func first_bedless() -> int:
	"""The first resident without a bed (-1: everyone has one)."""
	return bed_of.find(AllocationScript.NO_BED)


func set_hall(door: Vector2) -> void:
	"""Where the hall's door is (m): the bedless sleep inside (see WITHOUT A BED)."""
	_hall = door


func set_alarm(alarm: Callable) -> void:
	"""`alarm() -> bool`: whether a threat is under way (see THE ALARM)."""
	_alarm = alarm


static func is_night_hour(hour: int) -> bool:
	"""Whether `hour` (0..23) is night (see ON THE DEMO CALENDAR)."""
	return hour >= DUSK_HOUR or hour < DAWN_HOUR


static func is_hearth_hour(hour: int) -> bool:
	"""Whether the hearths burn at `hour` (0..23; see HEARTH_FROM_HOUR)."""
	return hour >= HEARTH_FROM_HOUR or hour < HEARTH_TO_HOUR


func is_night() -> bool:
	"""Whether it is night now."""
	return _night


func is_morning() -> bool:
	"""Whether the night is over (a sleep task's cue to get up)."""
	return not _night


func alarm() -> bool:
	"""Whether a threat is under way."""
	return _alarm.is_valid() and bool(_alarm.call())


func step() -> void:
	"""Once a frame: the beds, the night's turn, and everyone resting or not; at night, free residents to bed."""
	var fit: FixturesScript = _graph.fit
	var seen := Vector2i(fit.revision, _graph.rooms.revision)
	if seen != _seen:
		_seen = seen
		allocate()
	var night := is_night_hour(_calendar.now().hour)
	var dusk := night and not _night
	var dawn := _night and not night
	_night = night
	for b in _brains:
		b.resting = night
	if dusk:
		_at_dusk()
	elif dawn:
		_at_dawn()
	elif night:
		_send_the_free()


func _send_the_free() -> void:
	"""At night, anyone wandering on its own and not sent in the last RESEND_TICKS goes to bed."""
	for i in _brains.size():
		if _brains[i].order == BrainScript.ORDER_NONE and _calendar.tick - _sent_tick[i] >= RESEND_TICKS and may_send(i):
			send(i)


func _at_dusk() -> void:
	"""Beds allocated afresh; everyone who may go, to bed (their work parked); the feed told."""
	allocate()
	for i in _brains.size():
		if may_send(i):
			send(i)
	if _notices == null:
		return
	_notices.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, DUSK_NOTE)
	var bedless := bedless_names()
	if bedless.is_empty() or not _hall.is_finite():
		return
	if _incidents != null:
		_incidents.report(NO_BED_KEY, NoticesScript.SOURCE_CREW, IncidentsScript.SEVERITY_WARNING, NO_BED_WARNING % bedless,
			"", NoticesScript.TARGET_RESIDENT, first_bedless(), bed_state)
	else:
		_notices.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_WARNING, NO_BED_WARNING % bedless)


func _at_dawn() -> void:
	"""Anyone still on the way to bed turns back to the job it parked (or its own routine): its night is over."""
	for b in _brains:
		var task := b.task as SleepTaskScript
		if task != null and task.stage == SleepTaskScript.STAGE_GOING:
			b.work_done()


func allocate() -> void:
	"""REQ-SET-132 over the beds standing now (bed_allocation.gd), from where everyone is."""
	_graph.fit.beds_into(_graph, _beds)
	for i in _brains.size():
		_at_u[2 * i] = Rules.to_u(_brains[i].position.x)
		_at_u[2 * i + 1] = Rules.to_u(_brains[i].position.y)
	AllocationScript.allocate(bed_of, _at_u, permitted, _beds, _next)
	bed_of = _next.duplicate()


func may_send(i: int) -> bool:
	"""Whether resident `i` may be sent to bed now: not in the water or held by its rescue, not on a crossing, not
	in bed or on the way already, not in an emergency."""
	var b := _brains[i]
	if b.water_hold or b.in_water or b.state == BrainScript.State.CROSS:
		return false
	if b.task is SleepTaskScript:
		return false
	return b.task == null or not b.task.urgent()


func send(i: int) -> bool:
	"""Hand resident `i` its night: to its bed if it has one it can reach, else to the hall; a work order at a spot is
	parked first (WorkBack). False (nothing done) with neither."""
	_sent_tick[i] = _calendar.tick
	if bed_of[i] == AllocationScript.NO_BED and not _hall.is_finite():
		return false
	var b := _brains[i]
	var task := SleepTaskScript.new(is_morning, alarm)
	if not _bed_task(i, task):
		if not _hall.is_finite():
			return false
		task.to_hall(hall_spot(i))
	if b.order == BrainScript.ORDER_WORK and b.poi >= 0:
		b.remember_unfinished(UnfinishedScript.new(WorkBack.new(b.poi).take_back, "Work at %s" % _poi_name(b.poi)))
	b.order_task(task)
	return true


func _bed_task(i: int, task: SleepTaskScript) -> bool:
	"""Set `task` for resident `i`'s bed; false when it has none, or its home's middle cannot be reached."""
	var bed := bed_of[i]
	if bed == AllocationScript.NO_BED:
		return false
	var r := bed / FixturesScript.PLACES
	var f := bed % FixturesScript.PLACES
	var rooms: RoomsScript = _graph.rooms
	var middle: int = rooms.middle[r]
	var fit_class: int = _graph.walker_class(i, false)
	if fit_class == PathsScript.CLASS_NONE or _graph.paths.nearest_mouth(_graph, middle, fit_class) < 0:
		return false
	var at: Vector2i = _graph.fit.bed_middle_u(_graph, r, f)
	var face := RoomsScript.rotate_u(Vector2i(RoomsScript.fixture_field(RoomsScript.TEMPLATE_HOME, f, 3),
		RoomsScript.fixture_field(RoomsScript.TEMPLATE_HOME, f, 4)), rooms.turns[r])
	var large: bool = _graph.fit.kind_at(_graph, r, f) == RoomsScript.FIX_BIG_BED
	task.to_bed(room_name(r), middle, _graph.node_m(middle), Vector2(Rules.to_m(at.x), Rules.to_m(at.y)),
		atan2(float(face.x), float(face.y)), Layers.FLOOR_Y_M + bed_top_m,
		SleepTaskScript.LARGE_FOOT_M if large else SleepTaskScript.FOOT_M)
	return true


func hall_spot(i: int) -> Vector2:
	"""Where resident `i` goes in at the hall: the door, stepped along it by its place among the bedless (see
	HALL_SPACING_M)."""
	var k := 0
	for j in i:
		k += 1 if bed_of[j] == AllocationScript.NO_BED else 0
	return _hall + Vector2(HALL_SPACING_M * float(k % 5 - 2), 0.0)


static func room_name(r: int) -> String:
	"""A home's name: "Burrow home 2"."""
	return "%s %d" % [RoomsScript.NAMES[RoomsScript.TEMPLATE_HOME], r + 1]


func _poi_name(poi: int) -> String:
	"""A work spot's name, in words ("hall_steps" -> "hall steps")."""
	return String(_brains[0].space().poi_names[poi]).replace("_", " ")


func bedless_names() -> String:
	"""Who has no bed, by name ("the badger quarryman, the otter fisher"; "" when everyone has one)."""
	var out := PackedStringArray()
	for i in _brains.size():
		if bed_of[i] == AllocationScript.NO_BED:
			out.append(_names[i])
	return ", ".join(out)


func sleepers_of(r: int) -> String:
	"""Who has a bed in home row `r`, by name ("" nobody)."""
	var out := PackedStringArray()
	for i in _brains.size():
		if bed_of[i] != AllocationScript.NO_BED and bed_of[i] / FixturesScript.PLACES == r:
			out.append(_names[i])
	return ", ".join(out)


func hearth_burns() -> bool:
	"""Whether the hearths burn now (see THE HEARTHS)."""
	return is_hearth_hour(_calendar.now().hour)


func home_text(who: int, alone: bool) -> String:
	"""The party panel's line for resident `who` (demo_command.gd `add_skill_text`): its bed and its home's comfort,
	or that it has none -- alone, in full; in a list, only "no bed"."""
	var bed := bed_of[who]
	if bed == AllocationScript.NO_BED:
		return "No %s: sleeps on the hall's floor" % BED_WORDS[permitted[who]] if alone else "no bed"
	if not alone:
		return ""
	var r := bed / FixturesScript.PLACES
	var comfort: int = _graph.fit.comfort(_graph, r)
	return "Bed: %s · comfort %d (%s)" % [room_name(r), comfort, FixturesScript.comfort_word(comfort)]


## A work order at a spot, parked at dusk to come back to (see AT DUSK): a free slot at the same spot.
class WorkBack extends RefCounted:
	var poi: int = -1

	func _init(p_poi: int) -> void:
		"""The spot `p_poi`."""
		poi = p_poi

	func take_back(brain: RefCounted) -> bool:
		"""Send `brain` back to work at the spot, if a slot there is free."""
		var free: int = brain.space().free_slot(poi)
		if free < 0:
			return false
		brain.order_work(poi, free)
		return true

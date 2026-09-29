extends RefCounted
## The player's orders on finished tunnels. Decision 0196 (live demo). Presentation only.
##
## SELECTING. A left click that picks no resident picks the finished tunnel whose route or mouth is
## nearest the click (within PICK_M), and the tunnel panel shows it; residents stay selected, so a
## crew can be chosen first and a tunnel second.
##
## JOBS (tunnel_jobs.gd), from the tunnel panel's buttons, on the selected tunnel:
##   Widen, Clear the fall, Burrow home / Root cellar   the Foremole -- the selected mole, else the
##       village's mole -- with every other selected resident as its crew (tunnel_crew.gd).
##   Brace, Hang lanterns    the first selected resident who fits the bore, else the nearest one who
##       fits and is about their own business.
##   Pump out                likewise, but anyone (it is worked from the surface).
## A job already posted of the same kind is resumed with its progress. Refused, with the reason
## said: nothing selected; the tunnel unfinished, closed (for all but its repair), or busy with
## another job; the upgrade already done; no worker free; the demo stores short.
##
## CHAMBERS: "Burrow home" / "Root cellar" arm placement; the next left click on (or beside) the
## selected tunnel marks the room -- on the side of the tunnel clicked, or the other side when that
## one is refused (burrow_chambers.gd says why) -- and the Foremole goes to dig it. Esc disarms.
##
## CREWS: a dig confirmed with other residents selected besides the mole, or a right click on the
## entrance of a tunnel being dug with residents selected, puts them on its crew.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const JobTaskScript := preload("res://demo/tunnel/tunnel_job_task.gd")
const CrewTaskScript := preload("res://demo/tunnel/tunnel_crew_task.gd")
const HeapsScript := preload("res://demo/tunnel/tunnel_heaps.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")

const PICK_M: float = 0.9
const MOUTH_PICK_M: float = 1.2
## A chamber click must land this near the tunnel's route.
const CHAMBER_PICK_M: float = 3.5
## A crew's surface hands stand this far from the entrance, round it.
const HAND_M: float = 1.8
const HAND_TURNS: Array[float] = [0.7, -0.7, 1.4, -1.4, 2.1, -2.1, 0.0, 2.8]

const REFUSED: String = "Can't: %s"
const NO_TUNNEL: String = "select a finished tunnel first (click its mouth or route)"
const NOT_OPEN: String = "tunnel %d is not finished"
const CLOSED: String = "tunnel %d is closed — repair it first"
const BUSY: String = "tunnel %d already has a job: %s"
const DONE_ALREADY: Array[String] = ["", "tunnel %d is already wide", "tunnel %d is already braced",
	"tunnel %d is already lit", "tunnel %d is not flooded", "tunnel %d has no fall to clear", ""]
const NOTHING_TO_REPAIR: String = "tunnel %d needs no repair"
const NO_MOLE: String = "the Foremole is busy digging"
const NO_WORKER: String = "nobody who fits tunnel %d's bore is free"
const SHORT: String = "the demo stores are short (need wood %s, stone %s)"
const POSTED: String = "%s: %s is on the way to tunnel %d"
const CREW_JOINED: String = "%d joined the Foremole's crew on tunnel %d"
const PLACE_PROMPT: String = "Click along tunnel %d where the %s should open (Esc: cancel)"
const PLACE_FAR: String = "click on or beside tunnel %d"
const PLACE_CANCELLED: String = "Chamber placement cancelled"

var selected: int = -1
var selected_gen: int = 0
## The chamber kind being placed (ChambersScript.KIND_NONE while not placing).
var placing: int = ChambersScript.KIND_NONE

var _works: WorksScript = null
var _network: NetworkScript = null
var _space: CastSpaceScript = null
var _is_mole: PackedByteArray = PackedByteArray()
var _names: PackedStringArray = PackedStringArray()
var _bounds_u: Rect2i = Rect2i()
var _under_u: PackedInt32Array = PackedInt32Array()
var _cost: PackedInt32Array = PackedInt32Array([0, 0])
var _pick: PackedInt32Array = PackedInt32Array([0])


func _init(works: WorksScript, space: CastSpaceScript, is_mole: PackedByteArray, names: PackedStringArray,
		bounds_u: Rect2i) -> void:
	"""Orders through these works on this cast (`is_mole` and `names` by resident index)."""
	_works = works
	_space = space
	_network = space.tunnels
	_is_mole = is_mole
	_names = names
	_bounds_u = bounds_u


func set_under(under_u: PackedInt32Array) -> void:
	"""The buildings' footprint circles (x, radius, z in u) no chamber may be dug under."""
	_under_u = under_u


# --- selecting ------------------------------------------------------------------------------

func pick_into(at: Vector2, out: PackedInt32Array) -> bool:
	"""The finished tunnel nearest `at` within PICK_M of its route (or MOUTH_PICK_M of a mouth), into
	out[0]. False when none is that near."""
	var best_d := PICK_M
	var found := false
	for slot in Rules.MAX_TUNNELS:
		if not _network.is_open(slot):
			continue
		var d := _network.distance_to_route(slot, at)
		for end in 2:
			d = minf(d, _network.mouth(slot, end == 1).distance_to(at) - (MOUTH_PICK_M - PICK_M))
		if d <= best_d:
			best_d = d
			out[0] = slot
			found = true
	return found


func select_at(at: Vector2) -> bool:
	"""Select the finished tunnel under `at`. False (the selection kept) when none is there."""
	if not pick_into(at, _pick):
		return false
	select(_pick[0])
	return true


func select(slot: int) -> void:
	"""Select tunnel `slot`."""
	selected = slot
	selected_gen = _network.generation[slot]


func clear_selection() -> void:
	"""Select no tunnel."""
	selected = -1
	placing = ChambersScript.KIND_NONE


func has_selection() -> bool:
	"""Whether a tunnel that still exists is selected."""
	return selected >= 0 and _network.is_ref(selected, selected_gen)


# --- jobs -----------------------------------------------------------------------------------

func order(job: int, selection: PackedInt32Array) -> bool:
	"""Order `job` on the selected tunnel (see JOBS). False, with the reason said, when refused."""
	var reason := _job_refusal(job)
	if reason.is_empty() and not _choose_worker(job, selection):
		reason = NO_MOLE if _mole_job(job) else NO_WORKER % (selected + 1)
	if reason.is_empty():
		reason = _cost_refusal(job)
	if not reason.is_empty():
		_works.say(REFUSED % reason)
		return false
	_post(job, _works.brain(_pick[0]), selection)
	return true


static func _mole_job(job: int) -> bool:
	"""Whether the Foremole works this job (with a crew)."""
	return job == JobsScript.JOB_WIDEN or job == JobsScript.JOB_CLEAR or job == JobsScript.JOB_CHAMBER


func _job_refusal(job: int) -> String:
	"""Why `job` cannot be ordered on the selected tunnel ("" when it can, as far as the tunnel goes)."""
	if not has_selection():
		return NO_TUNNEL
	var slot := selected
	var n := slot + 1
	if not _network.is_open(slot):
		return NOT_OPEN % n
	var jobs := _works.jobs
	if jobs.has_job(slot) and jobs.kind[slot] != job:
		return BUSY % [n, jobs.label(slot)]
	var closed := _network.closed[slot]
	var repair := job == JobsScript.JOB_PUMP or job == JobsScript.JOB_CLEAR
	if closed != NetworkScript.CLOSED_NONE and not repair:
		return CLOSED % n
	return _already(job, slot)


func _already(job: int, slot: int) -> String:
	"""Why `job` is not needed on tunnel `slot` ("" when it is)."""
	var n := slot + 1
	var needless := false
	match job:
		JobsScript.JOB_WIDEN:
			needless = _network.bore[slot] == Rules.BORE_WIDE
		JobsScript.JOB_BRACE:
			needless = _network.braced[slot] == 1
		JobsScript.JOB_LANTERNS:
			needless = _network.lit[slot] == 1
		JobsScript.JOB_PUMP:
			needless = _network.closed[slot] != NetworkScript.CLOSED_FLOODED
		JobsScript.JOB_CLEAR:
			needless = _network.closed[slot] != NetworkScript.CLOSED_COLLAPSED
	return DONE_ALREADY[job] % n if needless else ""


func _cost_refusal(job: int) -> String:
	"""Why the stores cannot pay for `job` ("" when they can, or it was paid already)."""
	var jobs := _works.jobs
	if jobs.has_job(selected) and jobs.kind[selected] == job and jobs.paid[selected] == 1:
		return ""
	jobs.cost_into(selected, job, _cost)
	if _works.stores.can_pay(_cost[0], _cost[1]):
		return ""
	return SHORT % [StoresScript.units_text(_cost[0]), StoresScript.units_text(_cost[1])]


func _choose_worker(job: int, selection: PackedInt32Array) -> bool:
	"""The worker for `job`, into _pick[0]: the Foremole for mole work, else the first selected resident
	who can do it, else the nearest free one (see JOBS). False when nobody can."""
	if _mole_job(job):
		return mole_into(selection, _pick)
	var below := job != JobsScript.JOB_PUMP
	for i in selection:
		if _can_work(i, below, false):
			_pick[0] = i
			return true
	return _nearest_free(below)


func _can_work(i: int, below: bool, free_only: bool) -> bool:
	"""Whether resident `i` can take a job on the selected tunnel (fitting its bore when `below`)."""
	var b := _works.brain(i)
	if b.order == BrainScript.ORDER_DIG or b.underground:
		return false
	if free_only and b.order != BrainScript.ORDER_NONE:
		return false
	return not below or _network.fits_tunnel(i, selected, false)


func _nearest_free(below: bool) -> bool:
	"""The free resident nearest the selected tunnel's entrance who can work it, into _pick[0]."""
	var at := _network.mouth(selected, false)
	var best := INF
	for i in _works.resident_count():
		if _is_mole[i] == 1 or not _can_work(i, below, true):
			continue
		var d := _works.brain(i).position.distance_to(at)
		if d < best:
			best = d
			_pick[0] = i
	return best < INF


func mole_into(selection: PackedInt32Array, out: PackedInt32Array) -> bool:
	"""The Foremole into out[0]: the selected mole, else the village's first; false when every mole is
	digging a tunnel."""
	for i in selection:
		if _free_mole(i):
			out[0] = i
			return true
	for i in _works.resident_count():
		if _free_mole(i):
			out[0] = i
			return true
	return false


func _free_mole(i: int) -> bool:
	"""Whether resident `i` is a mole not digging a tunnel."""
	return _is_mole[i] == 1 and _works.brain(i).order != BrainScript.ORDER_DIG


func _post(job: int, worker: BrainScript, selection: PackedInt32Array) -> void:
	"""Post `job` on the selected tunnel for `worker`, send it, and put the rest of the selection on
	the Foremole's crew for mole work."""
	var slot := selected
	var jobs := _works.jobs
	var span := _span_u(job, slot)
	var resumed := jobs.has_job(slot) and jobs.kind[slot] == job
	jobs.post(slot, job, worker.index, span.x, span.y)
	if job == JobsScript.JOB_WIDEN and not resumed:
		_regrade_heaps(slot)
	worker.order_task(JobTaskScript.new(jobs, _network, slot))
	_works.say(POSTED % [JobsScript.NAMES[job], _names[worker.index], slot + 1])
	if _mole_job(job):
		add_crew(slot, selection, worker.index)


func _span_u(job: int, slot: int) -> Vector2i:
	"""The stretch of tunnel `slot` a job works along (from, to) in u."""
	if job == JobsScript.JOB_CLEAR:
		return Vector2i(_network.closed_from_u[slot], _network.closed_to_u[slot])
	if job == JobsScript.JOB_PUMP:
		return Vector2i(0, 0)
	return Vector2i(0, _network.length_u[slot])


func _regrade_heaps(slot: int) -> void:
	"""A widening accepted: re-place the tunnel's heaps at the size they will reach with its spoil."""
	var extra := PackedInt64Array()
	extra.resize(NetworkScript.P_SIZE)
	_network.progress_into(slot, _network.pass_ticks(slot, Rules.WIDE_EXTRA_QUANTA), Rules.WIDE_EXTRA_QUANTA, extra)
	HeapsScript.clear(_network, _space, slot)
	HeapsScript.place(_network, _space, slot, extra[NetworkScript.P_SPOIL])


# --- crews ----------------------------------------------------------------------------------

func add_crew(slot: int, members: PackedInt32Array, lead: int) -> int:
	"""Put `members` (all but `lead` and anyone digging) on tunnel `slot`'s crew, each sent to its post.
	Returns how many joined (the crew holds at most CrewScript.MAX_BUILDERS with the Foremole)."""
	var joined := 0
	var taken := PackedVector2Array()
	for i in members:
		var b := _works.brain(i)
		if i == lead or b.order == BrainScript.ORDER_DIG or not _works.crew.join(i, slot):
			continue
		var fits := _network.fits_tunnel(i, slot, false)
		var spot := _hand_spot(slot, b.radius, taken)
		taken.append(spot)
		b.order_task(CrewTaskScript.new(_works.crew, _network, slot, fits, spot, _works.crew_active, _works.crew_along))
		joined += 1
	if joined > 0:
		_works.say(CREW_JOINED % [joined, slot + 1])
		_works.say(CrewScript.LINE_CREW)
	return joined


func _hand_spot(slot: int, body: float, taken: PackedVector2Array) -> Vector2:
	"""A spot HAND_M from tunnel `slot`'s entrance for a surface hand: the first of HAND_TURNS round the
	way out that is inside the village, clear of obstacles, holes and the spots already taken."""
	var at := _network.mouth(slot, false)
	var outward := -_network.direction_at(slot, 0.0)
	for turn in HAND_TURNS:
		var spot := at + outward.rotated(turn) * HAND_M
		if _hand_spot_clear(spot, body, taken):
			return spot
	return at + outward * HAND_M


func _hand_spot_clear(spot: Vector2, body: float, taken: PackedVector2Array) -> bool:
	"""Whether a surface hand of radius `body` may stand at `spot`."""
	if not _space.bounds.grow(-body).has_point(spot) or _space.obstacle_clearance(spot) < body + 0.1:
		return false
	if _space.on_mouth(spot, body):
		return false
	for other in taken:
		if other.distance_to(spot) < 2.0 * body + 0.3:
			return false
	return true


# --- chambers -------------------------------------------------------------------------------

func begin_chamber(kind: int, selection: PackedInt32Array) -> bool:
	"""Arm placement of a chamber of `kind` on the selected tunnel (see CHAMBERS). False, said, when
	refused."""
	var reason := _job_refusal(JobsScript.JOB_CHAMBER)
	if reason.is_empty() and not mole_into(selection, _pick):
		reason = NO_MOLE
	if not reason.is_empty():
		_works.say(REFUSED % reason)
		return false
	placing = kind
	_works.say(PLACE_PROMPT % [selected + 1, ChambersScript.KIND_NAMES[kind].to_lower()])
	return true


func cancel_chamber() -> void:
	"""Stop placing a chamber."""
	if placing == ChambersScript.KIND_NONE:
		return
	placing = ChambersScript.KIND_NONE
	_works.say(PLACE_CANCELLED)


func place_chamber(at: Vector2, selection: PackedInt32Array) -> bool:
	"""Place the armed chamber where the tunnel passes nearest `at`, and send the Foremole to dig it.
	False, said, when refused (placement stays armed)."""
	var slot := selected
	if not has_selection() or _network.distance_to_route(slot, at) > CHAMBER_PICK_M:
		_works.say(REFUSED % (PLACE_FAR % (selected + 1)))
		return false
	var along := clampi(Rules.to_u(_network.along_of(slot, at)), Rules.QUANTUM_U, _network.length_u[slot] - Rules.QUANTUM_U)
	var centre := Vector2i.ZERO
	var reason := ChambersScript.REFUSE_NONE
	for side in _sides(slot, along, at):
		centre = ChambersScript.centre_for(_network, slot, along, side)
		reason = _works.chambers.refusal(_network, centre, _bounds_u, _under_u)
		if reason == ChambersScript.REFUSE_NONE:
			break
	if reason != ChambersScript.REFUSE_NONE:
		_works.say(REFUSED % ChambersScript.reason_text(reason))
		return false
	return _dig_chamber(slot, along, centre, selection)


func _sides(slot: int, along: int, at: Vector2) -> PackedInt32Array:
	"""The side of the tunnel clicked first (+1 right, -1 left of the way to the exit), then the other."""
	var on := _network.point_at(slot, Rules.to_m(along))
	var ahead := _network.direction_at(slot, Rules.to_m(along))
	var cross := ahead.x * (at.y - on.y) - ahead.y * (at.x - on.x)
	return PackedInt32Array([1, -1]) if cross >= 0.0 else PackedInt32Array([-1, 1])


func _dig_chamber(slot: int, along: int, centre: Vector2i, selection: PackedInt32Array) -> bool:
	"""Plan the chamber and post its job for the Foremole (with the rest of the selection as crew)."""
	var ref := PackedInt32Array([0, 0])
	if not mole_into(selection, _pick) or not _works.chambers.add_into(placing, _network, slot, along, centre, ref):
		_works.say(REFUSED % ChambersScript.reason_text(ChambersScript.REFUSE_FULL))
		return false
	var kind := _works.ground.type_at(centre.x, centre.y)
	_works.jobs.post_chamber(slot, _pick[0], ref[0], along, kind)
	placing = ChambersScript.KIND_NONE
	var mole := _works.brain(_pick[0])
	mole.order_task(JobTaskScript.new(_works.jobs, _network, slot))
	_works.say(POSTED % [ChambersScript.KIND_NAMES[_works.chambers.kind[ref[0]]], _names[mole.index], slot + 1])
	add_crew(slot, selection, mole.index)
	return true

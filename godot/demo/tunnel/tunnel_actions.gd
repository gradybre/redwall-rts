extends RefCounted
## The player's orders on finished tunnels. Decisions 0196 (live demo) and 0208 (the network: a "tunnel"
## here is one SEGMENT of it, numbered slot + 1). Presentation only.
##
## SELECTING. A left click that picks no resident picks the finished segment whose route or mouth is
## nearest the click (within PICK_M), and the tunnel panel shows it; residents stay selected, so a
## crew can be chosen first and a tunnel second.
##
## JOBS (tunnel_jobs.gd), from the tunnel panel's buttons, on the selected segment:
##   Widen, Clear the fall   the Foremole -- the first selected resident who
##       can dig (anybeast who fits a bore; dig_skills.gd), else the village's most skilled free digger --
##       with every other selected resident as its crew (tunnel_crew.gd).
##   Brace, Hang lanterns    the first selected resident who fits the bore, else the nearest one who
##       fits and is about their own business.
##   Pump out                likewise, but anyone (it is worked from the surface).
## A job already posted of the same kind is resumed with its progress. Refused, with the reason
## said: nothing selected; the tunnel unfinished, closed (for all but its repair), or busy with
## another job; the upgrade already done; no worker free; the demo stores short.
##
## ROOMS are not a tunnel's job (decision 0209): burrow homes and root cellars are placed with the Dig tool's
## room tool (room_tool.gd) as their own structures, and a room's segments are never selected as a tunnel.
##
## CREWS: a dig confirmed with other residents selected besides the mole, or a right click on the
## entrance of a tunnel being dug with residents selected, puts them on its crew.
##
## THE DECISION (decision 0332, review F33/F44): `refusal` -- the tunnel's state, the worker (into `_pick[0]`) and the
## stores, in that order -- is the ONE check both `order` and the panel's action cards (`preview_into`) run, so a
## card's refusal is the order's, word for word, and its worker the one sent.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const JobTaskScript := preload("res://demo/tunnel/tunnel_job_task.gd")
const CrewTaskScript := preload("res://demo/tunnel/tunnel_crew_task.gd")
const HeapsScript := preload("res://demo/tunnel/tunnel_heaps.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")

const PICK_M: float = 0.9
const MOUTH_PICK_M: float = 1.2
## A crew's surface hands stand this far from the entrance, round it.
const HAND_M: float = 1.8
const HAND_TURNS: Array[float] = [0.7, -0.7, 1.4, -1.4, 2.1, -2.1, 0.0, 2.8]

const REFUSED: String = "Can't: %s"
const NO_TUNNEL: String = "select a finished tunnel first (click its mouth or route)"
const NOT_OPEN: String = "tunnel %d is not finished"
const CLOSED: String = "tunnel %d is closed — repair it first"
const BUSY: String = "tunnel %d already has a job: %s"
const DONE_ALREADY: Array[String] = ["", "tunnel %d is already wide", "tunnel %d is already braced",
	"tunnel %d is already lit", "tunnel %d is not flooded", "tunnel %d has no fall to clear"]
const NOTHING_TO_REPAIR: String = "tunnel %d needs no repair"
const NO_MOLE: String = "nobody free who fits a bore can dig it"
const NO_WORKER: String = "nobody who fits tunnel %d's bore is free"
const SHORT: String = "the demo stores are short (need wood %s, stone %s)"
const POSTED: String = "%s: %s is on the way to tunnel %d"
## THE DECISION's checks, and the codes an action card gives them.
const REFUSED_BY_NONE: int = 0
const REFUSED_BY_TUNNEL: int = 1
const REFUSED_BY_WORKER: int = 2
const REFUSED_BY_STORES: int = 3
const REFUSED_CODES: Array[String] = ["", "TUNNEL", "NO_WORKER", "STORES_SHORT"]
## Each job's result, need, and the card's words (by tunnel_jobs.gd JOB_*).
const RESULTS: Array[String] = ["", "Widened: otters and the badger fit, and loads go through", "Braced: no seep, no roof fall",
	"Lit: a lantern every 4 m; walking below is quicker", "Pumped out: the tunnel opens again",
	"The fall cleared: the tunnel opens again"]
const NEEDS: Array[String] = ["", "a finished, open tunnel; a free digger (and any crew selected)",
	"a finished, open tunnel; a resident who fits its bore", "a finished, open tunnel; a resident who fits its bore",
	"a flooded tunnel; anyone (worked from the surface)", "a fallen roof; a free digger (and any crew selected)"]
const PAID_NOTE: String = " (materials paid already)"
const MOLE_NOTE: String = ", plus the walk (one digger's pace; a crew is quicker)"
const FIRST_DIGGER: String = "who can dig"
const FIRST_FITS: String = "who fits the bore"
const MOST_SKILLED: String = "the village's most skilled free digger"
const NEAREST_FREE: String = "the nearest free resident who fits the bore"
const FIX_SELECT: String = "click a finished tunnel's mouth or route"
const FIX_CLOSED: String = "Repair it first (Pump out / Clear the fall)"
const FIX_DIGGER: String = "select a mole, mouse or squirrel who is not digging"
const FIX_WORKER: String = "select a mouse, mole or squirrel who is free"
const FIX_STORES: String = "Woods ▸ Haul logs or Gather deadfall for wood; digging through rock brings stone"
const CREW_JOINED: String = "%d joined the Foremole's crew on tunnel %d"

var selected: int = -1
var selected_gen: int = 0
## Which check the last `refusal` stopped at (REFUSED_BY_*; REFUSED_BY_NONE when it allowed the job).
var refused_by: int = 0

var _works: WorksScript = null
var _network: GraphScript = null
var _space: CastSpaceScript = null
## Per resident: 1 when its body fits a standard bore (it can dig; decision 0208).
var _can_dig: PackedByteArray = PackedByteArray()
var _names: PackedStringArray = PackedStringArray()
var _bounds_u: Rect2i = Rect2i()
var _under_u: PackedInt32Array = PackedInt32Array()
var _cost: PackedInt32Array = PackedInt32Array([0, 0])
var _pick: PackedInt32Array = PackedInt32Array([0])


func _init(works: WorksScript, space: CastSpaceScript, can_dig: PackedByteArray, names: PackedStringArray,
		bounds_u: Rect2i) -> void:
	"""Orders through these works on this cast (`can_dig` and `names` by resident index)."""
	_works = works
	_space = space
	_network = space.tunnels
	_can_dig = can_dig
	_names = names
	_bounds_u = bounds_u


func set_under(under_u: PackedInt32Array) -> void:
	"""The buildings' footprint circles (x, radius, z in u)."""
	_under_u = under_u


# --- selecting ------------------------------------------------------------------------------

func pick_into(at: Vector2, out: PackedInt32Array, level: int = Rules.TOP_LEVEL) -> bool:
	"""The finished segment on `level` nearest `at` within PICK_M of its route (or MOUTH_PICK_M of a mouth it opens
	at), into out[0] -- a link down is on both levels it joins (decision 0212). False when none is that near."""
	var best_d := PICK_M
	var found := false
	for slot in Rules.MAX_SEGMENTS:
		if not _network.is_open(slot) or _network.seg_room[slot] >= 0 or not on_level(slot, level):
			continue
		var d := _network.distance_to_route(slot, at)
		for end in 2:
			if _network.mouth_of_end(slot, end == 1) >= 0:
				d = minf(d, _network.end_at(slot, end == 1).distance_to(at) - (MOUTH_PICK_M - PICK_M))
		if d <= best_d:
			best_d = d
			out[0] = slot
			found = true
	return found


func on_level(slot: int, level: int) -> bool:
	"""Whether segment `slot` is seen on `level`: its own, or -- a link -- either it joins."""
	var own: int = _network.seg_level[slot]
	return own == level or (_network.seg_kind[slot] == GraphScript.SEG_LINK and own + 1 == level)


func select_at(at: Vector2, level: int = Rules.TOP_LEVEL) -> bool:
	"""Select the finished tunnel on `level` under `at`. False (the selection kept) when none is there."""
	if not pick_into(at, _pick, level):
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


func has_selection() -> bool:
	"""Whether a tunnel that still exists is selected."""
	return selected >= 0 and _network.is_ref(selected, selected_gen)


# --- jobs -----------------------------------------------------------------------------------

func order(job: int, selection: PackedInt32Array) -> bool:
	"""Order `job` on the selected tunnel (see JOBS). False, with the reason said, when refused."""
	var reason := refusal(job, selection)
	if not reason.is_empty():
		_works.tell(REFUSED % reason)
		return false
	_post(job, _works.brain(_pick[0]), selection)
	return true


func refusal(job: int, selection: PackedInt32Array) -> String:
	"""Why `job` may not be ordered on the selected tunnel with `selection` ("" when it may; the worker is then in
	`_pick[0]`) -- see THE DECISION. `refused_by` says which check refused (REFUSED_BY_*). Changes nothing."""
	refused_by = REFUSED_BY_TUNNEL
	var reason := _job_refusal(job)
	if not reason.is_empty():
		return reason
	refused_by = REFUSED_BY_WORKER
	if not _choose_worker(job, selection):
		return NO_MOLE if _mole_job(job) else NO_WORKER % (selected + 1)
	refused_by = REFUSED_BY_STORES
	reason = _cost_refusal(job)
	refused_by = REFUSED_BY_NONE if reason.is_empty() else REFUSED_BY_STORES
	return reason


func preview_into(card: CardScript, job: int, selection: PackedInt32Array) -> void:
	"""The action card for `job` on the selected tunnel with `selection` (decision 0332): `refusal`'s answer, the
	job's result, its cost from the stores (have / need; nothing once paid), its work left and who goes."""
	var n := selected + 1
	card.reset("%s tunnel %d" % [JobsScript.NAMES[job], n] if has_selection() else JobsScript.NAMES[job])
	card.result = RESULTS[job]
	card.prerequisites.append(NEEDS[job])
	var reason := refusal(job, selection)
	if has_selection() and _network.is_open(selected):
		_cost_rows(card, job)
	if not reason.is_empty():
		card.refuse(REFUSED_CODES[refused_by], reason, _fix_for(job))
		return
	var jobs := _works.jobs
	var done := jobs.done_ticks(selected) if jobs.has_job(selected) and jobs.kind[selected] == job else 0
	card.work_usec = maxi(jobs.ticks_for(selected, job) - done, 0) * Rules.USEC_PER_SECOND / Rules.TICKS_PER_SECOND
	if _mole_job(job):
		card.work_note = MOLE_NOTE
	_preview_who(card, job, selection)
	card.members = members_line(job, selection)


func members_line(job: int, selection: PackedInt32Array) -> String:
	"""A group order's preview, member by member (decision 0411, review UX-001): who of the selection could work `job`
	on the selected tunnel -- the Foremole's digging or the bore's fit, `_choose_worker`'s own tests -- and why not the
	others. (A mole job's other members join its crew: they are shown as able when they could dig it.)"""
	if selection.size() <= 1:
		return ""
	var names := PackedStringArray()
	var why := PackedStringArray()
	for i: int in selection:
		names.append(_names[i])
		why.append(member_refusal(job, i))
	return CardScript.each_member(names, why)


func member_refusal(job: int, i: int) -> String:
	"""Why resident `i` could not work `job` on the selected tunnel, in the work board's words (demo/work/work_ids.gd;
	"" when it could): `_choose_worker`'s own tests -- a digger for a mole job, else one not below who fits the bore."""
	var b := _works.brain(i)
	if b.order == BrainScript.ORDER_DIG:
		return WorkIds.DIGGING
	if _mole_job(job):
		return "" if _can_dig[i] == 1 else WorkIds.NOT_A_DIGGER
	if b.underground:
		return WorkIds.BELOW
	if job != JobsScript.JOB_PUMP and not _network.fits_tunnel(i, selected, false):
		return WorkIds.NOT_FITTING
	return ""


func _cost_rows(card: CardScript, job: int) -> void:
	"""The job's cost rows, as `_cost_refusal` weighs them: wood and stone the stores hold against the job's price
	(none for a job whose inputs were paid already, or that costs nothing)."""
	var jobs := _works.jobs
	if jobs.has_job(selected) and jobs.kind[selected] == job and jobs.paid[selected] == 1:
		card.result += PAID_NOTE
		return
	jobs.cost_into(selected, job, _cost)
	if _cost[0] > 0:
		card.add_cost("Wood", _works.stores.wood_milli_u, _cost[0])
	if _cost[1] > 0:
		card.add_cost("Stone", _works.stores.stone_milli_u, _cost[1])


func _preview_who(card: CardScript, job: int, selection: PackedInt32Array) -> void:
	"""Who `order` sends (the worker `refusal` chose) in the one command grammar, and a mole job's crew."""
	var who := _pick[0]
	var from_selection := selection.has(who)
	card.worker = who
	if _mole_job(job):
		var crew := crew_joining(selected, selection, who)
		var lead := CardScript.assign_first(_names[who], selection.size(), FIRST_DIGGER) if from_selection \
			else CardScript.assign_village(_names[who], MOST_SKILLED)
		card.who = lead if crew == 0 else "%s + %d on the crew" % [lead, crew]
	elif from_selection:
		card.who = CardScript.assign_first(_names[who], selection.size(), FIRST_FITS)
	else:
		card.who = CardScript.assign_village(_names[who], NEAREST_FREE)


func crew_joining(slot: int, members: PackedInt32Array, lead: int) -> int:
	"""How many of `members` `add_crew` would put on tunnel `slot`'s crew under `lead`: all but the lead, anyone
	digging and anyone on it already, up to the crew's room (tunnel_crew.gd `join`)."""
	var room := CrewScript.MAX_BUILDERS - 1 - _works.crew.count_of(slot)
	var n := 0
	for i: int in members:
		if i != lead and _works.brain(i).order != BrainScript.ORDER_DIG and _works.crew.member_site[i] != slot:
			n += 1
	return clampi(n, 0, maxi(room, 0))


func _fix_for(job: int) -> String:
	"""How to put the last refusal right (see FIXES)."""
	if refused_by == REFUSED_BY_TUNNEL and has_selection() and _network.is_open(selected) \
			and _network.closed[selected] != GraphScript.CLOSED_NONE and job != JobsScript.JOB_PUMP and job != JobsScript.JOB_CLEAR:
		return FIX_CLOSED
	if refused_by == REFUSED_BY_TUNNEL and not has_selection():
		return FIX_SELECT
	if refused_by == REFUSED_BY_WORKER:
		return FIX_DIGGER if _mole_job(job) else FIX_WORKER
	if refused_by == REFUSED_BY_STORES:
		return FIX_STORES
	return ""


static func _mole_job(job: int) -> bool:
	"""Whether the Foremole works this job (with a crew)."""
	return job == JobsScript.JOB_WIDEN or job == JobsScript.JOB_CLEAR


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
	if closed != GraphScript.CLOSED_NONE and not repair:
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
			needless = _network.closed[slot] != GraphScript.CLOSED_FLOODED
		JobsScript.JOB_CLEAR:
			needless = _network.closed[slot] != GraphScript.CLOSED_COLLAPSED
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
	if free_only and (b.order != BrainScript.ORDER_NONE or b.resting):
		return false
	return not below or _network.fits_tunnel(i, selected, false)


func _nearest_free(below: bool) -> bool:
	"""The free resident nearest the selected segment's way in who can work it (skilled diggers are kept for
	digging), into _pick[0]."""
	var at := _network.way_in_m(_network.piece[selected])
	var best := INF
	for i in _works.resident_count():
		if _works.crew.skills.level_of(i) > 0 or not _can_work(i, below, true):
			continue
		var d := _works.brain(i).position.distance_to(at)
		if d < best:
			best = d
			_pick[0] = i
	return best < INF


func mole_into(selection: PackedInt32Array, out: PackedInt32Array) -> bool:
	"""The Foremole into out[0]: the first selected resident who can dig and is free, else the village's
	most skilled free digger (the lower index on a tie); false when every digger is busy digging."""
	for i in selection:
		if _free_digger(i):
			out[0] = i
			return true
	var best := -1
	for i in _works.resident_count():
		if _free_digger(i) and (best < 0 or _works.crew.skills.level_of(i) > _works.crew.skills.level_of(best)):
			best = i
	out[0] = best
	return best >= 0


func _free_digger(i: int) -> bool:
	"""Whether resident `i` can dig (fits a bore) and is not digging a tunnel."""
	return _can_dig[i] == 1 and _works.brain(i).order != BrainScript.ORDER_DIG


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
	_works.tell(POSTED % [JobsScript.NAMES[job], _names[worker.index], slot + 1])
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
	"""A widening accepted: grow the heap at the segment's spoil mouth to the size it will reach with its
	spoil."""
	var extra := PackedInt64Array()
	extra.resize(GraphScript.P_SIZE)
	_network.progress_into(slot, _network.pass_ticks(slot, Rules.WIDE_EXTRA_QUANTA), Rules.WIDE_EXTRA_QUANTA, extra)
	if _network.is_mouth(_network.spoil_mouth[slot]):
		HeapsScript.place(_network, _space, _network.spoil_mouth[slot], extra[GraphScript.P_SPOIL])


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
		_works.tell(CREW_JOINED % [joined, slot + 1])
		_works.speak(CrewScript.SAY_CREW, lead)
	return joined


func _hand_spot(slot: int, body: float, taken: PackedVector2Array) -> Vector2:
	"""A spot HAND_M from the way into segment `slot`'s piece (its entrance, or the mouth it spoils at) for
	a surface hand: the first of HAND_TURNS round the way out that is inside the village, clear of
	obstacles, holes and the spots already taken."""
	var at := _network.way_in_m(_network.piece[slot])
	var outward := -_network.direction_at(slot, 0.0)
	var m := _network.mouth_of_end(slot, false)
	if m < 0 and _network.is_mouth(_network.piece_mouth[_network.piece[slot]]):
		outward = -_network.mouth_inward(_network.piece_mouth[_network.piece[slot]])
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

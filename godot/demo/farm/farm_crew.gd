extends RefCounted
## The demo farm's hands: residents carrying out the job board. Decision 0196. Presentation of the
## work (walking, carrying, the work clip) goes through the cast's own brains; the EFFECT of each
## piece of work is a farm_sim.gd / farm_pantry.gd / farm_tunnels.gd call at the step it belongs to.
##
## WHO WORKS. A job the player orders with residents selected goes to the nearest of them, whatever
## they were doing. Any job left on the board -- queued from the bed panel with nobody selected, or
## raised by the farm itself -- is picked up by the ROUTINE crew (CREW_KEYS: the fieldworker and the
## gatherer) when one of them is wandering on its own: their daily routine now includes the farm.
## The farm raises REQ-SET-073's harvest job for every ripe bed and REQ-SET-085's clearing job for
## every withered one; everything else waits for the player.
##
## HOW A STEP RUNS. A walk issues `order_move()` (or `order_carry()`, the carry walk, for a harvest
## to the store and water or spoil to a bed) to a standable spot beside its target, facing it, and
## is done when the brain holds there. A work step plays the work clip in place for its WU
## (farm_jobs.gd) of the cast's time, applying its effect at the end -- except sowing's seed
## commitment, which is REQ-SET-071's productive START. A resident the player orders elsewhere (or
## releases) drops the job back on the board where it had got to, load and all; a step that cannot
## be done any more (the crop withered on the way, a spot out of reach) ends the job with a notice.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const TunnelsScript := preload("res://demo/farm/farm_tunnels.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const FarmCellars := preload("res://demo/farm/farm_cellars.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const FarmCard := preload("res://demo/farm/farm_card.gd")
const InterruptScript := preload("res://demo/control/work_interrupt.gd")

## THE DECISION (decision 0331, review F33/F44). `decide` answers what an order of a verb on a bed would do now --
## its refusal, the same job already on the board, and who takes it -- and is the ONE function both `order` and the
## bed panel's action card (`preview_into`) read, so the card names the resident the order then sends.
class Decision:
	## The refusal (empty: the order goes ahead).
	var code: StringName = &""
	## The same job already on the board (-1: a new one is opened).
	var row: int = -1
	## Who takes it now (-1: it waits for the field crew).
	var worker: int = -1
	## The job is already under way with `worker` (nothing changes).
	var busy: bool = false
	## Selected residents free to take it, and how many are selected.
	var free: int = 0
	var selected: int = 0


## The residents whose routine includes farm work.
const CREW_KEYS: Array[StringName] = [&"mouse_fieldworker", &"squirrel_gatherer"]
const WORK_CLIP: StringName = &"collect_object"
## A walk is done when the brain holds this close to its spot.
const ARRIVE_M: float = 0.4
## Rings tried round a target for a standable spot, and spots per ring.
const RING_GAP_M: float = 0.45
const RINGS: int = 4
const RING_SPOTS: int = 12
## How far beyond a bed's edge (and a heap's) a worker stands first.
const BED_STAND_M: float = 2.35
const HEAP_STAND_M: float = 0.55
const WELL_STAND_M: float = 1.6
## The routine crew looks at the board this often (cast time).
const PICKUP_USEC: int = 500000

var jobs: JobsScript = JobsScript.new()

var _cast: DemoCastScript = null
var _sim: SimScript = null
var _pantry: PantryScript = null
var _tunnels: TunnelsScript = null
var _network: GraphScript = null
var _well_at: Vector2 = Vector2.ZERO
var _notice: Callable = Callable()
var _crew: PackedInt32Array = PackedInt32Array()
var _pickup_usec: int = 0
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _busy: IntMath.IntResult = IntMath.IntResult.new()
## `decide`'s own scratch and answer (reused; read before the next call).
var _probe: IntMath.IntResult = IntMath.IntResult.new()
var _decision: Decision = Decision.new()
var _no_taken: PackedVector2Array = PackedVector2Array()
var _idle: PackedInt32Array = PackedInt32Array()
## Where the last target/spot search landed (presentation positions).
var _found: Vector2 = Vector2.ZERO


func configure(cast: DemoCastScript, sim: SimScript, pantry: PantryScript, tunnels: TunnelsScript,
		well_at: Vector2, notice: Callable) -> void:
	"""Work with this cast on this farm. `notice(text)` reports what happened (farm_hud.gd)."""
	_cast = cast
	_sim = sim
	_pantry = pantry
	_tunnels = tunnels
	_network = cast.space().tunnels
	_well_at = well_at
	_notice = notice
	_crew.clear()
	for i: int in cast.actor_count():
		if CREW_KEYS.has((cast.actor(i) as DemoActorScript).creature_key):
			_crew.append(i)


func set_crew(members: PackedInt32Array) -> void:
	"""Replace the routine crew (a test's placeholder cast has no fieldworker)."""
	_crew = members.duplicate()


func crew() -> PackedInt32Array:
	"""The routine crew's actor indices."""
	return _crew


# --- ordering -----------------------------------------------------------------------------------

func order(kind: int, bed: int, members: PackedInt32Array, origin: int) -> String:
	"""Queue `kind` on `bed` and, with `members`, give it to the nearest free of them now -- as `decide` says. Returns
	what to tell the player: who is on it, that it waits for the crew, or why it cannot be done."""
	var d: Decision = decide(kind, bed, members)
	var what: String = JobsScript.KIND_NAMES[kind]
	if d.code != &"":
		return "Can't %s: %s" % [what.to_lower(), reason_text(d.code)]
	if d.busy:
		return "%s is already under way: %s is on it" % [what, _name_of(d.worker)]
	var row: int = d.row
	var queued: bool = row >= 0
	var who: int = d.worker
	if not queued:
		var source: int = JobsScript.compost_source(_sim, bed) if kind == JobsScript.KIND_COMPOST else 0
		if not jobs.open_into(kind, bed, origin, source, _read):
			return "Can't %s: %s" % [what.to_lower(), reason_text(StringName(_read.error))]
		row = _read.value
	if who < 0:
		return ("%s is already queued for the field crew" if queued else "%s queued: the field crew will see to it") % what
	_take_over(row, who)
	return "%s: %s is on it" % [what, _name_of(who)]


func decide(kind: int, bed: int, members: PackedInt32Array, sow_item: int = Catalog.NO_ITEM) -> Decision:
	"""What ordering `kind` on `bed` with `members` selected would do now (see THE DECISION): the refusal (the verb's
	own, or a full board), the same job on the board, and the nearest free member to take it -- or, under way
	already, who has it. `sow_item`: sowing as if that crop were chosen (the picker's rows; `refusal_for` asks the
	same `sow_refusal` of the chosen crop). Changes nothing. The answer is reused: read it before the next call."""
	var d: Decision = _decision
	if kind == JobsScript.KIND_SOW and Catalog.is_item(sow_item):
		d.code = _sim.sow_refusal(bed, sow_item)
	else:
		d.code = JobsScript.refusal_for(_sim, kind, bed, max_heap_spoil())
	d.row = -1
	d.worker = -1
	d.busy = false
	d.selected = members.size()
	d.free = 0
	if d.code != &"":
		return d
	if jobs.job_on_bed_into(kind, bed, _probe):
		d.row = _probe.value
		if jobs.worker[d.row] != JobsScript.NOBODY:
			d.worker = jobs.worker[d.row]
			d.busy = true
			return d
	elif jobs.live_count() >= JobsScript.MAX_JOBS:
		d.code = StringName(JobsScript.REFUSE_BOARD_FULL)
		return d
	for who: int in members:
		d.free += 1 if _is_free(who) else 0
	if _nearest_free_into(members, Catalog.bed_centre_m(bed), _probe):
		d.worker = _probe.value
	return d


func _is_free(who: int) -> bool:
	"""Whether resident `who` exists and has no farm job (`_nearest_free_into`'s test)."""
	return who >= 0 and who < _cast.actor_count() and not jobs.job_of_worker_into(who, _busy)


func preview_into(card: CardScript, kind: int, bed: int, members: PackedInt32Array, sow_item: int = Catalog.NO_ITEM) -> void:
	"""The action card for `kind` on `bed` with `members` selected (decision 0331): `decide`'s refusal and assignment,
	the verb's result, cost and needs (farm_card.gd), and the work left in its plan -- what `order` will do.
	`sow_item`: a picker row's crop (see `decide`)."""
	var d: Decision = decide(kind, bed, members, sow_item)
	card.reset("%s %s" % [JobsScript.KIND_NAMES[kind], bed_label(bed)])
	FarmCard.fill(card, _sim, kind, bed, max_heap_spoil(), _probe, sow_item)
	if d.code != &"":
		card.refuse(String(d.code), reason_text(d.code), FarmCard.fix_for(d.code))
		return
	var source: int = JobsScript.compost_source(_sim, bed) if kind == JobsScript.KIND_COMPOST else 0
	if d.row >= 0:
		source = jobs.source[d.row]
	var from_step: int = jobs.step[d.row] if d.row >= 0 else 0
	var kept: int = jobs.elapsed_usec[d.row] if d.row >= 0 else 0
	card.work_usec = maxi(JobsScript.plan_work_usec(kind, source, from_step) - kept, 0)
	_preview_who(card, d)


func _preview_who(card: CardScript, d: Decision) -> void:
	"""The card's assignment: who is on it already, the selected resident it goes to, or the field crew's queue."""
	if d.busy:
		card.who = CardScript.under_way(_name_of(d.worker))
	elif d.worker >= 0:
		card.who = CardScript.assign_selected(_name_of(d.worker), d.free, d.selected)
		card.worker = d.worker
	else:
		card.who = CardScript.queue_for("the field crew", crew_names(), d.selected)


func crew_names() -> PackedStringArray:
	"""The routine crew's names, in crew order."""
	var names := PackedStringArray()
	for who: int in _crew:
		names.append(_name_of(who))
	return names


func resume_rule(who: int) -> int:
	"""demo_command.gd `add_resume_rule`: a resident with a farm job goes back to it after another order (`_drop`
	keeps it on its resume list)."""
	return InterruptScript.RESUMES if jobs.job_of_worker_into(who, _busy) else InterruptScript.NOT_MINE


func _nearest_free_into(members: PackedInt32Array, to: Vector2, out: IntMath.IntResult) -> bool:
	"""The member nearest `to` (a walking choice, so float) that has no farm job already, into `out`;
	refuses NO_ONE_FREE."""
	var found: bool = false
	var best_d: float = INF
	for who: int in members:
		if who < 0 or who >= _cast.actor_count() or jobs.job_of_worker_into(who, _busy):
			continue
		var d: float = _brain(who).surface_point().distance_squared_to(to)
		if not found or d < best_d:
			best_d = d
			found = out.succeed(who)
	if not found:
		return out.refuse("NO_ONE_FREE")
	return true


func _take_over(row: int, who: int) -> void:
	"""Hand job `row` to resident `who`, taking it off whatever it was doing."""
	jobs.assign(row, who)


func cancel_bed(bed: int) -> int:
	"""Take every job off a bed; a harvest being carried is put in store as it is. Returns how many."""
	var cancelled: int = 0
	for row: int in JobsScript.MAX_JOBS:
		if jobs.is_live(row) and jobs.bed[row] == bed:
			_finish(row, "")
			cancelled += 1
	return cancelled


func raise_routine_jobs() -> void:
	"""REQ-SET-073 and REQ-SET-085: a harvest job for every ripe bed, a clearing job for every withered
	one, unless one is already queued."""
	for bed: int in Catalog.BED_COUNT:
		var stage: int = _sim.stage_of(bed)
		if stage == SimScript.STAGE_RIPE and not jobs.job_on_bed_into(JobsScript.KIND_HARVEST, bed, _read):
			jobs.open_into(JobsScript.KIND_HARVEST, bed, JobsScript.ORIGIN_ROUTINE, 0, _read)
		if stage == SimScript.STAGE_WITHERED and not jobs.job_on_bed_into(JobsScript.KIND_CLEAR, bed, _read):
			jobs.open_into(JobsScript.KIND_CLEAR, bed, JobsScript.ORIGIN_ROUTINE, 0, _read)


# --- per frame ----------------------------------------------------------------------------------

func update(usec: int) -> void:
	"""Advance every assigned job by `usec` of the cast's time; hand waiting jobs to the idle crew."""
	if usec <= 0:
		return
	_pickup_usec += usec
	if _pickup_usec >= PICKUP_USEC:
		_pickup_usec = 0
		_hand_out()
	for row: int in JobsScript.MAX_JOBS:
		if jobs.is_live(row) and jobs.worker[row] != JobsScript.NOBODY:
			_step(row, usec)


func _hand_out() -> void:
	"""Give each waiting job, oldest row first, to the nearest crew member wandering on its own."""
	for row: int in JobsScript.MAX_JOBS:
		if not jobs.is_live(row) or jobs.worker[row] != JobsScript.NOBODY:
			continue
		_idle.clear()
		for who: int in _crew:
			var brain: BrainScript = _brain(who)
			if brain.order == BrainScript.ORDER_NONE and not brain.underground and not brain.resting:
				_idle.append(who)
		if _nearest_free_into(_idle, Catalog.bed_centre_m(jobs.bed[row]), _read):
			_take_over(row, _read.value)


func _step(row: int, usec: int) -> void:
	"""Run one frame of job `row`'s current step."""
	var code: int = jobs.current_step(row)
	if code >= JobsScript.STEP_WORK:
		_step_work(row, code - JobsScript.STEP_WORK, usec)
	else:
		_step_walk(row, code)


func _step_walk(row: int, code: int) -> void:
	"""Issue the walk, then wait for the brain to hold at its spot (or give the job back)."""
	var brain: BrainScript = _brain(jobs.worker[row])
	if jobs.issued[row] == 0:
		_issue_walk(row, code, brain)
		return
	if brain.order != BrainScript.ORDER_MOVE or brain.goal() != jobs.goal[row]:
		_drop(row)
		return
	if brain.state != BrainScript.State.HOLD:
		return
	if brain.position.distance_to(jobs.goal[row]) <= ARRIVE_M:
		jobs.advance(row)
		return
	jobs.tries[row] += 1
	jobs.issued[row] = 0
	if jobs.tries[row] >= JobsScript.MAX_TRIES:
		_finish(row, "%s: %s couldn't get there" % [JobsScript.KIND_NAMES[jobs.kind[row]], _name_of(jobs.worker[row])])


func _issue_walk(row: int, code: int, brain: BrainScript) -> void:
	"""Send the worker to a spot beside this step's target, carrying on a carry step -- into a root cellar, down to its
	middle to shelve the harvest (farm_cellars.gd CARRIED IN)."""
	if code == JobsScript.STEP_CARRY_STORE and _carry_into_cellar(row, brain):
		return
	if not _target_into(row, code):
		_finish(row, "%s: nothing to fetch it from" % JobsScript.KIND_NAMES[jobs.kind[row]])
		return
	var target: Vector2 = _found
	if not _spot_near(target, _stand_of(row, code), brain):
		_finish(row, "%s: no way through to it" % JobsScript.KIND_NAMES[jobs.kind[row]])
		return
	jobs.goal[row] = _found
	jobs.issued[row] = 1
	if code == JobsScript.STEP_CARRY_BED or code == JobsScript.STEP_CARRY_STORE:
		brain.order_carry(_found, target)
	else:
		brain.order_move(_found, target)


func _carry_into_cellar(row: int, brain: BrainScript) -> bool:
	"""A harvest bound for a root cellar the worker can carry it down into: walked in at the hatch to the cellar's
	middle, facing its racks (the drop work then shelves it there). False when the store is not such a cellar (a
	cellar is a store only once dug)."""
	var ref := FarmCellars.room_of(_pantry.storage.id_of(jobs.location[row]))
	if not _network.rooms.is_ref(ref.x, ref.y):
		return false
	var node: int = _network.rooms.middle[ref.x]
	if not brain.can_haul_below(node):
		return false
	jobs.goal[row] = _network.node_m(node)
	jobs.issued[row] = 1
	brain.order_carry_below(node, FarmCellars.rack_at(_network, ref.x))
	return true


func _target_into(row: int, code: int) -> bool:
	"""Where a walk step goes, into `_found`: the bed, the well, a spoil heap with enough on it, or
	the store the harvest is bound for. False when there is no heap to go to."""
	match code:
		JobsScript.STEP_GO_WELL:
			_found = _well_at
		JobsScript.STEP_GO_HEAP:
			var from: Vector2 = _brain(jobs.worker[row]).surface_point()
			if not _tunnels.nearest_heap_into(_network, from, JobsScript.SPOIL_PER_JOB_MILLI, _read):
				return false
			jobs.heap[row] = _read.value
			_found = _network.heap_at[_read.value]
		JobsScript.STEP_CARRY_STORE:
			_found = _pantry.storage.position_of(jobs.location[row])
		_:
			_found = Catalog.bed_centre_m(jobs.bed[row])
	return true


func _stand_of(row: int, code: int) -> float:
	"""How far from a step's target the worker first tries to stand."""
	match code:
		JobsScript.STEP_GO_WELL:
			return WELL_STAND_M
		JobsScript.STEP_GO_HEAP:
			return _network.heap_radius_m[jobs.heap[row]] + HEAP_STAND_M
		JobsScript.STEP_CARRY_STORE:
			return RING_GAP_M * jobs.tries[row]
	return BED_STAND_M + RING_GAP_M * jobs.tries[row]


func _spot_near(target: Vector2, first_ring: float, brain: BrainScript) -> bool:
	"""The standable, reachable spot nearest the worker on rings round `target`, clear of anyone
	standing (cast_orders.spot_ok), into `_found`. False when no ring has one."""
	var from: Vector2 = brain.surface_point()
	var members: Array[BrainScript] = [brain]
	var avoid: PackedVector3Array = CastOrdersScript.standing_except(_cast.space(), members)
	for ring: int in RINGS:
		var radius: float = first_ring + RING_GAP_M * ring
		var found: bool = false
		for k: int in (1 if radius <= 0.0 else RING_SPOTS):
			var spot: Vector2 = target + Vector2.from_angle(TAU * k / RING_SPOTS) * radius
			if found and spot.distance_squared_to(from) >= _found.distance_squared_to(from):
				continue
			if CastOrdersScript.spot_ok(_cast.space(), spot, brain.radius, _cast.bounds(), avoid, _no_taken, from):
				_found = spot
				found = true
		if found:
			return true
	return false


func _step_work(row: int, work: int, usec: int) -> void:
	"""Start the work (its opening effect once, the clip), count its WU, and apply its effect at the
	end. Work done by an earlier worker is kept (see farm_jobs.rewind_to_walk)."""
	var brain: BrainScript = _brain(jobs.worker[row])
	if jobs.issued[row] == 0:
		var refused: String = _begin_work(row, work)
		if refused != "":
			_finish(row, refused)
			return
		jobs.begun[row] = 1
		brain.play_in_place(WORK_CLIP)
		jobs.issued[row] = 1
	if brain.state != BrainScript.State.HOLD or brain.order != BrainScript.ORDER_MOVE:
		_drop(row)
		return
	jobs.elapsed_usec[row] += usec
	if jobs.elapsed_usec[row] < jobs.work_usec(work):
		return
	brain.play_in_place(BrainScript.CLIP_IDLE)
	var ended: String = _end_work(row, work)
	if ended != "":
		_finish(row, ended)
	elif not jobs.advance(row):
		_finish(row, "" if work == JobsScript.WORK_DROP else _done_text(row))


func _begin_work(row: int, work: int) -> String:
	"""The effect at a work step's start, or why it can no longer be done ("" to go ahead). Sowing
	commits its seed only the first time (a second worker carries on the same sowing)."""
	var bed: int = jobs.bed[row]
	if work == JobsScript.WORK_SOW:
		return "" if jobs.begun[row] == 1 else _said(_sim.sow_start(bed), "Sow")
	if work == JobsScript.WORK_DIG:
		var enough: bool = _tunnels.spoil_left(_network, jobs.heap[row]) >= JobsScript.SPOIL_PER_JOB_MILLI
		return "" if enough else "The spoil heap is used up"
	if work == JobsScript.WORK_FETCH or work == JobsScript.WORK_DROP:
		return ""
	var code: StringName = &""
	if work == JobsScript.WORK_COMPOST:
		code = _sim.compost_refusal(bed, jobs.source[row] == JobsScript.SOURCE_STORE)
	else:
		code = JobsScript.refusal_for(_sim, jobs.kind[row], bed, JobsScript.SPOIL_PER_JOB_MILLI)
	if code == &"":
		return ""
	return "Can't %s: %s" % [JobsScript.KIND_NAMES[jobs.kind[row]].to_lower(), reason_text(code)]


func _end_work(row: int, work: int) -> String:
	"""The effect at a work step's end ("" when it took)."""
	var bed: int = jobs.bed[row]
	match work:
		JobsScript.WORK_SOW:
			return _said(_sim.sow_finish(bed), "Sow")
		JobsScript.WORK_TEND:
			return _said(_sim.water(bed), "Water")
		JobsScript.WORK_HARVEST:
			return _end_harvest(row)
		JobsScript.WORK_CLEAR:
			return _said(_sim.clear(bed), "Clear")
		JobsScript.WORK_COMPOST:
			return _said(_sim.compost(bed, jobs.source[row] == JobsScript.SOURCE_STORE), "Compost")
		JobsScript.WORK_COVER:
			return _said(_sim.cover(bed), "Cover")
		JobsScript.WORK_RAISE:
			return _said(_sim.raise_bed(bed), "Raise")
		JobsScript.WORK_BANK:
			return _said(_sim.bank_bed(bed), "Bank")
		JobsScript.WORK_DRAIN:
			return _said(_sim.drain_bed(bed), "Drain")
		JobsScript.WORK_DIG:
			return _end_dig(row)
		JobsScript.WORK_DROP:
			return _end_drop(row)
	return ""


func _end_harvest(row: int) -> String:
	"""REQ-SET-074's harvest: the yield of the bed's item becomes the worker's load, bound for the
	store that spoils it slowest with room for it -- the nearest to the bed among equals."""
	var bed: int = jobs.bed[row]
	var item: int = _sim.item_of(bed)
	var cut: FarmingScript.OpResult = _sim.harvest(bed)
	if not cut.ok:
		return "Can't harvest: %s" % reason_text(cut.error)
	jobs.load_item[row] = item
	jobs.load_milli[row] = cut.value
	if not _pantry.location_near_into(cut.value, Catalog.bed_centre_m(bed), _read):
		return "No room in any store for the %s" % Catalog.ITEM_LABELS[item].to_lower()
	jobs.location[row] = _read.value
	return ""


func _end_dig(row: int) -> String:
	"""Spoil off the heap: the heap shrinks by the job's 2 U."""
	if not _tunnels.take_spoil_into(_network, jobs.heap[row], JobsScript.SPOIL_PER_JOB_MILLI, _read):
		return "The spoil heap is used up"
	jobs.load_milli[row] = JobsScript.SPOIL_PER_JOB_MILLI
	return ""


func _end_drop(row: int) -> String:
	"""The harvest goes into the pantry at its store, as its own item; the job ends saying how much."""
	var what: String = _done_text(row)
	if not _deliver_load(row):
		return "The store had no room: the %s was lost" % Catalog.ITEM_LABELS[jobs.load_item[row]].to_lower()
	_say(what)
	return ""


func _deliver_load(row: int) -> bool:
	"""Put a carried harvest into the pantry (at its store, else wherever has room). True when stored
	or when there was no harvest to store."""
	var item: int = jobs.load_item[row]
	var milli: int = jobs.load_milli[row]
	if jobs.kind[row] != JobsScript.KIND_HARVEST or not Catalog.is_item(item) or milli <= 0:
		return true
	jobs.load_milli[row] = 0
	if _pantry.add_into(item, milli, jobs.location[row], _read):
		return true
	return _pantry.location_for_into(milli, _read) and _pantry.add_into(item, milli, _read.value, _read)


func _drop(row: int) -> void:
	"""The worker was ordered away: the job waits on the board where it had got to, and the worker keeps
	it to come back to (resident_brain.gd RESUMING) -- unless the player released it (R), which forgets."""
	var who: int = jobs.worker[row]
	jobs.unassign(row)
	jobs.rewind_to_walk(row)
	if who >= 0 and who < _cast.actor_count() and _brain(who).order != BrainScript.ORDER_NONE:
		_brain(who).remember_unfinished(UnfinishedScript.new(take_back.bind(row, jobs.kind[row], jobs.bed[row]),
			"%s, bed %d" % [JobsScript.KIND_NAMES[jobs.kind[row]], jobs.bed[row] + 1]))
	_say("%s left the %s job" % [_name_of(who), JobsScript.KIND_NAMES[jobs.kind[row]].to_lower()])


func _finish(row: int, text: String) -> void:
	"""Close job `row` -- putting a harvest still being carried into store, so no food is lost -- send
	its worker back to its routine, and say how it ended."""
	_deliver_load(row)
	var who: int = jobs.worker[row]
	jobs.close(row)
	if who >= 0 and who < _cast.actor_count():
		var brain: BrainScript = _brain(who)
		brain.play_in_place(BrainScript.CLIP_IDLE)
		brain.work_done()
	if text != "":
		_say(text)


func take_back(brain: RefCounted, row: int, kind: int, bed: int) -> bool:
	"""Give job `row` back to the resident it was taken from (resident_brain.gd RESUMING), if it is still
	the same job, waiting for someone."""
	var who: int = int(brain.get(&"index"))
	if not jobs.is_live(row) or jobs.kind[row] != kind or jobs.bed[row] != bed:
		return false
	if jobs.worker[row] != JobsScript.NOBODY or jobs.job_of_worker_into(who, _busy):
		return false
	_take_over(row, who)
	return true


func _done_text(row: int) -> String:
	"""What a finished job says."""
	var bed_name: String = bed_label(jobs.bed[row])
	if jobs.kind[row] == JobsScript.KIND_HARVEST:
		return "Harvested %s U of %s into the %s" % [_units_text(jobs.load_milli[row]),
			Catalog.ITEM_LABELS[jobs.load_item[row]].to_lower(), _pantry.storage.label_of(jobs.location[row]).to_lower()]
	return "%s done: %s" % [JobsScript.KIND_NAMES[jobs.kind[row]], bed_name]


# --- readouts -----------------------------------------------------------------------------------

func task_text(who: int) -> String:
	"""What resident `who` is doing for the farm, for the party panel ("" when nothing)."""
	if not jobs.job_of_worker_into(who, _read):
		return ""
	var row: int = _read.value
	var code: int = jobs.current_step(row)
	var what: String = "%s %s" % [JobsScript.KIND_DOING[jobs.kind[row]], bed_label(jobs.bed[row])]
	match code:
		JobsScript.STEP_GO_WELL:
			return what + " — to the well"
		JobsScript.STEP_GO_HEAP:
			return what + " — to the spoil heap"
		JobsScript.STEP_CARRY_STORE:
			return "Carrying the %s harvest to store" % Catalog.ITEM_LABELS[jobs.load_item[row]].to_lower()
		JobsScript.STEP_CARRY_BED:
			return what + " — carrying"
	return what


func worker_name(row: int) -> String:
	"""The name of whoever has job `row` ("" while it waits on the board)."""
	var who: int = jobs.worker[row]
	return _name_of(who) if who >= 0 and who < _cast.actor_count() else ""


func bed_label(bed: int) -> String:
	"""A bed as the player reads it: its crop, or its number."""
	var item: int = _sim.item_of(bed)
	if Catalog.is_item(item):
		return "the %s bed" % Catalog.ITEM_LABELS[item].to_lower()
	return "bed %d" % (bed + 1)


func max_heap_spoil() -> int:
	"""The most spoil any one heap holds, milli-U."""
	var most: int = 0
	for heap: int in TunnelsScript.HEAPS:
		most = maxi(most, _tunnels.spoil_left(_network, heap))
	return most


static func reason_text(code: StringName) -> String:
	"""A refusal code in the player's words -- the action card's too (farm_card.gd)."""
	return FarmCard.reason_words(code)


static func _units_text(milli: int) -> String:
	"""Milli-U as whole units with one decimal (display only)."""
	return "%d.%d" % [milli / 1000, (milli % 1000) / 100]


func _said(result: FarmingScript.OpResult, verb: String) -> String:
	"""'' for success, else the refusal in words."""
	return "" if result.ok else "Can't %s: %s" % [verb.to_lower(), reason_text(result.error)]


func _say(text: String) -> void:
	"""Pass a line to the notice callback, if any."""
	if _notice.is_valid():
		_notice.call(text)


func _brain(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func _name_of(who: int) -> String:
	"""Resident `who`'s display name."""
	return (_cast.actor(who) as DemoActorScript).display_name

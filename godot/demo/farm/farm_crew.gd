extends RefCounted
## The demo farm's hands: residents carrying out the job board. Decision 0196. Presentation of the
## work (walking, carrying, the work clip) goes through the cast's own brains; the EFFECT of each
## piece of work is a farm_sim.gd / farm_pantry.gd / farm_tunnels.gd call at the step it belongs to.
##
## WHO WORKS. A job the player orders with residents selected goes to the nearest of them, whatever
## they were doing. Any job left on the board -- queued from the bed panel with nobody selected, or
## raised by the farm itself -- is CLAIMED: in the live demo by the village's work board (demo/work/work_board.gd,
## decision 0411: any idle eligible resident, the Field crew first), through `claim`; without one (a suite's crew
## alone) by the ROUTINE crew (CREW_KEYS: the fieldworker and the gatherer) when one of them is wandering on its own.
## The farm raises REQ-SET-073's harvest job for every ripe bed and REQ-SET-085's clearing job for
## every withered one; everything else waits for the player.
##
## HOW A STEP RUNS. A walk issues `order_move()` (or `order_carry()`, the carry walk, for a harvest
## to the store and water or spoil to a bed) to a standable spot beside its target, facing it, and
## is done when the brain has ARRIVED there (decision 0361: `arrived_near`, never merely holding -- a walk given up
## holds too). A work step plays the work clip in place for its WU
## (farm_jobs.gd) of the cast's time, applying its effect at the end -- except sowing's seed
## commitment, which is REQ-SET-071's productive START. A resident the player orders elsewhere (or
## releases) drops the job back on the board where it had got to, load and all; a step that cannot
## be done any more (the crop withered on the way, a spot out of reach) ends the job with a notice.
## Arrival is RECHECKED every frame of work: a worker no longer at its spot credits nothing there -- the job goes back
## to its walk, keeping the work done (decision 0411, closing 0361's open farm case of the review's F05).
##
## CONSERVATION (decision 0222; the review's F19 and F24). A harvest is the one job that makes stock,
## and none of it is ever lost or credited from afar:
##   * ROOM FIRST. The harvest reserves room for its expected yield (farm_pantry.gd RESERVATIONS) as the
##     cutting starts; with none anywhere it is NOT cut: the job waits on the board, the worker goes free,
##     and the shortage is said -- in the order's answer, the feed and the bed's own text
##     (`shortage_text`), which points at the Pantry. The crew takes it up again once there is room.
##   * WHAT FITS. At the store the carrier puts down what fits (a cellar can shrink under a reservation,
##     its racks taken out) and keeps the rest: it carries it on to another store with room, or waits
##     there with it, trying again every drop, until there is room.
##   * CANCEL IS NOT DELIVERY. Cancelling a bed's jobs closes its production; a harvest already cut
##     becomes a DELIVERY (farm_jobs.gd) that its carrier walks on and puts down -- the store is credited
##     at the store, on arrival. Called away, a carrier leaves the load with the job and comes back to it
##     through its resume queue; released, the routine crew takes it. A job never closes holding a load:
##     one that cannot get through waits on the board with it (`_park`) and is tried again next hour.
##
## INCIDENTS (decision 0331, review UX-011). Two of those endings are conditions that stay true after the
## notice, so they are also incidents (demo_incidents.gd) when the crew is bound to them (`set_incidents`):
##   * a STUCK JOB -- nobody could get to the bed, or no way through to it: "farm:stuck:<bed>:<kind>", on
##     the bed, ASSIGNED while that job is on the board again, RESOLVED once the bed no longer wants it
##     (`JobsScript.refusal_for` refuses it: harvested, watered, cleared...);
##   * a FULL STORE -- a harvest or its load waits for room (CONSERVATION's shortage: `_flag_shortage`, a
##     harvest left standing, a harvest queued without room): "farm:store_full", RESOLVED once a store has
##     room for STORE_ROOM_MILLI again.

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
const Text := preload("res://demo/farm/farm_text.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const FarmCard := preload("res://demo/farm/farm_card.gd")
const InterruptScript := preload("res://demo/control/work_interrupt.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")

## THE DECISION (decision 0332, review F33/F44). `decide` answers what an order of a verb on a bed would do now --
## its refusal, the same job already on the board, and who takes it -- and is the ONE function both `order` and the
## bed panel's action card (`preview_into`) read, so the card names the resident the order then sends -- and, for a
## harvest with no store room (CONSERVATION), says it waits for room, as the order then does.
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
	## A harvest with no store room for it (see CONSERVATION): the order queues it (or finds it queued) and it WAITS
	## on the board, uncut, with nobody sent; `need_milli` of `item` is what has nowhere to go.
	var waits_room: bool = false
	var need_milli: int = 0
	var item: int = Catalog.NO_ITEM


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
## Where the player makes room (the bed panel's Pantry button and the K key).
const MAKE_ROOM: String = "make room in the Pantry (K)"
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const STORE_FULL_KEY: String = "farm:store_full"
const STORE_FULL_TEXT: String = "The stores are full: a harvest has nowhere to go — dig a root cellar or eat from the Pantry"
## A full store counts as resolved once there is room for this much (one unit) somewhere.
const STORE_ROOM_MILLI: int = 1000
const STUCK_TEXT: String = "%s on bed %d is stuck: nobody can get to it — clear the way or order it again"

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
## The crew whose names `_crew_names` holds (crew_names).
var _named_crew: PackedInt32Array = PackedInt32Array()
var _crew_names: PackedStringArray = PackedStringArray()
var _no_taken: PackedVector2Array = PackedVector2Array()
var _idle: PackedInt32Array = PackedInt32Array()
## Where the last target/spot search landed (presentation positions).
var _found: Vector2 = Vector2.ZERO
var _incidents: IncidentsScript = null
var _room_read: IntMath.IntResult = IntMath.IntResult.new()
## Per job row: 1 while its walk goes DOWN into a root cellar (its arrival is below, see `_arrived`).
var _below: PackedByteArray = PackedByteArray()
## Per job row: the serial of the job the player paused there (0: none) -- a reused row is never paused.
var _paused_serial: PackedInt64Array = PackedInt64Array()
## The work board claims the waiting jobs (decision 0411): the routine crew's own hand-out stands down.
var _claimed_outside: bool = false
## The board's "who" for a job left on the board, for the action card (`func(activity, selected) -> String`).
var _queue_words: Callable = Callable()


func _init() -> void:
	"""Size the crew's own per-row columns."""
	_below.resize(JobsScript.MAX_JOBS)
	_paused_serial.resize(JobsScript.MAX_JOBS)


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


func set_incidents(incidents: IncidentsScript) -> void:
	"""Raise stuck jobs and full stores as incidents in `incidents` (see INCIDENTS)."""
	_incidents = incidents


func _raise_stuck(row: int) -> void:
	"""Job `row` could not be reached: its bed's stuck-job incident."""
	if _incidents == null:
		return
	var bed: int = jobs.bed[row]
	var kind: int = jobs.kind[row]
	_incidents.raise("farm:stuck:%d:%d" % [bed, kind], NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING,
		STUCK_TEXT % [JobsScript.KIND_NAMES[kind], bed + 1], NoticesScript.TARGET_BED, bed, stuck_state.bind(bed, kind))


func stuck_state(bed: int, kind: int) -> int:
	"""A stuck job's incident state: RESOLVED once the bed no longer wants it, ASSIGNED while it is on the board
	again, else needing a decision."""
	if JobsScript.refusal_for(_sim, kind, bed, max_heap_spoil()) != &"":
		return IncidentsScript.STATE_RESOLVED
	if jobs.job_on_bed_into(kind, bed, _room_read):
		return IncidentsScript.STATE_ASSIGNED
	return IncidentsScript.STATE_NEEDS_DECISION


func _raise_store_full() -> void:
	"""A harvest waits for room (see CONSERVATION): the full-store incident."""
	if _incidents != null:
		_incidents.raise(STORE_FULL_KEY, NoticesScript.SOURCE_FARM, IncidentsScript.SEVERITY_WARNING, STORE_FULL_TEXT,
			NoticesScript.TARGET_NONE, -1, store_state)


func store_state() -> int:
	"""The full store's incident state: RESOLVED once some store has room for STORE_ROOM_MILLI."""
	if _pantry.location_near_into(STORE_ROOM_MILLI, _well_at, _room_read):
		return IncidentsScript.STATE_RESOLVED
	return IncidentsScript.STATE_NEEDS_DECISION


func set_crew(members: PackedInt32Array) -> void:
	"""Replace the routine crew (a test's placeholder cast has no fieldworker)."""
	_crew = members.duplicate()


func crew() -> PackedInt32Array:
	"""The routine crew's actor indices."""
	return _crew


# --- ordering -----------------------------------------------------------------------------------

func order(kind: int, bed: int, members: PackedInt32Array, origin: int) -> String:
	"""Queue `kind` on `bed` and, with `members`, give it to the nearest free of them now -- as `decide` says. Returns
	what to tell the player: who is on it, that it waits for the crew or for store room, or why it cannot be done."""
	var d: Decision = decide(kind, bed, members)
	var what: String = JobsScript.KIND_NAMES[kind]
	if d.code != &"":
		return "Can't %s: %s" % [what.to_lower(), reason_text(d.code)]
	if d.busy:
		return "%s is already under way: %s is on it" % [what, _name_of(d.worker)]
	var row: int = d.row
	var queued: bool = row >= 0
	var who: int = d.worker
	if queued and jobs.blocked[row] == JobsScript.BLOCK_WAY:
		jobs.blocked[row] = JobsScript.BLOCK_NONE
	if not queued:
		var source: int = JobsScript.compost_source(_sim, bed) if kind == JobsScript.KIND_COMPOST else 0
		if not jobs.open_into(kind, bed, origin, source, _read):
			return "Can't %s: %s" % [what.to_lower(), reason_text(StringName(_read.error))]
		row = _read.value
	if d.waits_room:
		return _wait_for_room(row, queued)
	if queued:
		jobs.blocked[row] = JobsScript.BLOCK_NONE
	if who < 0 and _claimed_outside:
		return ("%s is already queued" if queued else "%s queued: the first free resident who can takes it") % what
	if who < 0:
		return ("%s is already queued for the field crew" if queued else "%s queued: the field crew will see to it") % what
	_take_over(row, who)
	return "%s: %s is on it" % [what, _name_of(who)]


func _wait_for_room(row: int, queued: bool) -> String:
	"""An ordered harvest with no store room (see CONSERVATION): it waits on the board, the shortage said (once, for
	one already waiting) and raised as the full-store incident."""
	if queued:
		_flag_shortage(row, false)
		return "%s waits: %s" % [JobsScript.KIND_NAMES[jobs.kind[row]], _shortage_words(row)]
	jobs.blocked[row] = JobsScript.BLOCK_ROOM
	_raise_store_full()
	return "Harvest queued, but %s" % _shortage_words(row)


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
	d.waits_room = false
	d.need_milli = 0
	d.item = Catalog.NO_ITEM
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
	if not _room_for(kind, bed, d):
		d.waits_room = true
		return d
	if _nearest_free_into(members, Catalog.bed_centre_m(bed), _probe):
		d.worker = _probe.value
	return d


func _room_for(kind: int, bed: int, d: Decision) -> bool:
	"""Whether the job `d` decides has somewhere to put its harvest -- `_can_store` for the one on the board, else the
	same test for a new harvest's expected yield (CONSERVATION: none anywhere, it waits). Fills `d.need_milli` and
	`d.item` either way."""
	if d.row >= 0:
		d.need_milli = _need_milli(d.row)
		d.item = _harvest_item(d.row)
		return _can_store(d.row)
	if kind != JobsScript.KIND_HARVEST or _sim.stage_of(bed) != SimScript.STAGE_RIPE \
			or not _sim.expected_yield_into(bed, _probe) or _probe.value <= 0:
		return true
	d.need_milli = _probe.value
	d.item = _sim.item_of(bed)
	return _pantry.location_for_item_into(d.item, d.need_milli, _probe)


func _is_free(who: int) -> bool:
	"""Whether resident `who` exists and has no farm job (`_nearest_free_into`'s test)."""
	return who >= 0 and who < _cast.actor_count() and not jobs.job_of_worker_into(who, _busy)


func preview_into(card: CardScript, kind: int, bed: int, members: PackedInt32Array, sow_item: int = Catalog.NO_ITEM) -> void:
	"""The action card for `kind` on `bed` with `members` selected (decision 0332): `decide`'s refusal and assignment,
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
	card.members = members_line(members)


func members_line(members: PackedInt32Array) -> String:
	"""A group order's preview, member by member (decision 0411, review UX-001): who of the selection could take a farm
	job -- not one with a farm job already, nor one the water's rescue holds (it takes no order)."""
	if members.size() <= 1:
		return ""
	var names := PackedStringArray()
	var why := PackedStringArray()
	for who: int in members:
		if who < 0 or who >= _cast.actor_count():
			continue
		names.append(_name_of(who))
		why.append("has a farm job" if not _is_free(who) else ("held by the rescue" if _brain(who).water_hold else ""))
	return CardScript.each_member(names, why)


func _preview_who(card: CardScript, d: Decision) -> void:
	"""The card's assignment: who is on it already, the selected resident it goes to, or the field crew's queue."""
	if d.busy:
		card.who = CardScript.under_way(_name_of(d.worker))
	elif d.waits_room:
		card.who = "Waits on the board: " + room_words(d.need_milli, d.item)
	elif d.worker >= 0:
		card.who = CardScript.assign_selected(_name_of(d.worker), d.free, d.selected)
		card.worker = d.worker
	elif _queue_words.is_valid():
		card.who = String(_queue_words.call(WorkIds.ACT_FARM, d.selected))
	else:
		card.who = CardScript.queue_for("the field crew", crew_names(), d.selected)


func crew_names() -> PackedStringArray:
	"""The routine crew's names, in crew order (made again only when the crew changed; read, never kept)."""
	if _named_crew != _crew:
		_named_crew = _crew.duplicate()
		_crew_names.clear()
		for who: int in _crew:
			_crew_names.append(_name_of(who))
	return _crew_names


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
	"""Take every production job off a bed. A harvest already cut is not put in store here: it becomes
	its delivery, carried on and credited at the store (see CONSERVATION). Returns how many."""
	var cancelled: int = 0
	for row: int in JobsScript.MAX_JOBS:
		if not jobs.is_live(row) or jobs.bed[row] != bed or jobs.kind[row] == JobsScript.KIND_DELIVER:
			continue
		cancelled += 1
		if not _holds_load(row):
			_finish(row, "")
			continue
		jobs.become_delivery(row)
		var who: String = worker_name(row)
		_say("Harvest cancelled: %s carries the %s of %s on to store" % [who if who != "" else "the crew",
			Text.units_text(jobs.load_milli[row]), _item_word(row)])
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
	for row: int in JobsScript.MAX_JOBS:
		if jobs.is_live(row) and jobs.blocked[row] == JobsScript.BLOCK_WAY:
			jobs.blocked[row] = JobsScript.BLOCK_NONE


# --- per frame ----------------------------------------------------------------------------------

func update(usec: int) -> void:
	"""Advance every assigned job by `usec` of the cast's time; hand waiting jobs to the idle crew."""
	if usec <= 0:
		return
	_pickup_usec += usec
	if _pickup_usec >= PICKUP_USEC:
		_pickup_usec = 0
		if not _claimed_outside:
			_hand_out()
	for row: int in JobsScript.MAX_JOBS:
		if jobs.is_live(row) and jobs.worker[row] != JobsScript.NOBODY:
			_step(row, usec)


func _hand_out() -> void:
	"""Give each waiting job, oldest row first, to the nearest crew member wandering on its own (no work board)."""
	for row: int in JobsScript.MAX_JOBS:
		if not jobs.is_live(row) or jobs.worker[row] != JobsScript.NOBODY or not _ready(row):
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
	"""Issue the walk, then wait for the brain to ARRIVE at its spot (or give the job back). A walk given up holds too:
	that is a failed try, never arrival (decision 0361)."""
	var brain: BrainScript = _brain(jobs.worker[row])
	if jobs.issued[row] == 0:
		_issue_walk(row, code, brain)
		return
	if brain.order != BrainScript.ORDER_MOVE or brain.goal() != jobs.goal[row]:
		_drop(row)
		return
	if brain.state != BrainScript.State.HOLD:
		return
	if _arrived(row, brain):
		jobs.advance(row)
		return
	jobs.tries[row] += 1
	jobs.issued[row] = 0
	if jobs.tries[row] >= JobsScript.MAX_TRIES:
		_raise_stuck(row)
		_finish(row, "%s: %s couldn't get there" % [JobsScript.KIND_NAMES[jobs.kind[row]], _name_of(jobs.worker[row])])


func _issue_walk(row: int, code: int, brain: BrainScript) -> void:
	"""Send the worker to a spot beside this step's target, carrying on a carry step -- into a root cellar, down to its
	middle to shelve the harvest (farm_cellars.gd CARRIED IN)."""
	_below[row] = 0
	if code == JobsScript.STEP_CARRY_STORE:
		_aim_delivery(row, brain)
		if _carry_into_cellar(row, brain):
			return
	if not _target_into(row, code):
		_finish(row, "%s: nothing to fetch it from" % JobsScript.KIND_NAMES[jobs.kind[row]])
		return
	var target: Vector2 = _found
	if not _spot_near(target, _stand_of(row, code), brain):
		_raise_stuck(row)
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
	_below[row] = 1
	brain.order_carry_below(node, FarmCellars.rack_at(_network, ref.x))
	return true


func _arrived(row: int, brain: BrainScript) -> bool:
	"""ARRIVAL (decision 0361): the walk's trip ARRIVED and the worker stands within ARRIVE_M of its spot -- on the
	surface (`arrived_near`), or, carried down into a root cellar, below at the cellar's middle. Holding alone is not
	arriving."""
	if _below[row] == 1:
		return brain.underground and brain.trip_outcome == BrainScript.TRIP_ARRIVED \
			and brain.position.distance_to(jobs.goal[row]) <= ARRIVE_M
	return brain.arrived_near(jobs.goal[row], ARRIVE_M)


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
	end. Work done by an earlier worker is kept (see farm_jobs.rewind_to_walk). Every frame the worker must still be
	ARRIVED at its spot (decision 0411): one that is not goes back to the walk, crediting nothing, its work kept."""
	var brain: BrainScript = _brain(jobs.worker[row])
	if brain.state != BrainScript.State.HOLD or brain.order != BrainScript.ORDER_MOVE:
		_drop(row)
		return
	if not _arrived(row, brain):
		jobs.rewind_to_walk(row)
		return
	if jobs.issued[row] == 0 and not _start_work(row, work, brain):
		return
	jobs.elapsed_usec[row] += usec
	if jobs.elapsed_usec[row] < jobs.work_usec(work):
		return
	brain.play_in_place(BrainScript.CLIP_IDLE)
	if work == JobsScript.WORK_DROP:
		_end_drop(row)
		return
	var ended: String = _end_work(row, work)
	if ended != "":
		_finish(row, ended)
	elif not jobs.advance(row):
		_finish(row, _done_text(row))


func _start_work(row: int, work: int, brain: BrainScript) -> bool:
	"""Open a work step: its opening effect or refusal, a harvest's room reserved (else it waits, uncut),
	then the clip. False when the job ended or went back to the board instead."""
	var refused: String = _begin_work(row, work)
	if refused != "":
		_finish(row, refused)
		return false
	if work == JobsScript.WORK_HARVEST and not _reserve_harvest(row):
		return false
	jobs.begun[row] = 1
	brain.play_in_place(WORK_CLIP)
	jobs.issued[row] = 1
	return true


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
	return ""


func _end_harvest(row: int) -> String:
	"""REQ-SET-074's harvest: the yield of the bed's item becomes the worker's load, bound for the store
	its reservation holds room at (the slowest-spoiling with room, the nearest the bed among equals). A
	cut bigger than the reservation keeps its extra room where there is any; the drop puts down what fits."""
	var bed: int = jobs.bed[row]
	var item: int = _sim.item_of(bed)
	var cut: FarmingScript.OpResult = _sim.harvest(bed)
	if not cut.ok:
		return "Can't harvest: %s" % reason_text(cut.error)
	jobs.load_item[row] = item
	jobs.load_milli[row] = cut.value
	_pantry.resize_hold(jobs.hold[row], cut.value)
	return ""


func _end_dig(row: int) -> String:
	"""Spoil off the heap: the heap shrinks by the job's 2 U."""
	if not _tunnels.take_spoil_into(_network, jobs.heap[row], JobsScript.SPOIL_PER_JOB_MILLI, _read):
		return "The spoil heap is used up"
	jobs.load_milli[row] = JobsScript.SPOIL_PER_JOB_MILLI
	return ""


func _end_drop(row: int) -> void:
	"""The harvest into the pantry at its store: what fits (see CONSERVATION). All of it: the job ends
	saying how much. Some left: carried on to a store with room, or kept, waiting, until there is one."""
	var stored: int = 0
	if _here_into(row, _read):
		jobs.location[row] = _read.value
		if _pantry.store_upto_into(jobs.load_item[row], jobs.load_milli[row], _read.value, jobs.hold[row], _read):
			stored = _read.value
	jobs.load_milli[row] -= stored
	if jobs.load_milli[row] > 0:
		_carry_on(row, stored)
		return
	_release_hold(row)
	_finish(row, "Harvested %s of %s into the %s" % [Text.units_text(stored), _item_word(row),
		_pantry.storage.label_of(jobs.location[row]).to_lower()])


func _carry_on(row: int, stored: int) -> void:
	"""Part of a load is still in hand after a drop: reserve room for it from here and walk it on. With
	none anywhere, wait with it and try the drop again (said once) -- here, keeping the spent reservation
	to follow this store by id, or at the covered store when this one has gone."""
	var from: Vector2 = _brain(jobs.worker[row]).surface_point()
	if _pantry.reserve_near_into(jobs.load_item[row], jobs.load_milli[row], from, _busy):
		var took: String = _took_text(row, stored)
		_release_hold(row)
		_take_hold(row, _busy.value)
		jobs.blocked[row] = JobsScript.BLOCK_NONE
		jobs.back_to_carry(row)
		_say("%s%s carries the %s%s of %s on to the %s" % [took, _name_of(jobs.worker[row]), "other " if stored > 0 else "",
			Text.units_text(jobs.load_milli[row]), _item_word(row), _pantry.storage.label_of(jobs.location[row]).to_lower()])
		return
	if _here_into(row, _read):
		jobs.elapsed_usec[row] = 0
	else:
		_release_hold(row)
		jobs.location[row] = 0
		jobs.back_to_carry(row)
	_flag_shortage(row, stored > 0)


func _took_text(row: int, stored: int) -> String:
	"""'The covered store took 3.0 U of carrot: ' for a part put down ('' for none)."""
	if stored <= 0:
		return ""
	return "The %s took %s of %s: " % [_pantry.storage.label_of(jobs.location[row]).to_lower(), Text.units_text(stored),
		_item_word(row)]


func _drop(row: int) -> void:
	"""The worker was ordered away: the job waits on the board where it had got to, and the worker keeps
	it to come back to (resident_brain.gd RESUMING) -- unless the player released it (R), which forgets."""
	var who: int = jobs.worker[row]
	jobs.unassign(row)
	jobs.rewind_to_walk(row)
	if who >= 0 and who < _cast.actor_count() and _brain(who).order != BrainScript.ORDER_NONE:
		_brain(who).remember_unfinished(unfinished_of(row))
	_say("%s left the %s job" % [_name_of(who), JobsScript.KIND_NAMES[jobs.kind[row]].to_lower()])


func _finish(row: int, text: String) -> void:
	"""Close job `row`, send its worker back to its routine, and say how it ended. A job still holding a
	harvest is never closed: it waits on the board with its load (`_park`)."""
	if _holds_load(row):
		_park(row, text, JobsScript.BLOCK_WAY)
		return
	_release_hold(row)
	var who: int = jobs.worker[row]
	jobs.close(row)
	_free_worker(who)
	if text != "":
		_say(text)


func _park(row: int, text: String, why: int) -> void:
	"""Put job `row` back on the board where it had got to -- load, reservation and all -- blocked for
	`why` (farm_jobs.gd BLOCK_*), its worker free; say `text`."""
	var who: int = jobs.worker[row]
	jobs.unassign(row)
	jobs.rewind_to_walk(row)
	jobs.blocked[row] = why
	_free_worker(who)
	if text != "":
		_say(text)


func _free_worker(who: int) -> void:
	"""A worker done with its job: idle, and back to its routine (or its next unfinished job)."""
	if who >= 0 and who < _cast.actor_count():
		var brain: BrainScript = _brain(who)
		brain.play_in_place(BrainScript.CLIP_IDLE)
		brain.work_done()


func take_back(brain: RefCounted, row: int, serial: int) -> bool:
	"""Give job `row` back to the resident it was taken from (resident_brain.gd RESUMING), if it is still
	the same job (its serial: a harvest become a delivery still is), waiting for someone and ready."""
	var who: int = int(brain.get(&"index"))
	if not jobs.is_live(row) or jobs.serial[row] != serial:
		return false
	if jobs.worker[row] != JobsScript.NOBODY or jobs.job_of_worker_into(who, _busy) or not _ready(row):
		return false
	_take_over(row, who)
	return true


func unfinished_of(row: int) -> UnfinishedScript:
	"""Job `row` as an order-list entry: taken back by `take_back` while it is still the same job, naming the work
	board task it is (decision 0411)."""
	return UnfinishedScript.new(take_back.bind(row, jobs.serial[row]), job_words(row), WorkIds.SOURCE_FARM,
		jobs.serial[row])


func job_words(row: int) -> String:
	"""A job in a few words, as the order list says it: "Harvest, bed 3"."""
	return "%s, bed %d" % [JobsScript.KIND_NAMES[jobs.kind[row]], jobs.bed[row] + 1]


# --- the work board's hands (decision 0411) ---------------------------------------------------------

func set_claimer(queue_words: Callable) -> void:
	"""The village's work board claims the waiting jobs from now on (the routine crew's hand-out stands down);
	`queue_words(activity, selected) -> String` is its "who" for a job left on the board, the action card's."""
	_claimed_outside = true
	_queue_words = queue_words


func claims_outside() -> bool:
	"""Whether the work board claims the waiting jobs."""
	return _claimed_outside


func waiting(row: int) -> bool:
	"""Whether job `row` waits on the board for a worker and could be handed out now (not paused, not waiting for a
	way or for store room)."""
	return jobs.is_live(row) and jobs.worker[row] == JobsScript.NOBODY and _ready(row)


func claim(row: int, who: int) -> bool:
	"""The work board hands waiting job `row` to resident `who`, who sets off at once. False when the job is not
	waiting or `who` has a farm job already."""
	if not waiting(row) or not _is_free(who):
		return false
	_take_over(row, who)
	_step(row, 0)
	return true


func is_paused(row: int) -> bool:
	"""Whether the player paused job `row`."""
	return jobs.is_live(row) and _paused_serial[row] == jobs.serial[row]


func pause(row: int, on: bool) -> String:
	"""The player pauses job `row` (its worker let go, the work done kept; nobody takes it until it is resumed) or
	resumes it. A load in hand is never paused: its carrier finishes the delivery first. "" when done, else why not."""
	if not jobs.is_live(row):
		return WorkIds.NOT_FOUND
	if not on:
		_paused_serial[row] = 0
		return ""
	if is_paused(row):
		return WorkIds.PAUSED_ALREADY
	if _holds_load(row):
		return WorkIds.CARRYING % _carrier_words(row)
	_paused_serial[row] = jobs.serial[row]
	if jobs.worker[row] != JobsScript.NOBODY:
		_park(row, "", jobs.blocked[row])
	return ""


func cancel_row(row: int) -> String:
	"""The player cancels job `row` alone: closed, its reservation let go -- or, a harvest already cut, it becomes its
	delivery and is carried on (CONSERVATION: cancel is not delivery). A delivery is not cancelled. "" when done."""
	if not jobs.is_live(row):
		return WorkIds.NOT_FOUND
	if jobs.kind[row] == JobsScript.KIND_DELIVER:
		return WorkIds.DELIVERY_GOES_ON
	_paused_serial[row] = 0
	if not _holds_load(row):
		_finish(row, "")
		return ""
	jobs.become_delivery(row)
	_say("Harvest cancelled: %s carries the %s of %s on to store" % [_carrier_words(row), Text.units_text(jobs.load_milli[row]),
		_item_word(row)])
	return ""


func reassign(row: int, who: int) -> String:
	"""The player gives job `row` to resident `who` instead, taken off whatever it was doing; the one on it is let go
	(the work done stays with the job). A load in hand stays with its carrier (no load changes hands from afar). ""
	when done, else why not."""
	if not jobs.is_live(row):
		return WorkIds.NOT_FOUND
	if who < 0 or who >= _cast.actor_count():
		return "nobody to give it to"
	if _holds_load(row):
		return WorkIds.CARRYING % _carrier_words(row)
	if jobs.job_of_worker_into(who, _busy) and _busy.value != row:
		return "has another farm job"
	if jobs.worker[row] == who:
		return ""
	if jobs.worker[row] != JobsScript.NOBODY:
		_park(row, "", JobsScript.BLOCK_NONE)
	_paused_serial[row] = 0
	jobs.blocked[row] = JobsScript.BLOCK_NONE
	_take_over(row, who)
	_step(row, 0)
	return ""


func holds_load(row: int) -> bool:
	"""Whether job `row` has a harvest in hand (see CONSERVATION)."""
	return jobs.is_live(row) and _holds_load(row)


func blocked_words(row: int) -> String:
	"""Why waiting job `row` cannot be handed out, in the order's own words ("" when it can): a harvest's shortage of
	store room (CONSERVATION), or nobody able to get to it (lifted at the farm's next hour)."""
	if jobs.blocked[row] == JobsScript.BLOCK_ROOM or not _can_store(row):
		return _shortage_words(row)
	if jobs.blocked[row] == JobsScript.BLOCK_WAY:
		return "can't reach it — tried again at the farm's next hour"
	return ""


func _carrier_words(row: int) -> String:
	"""Who carries job `row`'s load ("the crew" while it waits on the board)."""
	var who: String = worker_name(row)
	return who if who != "" else "the crew"


func _done_text(row: int) -> String:
	"""What a finished job says (a harvest says it at its drop)."""
	return "%s done: %s" % [JobsScript.KIND_NAMES[jobs.kind[row]], bed_label(jobs.bed[row])]


# --- storage room (see CONSERVATION) ---------------------------------------------------------------

func _reserve_harvest(row: int) -> bool:
	"""Room for the harvest's expected yield, reserved before it is cut (kept from an earlier start while
	its store stands). With none anywhere the job waits on the board, uncut; false."""
	if jobs.hold[row] != JobsScript.FREE and _here_into(row, _read):
		return true
	_release_hold(row)
	if _pantry.reserve_near_into(_harvest_item(row), _need_milli(row), Catalog.bed_centre_m(jobs.bed[row]), _read):
		_take_hold(row, _read.value)
		return true
	var who: String = _name_of(jobs.worker[row])
	_park(row, "", JobsScript.BLOCK_ROOM)
	_raise_store_full()
	_say("%s left the harvest standing: %s" % [who, _shortage_words(row)])
	return false


func _aim_delivery(row: int, brain: BrainScript) -> void:
	"""Before a carry walk: the store its reservation holds room for the whole load at; else a new
	reservation from here; else wherever its reservation still stands, or the covered store, to put down
	what fits and wait there with the rest."""
	var need: int = _need_milli(row)
	if _pantry.hold_milli(jobs.hold[row]) >= need and _here_into(row, _read):
		jobs.location[row] = _read.value
		return
	if _pantry.reserve_near_into(_harvest_item(row), need, brain.surface_point(), _busy):
		_release_hold(row)
		_take_hold(row, _busy.value)
		return
	if not _here_into(row, _read):
		_release_hold(row)
	jobs.location[row] = _read.value if _here_into(row, _read) else 0


func _here_into(row: int, out: IntMath.IntResult) -> bool:
	"""The store job `row` is delivering to, into `out`: where its reservation is, else the covered
	store it walks to without one. Refuses when its reservation's store has gone."""
	if jobs.hold[row] == JobsScript.FREE:
		return out.succeed(0)
	return _pantry.hold_location_into(jobs.hold[row], out)


func _take_hold(row: int, held: int) -> void:
	"""Job `row` keeps reservation `held`, delivering to its store."""
	jobs.hold[row] = held
	if _pantry.hold_location_into(held, _busy):
		jobs.location[row] = _busy.value


func _release_hold(row: int) -> void:
	"""Job `row` gives up its reservation, if any."""
	_pantry.release(jobs.hold[row])
	jobs.hold[row] = JobsScript.FREE


func _holds_load(row: int) -> bool:
	"""Whether job `row` has a harvest in hand."""
	return (jobs.kind[row] == JobsScript.KIND_HARVEST or jobs.kind[row] == JobsScript.KIND_DELIVER) \
		and jobs.load_milli[row] > 0 and Catalog.is_item(jobs.load_item[row])


func _need_milli(row: int) -> int:
	"""The room job `row` needs: its load in hand, else a ripe harvest's expected yield (0: none)."""
	if _holds_load(row):
		return jobs.load_milli[row]
	if jobs.kind[row] != JobsScript.KIND_HARVEST or _sim.stage_of(jobs.bed[row]) != SimScript.STAGE_RIPE:
		return 0
	return _busy.value if _sim.expected_yield_into(jobs.bed[row], _busy) else 0


func _can_store(row: int) -> bool:
	"""Whether job `row`'s harvest has somewhere to go: nothing to store, its reservation standing, or
	room for it somewhere now."""
	var need: int = _need_milli(row)
	if need <= 0 or (_pantry.hold_milli(jobs.hold[row]) >= need and _here_into(row, _busy)):
		return true
	return _pantry.location_for_item_into(_harvest_item(row), need, _busy)


func _ready(row: int) -> bool:
	"""Whether a waiting job can be handed out (or taken back): not paused by the player, not waiting for a way (lifted
	hourly), and with room for its harvest -- a shortage newly found is said once."""
	if jobs.blocked[row] == JobsScript.BLOCK_WAY or is_paused(row):
		return false
	if _can_store(row):
		jobs.blocked[row] = JobsScript.BLOCK_NONE
		return true
	_flag_shortage(row, false)
	return false


func _flag_shortage(row: int, partly: bool) -> void:
	"""Mark job `row` waiting for room and say so, once until it moves again."""
	if jobs.blocked[row] == JobsScript.BLOCK_ROOM:
		return
	jobs.blocked[row] = JobsScript.BLOCK_ROOM
	_raise_store_full()
	var line: String = _shortage_words(row, partly)
	_say(line.left(1).to_upper() + line.substr(1))


func _shortage_words(row: int, partly: bool = false) -> String:
	"""'no store has room for 5.1 U of carrot — make room in the Pantry (K)' ('the other 2.1 U' once part
	of a load is stored)."""
	return room_words(_need_milli(row), _harvest_item(row), partly)


static func room_words(need_milli: int, item: int, partly: bool = false) -> String:
	"""A harvest's shortage, the order's and the action card's words alike: 'no store has room for 5.1 U of carrot —
	make room in the Pantry (K)' ('the other 2.1 U' once part of a load is stored)."""
	var word: String = Catalog.ITEM_LABELS[item].to_lower() if Catalog.is_item(item) else "harvest"
	return "no store has room for %s%s of %s — %s" % ["the other " if partly else "", Text.units_text(need_milli), word,
		MAKE_ROOM]


func _item_word(row: int) -> String:
	"""The item a job's harvest is, lower case ("harvest" when it has none)."""
	var item: int = _harvest_item(row)
	return Catalog.ITEM_LABELS[item].to_lower() if Catalog.is_item(item) else "harvest"


func _store_word(row: int) -> String:
	"""The store a delivery is bound for, lower case, read through its reservation (a store index can
	move at the hourly refresh); "store" once its store has gone."""
	if not _here_into(row, _busy):
		return "store"
	return _pantry.storage.label_of(_busy.value).to_lower()


func _harvest_item(row: int) -> int:
	"""The item a job's harvest is: its load, else its bed's crop (Catalog.NO_ITEM for neither)."""
	return jobs.load_item[row] if Catalog.is_item(jobs.load_item[row]) else _sim.item_of(jobs.bed[row])


func shortage_text(bed: int) -> String:
	"""The bed's storage shortage for its farm text: its harvest or delivery waiting for room ("" when
	none is)."""
	for row: int in JobsScript.MAX_JOBS:
		if jobs.is_live(row) and jobs.bed[row] == bed and not _can_store(row):
			return "Waiting: " + _shortage_words(row)
	return ""



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
			return "Carrying %s of %s to the %s" % [Text.units_text(jobs.load_milli[row]), _item_word(row), _store_word(row)]
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


func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain (the work board's read)."""
	return _brain(who)


func _name_of(who: int) -> String:
	"""Resident `who`'s display name."""
	return (_cast.actor(who) as DemoActorScript).display_name

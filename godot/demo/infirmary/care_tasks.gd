extends RefCounted
## The infirmary's three tasks (resident_brain.gd TASKS). Decisions 0622, 0623. Presentation only: the care state
## (care_state.gd) keeps every number; these only move the residents.
##
##   * BedRest -- a hurt resident's: to rest until it may be up again (CareRules.UP_HEALTH, P4). In the INFIRMARY
##     building when it is built and has a bed (decision 0623: in at its door, inside, not drawn); before that, or when
##     it is full (PROPOSAL 0623 P2), its own bed, else lying on the ground at the FIELD-CARE SPOT by the hall's steps
##     (REQ-SET-173: treatment "at a field landing point or a bed"). In a bed it wraps the night's own SleepTask, so the
##     walk home through the network, the stroll to the bedside and lying down are the night's motion, and its "morning"
##     is being well again. It is urgent: dusk does not send it to bed again, nor dawn turn it back.
##   * Treat -- the healer's: into the infirmary, or to the patient's bed or spot, beside it, and the work clip while the
##     care state credits the HEAL work; done, back out. Urgent, so the night does not park a treatment.
##   * Gather -- the herbalist's: to the herb patch, the work clip while the care state credits the gathering, then the
##     load carried to the shelf at the hall's steps, where it is delivered (the patch is debited there, not before).

const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

## Where a patient rests.
const WHERE_BED: int = 0
const WHERE_FIELD: int = 1
const WHERE_INFIRMARY: int = 2
## The clip a healer tends with and a gatherer picks with: the hand clip (install_task.gd WORK_CLIP).
const WORK_CLIP: StringName = &"collect_object"
## A healer stands this far from the patient's bedside toward the room's middle (m), and this far beside a patient
## lying at the field-care spot.
const BESIDE_M: float = 0.45
const FIELD_GAP_M: float = 0.75
## Where a patient lies at the field-care spot: on the ground, facing the way the hall's steps face.
const FIELD_YAW: float = 0.0
const GROUND_Y_M: float = 0.0


class BedRest extends "res://demo/tunnel/tunnel_task.gd":
	"""A hurt resident resting until it may be up (see the header)."""
	var who: int = -1
	var where: int = WHERE_FIELD
	## Where it rests, in words, and (WHERE_BED) the bed (room * PLACES + place) and its room.
	var room_name: String = ""
	var bed: int = -1
	var room: int = -1
	var middle_node: int = -1
	var middle: Vector2 = Vector2.ZERO
	var sleep: SleepTaskScript = null
	var _up: Callable = Callable()
	var _hurt: Callable = Callable()
	var _field_at: Vector2 = Vector2.ZERO
	var _lying: bool = false
	## Whether it ever reached its place (kept after it gets up: a lost trip is one that never did).
	var arrived_once: bool = false

	func _init(i: int, up: Callable, alarm: Callable, hurt: Callable = Callable()) -> void:
		"""Resident `i` rests until `up() -> bool` (`hurt() -> bool` says whether it is still hurt, for its words);
		`alarm() -> bool` stands it by its bed while a threat lasts."""
		who = i
		_up = up
		_hurt = hurt if hurt.is_valid() else func() -> bool: return false
		sleep = SleepTaskScript.new(up, alarm)

	func in_bed(bed_id: int, r: int, name_of_room: String, node: int, at: Vector2) -> void:
		"""Rest in bed `bed_id` of room `r` (named so; its middle `node` at `at`) (the night has set the sleep task's bed:
		night_routine.gd `bed_task_at`)."""
		where = WHERE_BED
		bed = bed_id
		room = r
		room_name = name_of_room
		middle_node = node
		middle = at

	func in_infirmary(door: Vector2) -> void:
		"""Rest in the infirmary building, going in at its `door` (decision 0623)."""
		where = WHERE_INFIRMARY
		room_name = "the infirmary"
		sleep = null
		_field_at = door

	func in_field(at: Vector2) -> void:
		"""Rest lying on the ground at the field-care spot `at` (no bed)."""
		where = WHERE_FIELD
		room_name = "the field-care spot by the hall"
		sleep = null
		_field_at = at

	func site(brain: RefCounted) -> Vector2:
		"""The infirmary's door or the field-care spot (a bed's walk goes by its node)."""
		return sleep.site(brain) if sleep != null else _field_at

	func site_node(brain: RefCounted) -> int:
		"""The bed's room's middle node (-1: the surface)."""
		return sleep.site_node(brain) if sleep != null else -1

	func arrived(brain: RefCounted) -> void:
		"""At the room: across to the bed (the night's motion). At the infirmary: in. At the spot: lie down."""
		arrived_once = true
		if sleep != null:
			sleep.arrived(brain)
			return
		var walker := brain as BrainScript
		if where == WHERE_INFIRMARY:
			walker.task_go_indoors(true, BrainScript.INTERIOR_INFIRMARY)
			walker.task_play(BrainScript.CLIP_IDLE)
		else:
			walker.task_lie(_field_at, FIELD_YAW, GROUND_Y_M)
		_lying = true

	func step(brain: RefCounted, delta: float) -> bool:
		"""The night's motion in a bed (see the header); at the spot, lying until up again. False once up."""
		if sleep != null:
			return sleep.step(brain, delta)
		return not bool(_up.call())

	func finish(brain: RefCounted) -> void:
		"""Up: out of bed, or up off the ground."""
		_get_up(brain as BrainScript)

	func cancel(brain: RefCounted) -> void:
		"""Taken away (an order, the rescue): up where it lies."""
		_get_up(brain as BrainScript)

	func _get_up(walker: BrainScript) -> void:
		"""Stand up: the night's way from a bed, out of the infirmary's door, beside the spot from the ground."""
		if sleep != null:
			sleep.finish(walker)
		elif walker.lying:
			walker.task_rise(_field_at + Vector2(FIELD_GAP_M, 0.0))
		if where == WHERE_INFIRMARY and walker.indoors:
			walker.task_go_indoors(false, BrainScript.INTERIOR_NONE)
		_lying = false

	func in_place() -> bool:
		"""Whether it lies in its bed, in the infirmary, or on the ground at its spot: treatment may go on."""
		if sleep == null:
			return _lying
		return sleep.stage == SleepTaskScript.STAGE_ASLEEP

	func bedside() -> Vector2:
		"""Where the bed is got into, off its foot (the infirmary's door; the field-care spot)."""
		return sleep.bedside() if sleep != null else _field_at

	func urgent() -> bool:
		"""An emergency the night routine leaves be."""
		return true

	func holds_when_lost() -> bool:
		"""Lost on the way, back to its own routine (the infirmary sends it again)."""
		return false

	func label() -> String:
		"""What the panel says."""
		var how := "getting up" if bool(_up.call()) else ("hurt" if bool(_hurt.call()) else "recovering")
		if not in_place():
			return "Going to %s to rest (%s)" % [room_name, how]
		return ("Resting at %s (%s)" if where == WHERE_FIELD else "Resting in %s (%s)") % [room_name, how]


class Treat extends "res://demo/tunnel/tunnel_task.gd":
	"""A healer treating a patient (see the header)."""
	const STAGE_GOING: int = 0
	const STAGE_TO_SPOT: int = 1
	const STAGE_WORKING: int = 2
	const STAGE_BACK: int = 3
	var healer: int = -1
	var patient: int = -1
	var rest: BedRest = null
	var stage: int = STAGE_GOING
	var _patient_brain: BrainScript = null
	var _hurt: Callable = Callable()
	var _words: Callable = Callable()
	var _ended: Callable = Callable()

	func _init(h: int, rest_task: BedRest, patient_brain: BrainScript, hurt: Callable, words: Callable,
			ended: Callable) -> void:
		"""Healer `h` treats the patient resting under `rest_task`, while `hurt() -> bool`; `words() -> String` says the
		progress; `ended(healer, patient)` is told when it stops, for any reason."""
		healer = h
		rest = rest_task
		patient = rest_task.who
		_patient_brain = patient_brain
		_hurt = hurt
		_words = words
		_ended = ended

	func site(_brain: RefCounted) -> Vector2:
		"""The infirmary's door, or beside the field-care spot (a bed's walk goes by its node)."""
		if rest.where == WHERE_INFIRMARY:
			return rest.bedside()
		return rest.bedside() + Vector2(FIELD_GAP_M, 0.0)

	func site_node(_brain: RefCounted) -> int:
		"""The bed's room's middle node (-1: the surface)."""
		return rest.middle_node if rest.where == WHERE_BED else -1

	func spot() -> Vector2:
		"""Where the healer stands at a bed: beside its bedside, toward the room's middle."""
		var side := rest.bedside()
		return side + (rest.middle - side).normalized() * BESIDE_M if rest.middle.distance_to(side) > 1e-3 else side

	func arrived(brain: RefCounted) -> void:
		"""In the room: across to the bed. At the infirmary: in, and tend. At the spot: tend."""
		var walker := brain as BrainScript
		if rest.where == WHERE_BED:
			walker.task_hold_below()
			stage = STAGE_TO_SPOT
			return
		if rest.where == WHERE_INFIRMARY:
			walker.task_go_indoors(true, BrainScript.INTERIOR_INFIRMARY)
		stage = STAGE_WORKING

	func step(brain: RefCounted, delta: float) -> bool:
		"""One frame: to the bedside, then tend while the patient is hurt and resting under this rest; back to the middle
		once it is not (well again, or taken off its rest by an order)."""
		var walker := brain as BrainScript
		if stage != STAGE_BACK and stage != STAGE_GOING and (not bool(_hurt.call()) or _patient_brain.task != rest):
			stage = STAGE_BACK
		if stage == STAGE_TO_SPOT and walker.task_stroll_to(spot(), delta):
			stage = STAGE_WORKING
		elif stage == STAGE_WORKING:
			walker.task_face(rest.bedside(), delta)
			walker.task_play(WORK_CLIP if working() else BrainScript.CLIP_IDLE)
		elif stage == STAGE_BACK:
			return rest.where == WHERE_BED and not walker.task_stroll_to(rest.middle, delta)
		return true

	func working() -> bool:
		"""Whether the work counts now: beside the patient, who lies in its bed or at its spot."""
		return stage == STAGE_WORKING and rest.in_place()

	func finish(brain: RefCounted) -> void:
		"""Done: out of the infirmary's door, and the desk told."""
		_end(brain as BrainScript)

	func cancel(brain: RefCounted) -> void:
		"""Called away: the care work done so far stays the patient's (care_state.gd `book_care`)."""
		_end(brain as BrainScript)

	func _end(walker: BrainScript) -> void:
		"""Out of the infirmary's door, and the desk told, once."""
		if walker.indoors:
			walker.task_go_indoors(false, BrainScript.INTERIOR_NONE)
		if _ended.is_valid():
			_ended.call(healer, patient)
			_ended = Callable()

	func urgent() -> bool:
		"""Care is not parked by the night (see the header)."""
		return true

	func holds_when_lost() -> bool:
		"""Lost on the way, back to its own routine (the infirmary sends someone again)."""
		return false

	func label() -> String:
		"""What the panel says."""
		return String(_words.call())


class Gather extends "res://demo/tunnel/tunnel_task.gd":
	"""The herbalist gathering herbs (see the header)."""
	const STAGE_GOING: int = 0
	const STAGE_PICKING: int = 1
	const STAGE_CARRYING: int = 2
	const STAGE_DONE: int = 3
	var who: int = -1
	var stage: int = STAGE_GOING
	## The herb gathered so far this trip (milli-U), the work toward the next unit (milli-WU), and what a trip takes.
	var load_milli: int = 0
	var work_mwu: int = 0
	var trip_milli: int = 0
	var _patch: Vector2 = Vector2.ZERO
	var _shelf: Vector2 = Vector2.ZERO
	var _deliver: Callable = Callable()
	var _ended: Callable = Callable()

	func _init(i: int, patch: Vector2, shelf: Vector2, trip: int, deliver: Callable, ended: Callable) -> void:
		"""Resident `i` gathers `trip` milli-U at `patch` and carries it to `shelf`; `deliver(who, milli)` books it
		there; `ended(who)` is told when it stops, for any reason."""
		who = i
		_patch = patch
		_shelf = shelf
		trip_milli = trip
		_deliver = deliver
		_ended = ended

	func site(_brain: RefCounted) -> Vector2:
		"""The herb patch."""
		return _patch

	func arrived(brain: RefCounted) -> void:
		"""At the patch: pick. At the shelf: deliver."""
		if stage == STAGE_CARRYING:
			(brain as BrainScript).carrying = false
			_deliver.call(who, load_milli)
			load_milli = 0
			stage = STAGE_DONE
			return
		stage = STAGE_PICKING

	func step(brain: RefCounted, delta: float) -> bool:
		"""One frame: pick until the trip's load is gathered, then carry it to the shelf; false once delivered."""
		var walker := brain as BrainScript
		if stage == STAGE_PICKING:
			walker.task_face(_patch + Vector2(0.0, 0.6), delta)
			walker.task_play(WORK_CLIP)
			if load_milli >= trip_milli:
				stage = STAGE_CARRYING
				walker.task_carry_to(_shelf)
		return stage != STAGE_DONE

	func picking() -> bool:
		"""Whether the gathering work counts now."""
		return stage == STAGE_PICKING

	func finish(brain: RefCounted) -> void:
		"""Delivered."""
		_end(brain as BrainScript)

	func cancel(brain: RefCounted) -> void:
		"""Called away: what was picked is not taken (the patch is debited only at the shelf)."""
		_end(brain as BrainScript)

	func _end(walker: BrainScript) -> void:
		"""The infirmary told; the carry set down."""
		walker.carrying = false
		if _ended.is_valid():
			_ended.call(who)
			_ended = Callable()

	func holds_when_lost() -> bool:
		"""Lost on the way, back to its own routine."""
		return false

	func label() -> String:
		"""What the panel says."""
		if stage == STAGE_CARRYING:
			return "Carrying %.1f U of herbs to the hall's shelf" % (float(load_milli) / 1000.0)
		if stage == STAGE_PICKING:
			return "Gathering herbs — %.1f of %.1f U" % [float(load_milli) / 1000.0, float(trip_milli) / 1000.0]
		return "Going to gather herbs"

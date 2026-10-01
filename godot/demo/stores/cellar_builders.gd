extends RefCounted
## WHO BUILDS A CELLAR (decision 0612): residents fetch its materials from the village stores and build it, through the
## work board (work/stores_work.gd lists each place). Presentation only; the hall's flow (decision 0771) and its rules.
##
## PLACES. Each cellar has cellar_rules.gd `max_builders()` places (§5.9's "maximum 4 builders/project"), each worked by
## one resident at a time, handed out by the work board's claim to an idle resident who can carry (LORE-P12: no species
## lock). A place is WANTED while its cellar has a material left to fetch that the stores hold, or is being built.
##
## THE ROUND, every number cellar_rules.gd's:
##   DELIVERING  to the stockpile (the village stores) for the first material the cellar still needs, RESERVED as it sets
##               off (cellar_projects.gd `reserve`: at most its §5.2 carry of §5.5's 5000 g a unit); LIFT it there
##               (taken from the stores only now, REQ-SET-124); CARRY it to the cellar's site; PUT IT DOWN (delivered);
##               then again, while anything is left to fetch;
##   BUILDING    once everything is delivered (REQ-SET-125): to a spot by the cellar and WORK, its demo time added to the
##               cellar's (the builders' work sums), until it is built.
## Lifting and putting down are the farm's put-down work (1 WU each).
##
## CALLED AWAY (an order, the night, a release): a reservation is given up and a load in arms goes back into the stores
## whole -- it was never delivered (the bridges' and the hall's rule); the place waits for a resident again. A walk that
## fails MAX_TRIES times lets the resident go the same way and rests the place for RETRY_USEC. A cancelled cellar lets
## every resident on it go first (`release_cellar`).

const Rules := preload("res://demo/stores/cellar_rules.gd")
const ProjectsScript := preload("res://demo/stores/cellar_projects.gd")
const FarmJobs := preload("res://demo/farm/farm_jobs.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const SpotScript := preload("res://demo/stores/stand_spot.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

const NOBODY: int = -1
const NONE: int = -1
const STEP_TO_STORE: int = 0
const STEP_LIFT: int = 1
const STEP_CARRY: int = 2
const STEP_PUT_DOWN: int = 3
const STEP_TO_WORK: int = 4
const STEP_WORK: int = 5
const STEP_WORDS: Array[String] = ["Going to the stockpile for %s for the %s", "Lifting %s for the %s",
	"Carrying %s to the %s", "Setting %s down at the %s", "Going to build the %s", "Building the %s"]
const LIFT_USEC: int = FarmJobs.WORK_WU[FarmJobs.WORK_DROP] * FarmJobs.DEMO_USEC_PER_WU
const PUT_DOWN_USEC: int = LIFT_USEC
const ARRIVE_M: float = 0.4
const RING_GAP_M: float = 0.45
const MAX_TRIES: int = 3
## A place whose walks failed rests this long before it is wanted again (demo value).
const RETRY_USEC: int = 10000000
const WORK_CLIP: StringName = &"collect_object"
## What each material is carried as: a timber, a basket of stone.
const CARRY_KEYS: Array[StringName] = [&"bridge_plank", &"basket"]
const CANT_CARRY: String = "can't carry a load"
const OTHER_PLACE: String = "builds another part of a cellar"
const IN_HAND: String = "the load is in hand — it is set down first"
const GONE: String = "that place is no longer on the board"

var worker: PackedInt32Array = PackedInt32Array()
var step: PackedByteArray = PackedByteArray()
var issued: PackedByteArray = PackedByteArray()
var mat: PackedInt32Array = PackedInt32Array()
var reserve_milli: PackedInt64Array = PackedInt64Array()
var load_milli: PackedInt64Array = PackedInt64Array()
var elapsed_usec: PackedInt64Array = PackedInt64Array()
var tries: PackedInt32Array = PackedInt32Array()
var goal: PackedVector2Array = PackedVector2Array()
var paused: PackedByteArray = PackedByteArray()
var rest_usec: PackedInt64Array = PackedInt64Array()
var revision: int = 0

var projects: ProjectsScript = null
var _cast: DemoCastScript = null
var _props: PropsScript = null
var _store_at: Vector2 = Vector2.ZERO
var _found: Vector2 = Vector2.ZERO
var _spot: PackedVector2Array = PackedVector2Array([Vector2.ZERO])


func _init(p_projects: ProjectsScript) -> void:
	"""Places for every cellar (packed columns are values: each is sized by name)."""
	projects = p_projects
	var rows: int = capacity()
	worker.resize(rows)
	step.resize(rows)
	issued.resize(rows)
	mat.resize(rows)
	reserve_milli.resize(rows)
	load_milli.resize(rows)
	elapsed_usec.resize(rows)
	tries.resize(rows)
	goal.resize(rows)
	paused.resize(rows)
	rest_usec.resize(rows)
	worker.fill(NOBODY)
	mat.fill(NONE)


func configure(cast: DemoCastScript, props: PropsScript, store_at: Vector2) -> void:
	"""Build with this cast, drawing loads from `props` (null: none drawn), fetching from the stores at `store_at`."""
	_cast = cast
	_props = props
	_store_at = store_at


static func capacity() -> int:
	"""Every place of every cellar."""
	return ProjectsScript.MAX_CELLARS * Rules.max_builders()


static func cellar_of(row: int) -> int:
	"""The cellar place `row` belongs to."""
	@warning_ignore("integer_division")  # the cellar's row by intent
	var c: int = row / Rules.max_builders()
	return c


# --- the board ------------------------------------------------------------------------------------

func wanted(row: int) -> bool:
	"""Whether place `row` has work: its cellar is being built, or needs a material the stores hold (see PLACES)."""
	var c: int = cellar_of(row)
	if rest_usec[row] > 0 or not projects.is_active(c):
		return false
	return projects.state[c] == ProjectsScript.STATE_BUILDING or projects.next_material(c) != NONE


func is_live(row: int) -> bool:
	"""Whether place `row` is on the board: worked, wanted or paused."""
	return worker[row] != NOBODY or (projects.is_active(cellar_of(row)) and (paused[row] == 1 or wanted(row)))


func waiting(row: int) -> bool:
	"""Whether place `row` waits for a resident and may be claimed now."""
	return worker[row] == NOBODY and paused[row] == 0 and wanted(row)


func carrying(row: int) -> bool:
	"""Whether place `row`'s resident has a load in arms."""
	return worker[row] != NOBODY and load_milli[row] > 0


func row_of_worker(who: int) -> int:
	"""The place resident `who` works, or NONE."""
	return worker.find(who) if who >= 0 else NONE


func eligibility(row: int, who: int) -> String:
	"""Why resident `who` could not take place `row` ("" when it could)."""
	if who < 0 or who >= _cast.actor_count() or not _brain(who).can_carry():
		return CANT_CARRY
	var had: int = row_of_worker(who)
	return OTHER_PLACE if had != NONE and had != row else ""


func claim(row: int, who: int) -> bool:
	"""Hand waiting place `row` to `who`, who sets off on its round. False when it was not taken."""
	if not waiting(row) or not eligibility(row, who).is_empty():
		return false
	worker[row] = who
	if not _next_round(row):
		worker[row] = NOBODY
		return false
	return true


func pause(row: int, on: bool) -> String:
	"""Pause place `row` (its resident let go) or let it wait again: "" when done, else why not."""
	if not projects.is_active(cellar_of(row)):
		return GONE
	if carrying(row):
		return IN_HAND
	if on:
		let_go(row)
	paused[row] = 1 if on else 0
	revision += 1
	return ""


func reassign(row: int, who: int) -> String:
	"""Give place `row` to `who` instead: "" when done, else why not (nothing changed -- a pause kept)."""
	var why: String = eligibility(row, who)
	if why.is_empty() and carrying(row):
		why = IN_HAND
	if why.is_empty() and not wanted(row):
		why = "there is nothing there to do now"
	if not why.is_empty():
		return why
	let_go(row)
	paused[row] = 0
	return "" if claim(row, who) else "there is nothing there to do now"


func release_cellar(c: int) -> void:
	"""Let every resident on cellar `c` go (it is being cancelled): reservations given up, loads back in the stores."""
	for row: int in capacity():
		if cellar_of(row) == c:
			let_go(row)
			paused[row] = 0


# --- the round (see THE ROUND) ---------------------------------------------------------------------

func _next_round(row: int) -> bool:
	"""Set place `row`'s resident on its next round: fetch a material, or build. False when there is nothing to do."""
	var c: int = cellar_of(row)
	if projects.state[c] == ProjectsScript.STATE_BUILDING:
		_start(row, STEP_TO_WORK)
		return true
	var m: int = projects.next_material(c) if projects.is_active(c) else NONE
	if m == NONE:
		return false
	var size: int = MealRules.size_of_species((_cast.actor(worker[row]) as DemoActorScript).species)
	reserve_milli[row] = projects.reserve(c, m, Rules.carry_milli(size, m))
	if reserve_milli[row] <= 0:
		return false
	mat[row] = m
	_start(row, STEP_TO_STORE)
	return true


func _start(row: int, at_step: int) -> void:
	"""Begin step `at_step` afresh."""
	step[row] = at_step
	issued[row] = 0
	elapsed_usec[row] = 0
	tries[row] = 0
	revision += 1


func update(usec: int) -> void:
	"""One frame of every place, `usec` microseconds of demo time (0 while paused)."""
	for row: int in capacity():
		rest_usec[row] = maxi(0, rest_usec[row] - usec)
		if worker[row] == NOBODY:
			continue
		if not projects.is_active(cellar_of(row)):
			let_go(row)
		elif step[row] == STEP_TO_STORE or step[row] == STEP_CARRY or step[row] == STEP_TO_WORK:
			_step_walk(row)
		else:
			_step_work(row, usec)


func _step_walk(row: int) -> void:
	"""Issue the walk, then wait to ARRIVE (decision 0361); called away, the place waits again; MAX_TRIES failed walks
	rest it."""
	var brain: BrainScript = _brain(worker[row])
	if issued[row] == 0:
		_issue_walk(row, brain)
		return
	if brain.order != BrainScript.ORDER_MOVE or brain.goal() != goal[row]:
		_unassign(row)
		return
	if brain.state != BrainScript.State.HOLD:
		return
	if brain.arrived_near(goal[row], ARRIVE_M):
		step[row] += 1
		issued[row] = 0
		elapsed_usec[row] = 0
		tries[row] = 0
		return
	tries[row] += 1
	issued[row] = 0
	if tries[row] >= MAX_TRIES:
		_give_up(row)


func _issue_walk(row: int, brain: BrainScript) -> void:
	"""Send the resident to the stockpile, with its load to the site, or to a spot by the cellar to build."""
	var c: int = cellar_of(row)
	var target: Vector2 = _store_at
	var first: float = RING_GAP_M
	if step[row] == STEP_CARRY:
		target = projects.site_of(c)
	elif step[row] == STEP_TO_WORK:
		target = projects.at[c]
		first = ProjectsScript.RADIUS_M + RING_GAP_M
	if not _spot_near(target, first + RING_GAP_M * tries[row], brain):
		_give_up(row)
		return
	goal[row] = _found
	issued[row] = 1
	if step[row] == STEP_CARRY:
		brain.order_carry(_found, target)
	else:
		brain.order_move(_found, target)


func _step_work(row: int, usec: int) -> void:
	"""Lift, put down or build, the resident still ARRIVED at its spot (else back to the walk, nothing done)."""
	var brain: BrainScript = _brain(worker[row])
	if brain.state != BrainScript.State.HOLD or brain.order != BrainScript.ORDER_MOVE:
		_unassign(row)
		return
	if not brain.arrived_near(goal[row], ARRIVE_M):
		step[row] -= 1
		issued[row] = 0
		elapsed_usec[row] = 0
		return
	brain.play_in_place(WORK_CLIP if brain.has_clip(WORK_CLIP) else BrainScript.CLIP_IDLE)
	elapsed_usec[row] += usec
	if step[row] == STEP_LIFT and elapsed_usec[row] >= LIFT_USEC:
		_lift(row)
	elif step[row] == STEP_PUT_DOWN and elapsed_usec[row] >= PUT_DOWN_USEC:
		_put_down(row)
	elif step[row] == STEP_WORK:
		_work(row, usec)


func _lift(row: int) -> void:
	"""Take the reserved load from the stores and set off with it; with nothing to take, the round ends."""
	var amount: int = projects.lift(cellar_of(row), mat[row], reserve_milli[row])
	reserve_milli[row] = 0
	if amount <= 0:
		_end(row)
		return
	load_milli[row] = amount
	_hold_load(row, true)
	_start(row, STEP_CARRY)


func _put_down(row: int) -> void:
	"""The load is delivered (a cellar no longer taking deliveries: it goes back into the stores); then the next round,
	or the end."""
	if not projects.deliver(cellar_of(row), mat[row], load_milli[row]):
		projects.return_load(cellar_of(row), mat[row], load_milli[row])
	load_milli[row] = 0
	_hold_load(row, false)
	if not _next_round(row):
		_end(row)


func _work(row: int, usec: int) -> void:
	"""The builder's time into the cellar; built, every builder on it is done."""
	if projects.add_work(cellar_of(row), usec):
		var c: int = cellar_of(row)
		for other: int in capacity():
			if cellar_of(other) == c and worker[other] != NOBODY:
				_end(other)


# --- ending ---------------------------------------------------------------------------------------

func _give_up(row: int) -> void:
	"""Nowhere reachable: the resident is let go (its load back in the stores) and the place rests RETRY_USEC."""
	rest_usec[row] = RETRY_USEC
	_end(row)


func _end(row: int) -> void:
	"""The resident's part is over: back to its routine (or its next unfinished job)."""
	let_go(row)


func let_go(row: int) -> void:
	"""Take place `row`'s resident off it (`_unassign`) and send it back to its routine."""
	var who: int = worker[row]
	_unassign(row)
	if who != NOBODY and who < _cast.actor_count():
		var brain: BrainScript = _brain(who)
		brain.play_in_place(BrainScript.CLIP_IDLE)
		brain.work_done()


func _unassign(row: int) -> void:
	"""No resident: its reservation given up, its load back in the stores whole (never delivered), the place waiting."""
	var c: int = cellar_of(row)
	if reserve_milli[row] > 0:
		projects.unreserve(c, mat[row], reserve_milli[row])
	if load_milli[row] > 0:
		projects.return_load(c, mat[row], load_milli[row])
	if worker[row] != NOBODY:
		_hold_load(row, false)
	reserve_milli[row] = 0
	load_milli[row] = 0
	worker[row] = NOBODY
	mat[row] = NONE
	revision += 1


# --- words and helpers -----------------------------------------------------------------------------

func doing_text(who: int) -> String:
	"""What resident `who` is doing for a cellar, in the party panel's words ("" for nothing)."""
	var row: int = row_of_worker(who)
	if row == NONE:
		return ""
	var cellar: String = (Rules.LABEL % (cellar_of(row) + 1)).to_lower()
	if step[row] >= STEP_TO_WORK:
		return STEP_WORDS[step[row]] % cellar
	return STEP_WORDS[step[row]] % [Rules.MAT_WORDS[maxi(mat[row], 0)], cellar]


func in_hand_milli(m: int) -> int:
	"""What of a material residents carry for cellars now, milli-U (the books' third place)."""
	var held: int = 0
	for row: int in capacity():
		if mat[row] == m:
			held += load_milli[row]
	return held


func builders_on(c: int) -> int:
	"""How many residents work cellar `c`."""
	var n: int = 0
	for row: int in capacity():
		if cellar_of(row) == c and worker[row] != NOBODY:
			n += 1
	return n


func _brain(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func _hold_load(row: int, on: bool) -> void:
	"""The load in the resident's arms -- a timber or a basket of stone -- or nothing."""
	var actor := _cast.actor(worker[row]) as DemoActorScript
	if not on or _props == null or mat[row] < 0:
		if actor.holding():
			actor.drop_held()
		return
	var key: StringName = CARRY_KEYS[mat[row]]
	var bound: AABB = _props.drawn_bound(key)
	actor.hold(_props.mesh_of(key), Transform3D(Basis.IDENTITY, -bound.get_center()) * _props.fit_of(key))


func _spot_near(target: Vector2, first_ring: float, brain: BrainScript) -> bool:
	"""The spot to stand at round `target` (stand_spot.gd), into `_found`. False when there is none."""
	if not SpotScript.find_into(_cast, target, first_ring, brain, _spot):
		return false
	_found = _spot[0]
	return true

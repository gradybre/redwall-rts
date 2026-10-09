extends RefCounted
## THE HALL'S BUILDERS (decision 0771): who carries a hall project's materials in and builds it. Presentation only.
##
## PLACES. Each project has places (hall_rules.gd ROWS: the upgrade's four -- §5.9's "maximum 4 builders/project" --
## then one per banner), each worked by one resident at a time. A place is handed out by the work board
## (work/hall_work.gd: any idle eligible resident, the Builders crew first), or to the residents selected when the
## player plans or right-clicks the hall (`give`). Anybeast on land may build (LORE-P12).
##
## THE ROUND, one hall_task.gd each, every number here:
##   DELIVERING  to the stockpile (the village stores) for one material the project still needs and the stores hold,
##               RESERVED as it sets off; LIFT it there (LOAD_USEC: taken from the stores now, as much as is there,
##               never more than its §5.2 carry capacity at §5.7's masses); CARRY it to the hall's site pile; SET IT
##               DOWN (PUT_DOWN_USEC: delivered); then again, while anything is left to fetch;
##   BUILDING    once all of it is delivered (REQ-SET-125): to its place before the hall and WORK, its demo time
##               credited to the project (hall_projects.gd `add_work`; the builders' work sums).
## A place with nothing left for it (the rest is in others' arms, or the stores are out) ends; the work board hands it
## out again when there is.
##
## CALLED AWAY (an order, the night, a release, a walk it could not finish): a reservation is given up, a load in arms
## goes back into the stores whole (it was never delivered: the bridges' rule, bridge_crew.gd `_drop`), and the
## resident keeps the project to come back to (hall_resume.gd). Carrying, it is not taken to bed first (decision
## 0222). The player's PAUSE, REASSIGN and a cancelled project let the resident go the same way, with nothing to come
## back to.

const Rules := preload("res://demo/hall/hall_rules.gd")
const ProjectsScript := preload("res://demo/hall/hall_projects.gd")
const TaskScript := preload("res://demo/hall/hall_task.gd")
const ResumeScript := preload("res://demo/hall/hall_resume.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const PlacesScript := preload("res://demo/kitchen/kitchen_places.gd")
const MealRules := preload("res://demo/kitchen/meal_rules.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const Measures := preload("res://scripts/ui/goods_measures.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")

const NOBODY: int = -1
const STEP_NONE: int = 0
const STEP_TO_STORE: int = 1
const STEP_LOAD: int = 2
const STEP_CARRY: int = 3
const STEP_PUT_DOWN: int = 4
const STEP_TO_WORK: int = 5
const STEP_WORK: int = 6
const WALK_STEPS: Array[int] = [STEP_TO_STORE, STEP_CARRY, STEP_TO_WORK]
const STEP_WORDS: Array[String] = ["", "Going to the stockpile for %s", "Lifting %s", "Carrying %s to the hall",
	"Setting %s down at the hall", "Going to work on %s", "Building %s"]
## What each material is carried as (props: a timber, a basket of stone, a folded cloth).
const CARRY_KEYS: Array[StringName] = [&"bridge_plank", &"basket", &"relic_banner"]
const CLIP_HEAVY: StringName = &"pull_radish"
const CLIP_WORK: StringName = &"collect_object"
const NOT_YOURS: String = "nobody to give it to"
const OTHER_PLACE: String = "builds another part of the hall"
const CANT_TAKE: String = "there is nothing it could do there now"

## Per place (board row): who works it, its step, whether that step's walk was issued, the material and the
## reservation it set off for, the load in its arms, the time spent at the step's work, and where it walks.
var worker: PackedInt32Array = PackedInt32Array()
var step: PackedByteArray = PackedByteArray()
var issued: PackedByteArray = PackedByteArray()
var load_mat: PackedInt32Array = PackedInt32Array()
var reserve_milli: PackedInt64Array = PackedInt64Array()
var load_milli: PackedInt64Array = PackedInt64Array()
var elapsed_usec: PackedInt64Array = PackedInt64Array()
var target: PackedVector2Array = PackedVector2Array()
## Per place: the generation of the project planning the player paused it in (-1: not paused).
var paused_gen: PackedInt32Array = PackedInt32Array()
var revision: int = 0

var _projects: ProjectsScript = null
var _cast: DemoCastScript = null
var _props: PropsScript = null
var _calendar: CalendarScript = null
var _store_at: Vector2 = Vector2.ZERO
var _site_at: Vector2 = Vector2.ZERO
var _hall_at: Vector2 = Vector2.ZERO
var _work_at: PackedVector2Array = PackedVector2Array()
var _face_at: PackedVector2Array = PackedVector2Array()
var _tasks: Array[TaskScript] = []
## Set while the crew itself lets a resident go (`let_go`): the resident's work_done must not hand it straight back a
## place on the same project through an older resume record (`take_back` refuses meanwhile).
var _letting_go: bool = false


func configure(projects: ProjectsScript, cast: DemoCastScript, props: PropsScript, calendar: CalendarScript) -> void:
	"""Build `projects` with this cast (its props carried; none: carried unseen), dated by `calendar`."""
	_projects = projects
	_cast = cast
	_props = props
	_calendar = calendar
	worker.resize(Rules.ROWS)
	worker.fill(NOBODY)
	load_mat.resize(Rules.ROWS)
	load_mat.fill(NOBODY)
	step.resize(Rules.ROWS)
	issued.resize(Rules.ROWS)
	reserve_milli.resize(Rules.ROWS)
	load_milli.resize(Rules.ROWS)
	elapsed_usec.resize(Rules.ROWS)
	target.resize(Rules.ROWS)
	paused_gen.resize(Rules.ROWS)
	paused_gen.fill(-1)
	_tasks.resize(Rules.ROWS)


func set_places(store_at: Vector2, site_at: Vector2, hall_at: Vector2, work_at: PackedVector2Array,
		face_at: PackedVector2Array) -> void:
	"""Where the stores are fetched from, where loads are set down, the hall's middle, and each place's work spot and
	the point it faces (ROWS each)."""
	_store_at = store_at
	_site_at = site_at
	_hall_at = hall_at
	_work_at = work_at
	_face_at = face_at


# --- who may build ----------------------------------------------------------------------------------------------

func brain_of(who: int) -> BrainScript:
	"""Resident `who`'s brain."""
	return (_cast.actor(who) as DemoActorScript).brain


func is_resident(who: int) -> bool:
	"""Whether `who` names one of the cast."""
	return _cast != null and who >= 0 and who < _cast.actor_count()


func eligibility(who: int) -> String:
	"""Why `who` could not take a place now ("" when it could): on land, free of the water's rescue, on no other place."""
	if not is_resident(who):
		return NOT_YOURS
	var brain: BrainScript = brain_of(who)
	if brain.water_hold:
		return WorkIds.HELD
	if brain.in_water:
		return WorkIds.IN_WATER
	return OTHER_PLACE if worker.has(who) else ""


func wanted(row: int) -> bool:
	"""Whether place `row`'s project has something for one more pair of hands now."""
	var p: int = Rules.row_project(row)
	if not _projects.is_active(p):
		return false
	return _projects.phase[p] == ProjectsScript.PHASE_BUILDING or _projects.next_material(p) >= 0


func is_paused(row: int) -> bool:
	"""Whether the player paused place `row` in its project's current planning."""
	var p: int = Rules.row_project(row)
	return _projects.is_active(p) and paused_gen[row] == _projects.generation[p]


func waiting(row: int) -> bool:
	"""Whether place `row` waits for a builder now: its project active, nobody on it, not paused, something to do."""
	return Rules.row_project(row) >= 0 and worker[row] == NOBODY and not is_paused(row) and wanted(row)


func key(row: int) -> int:
	"""Place `row`'s task key: its project's planning and the place (a re-planned project is a new task)."""
	var p: int = Rules.row_project(row)
	return _projects.generation[p] * Rules.ROWS + row if p >= 0 else -1


# --- handing out --------------------------------------------------------------------------------------------------

func give(row: int, who: int) -> bool:
	"""Resident `who` takes waiting place `row` and sets off at once (taken off whatever it was doing). False when the
	place does not wait, `who` may not take it, or nothing is left for it to do."""
	if not waiting(row) or not eligibility(who).is_empty():
		return false
	worker[row] = who
	if not _plan_next(row):
		worker[row] = NOBODY
		return false
	var p: int = Rules.row_project(row)
	var task := TaskScript.new(self, row, p, _projects.generation[p])
	_tasks[row] = task
	issued[row] = 1
	brain_of(who).order_task(task)
	if brain_of(who).task != task:
		_clear_row(row)
		return false
	revision += 1
	return true


func give_selected(project: int, members: PackedInt32Array) -> int:
	"""Each of `members` takes one waiting place of `project`, in place order. How many were given."""
	var given: int = 0
	var first: int = Rules.first_row(project)
	for who: int in members:
		for row: int in range(first, first + Rules.places_of(project)):
			if waiting(row) and give(row, who):
				given += 1
				break
	return given


func take_back(brain: RefCounted, project: int, generation: int) -> bool:
	"""A resident called away comes back to `project`'s same planning: a waiting place, if any (never while the crew is
	letting someone go: see `_letting_go`)."""
	if _letting_go or not _projects.is_active(project) or _projects.generation[project] != generation:
		return false
	var who: int = (brain as BrainScript).index
	var first: int = Rules.first_row(project)
	for row: int in range(first, first + Rules.places_of(project)):
		if waiting(row) and give(row, who):
			return true
	return false


# --- the round ----------------------------------------------------------------------------------------------------

func _plan_next(row: int) -> bool:
	"""Place `row`'s next step: fetch a material while delivering, else to the work while building. False when nothing
	is left for it."""
	var p: int = Rules.row_project(row)
	issued[row] = 0
	elapsed_usec[row] = 0
	if _projects.phase[p] == ProjectsScript.PHASE_BUILDING:
		step[row] = STEP_TO_WORK
		target[row] = _spot(row, _work_at[row])
		return true
	var mat: int = _projects.next_material(p) if _projects.phase[p] == ProjectsScript.PHASE_DELIVERING else -1
	if mat < 0:
		step[row] = STEP_NONE
		return false
	var size: int = MealRules.size_of_species((_cast.actor(worker[row]) as DemoActorScript).species)
	reserve_milli[row] = _projects.reserve(p, mat, Rules.load_milli(size, mat))
	load_mat[row] = mat
	step[row] = STEP_TO_STORE if reserve_milli[row] > 0 else STEP_NONE
	target[row] = _spot(row, _store_at)
	return reserve_milli[row] > 0


func _spot(row: int, at: Vector2) -> Vector2:
	"""The clear, reachable spot nearest `at` for place `row`'s resident (`at` itself when none is found)."""
	var brain: BrainScript = brain_of(worker[row])
	return PlacesScript.spot_near(brain.space(), brain.space().bounds, at, at, brain.position)


func first_site(row: int) -> Vector2:
	"""Where place `row`'s resident walks first (hall_task.gd `site`)."""
	return target[row]


func arrived(row: int, task: TaskScript) -> void:
	"""Place `row`'s resident reached the end of its walk: the step's work begins."""
	if _tasks[row] != task:
		return
	elapsed_usec[row] = 0
	match step[row]:
		STEP_TO_STORE:
			step[row] = STEP_LOAD
		STEP_CARRY:
			step[row] = STEP_PUT_DOWN
		STEP_TO_WORK:
			step[row] = STEP_WORK
	revision += 1


func drive(row: int, task: TaskScript, brain: BrainScript, delta: float) -> bool:
	"""One frame of place `row` (hall_task.gd `step`): issue the walk, or stand at the work. False once over."""
	if _tasks[row] != task or not _projects.is_active(task.project) or task.generation != _projects.generation[
			task.project]:
		return false
	var usec: int = maxi(int(delta * 1000000.0), 0)
	if WALK_STEPS.has(step[row]):
		if issued[row] == 0:
			_issue(row, brain)
		return true
	match step[row]:
		STEP_LOAD:
			return _drive_load(row, brain, usec, delta)
		STEP_PUT_DOWN:
			return _drive_put_down(row, brain, usec, delta)
		STEP_WORK:
			return _drive_work(row, brain, usec, delta)
	return false


func _issue(row: int, brain: BrainScript) -> void:
	"""Send place `row`'s resident on its step's walk (loaded, carrying its material's prop, on the carry walk)."""
	issued[row] = 1
	if step[row] != STEP_CARRY:
		brain.task_walk_to(target[row])
		return
	_hold(row, true)
	brain.task_carry_to(target[row])


func _drive_load(row: int, brain: BrainScript, usec: int, delta: float) -> bool:
	"""At the stockpile: lift the load (LOAD_USEC), taking it from the stores; then carry it to the hall."""
	brain.task_face(_store_at, delta)
	brain.task_play(CLIP_HEAVY)
	elapsed_usec[row] += usec
	if elapsed_usec[row] < Rules.LOAD_USEC:
		return true
	var p: int = Rules.row_project(row)
	var got: int = _projects.lift(p, load_mat[row], reserve_milli[row])
	reserve_milli[row] = 0
	if got <= 0:
		return _plan_next(row)
	load_milli[row] = got
	step[row] = STEP_CARRY
	issued[row] = 0
	target[row] = _spot(row, _site_at)
	revision += 1
	return true


func _drive_put_down(row: int, brain: BrainScript, usec: int, delta: float) -> bool:
	"""At the hall's site pile: set the load down (PUT_DOWN_USEC) -- delivered -- and plan the next step."""
	brain.task_face(_site_at, delta)
	brain.task_play(CLIP_WORK)
	elapsed_usec[row] += usec
	if elapsed_usec[row] < Rules.PUT_DOWN_USEC:
		return true
	_projects.deliver(Rules.row_project(row), load_mat[row], load_milli[row])
	load_milli[row] = 0
	_hold(row, false)
	revision += 1
	return _plan_next(row)


func _drive_work(row: int, brain: BrainScript, usec: int, delta: float) -> bool:
	"""Before the hall: work, the time credited to the project; false once it is finished."""
	var p: int = Rules.row_project(row)
	if _projects.phase[p] != ProjectsScript.PHASE_BUILDING:
		return false
	brain.task_face(_face_at[row], delta)
	brain.task_play(CLIP_HEAVY if p == Rules.PROJECT_UPGRADE else CLIP_WORK)
	var tick: int = _calendar.tick if _calendar != null else 0
	return not _projects.add_work(p, usec, tick)


func _hold(row: int, on: bool) -> void:
	"""Show (or put away) place `row`'s load in its resident's arms; nothing with no props."""
	var actor := _cast.actor(worker[row]) as DemoActorScript
	if not on:
		if actor.holding():
			actor.drop_held()
		return
	if _props == null or load_mat[row] < 0:
		return
	var carried: StringName = CARRY_KEYS[load_mat[row]]
	var bound: AABB = _props.drawn_bound(carried)
	actor.hold(_props.mesh_of(carried), Transform3D(Basis.IDENTITY, -bound.get_center()) * _props.fit_of(carried))


# --- ending -------------------------------------------------------------------------------------------------------

func part_over(row: int, task: TaskScript) -> void:
	"""Place `row`'s task ended or was called away (see CALLED AWAY)."""
	if _tasks[row] == task:
		_clear_row(row)


func _clear_row(row: int) -> void:
	"""Place `row` is free: a reservation given up, a load in arms back in the stores whole, its prop put away."""
	var p: int = Rules.row_project(row)
	if reserve_milli[row] > 0:
		_projects.unreserve(p, load_mat[row], reserve_milli[row])
	if load_milli[row] > 0:
		_projects.return_load(p, load_mat[row], load_milli[row])
	if worker[row] != NOBODY:
		_hold(row, false)
	reserve_milli[row] = 0
	load_milli[row] = 0
	load_mat[row] = NOBODY
	worker[row] = NOBODY
	step[row] = STEP_NONE
	issued[row] = 0
	_tasks[row] = null
	revision += 1


func unfinished_of(task: TaskScript) -> RefCounted:
	"""The project `task`'s resident was called away from, to come back to (null when it is no longer that planning; a
	place the crew let go -- a pause -- never gets here: its task says `let_go`)."""
	var p: int = task.project
	if not _projects.is_active(p) or _projects.generation[p] != task.generation:
		return null
	var resume := ResumeScript.new(self, p, task.generation)
	return UnfinishedScript.new(resume.take_back, "%s at the hall" % project_verb(p), WorkIds.SOURCE_HALL,
		key(task.row))


func let_go(row: int) -> void:
	"""The crew lets place `row`'s resident go (back to its order list or routine), with nothing to come back to."""
	var who: int = worker[row]
	if who == NOBODY:
		return
	var task: TaskScript = _tasks[row]
	if task != null:
		task.let_go = true
	_clear_row(row)
	if brain_of(who).task == task:
		_letting_go = true
		brain_of(who).work_done()
		_letting_go = false


func release_project(project: int) -> void:
	"""Every place of `project` lets its resident go (a cancelled project): loads back in the stores whole."""
	var first: int = Rules.first_row(project)
	for row: int in range(first, first + Rules.places_of(project)):
		let_go(row)
		paused_gen[row] = -1


# --- the player's commands (the Work screen) ----------------------------------------------------------------------

func pause(row: int, on: bool) -> String:
	"""Pause place `row` (its resident let go, a load back in the stores) or resume it: "" when done, else why not."""
	var p: int = Rules.row_project(row)
	if not _projects.is_active(p):
		return WorkIds.NOT_FOUND
	if not on:
		paused_gen[row] = -1
		return ""
	if is_paused(row):
		return WorkIds.PAUSED_ALREADY
	paused_gen[row] = _projects.generation[p]
	let_go(row)
	revision += 1
	return ""


func reassign(row: int, who: int) -> String:
	"""Give place `row` to `who` instead (the one on it let go first): "" when done, else why not."""
	if not _projects.is_active(Rules.row_project(row)):
		return WorkIds.NOT_FOUND
	if worker[row] == who and who != NOBODY:
		return ""
	var why: String = eligibility(who)
	if not why.is_empty():
		return why
	let_go(row)
	paused_gen[row] = -1
	return "" if give(row, who) else CANT_TAKE


# --- words --------------------------------------------------------------------------------------------------------

static func project_verb(project: int) -> String:
	"""A project's work in words: "Raise the great hall", "Hang a banner"."""
	return "Raise the great hall" if project == Rules.PROJECT_UPGRADE else "Hang a banner"


static func project_noun(project: int) -> String:
	"""A project as the object of a sentence: "the hall's upgrade", "a banner"."""
	return "the hall's upgrade" if project == Rules.PROJECT_UPGRADE else "a banner"


func doing_text(row: int) -> String:
	"""What place `row`'s resident is doing, in words ("" for nobody)."""
	if worker[row] == NOBODY or step[row] == STEP_NONE:
		return ""
	var p: int = Rules.row_project(row)
	var words: String = STEP_WORDS[step[row]]
	if step[row] >= STEP_TO_WORK:
		return words % project_noun(p)
	var mat: String = Rules.MAT_NAMES[maxi(load_mat[row], 0)]
	if step[row] == STEP_CARRY or step[row] == STEP_PUT_DOWN:
		mat = Measures.amount(StringName(mat), load_milli[row])
	return words % mat


func carrying(row: int) -> bool:
	"""Whether place `row`'s resident has a load in its arms."""
	return load_milli[row] > 0


func walking(row: int) -> bool:
	"""Whether place `row`'s resident is on a walk step."""
	return worker[row] != NOBODY and WALK_STEPS.has(step[row])


func builders_on(project: int) -> int:
	"""How many residents work `project` now (none before the crew is configured)."""
	if worker.size() < Rules.ROWS:
		return 0
	var n: int = 0
	var first: int = Rules.first_row(project)
	for row: int in range(first, first + Rules.places_of(project)):
		n += 1 if worker[row] != NOBODY else 0
	return n


func names_on(project: int) -> String:
	"""The residents on `project` now, by name ("" none, or before the crew is configured)."""
	if worker.size() < Rules.ROWS or _cast == null:
		return ""
	var names := PackedStringArray()
	var first: int = Rules.first_row(project)
	for row: int in range(first, first + Rules.places_of(project)):
		if worker[row] != NOBODY:
			names.append((_cast.actor(worker[row]) as DemoActorScript).display_name)
	return ", ".join(names)

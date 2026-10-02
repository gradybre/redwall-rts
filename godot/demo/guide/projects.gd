extends RefCounted
## PLAYER-NAMED PROJECTS (decision 0481; review UX-020): up to MAX_PROJECTS pinned projects of the player's own -- a
## NAME, the PLACES it is about (what was selected when it was pinned: a bed, a tunnel, residents) and one simple
## MEASURE with a target ("Wood in store reaches 60.0 U", "2 bridges open", "10.0 U harvested from now"). The measure
## is read from the village's own figures (guide_world.gd), never from anything the project keeps itself; when it
## reaches its target the project is DONE, once, and its CHRONICLE entry goes into the village news history (the
## Village source, decision 0331's history) with the before and after figures and a Go to its first place. A done
## project stays pinned, ticked, until removed. Session only: nothing is saved (the demo cannot save).
##
## "From now" measures (harvested, suppers) count from the moment the project is pinned; the rest are levels.

const WorldScript := preload("res://demo/guide/guide_world.gd")
const FactsScript := preload("res://demo/guide/guide_facts.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const FarmText := preload("res://demo/farm/farm_text.gd")

const MAX_PROJECTS: int = 3
const MAX_PLACES: int = 3
const NAME_MAX: int = 32
const MEASURE_WOOD: int = 0
const MEASURE_PLANKS: int = 1
const MEASURE_STONE: int = 2
const MEASURE_READY_FOOD: int = 3
const MEASURE_HARVESTED: int = 4
const MEASURE_SUPPERS: int = 5
const MEASURE_BRIDGES: int = 6
const MEASURE_TUNNELS: int = 7
const MEASURE_COUNT: int = 8
const MEASURE_NAMES: Array[String] = ["Wood in store", "Planks in store", "Stone in store", "Ready food",
	"Harvested into store from now", "Suppers eaten from now", "Bridges open", "Tunnel stretches open"]
## Whether a measure counts from when the project is pinned (else it is a level).
const FROM_NOW: Array[bool] = [false, false, false, false, true, true, false, false]
## Units: milli-U (shown "12.0 U"), milli-days ("2.5 days") or a plain count.
const UNIT_MILLI: int = 0
const UNIT_DAYS: int = 1
const UNIT_COUNT: int = 2
const UNITS: Array[int] = [UNIT_MILLI, UNIT_MILLI, UNIT_MILLI, UNIT_DAYS, UNIT_MILLI, UNIT_COUNT, UNIT_COUNT, UNIT_COUNT]
## The target's step for the - and + buttons, and its first value, by measure (in the measure's own unit).
const STEPS: Array[int] = [10000, 5000, 5000, 1000, 5000, 1, 1, 1]
const FIRST_TARGETS: Array[int] = [60000, 10000, 30000, 3000, 10000, 2, 1, 2]
const REFUSE_FULL: String = "Three projects are pinned already: remove one first."
const REFUSE_NAME: String = "Give the project a name."
const REFUSE_TARGET: String = "Its target must be above zero."
const CHRONICLE: String = "Project complete: \"%s\" -- %s, %s -> %s (target %s)."


## One pinned project.
class Project extends RefCounted:
	var name: String = ""
	var measure: int = 0
	var target: int = 0
	var start: int = 0
	var place_kinds: PackedInt32Array = PackedInt32Array()
	var place_ids: PackedInt32Array = PackedInt32Array()
	var place_names: PackedStringArray = PackedStringArray()
	var done: bool = false
	var finish: int = 0


var projects: Array[Project] = []
## `post(text, to_kind, to_id)`: the chronicle (demo_notices.gd `post` with the Village source, bound by the owner).
var post: Callable = Callable()
var revision: int = 0


func add(project_name: String, measure: int, target: int, world: WorldScript, facts: FactsScript,
		places: Array[Vector3i] = [], names: PackedStringArray = PackedStringArray()) -> String:
	"""Pin a project ('' when pinned, else why not): `places` are (TARGET_* kind, id, 0), named by `names`."""
	var clean: String = project_name.strip_edges().left(NAME_MAX)
	if projects.size() >= MAX_PROJECTS:
		return REFUSE_FULL
	if clean.is_empty():
		return REFUSE_NAME
	if target <= 0 or measure < 0 or measure >= MEASURE_COUNT:
		return REFUSE_TARGET
	var project := Project.new()
	project.name = clean
	project.measure = measure
	project.target = target
	project.start = raw_value(measure, world, facts)
	for k: int in mini(places.size(), MAX_PLACES):
		project.place_kinds.append(places[k].x)
		project.place_ids.append(places[k].y)
		project.place_names.append(names[k] if k < names.size() else "")
	projects.append(project)
	revision += 1
	return ""


func remove(k: int) -> void:
	"""Unpin project `k` (nothing else changes)."""
	if k >= 0 and k < projects.size():
		projects.remove_at(k)
		revision += 1


func update(world: WorldScript, facts: FactsScript) -> void:
	"""Look at every project's measure; one that has reached its target is done, and its chronicle entry posted."""
	for project: Project in projects:
		if project.done or progress(project, world, facts) < project.target:
			continue
		project.done = true
		project.finish = raw_value(project.measure, world, facts)
		revision += 1
		if post.is_valid():
			post.call(chronicle_text(project), project.place_kinds[0] if not project.place_kinds.is_empty()
				else NoticesScript.TARGET_NONE, project.place_ids[0] if not project.place_ids.is_empty() else -1)


func progress(project: Project, world: WorldScript, facts: FactsScript) -> int:
	"""How far its measure has come: the level now, or (FROM_NOW) what has happened since it was pinned."""
	var now: int = raw_value(project.measure, world, facts)
	return now - project.start if FROM_NOW[project.measure] else now


static func raw_value(measure: int, world: WorldScript, facts: FactsScript) -> int:
	"""The village's own figure for a measure, in its unit (0 when its owner is not bound)."""
	match measure:
		MEASURE_WOOD: return world.stores.wood_milli_u if world.stores != null else 0
		MEASURE_PLANKS: return world.stores.plank_milli_u if world.stores != null else 0
		MEASURE_STONE: return world.stores.stone_milli_u if world.stores != null else 0
		MEASURE_READY_FOOD: return world.kitchen.days_of_meals_milli() if world.kitchen != null else 0
		MEASURE_HARVESTED: return world.pantry.delivered_milli if world.pantry != null else 0
		MEASURE_SUPPERS: return facts.suppers_eaten
		MEASURE_BRIDGES: return world.open_bridges()
		MEASURE_TUNNELS: return world.open_tunnels()
	return 0


static func amount_text(measure: int, value: int) -> String:
	"""A measure's value as the player reads it: '12.0 U', '2.5 days', '3'."""
	match UNITS[measure]:
		UNIT_MILLI: return FarmText.units_text(maxi(value, 0))
		UNIT_DAYS:
			@warning_ignore("integer_division") return "%d.%d days" % [maxi(value, 0) / 1000, (maxi(value, 0) % 1000) / 100]
	return str(value)


static func goal_text(measure: int, target: int) -> String:
	"""'Wood in store reaches 60.0 U'."""
	return "%s reaches %s" % [MEASURE_NAMES[measure], amount_text(measure, target)]


func chronicle_text(project: Project) -> String:
	"""The history's line for a done project: its name, its measure, before and after, its target."""
	var shown_start: int = 0 if FROM_NOW[project.measure] else project.start
	var shown_end: int = project.finish - project.start if FROM_NOW[project.measure] else project.finish
	return CHRONICLE % [project.name, MEASURE_NAMES[project.measure].to_lower(),
		amount_text(project.measure, shown_start), amount_text(project.measure, shown_end),
		amount_text(project.measure, project.target)]


func is_full() -> bool:
	"""Whether MAX_PROJECTS are pinned."""
	return projects.size() >= MAX_PROJECTS

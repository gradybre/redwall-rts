extends Node
## THE VILLAGE'S FOOD STORES AT WORK (decisions 0611, 0612): the cool cellar's hauling (cellar_haul.gd) -- surplus food
## carried from a warmer store into a cooler one -- and the CELLAR BUILDINGS (cellar_projects.gd, cellar_builders.gd,
## cellar_place.gd, cellar_view.gd, cellar_bar.gd): placed from the Pantry, built by residents through the work board,
## a store once built. All stepped on the cast's clock; both kinds of work are on the work board's "Food stores" source
## (demo/work/stores_work.gd). demo_village.gd builds it after the farm, the kitchen and the tunnels (`configure`, then
## `configure_cellars`) and hands its boards to the work board. Presentation only.

const HaulScript := preload("res://demo/stores/cellar_haul.gd")
const ProjectsScript := preload("res://demo/stores/cellar_projects.gd")
const BuildersScript := preload("res://demo/stores/cellar_builders.gd")
const PlaceScript := preload("res://demo/stores/cellar_place.gd")
const ViewScript := preload("res://demo/stores/cellar_view.gd")
const BarScript := preload("res://demo/stores/cellar_bar.gd")
const Rules := preload("res://demo/stores/cellar_rules.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const GoodsScript := preload("res://demo/farm/farm_goods.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

## The cast space's structure circles the cellars stand as (cast_space.gd STRUCTURES): one each, from this one.
const FIRST_STRUCTURE: int = 0

var haul: HaulScript = HaulScript.new()
var projects: ProjectsScript = null
var builders: BuildersScript = null
var place: PlaceScript = PlaceScript.new()
var view: ViewScript = ViewScript.new()
var bar: BarScript = BarScript.new()

var _cast: DemoCastScript = null
var _pantry: PantryScript = null
var _unlock_facts: Callable = Callable()
var _seen: int = -1
## Each cellar's state as last synced (see `_sync_footprints`).
var _state_seen: PackedByteArray = PackedByteArray()


func configure(cast: DemoCastScript, network: GraphScript, pantry: PantryScript, free_of: Callable,
		hour_of: Callable, goods: GoodsScript) -> void:
	"""Move this pantry's surplus with this cast into this network's cellars (cellar_haul.gd `configure`)."""
	name = "DemoStores"
	_cast = cast
	_pantry = pantry
	haul.configure(cast, network, pantry, free_of, hour_of, goods)


func configure_cellars(stores: StoresScript, props: PropsScript, store_at: Vector2, site: Callable, site_key: Callable,
		network: GraphScript, camera: Camera3D, say: Callable) -> void:
	"""The cellar buildings over the village `stores`: built by this cast from the stores at `store_at`, drawn with
	`props`, placed clear of `site()` (taken again when `site_key()` changes) and `network`, through `camera`, answering
	by `say`; each built cellar a store of the pantry."""
	projects = ProjectsScript.new(stores)
	_state_seen.resize(ProjectsScript.MAX_CELLARS)
	builders = BuildersScript.new(projects)
	builders.configure(_cast, props, store_at)
	add_child(view)
	view.configure(projects, props)
	add_child(place)
	place.configure(projects, site, site_key, network, camera, props, say)
	bar.configure(projects, locked_words)
	bar.cancel_requested.connect(cancel)
	_pantry.storage.add_provider(projects.provider())


func set_unlock_facts(facts: Callable) -> void:
	"""`facts() -> Vector4i(day, residents, cast size, portions cooked)`: what the unlock (cellar_rules.gd UNLOCK)
	reads."""
	_unlock_facts = facts


func locked_words() -> String:
	"""Why a cellar building cannot be placed yet ("" when it can: see cellar_rules.gd THE UNLOCK)."""
	var facts: Vector4i = _unlock_facts.call() if _unlock_facts.is_valid() else Vector4i(0, 0, 0, 0)
	if Rules.unlocked(Rules.UNLOCK, facts.x, facts.y, facts.z, facts.w):
		return ""
	return Rules.locked_words(Rules.UNLOCK, facts.z)


func start_placing() -> bool:
	"""Arm the placing tool (the Pantry's "Build a cellar…"); false, armed not, while a cellar cannot be placed."""
	if not bar.build_refusal().is_empty():
		return false
	place.arm()
	return true


func cancel(c: int) -> String:
	"""Cancel planned cellar `c` (REQ-SET-126): its builders let go first -- reservations given up, loads back in the
	stores -- then what was delivered is returned; "" when done, else why not."""
	if not projects.is_active(c):
		return projects.cancel(c)
	builders.release_cellar(c)
	return projects.cancel(c)


func doing_text(who: int) -> String:
	"""What resident `who` is doing for the food stores (a move, or a cellar's building), in the party panel's words."""
	var said: String = builders.doing_text(who) if builders != null else ""
	return said if not said.is_empty() else haul.task_text(who)


func handle_input(event: InputEvent) -> bool:
	"""The placing tool's input while it is armed (demo_command.gd `add_input_hook`)."""
	return place.handle_input(event)


func _process(_delta: float) -> void:
	"""Plan and carry the moves, and build the cellars, on the demo clock (nothing while paused); a cellar's footprint
	stands as an obstacle from the moment it is placed."""
	if _cast == null:
		return
	haul.update(_cast.clock.frame_usec)
	if projects == null:
		return
	builders.update(_cast.clock.frame_usec)
	if projects.revision != _seen:
		_seen = projects.revision
		_sync_footprints()


func _sync_footprints() -> void:
	"""A cellar whose state changed: placed or built, it is an obstacle circle in the cast's space, cancelled none; and
	built, its store is read into the pantry at once (farm_pantry.gd `refresh_locations`), so food may go to it."""
	var built: bool = false
	for c: int in ProjectsScript.MAX_CELLARS:
		if projects.state[c] == _state_seen[c]:
			continue
		var was_standing: bool = _state_seen[c] != ProjectsScript.STATE_NONE
		_state_seen[c] = projects.state[c]
		built = built or projects.state[c] == ProjectsScript.STATE_DONE
		var standing: bool = projects.state[c] != ProjectsScript.STATE_NONE
		if standing == was_standing:
			continue
		var circle := Vector3(projects.at[c].x, ProjectsScript.RADIUS_M, projects.at[c].y) if standing else Vector3.ZERO
		_cast.space().set_structure(FIRST_STRUCTURE + c, circle)
	if built:
		_pantry.refresh_locations()

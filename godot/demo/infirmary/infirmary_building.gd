extends Node3D
## THE INFIRMARY BUILDING AT WORK (decision 0623): its books (infirmary_project.gd), its builders
## (infirmary_builders.gd, on the work board's "Infirmary" source), its placing tool (infirmary_place.gd) and its
## drawing (infirmary_view.gd), stepped on the cast's clock. demo_care.gd builds it and hands its project to the care desk, where the hurt go once it
## is built. The cellar building's node (decision 0612, demo_stores.gd), for one building. Presentation only.
##
## ITS FOOTPRINT is an obstacle in the cast's space from the moment it is placed (cast_space.gd `set_structure`, the
## structure slot STRUCTURE; the cellar buildings take the first slots), and none once cancelled; a cancel and a new
## placing between two frames moves it (the project's generation is compared too).

const ProjectsScript := preload("res://demo/infirmary/infirmary_project.gd")
const BuildersScript := preload("res://demo/infirmary/infirmary_builders.gd")
const PlaceScript := preload("res://demo/infirmary/infirmary_place.gd")
const ViewScript := preload("res://demo/infirmary/infirmary_view.gd")
const StateScript := preload("res://demo/infirmary/care_state.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

## The cast space's structure circle the infirmary stands as: the last slot.
const STRUCTURE: int = CastSpaceScript.STRUCTURES - 1

var project: ProjectsScript = null
var builders: BuildersScript = null
var place: PlaceScript = PlaceScript.new()
var view: ViewScript = ViewScript.new()

var _cast: DemoCastScript = null
var _seen: int = -1
var _standing: bool = false
var _standing_gen: int = -1
## `() -> void` run before the placing tool is armed (demo_care.gd: the Dig tool put away, so it does not take the
## click; the review's M5).
var before_placing: Callable = Callable()


func configure(cast: DemoCastScript, stores: StoresScript, care: StateScript, props: PropsScript, store_at: Vector2,
		shelf_at: Vector2) -> void:
	"""The infirmary for this cast, built from the village `stores` (wood, stone at `store_at`) and the `care` shelf
	(cloth at `shelf_at`), drawn with `props` (null: placeholders)."""
	name = "InfirmaryBuilding"
	_cast = cast
	project = ProjectsScript.new(stores, care, cast.actor_count())
	builders = BuildersScript.new(project)
	builders.configure(cast, props, store_at, shelf_at)
	add_child(view)
	view.configure(project, props)
	add_child(place)


func configure_place(site: Callable, site_key: Callable, network: GraphScript, camera: Camera3D, props: PropsScript,
		say: Callable, keep_clear: PackedVector2Array) -> void:
	"""The placing tool: clear of `site()` (taken again when `site_key()` changes), `network` and the `keep_clear`
	places (the care shelf, the herb patch, the field-care spots, the stockpile), through `camera`, answering by `say`
	(infirmary_place.gd `configure`)."""
	place.configure(project, site, site_key, network, camera, props, say)
	place.set_keep_clear(keep_clear)


func start_placing() -> String:
	"""Arm the placing tool; "" when armed, else why not (one is planned or built already)."""
	if project.state != ProjectsScript.STATE_NONE:
		return ProjectsScript.REFUSE_EXISTS
	if before_placing.is_valid():
		before_placing.call()
	place.arm()
	return ""


func cancel() -> String:
	"""Cancel the planned infirmary (REQ-SET-126): its builders let go first -- reservations given up, loads back in
	their sources -- then what was delivered is returned; "" when done, else why not."""
	if project.is_active():
		builders.release_all()
	return project.cancel()


func handle_input(event: InputEvent) -> bool:
	"""The placing tool's input while it is armed (demo_command.gd `add_input_hook`)."""
	return place.handle_input(event)


func _process(_delta: float) -> void:
	"""Build it on the demo clock (nothing while paused); its footprint follows its state."""
	if _cast == null:
		return
	builders.update(_cast.clock.frame_usec)
	if project.revision != _seen:
		_seen = project.revision
		sync_footprint()


func sync_footprint() -> void:
	"""Placed or built, an obstacle circle in the cast's space; cancelled, none (see ITS FOOTPRINT)."""
	var standing: bool = project.state != ProjectsScript.STATE_NONE
	if standing == _standing and project.generation == _standing_gen:
		return
	_standing = standing
	_standing_gen = project.generation
	var circle := Vector3(project.at.x, ProjectsScript.RADIUS_M, project.at.y) if standing else Vector3.ZERO
	_cast.space().set_structure(STRUCTURE, circle)

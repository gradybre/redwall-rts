extends Node3D
## The demo's underground view (U): a top-down section cutaway by render layer. Decision 0206 (the
## underground revamp's P0; design docs/design/underground_revamp.md §5), replacing decision 0196's
## fading view. Presentation only: it changes what is drawn, never where anyone is (MOVE-REQ-015).
##
## A SWITCH IS ONE WRITE: the camera's `cull_mask` (demo_layers.gd view_mask). Everything either view
## draws already exists on its own layer -- the village, its labels and crops on the surface layers; the
## cap (underground_cap.gd), the troughs, rooms, frames, lanterns, finds and residents below on the
## underground ones, built as they are dug -- so switching allocates nothing, builds nothing, fades
## nothing and changes no material: no pipeline is compiled by a toggle. What the U view draws the
## first time is drawn once at boot instead (`begin_prewarm`, behind the opening pause).
##
## PICKING. `ground_at` meets the view's own plane: the ground in the surface view, the level's floor in
## the U view (demo_layers.gd pick_y) -- where the cap shows the floor under the pointer.

const Layers := preload("res://demo/demo_layers.gd")
const CapScript := preload("res://demo/tunnel/underground_cap.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const WaterScript := preload("res://demo/village_water.gd")

## The prewarm's samples stand this far below the camera's focus (under the cap, over the backstop):
## drawn, and hidden by the depth test.
const SAMPLE_DEPTH_M: float = 2.0
## The world's sun, found by name (world_look.gd make_sun).
const SUN_NODE: String = "Sun"

var on: bool = false
## Every material and mesh the U view draws (underground_prewarm.gd): owners register as they build.
var prewarm: PrewarmScript = PrewarmScript.new()
var cap: CapScript = null

var _camera: Camera3D = null
var _samples: Node3D = null


func configure(camera: Camera3D, ground: GroundScript, water: WaterScript) -> void:
	"""The view through `camera` (surface first), its cap over this ground and water."""
	name = "TunnelView"
	_camera = camera
	cap = CapScript.new()
	add_child(cap)
	cap.configure(ground, water)
	cap.register(prewarm)
	set_on(false)


func set_world(world: Node3D, buildings: Array[Vector3], trees: Array[Dictionary]) -> void:
	"""The world's footings and roots on the cap, and its sun kept to the surface (it already is, by its
	layer; its cull mask says so too)."""
	cap.add_footprints(buildings)
	cap.add_roots(trees)
	var sun := world.find_child(SUN_NODE, true, false) as DirectionalLight3D if world != null else null
	if sun != null:
		sun.light_cull_mask = Layers.SURFACE_VIEW


func toggle() -> bool:
	"""Switch the view; returns whether it is now on."""
	set_on(not on)
	return on


func set_on(value: bool) -> void:
	"""Underground view on or off: the camera's cull mask, and nothing else (see the header)."""
	on = value
	if _camera != null:
		_camera.cull_mask = Layers.view_mask(on)


func pick_y() -> float:
	"""The plane this view picks on (the ground, or the level's floor)."""
	return Layers.pick_y(on)


func ground_at(screen: Vector2) -> Vector2:
	"""The point (x, z) of this view's plane under a screen point; INF when the ray misses it."""
	if _camera == null:
		return Vector2.INF
	return Layers.pick_ground(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen), pick_y())


# --- the boot prewarm -----------------------------------------------------------------------

func begin_prewarm() -> void:
	"""Draw the U view with one sample of everything registered (underground_prewarm.gd), from now until
	`end_prewarm` (demo_prewarm.gd runs it for PrewarmScript.FRAMES frames behind the opening pause)."""
	end_prewarm()
	_samples = Node3D.new()
	_samples.name = "PrewarmSamples"
	add_child(_samples)
	var focus: Vector3 = _focus()
	prewarm.build_samples(_samples, Vector3(focus.x, Layers.FLOOR_Y_M - SAMPLE_DEPTH_M * 0.5, focus.z))
	if _camera != null:
		_camera.cull_mask = Layers.UNDERGROUND_VIEW


func end_prewarm() -> void:
	"""Free the samples and give the camera back its view."""
	if _samples != null:
		remove_child(_samples)
		_samples.queue_free()
		_samples = null
	set_on(on)


func _focus() -> Vector3:
	"""Where the camera looks: a point in front of it on the ground, or the origin without one."""
	if _camera == null or not _camera.is_inside_tree():
		return Vector3.ZERO
	var at: Vector2 = Layers.pick_ground(_camera.global_position, -_camera.global_basis.z, 0.0)
	return Vector3.ZERO if at == Vector2.INF else Vector3(at.x, 0.0, at.y)


func is_prewarming() -> bool:
	"""Whether the prewarm's samples are up (checks)."""
	return _samples != null

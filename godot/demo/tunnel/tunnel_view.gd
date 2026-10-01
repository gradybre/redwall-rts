extends Node3D
## The demo's underground view (U): a top-down section cutaway by render layer. Decision 0206 (the
## underground revamp's P0; design docs/design/underground_revamp.md §5), replacing decision 0196's
## fading view. Presentation only: it changes what is drawn, never where anyone is (MOVE-REQ-015).
##
## A SWITCH IS TWO WRITES: the camera's `cull_mask` (demo_layers.gd view_mask) and its `environment`.
## Everything either view draws already exists on its own layer -- the village, its labels and crops on
## the surface layers; the cap (underground_cap.gd), the bores, rooms, frames, lanterns, finds and
## residents below on the underground ones, built as they are dug -- so switching allocates nothing,
## builds nothing, fades nothing and changes no material: no pipeline is compiled by a toggle. What the U
## view draws the first time is drawn once at boot instead (`begin_prewarm`, behind the opening pause),
## in its own environment.
##
## THE UNDERGROUND'S ENVIRONMENT (decision 0207; design §5 "Lighting"): its own Environment, set on the
## camera only while the U view is on (null gives the surface's WorldEnvironment back, untouched, so the
## weather's haze and the sky never reach below and nothing below reaches the surface): dark earth behind,
## a low cool-brown ambient, SSAO in the bores' corners, glow so the lantern glows bloom, and a faint warm
## depth haze -- warm lantern pools in dark earth.
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
## THE UNDERGROUND'S ENVIRONMENT (see the header).
const BACKGROUND: Color = Color(0.035, 0.028, 0.022)
const AMBIENT: Color = Color(0.42, 0.38, 0.36)
const AMBIENT_ENERGY: float = 0.55
const HAZE: Color = Color(0.16, 0.11, 0.07)
const HAZE_DENSITY: float = 0.006
const GLOW_INTENSITY: float = 0.7
const GLOW_BLOOM: float = 0.04
const GLOW_THRESHOLD: float = 1.0
## The prewarm's cover: a canvas layer over the 3D view (and under the stall banner's), in deep shade.
const COVER_LAYER: int = 1
const COVER_COLOUR: Color = Color(0.12, 0.1, 0.08)

var on: bool = false
## Every material and mesh the U view draws (underground_prewarm.gd): owners register as they build.
var prewarm: PrewarmScript = PrewarmScript.new()
var cap: CapScript = null
## The U view's own environment (see THE UNDERGROUND'S ENVIRONMENT).
var environment: Environment = underground_environment()

var _camera: Camera3D = null
var _samples: Node3D = null
## A plain cover over the screen while the prewarm draws (its frames are not for the player's eyes).
var _cover: CanvasLayer = null


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
	layer; its cull and shadow-caster masks say so too, so nothing underground is drawn into its shadow
	map)."""
	cap.add_footprints(buildings)
	cap.add_roots(trees)
	var sun := world.find_child(SUN_NODE, true, false) as DirectionalLight3D if world != null else null
	if sun != null:
		sun.light_cull_mask = Layers.SURFACE_VIEW
		sun.shadow_caster_mask = Layers.SURFACE_VIEW


func toggle() -> bool:
	"""Switch the view; returns whether it is now on."""
	set_on(not on)
	return on


func set_on(value: bool) -> void:
	"""Underground view on or off: the camera's cull mask and environment, and nothing else (see the
	header)."""
	on = value
	if _camera != null:
		_camera.cull_mask = Layers.view_mask(on)
		_camera.environment = environment if on else null


static func underground_environment() -> Environment:
	"""The U view's environment (see THE UNDERGROUND'S ENVIRONMENT)."""
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = AMBIENT_ENERGY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 2.2
	env.ssao_power = 1.5
	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	env.glow_bloom = GLOW_BLOOM
	env.glow_hdr_threshold = GLOW_THRESHOLD
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = HAZE
	env.fog_density = HAZE_DENSITY
	env.fog_sky_affect = 0.0
	return env


func pick_y() -> float:
	"""The plane this view picks on (the ground, or the level's floor)."""
	return Layers.pick_y(on)


func ground_at(screen: Vector2) -> Vector2:
	"""The point (x, z) of this view's plane under a screen point; INF when the ray misses it."""
	if _camera == null:
		return Vector2.INF
	return ground_along(_camera.project_ray_origin(screen), _camera.project_ray_normal(screen))


func ground_along(origin: Vector3, direction: Vector3) -> Vector2:
	"""Where a unit ray meets this view's plane, (x, z); INF when it misses it."""
	return Layers.pick_ground(origin, direction, pick_y())


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
	_cover = _make_cover()
	add_child(_cover)
	if _camera != null:
		_camera.cull_mask = Layers.UNDERGROUND_VIEW
		_camera.environment = environment


func end_prewarm() -> void:
	"""Free the samples and give the camera back its view."""
	for node: Node in [_samples, _cover]:
		if node != null:
			remove_child(node)
			node.queue_free()
	_samples = null
	_cover = null
	set_on(on)


static func _make_cover() -> CanvasLayer:
	"""An opaque screen-wide cover in the demo's deep shade, over everything but the HUD's own layers."""
	var cover := CanvasLayer.new()
	cover.name = "PrewarmCover"
	cover.layer = COVER_LAYER
	var fill := ColorRect.new()
	fill.color = COVER_COLOUR
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(fill)
	return cover


func _focus() -> Vector3:
	"""Where the camera looks: a point in front of it on the ground, or the origin without one."""
	if _camera == null or not _camera.is_inside_tree():
		return Vector3.ZERO
	var at: Vector2 = Layers.pick_ground(_camera.global_position, -_camera.global_basis.z, 0.0)
	return Vector3.ZERO if at == Vector2.INF else Vector3(at.x, 0.0, at.y)


func focus() -> Vector3:
	"""Where the U view looks: where the camera's forward ray meets the level's floor (the origin without a
	camera)."""
	if _camera == null or not _camera.is_inside_tree():
		return Vector3(0.0, Layers.FLOOR_Y_M, 0.0)
	return floor_focus(_camera.global_position, -_camera.global_basis.z)


static func floor_focus(origin: Vector3, forward: Vector3) -> Vector3:
	"""Where a camera at `origin` looking along unit `forward` meets the level's floor (the origin below
	when it looks level or up)."""
	var at: Vector2 = Layers.pick_ground(origin, forward, Layers.FLOOR_Y_M)
	return Vector3(at.x if at != Vector2.INF else 0.0, Layers.FLOOR_Y_M, at.y if at != Vector2.INF else 0.0)


func is_prewarming() -> bool:
	"""Whether the prewarm's samples are up (checks)."""
	return _samples != null

extends Node3D
## What the demo's threats look like. Decision 0196 (live demo). Presentation only.
##
## A threat's disc is ringed in clay on the ground while it lasts. A FLOOD spreads a sheet of water
## over its disc, rising in over RISE_S and draining away as it clears; a FIRE burns at the covered
## store -- flames, smoke and a warm flickering light.
##
## THE FLOOD SHEET IS A STAND-IN WATER VISUAL, kept to one flat disc in `_water` and isolated here:
## the village's real water (feat/demo-water) owns water drawing, and when it is merged this sheet
## should be removed (or given to it) -- nothing else reads it. Everything runs on the demo clock: paused,
## the water stands and the flames hang still. Built once; per frame it only eases and scales.

const EventsScript := preload("res://demo/events/demo_events.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const RISE_S: float = 3.0
const WATER_COLOUR: Color = Color(0.28, 0.48, 0.66, 0.62)
const WATER_Y_M: float = 0.07
## Flames go from a hot yellow to red and out; smoke rises in, greys and thins away.
const FLAME_RAMP: Array[Color] = [Color(1.0, 0.86, 0.45, 0.95), Color(1.0, 0.5, 0.12, 0.8), Color(0.55, 0.12, 0.04, 0.0)]
const SMOKE_RAMP: Array[Color] = [Color(0.32, 0.3, 0.28, 0.0), Color(0.3, 0.29, 0.28, 0.55), Color(0.26, 0.26, 0.26, 0.0)]
const FIRE_LIGHT: Color = Color(1.0, 0.55, 0.25)
## The fire burns on the store's roof (its thatch), where it shows over the building.
const FIRE_HEIGHT_M: float = 3.4

var _events: EventsScript = null
var _clock: DemoClockScript = null
var _water: MeshInstance3D = null
var _ring: MeshInstance3D = null
var _flames: CPUParticles3D = null
var _smoke: CPUParticles3D = null
var _light: OmniLight3D = null
var _level: float = 0.0
var _time: float = 0.0


func configure(events: EventsScript, clock: DemoClockScript) -> void:
	"""Draw these threats on this clock. Builds every node once."""
	name = "EventsView"
	_events = events
	_clock = clock
	_water = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 48
	_water.mesh = disc
	var material := StandardMaterial3D.new()
	material.albedo_color = WATER_COLOUR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.08
	material.metallic_specular = 0.8
	_water.material_override = material
	_water.visible = false
	add_child(_water)
	_ring = MarksScript.make_ring(Palette.CLAY)
	_ring.visible = false
	add_child(_ring)
	_build_fire()


func _build_fire() -> void:
	"""Flames, smoke and a warm light, off until a fire."""
	_flames = _plume(160, 0.9, Vector3(0.0, 2.4, 0.0), 0.55, _ramp(FLAME_RAMP))
	_smoke = _plume(80, 3.2, Vector3(0.0, 1.6, 0.0), 1.1, _ramp(SMOKE_RAMP))
	_light = OmniLight3D.new()
	_light.light_color = FIRE_LIGHT
	_light.light_energy = 0.0
	_light.omni_range = 12.0
	_light.visible = false
	add_child(_light)


static func _ramp(stops: Array[Color]) -> Gradient:
	"""A colour ramp over a particle's life through these stops, evenly spaced."""
	var ramp := Gradient.new()
	ramp.set_color(0, stops[0])
	ramp.set_color(1, stops[stops.size() - 1])
	for k in range(1, stops.size() - 1):
		ramp.add_point(float(k) / float(stops.size() - 1), stops[k])
	return ramp


static func _soft_blob() -> Texture2D:
	"""A round, soft-edged sprite: white at the centre fading to clear at the rim."""
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var blob := GradientTexture2D.new()
	blob.gradient = fade
	blob.fill = GradientTexture2D.FILL_RADIAL
	blob.fill_from = Vector2(0.5, 0.5)
	blob.fill_to = Vector2(1.0, 0.5)
	blob.width = 64
	blob.height = 64
	return blob


func _plume(count: int, lifetime: float, velocity: Vector3, size: float, ramp: Gradient) -> CPUParticles3D:
	"""A rising plume of soft round sprites, coloured over their life by `ramp`."""
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_blob()
	quad.material = material
	var plume := CPUParticles3D.new()
	plume.amount = count
	plume.lifetime = lifetime
	plume.mesh = quad
	plume.color_ramp = ramp
	plume.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	plume.emission_sphere_radius = 1.6
	plume.direction = velocity.normalized()
	plume.spread = 18.0
	plume.initial_velocity_min = velocity.length() * 0.7
	plume.initial_velocity_max = velocity.length() * 1.2
	plume.gravity = Vector3.ZERO
	plume.emitting = false
	plume.visible = false
	add_child(plume)
	return plume


func _process(_delta: float) -> void:
	"""Follow the threat under way on the demo clock."""
	if _events == null:
		return
	var dt := _clock.delta_s() if _clock != null else 0.0
	_time += dt
	var target := 1.0 if _events.active else 0.0
	_level = move_toward(_level, target, dt / RISE_S)
	var centre := _events.centre_m()
	var radius := _events.radius_m()
	var flood := _events.kind == EventsScript.KIND_FLOOD
	_ring.visible = _events.active
	_ring.position = Vector3(centre.x, MarksScript.LIFT_M, centre.y)
	_ring.scale = Vector3(radius, 1.0, radius)
	_water.visible = flood and _level > 0.01
	_water.position = Vector3(centre.x, WATER_Y_M, centre.y)
	_water.scale = Vector3(radius * _level, 1.0, radius * _level)
	_fire(not flood and _events.active, Vector3(centre.x, 0.0, centre.y))


func _fire(on: bool, at: Vector3) -> void:
	"""Burn at `at` while `on`, at the game's speed."""
	var speed := float(_clock.speed) if _clock != null else 1.0
	_run_plume(_flames, on, speed, at)
	_run_plume(_smoke, on, speed, at)
	_light.visible = on or _level > 0.01
	_light.position = at + Vector3(0.0, FIRE_HEIGHT_M + 1.5, 0.0)
	_light.light_energy = (2.2 + 0.4 * sin(_time * 11.0)) * _level if not (_events.kind == EventsScript.KIND_FLOOD) else 0.0


static func _run_plume(plume: CPUParticles3D, on: bool, speed: float, at: Vector3) -> void:
	"""Start or stop a plume at `at`, at the game's speed."""
	if plume.emitting != on:
		plume.emitting = on
		plume.visible = plume.visible or on
	plume.speed_scale = speed
	plume.position = at + Vector3(0.0, FIRE_HEIGHT_M, 0.0)


func water_level() -> float:
	"""How far the flood water has risen, 0..1 (for checks)."""
	return _level


func burning() -> bool:
	"""Whether the fire is burning (for checks)."""
	return _flames.emitting

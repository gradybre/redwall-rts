extends Node3D
## What the demo's threats look like. Decision 0196 (live demo). Presentation only.
##
## A threat's disc is ringed in clay on the ground while it lasts. A FLOOD raises the REAL stream: its
## level eases up over RISE_S and back down as it clears, and each change is handed to the water
## (`set_flood_rise`, demo/water/demo_water.gd `set_flood_rise`), which lifts the stream's own surface
## up its carved banks; where it spills -- the real west bank at the ford (village_water.gd) -- a film
## of water spreads FILM_M onto the east road with the level, and the ring marks how far into the
## village the flood reaches. (The old stand-in sheet, a disc of water over the reed beds far from any
## water, is gone: everything drawn now stands at the real stream.) A FIRE burns at the covered store
## -- flames, smoke and a warm flickering light.
##
## Everything runs on the demo clock: paused, the water stands and the flames hang still. Built once;
## per frame it only eases, and hands the water a new level only when it moved.

const EventsScript := preload("res://demo/events/demo_events.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const RISE_S: float = 3.0
## How far the spill's film spreads from the real bank at full flood (demo value), and its look: the
## stream's own grey-green, a little brighter where it runs thin over the road.
const FILM_M: float = 3.0
const FILM_COLOUR: Color = Color(0.38, 0.47, 0.48, 0.72)
const FILM_Y_M: float = 0.04
## Flames go from a hot yellow to red and out; smoke rises in, greys and thins away.
const FLAME_RAMP: Array[Color] = [Color(1.0, 0.86, 0.45, 0.95), Color(1.0, 0.5, 0.12, 0.8), Color(0.55, 0.12, 0.04, 0.0)]
const SMOKE_RAMP: Array[Color] = [Color(0.32, 0.3, 0.28, 0.0), Color(0.3, 0.29, 0.28, 0.55), Color(0.26, 0.26, 0.26, 0.0)]
const FIRE_LIGHT: Color = Color(1.0, 0.55, 0.25)
## The fire burns on the store's roof (its thatch), where it shows over the building.
const FIRE_HEIGHT_M: float = 3.4

var _events: EventsScript = null
var _clock: DemoClockScript = null
## `(level: float) -> void`: raises the real stream (none: the flood is only ringed).
var _flood_rise: Callable = Callable()
var _risen: float = 0.0
var _film: MeshInstance3D = null
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
	_film = _build_film()
	add_child(_film)
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
	_raise_stream(_level if flood else 0.0)
	_film.visible = flood and _level > 0.01
	_film.position = Vector3(centre.x, FILM_Y_M, centre.y)
	_film.scale = Vector3(FILM_M * _level, 1.0, FILM_M * _level)
	_fire(not flood and _events.active, Vector3(centre.x, 0.0, centre.y))


static func _build_film() -> MeshInstance3D:
	"""The spill's film: a unit disc of the stream's colour, scaled with the flood's level."""
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.01
	disc.radial_segments = 48
	var material := StandardMaterial3D.new()
	material.albedo_color = FILM_COLOUR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.1
	material.metallic_specular = 0.7
	var film := MeshInstance3D.new()
	film.name = "SpillFilm"
	film.mesh = disc
	film.material_override = material
	film.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	film.visible = false
	return film


func film_radius_m() -> float:
	"""How far the spill's film spreads now, in metres (checks)."""
	return _film.scale.x if _film.visible else 0.0


func set_flood_rise(rise: Callable) -> void:
	"""`rise(level: float)`: how a flood raises the real stream (demo_water.gd `set_flood_rise`)."""
	_flood_rise = rise


func _raise_stream(level: float) -> void:
	"""Hand the stream its flood level when it moved."""
	if level == _risen or not _flood_rise.is_valid():
		return
	_risen = level
	_flood_rise.call(level)


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

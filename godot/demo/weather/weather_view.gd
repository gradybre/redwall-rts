extends Node3D
## What the demo's weather looks like. Decision 0196 (live demo). Presentation only: it draws what
## demo_weather.gd says and changes nothing else.
##
## RAIN falls as pale streaks and SNOW as drifting flakes, from a box of sky that follows the camera's
## view of the ground, so the village is always under it at any zoom; FROST and SNOW lay a thin white
## veil over the ground. The sun dims and the haze thickens toward each condition's LOOK (demo
## values) -- a grey rainy day, a bright cold one -- and the change eases in over EASE_S of demo time.
## Particles run at the game's speed (paused: they hang in the air); the falls and the veil hide in
## the underground view so the tunnels read.
##
## Everything is built once; per frame it only moves the sky box and eases a few numbers.

const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")

## Per condition (CLEAR, RAIN, SNOW, FROST): the sun's energy as a share of the world's, the haze
## density added, and the ground veil's opacity.
const SUN_SHARE: Array[float] = [1.0, 0.45, 0.7, 0.85]
const FOG_ADD: Array[float] = [0.0, 0.012, 0.008, 0.002]
const VEIL_ALPHA: Array[float] = [0.0, 0.0, 0.42, 0.22]
const EASE_S: float = 3.0
const SKY_HALF_M: float = 18.0
const SKY_HEIGHT_M: float = 9.0
## Falls start no higher than this share of the camera's height, so no streak passes by the lens.
const SKY_BELOW_CAMERA: float = 0.6
const RAIN_COUNT: int = 2600
const SNOW_COUNT: int = 2200
const VEIL_SIZE_M: float = 60.0
const VEIL_LIFT_M: float = 0.02
const RAIN_COLOUR: Color = Color(0.8, 0.86, 0.94, 0.38)
const SNOW_COLOUR: Color = Color(0.97, 0.98, 1.0, 0.95)
const VEIL_COLOUR: Color = Color(0.93, 0.95, 0.98)

var _weather: WeatherScript = null
var _clock: DemoClockScript = null
var _sun: DirectionalLight3D = null
var _environment: Environment = null
var _sun_energy: float = 1.0
var _fog: float = 0.0
var _rain: CPUParticles3D = null
var _snow: CPUParticles3D = null
var _veil: MeshInstance3D = null
var _veil_material: StandardMaterial3D = null
var _share: float = 1.0
var _fog_add: float = 0.0
var _veil_alpha: float = 0.0
var _underground: bool = false


func configure(weather: WeatherScript, clock: DemoClockScript, world: Node) -> void:
	"""Draw this weather on this clock, dimming `world`'s sun and haze (none: particles only)."""
	name = "WeatherView"
	_weather = weather
	_clock = clock
	if world != null:
		_sun = world.find_child("Sun", true, false) as DirectionalLight3D
		var holder := world.find_child("Environment", true, false) as WorldEnvironment
		_environment = holder.environment if holder != null else null
	if _sun != null:
		_sun_energy = _sun.light_energy
	if _environment != null:
		_fog = _environment.fog_density
	_rain = _particles(RAIN_COUNT, _streak_mesh(), Vector3(0.0, -12.0, 0.0), 0.75)
	_snow = _particles(SNOW_COUNT, _flake_mesh(), Vector3(0.0, -1.2, 0.0), 3.8)
	_snow.spread = 25.0
	_build_veil()
	_apply_targets(1.0)


func _particles(count: int, mesh: Mesh, velocity: Vector3, lifetime: float) -> CPUParticles3D:
	"""A box of falling particles over the view, off until its condition comes."""
	var particles := CPUParticles3D.new()
	particles.amount = count
	particles.lifetime = lifetime
	particles.mesh = mesh
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(SKY_HALF_M, 0.5, SKY_HALF_M)
	particles.direction = velocity.normalized()
	particles.spread = 3.0
	particles.initial_velocity_min = velocity.length() * 0.85
	particles.initial_velocity_max = velocity.length() * 1.15
	particles.gravity = Vector3.ZERO
	particles.local_coords = false
	particles.emitting = false
	particles.visible = false
	add_child(particles)
	return particles


func _streak_mesh() -> Mesh:
	"""A thin pale streak of rain, lit by nothing."""
	var box := BoxMesh.new()
	box.size = Vector3(0.014, 0.5, 0.014)
	box.material = _unshaded(RAIN_COLOUR)
	return box


func _flake_mesh() -> Mesh:
	"""A small white flake."""
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = _unshaded(SNOW_COLOUR)
	return sphere


static func _unshaded(colour: Color) -> StandardMaterial3D:
	"""A flat see-through material."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = colour
	return material


func _build_veil() -> void:
	"""The thin white veil of frost or snow over the ground, following the view."""
	var plane := PlaneMesh.new()
	plane.size = Vector2(VEIL_SIZE_M, VEIL_SIZE_M)
	_veil_material = _unshaded(Color(VEIL_COLOUR, 0.0))
	_veil = MeshInstance3D.new()
	_veil.mesh = plane
	_veil.material_override = _veil_material
	_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_veil.visible = false
	add_child(_veil)


func set_underground_view(on: bool) -> void:
	"""Hide the ground veil and the falling rain and snow in the underground view (the tunnels must
	read; nothing falls below)."""
	_underground = on
	_veil.visible = not on and _veil_alpha > 0.01
	_rain.visible = not on and _rain.emitting
	_snow.visible = not on and _snow.emitting


func _process(_delta: float) -> void:
	"""Follow the view, run the particles at the game's speed, and ease toward the weather's look."""
	if _weather == null:
		return
	_follow_view()
	var speed := float(_clock.speed) if _clock != null else 1.0
	_rain.speed_scale = speed
	_snow.speed_scale = speed
	var condition := _weather.condition()
	_set_emitting(_rain, condition == WeatherScript.COND_RAIN)
	_set_emitting(_snow, condition == WeatherScript.COND_SNOW)
	var step := (_clock.delta_s() if _clock != null else 0.0) / EASE_S
	_apply_targets(clampf(step, 0.0, 1.0))


func _set_emitting(particles: CPUParticles3D, on: bool) -> void:
	"""Start or stop a fall (it stays drawn while its last particles land)."""
	if particles.emitting != on:
		particles.emitting = on
		if on:
			particles.visible = not _underground


func _apply_targets(weight: float) -> void:
	"""Ease the sun, the haze and the veil `weight` of the way toward the current condition's look."""
	var condition := _weather.condition()
	_share = lerpf(_share, SUN_SHARE[condition], weight)
	_fog_add = lerpf(_fog_add, FOG_ADD[condition], weight)
	_veil_alpha = lerpf(_veil_alpha, VEIL_ALPHA[condition], weight)
	if _sun != null:
		_sun.light_energy = _sun_energy * _share
	if _environment != null:
		_environment.fog_density = _fog + _fog_add
	_veil_material.albedo_color.a = _veil_alpha
	_veil.visible = not _underground and _veil_alpha > 0.01


func _follow_view() -> void:
	"""Centre the sky box and the veil on where the camera looks at the ground."""
	if not is_inside_tree():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var origin := camera.global_position
	var ahead := -camera.global_basis.z
	var t := -origin.y / ahead.y if ahead.y < -0.01 else 0.0
	var focus := origin + ahead * t
	var sky := minf(SKY_HEIGHT_M, origin.y * SKY_BELOW_CAMERA)
	_rain.global_position = Vector3(focus.x, sky, focus.z)
	_snow.global_position = Vector3(focus.x, sky * 0.6, focus.z)
	_veil.global_position = Vector3(focus.x, VEIL_LIFT_M, focus.z)


func sun_share() -> float:
	"""The sun's current energy as a share of the world's (for checks)."""
	return _share


func veil_alpha() -> float:
	"""The ground veil's current opacity (for checks)."""
	return _veil_alpha


func raining() -> bool:
	"""Whether rain is falling in the view."""
	return _rain.emitting


func snowing() -> bool:
	"""Whether snow is falling in the view."""
	return _snow.emitting

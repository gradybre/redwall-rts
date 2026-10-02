extends Node3D
## What the demo's weather looks like. Decision 0196 (live demo). Presentation only: it draws what
## demo_weather.gd says and changes nothing else.
##
## RAIN falls as pale streaks and SNOW as drifting flakes, from a box of sky that follows the camera's
## view of the ground, so the village is always under it at any zoom. The sun dims and the haze thickens
## toward each condition's LOOK (demo values) -- a grey rainy day, a bright cold one -- and the change
## eases in over EASE_S of demo time. Particles run at the game's speed (paused: they hang in the air).
##
## FROST AND SNOW LIE ON THINGS (decision 0301, review F42 -- they were a 60 m white sheet following the
## camera, laid over the water as well as the ground). Now the cover is a property of the SURFACES, in
## world space, so it has no edge: the ground's and the bank film's own shaders take `snow_cover` and
## `frost_cover` (demo_ground.gdshader, water_bank.gdshader FROST AND SNOW), and every building and
## prop in the village wears snow_cover.gdshader as its material_overlay while any lies -- on what faces
## up, roofs and lids, never at or below the water line. The water surfaces are not touched: liquid
## water never whitens. Snow is a fuller, whiter cover than frost (COVER, FROSTY).
## The falls and the cover are on the surface layer, which the underground view does not draw (decision
## 0206) -- nothing here hides for it.
##
## Everything is built once; per frame it only moves the sky box and eases a few numbers (and, as a
## cover comes or goes, puts the overlay on or takes it off the village's meshes).
##
## THE WEATHER ON TOP OF THE HOUR (decision 0541, the day and night). The sky's GLOOM -- overcast, rain, a storm,
## snow (`gloom_target`) -- eases here with the rest, and the lighting cycle (demo/world/day_night.gd) darkens and
## greys the hour by it. While the cycle drives the light (`drives_light` false) this view writes neither the sun's
## energy nor the haze: the cycle reads `sun_share`, `fog_add` and `gloom` and is the one writer of both, so the
## weather multiplies the time of day rather than fighting it. Its falls, which are unshaded, take the cycle's tint
## (`set_unlit_tint`), so rain and snow darken with the evening instead of glowing in the night.

const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")

## Per condition (CLEAR, RAIN, SNOW, FROST): the sun's energy as a share of the world's, the haze
## density added, how much frost or snow lies, and how much of that is frost.
## Rain's were 0.45 and 0.012 until the playtest (decision 0205): about six and a half times the clear
## haze read as a heavy grey fog over the village. Now a shower dims the light by a quarter and adds
## about the clear day's haze again; the streaks are what say it rains.
const SUN_SHARE: Array[float] = [1.0, 0.75, 0.7, 0.85]
const FOG_ADD: Array[float] = [0.0, 0.0024, 0.008, 0.002]
const COVER: Array[float] = [0.0, 0.0, 1.0, 0.6]
const FROSTY: Array[float] = [0.0, 0.0, 0.0, 1.0]
## THE GLOOM a sky brings (see THE WEATHER ON TOP OF THE HOUR), 0..1: clear and frost none; an overcast hour -- a rainy
## day's dry hours -- a little; rain more; a storm (rain on a day of the GDD's heavy rain, DOWNPOUR_RAIN or more) all;
## falling snow most of rain's.
const GLOOM_OVERCAST: float = 0.35
const GLOOM_RAIN: float = 0.6
const GLOOM_STORM: float = 1.0
const GLOOM_SNOW: float = 0.45
const EASE_S: float = 3.0
const SKY_HALF_M: float = 18.0
const SKY_HEIGHT_M: float = 9.0
## Falls start no higher than this share of the camera's height, so no streak passes by the lens.
const SKY_BELOW_CAMERA: float = 0.6
const RAIN_COUNT: int = 2600
const SNOW_COUNT: int = 2200
const RAIN_COLOUR: Color = Color(0.8, 0.86, 0.94, 0.3)
const SNOW_COLOUR: Color = Color(0.97, 0.98, 1.0, 0.95)
## The lying cover's colour: a cool white (the falling flakes' own, less the sky's tint).
const COVER_COLOUR: Color = Color(0.93, 0.95, 0.98)
## Below this cover the overlay is taken off the village's meshes (it would draw nothing).
const COVER_OFF: float = 0.01
const COVER_NOISE_SEED: int = 41
const COVER_SHADER := preload("res://demo/weather/snow_cover.gdshader")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")
const PARAM_COVER: StringName = &"snow_cover"
const PARAM_FROST: StringName = &"frost_cover"

var _weather: WeatherScript = null
var _clock: DemoClockScript = null
var _sun: DirectionalLight3D = null
var _environment: Environment = null
var _sun_energy: float = 1.0
var _fog: float = 0.0
var _rain: CPUParticles3D = null
var _snow: CPUParticles3D = null
## The materials the cover is set on: the ground's and the bank film's shaders, and the overlay.
var _cover_materials: Array[ShaderMaterial] = []
var _overlay: ShaderMaterial = null
## The village's buildings and props, which wear the overlay while a cover lies.
var _overlaid: Array[GeometryInstance3D] = []
var _overlay_on: bool = false
## While the boot prewarm's frame step runs, the overlay stays on whatever the cover (see begin_prewarm).
var _prewarming: bool = false
var _share: float = 1.0
var _fog_add: float = 0.0
var _cover: float = 0.0
var _frost: float = 0.0
var _gloom: float = 0.0
## Whether this view writes the sun's energy and the haze itself (see THE WEATHER ON TOP OF THE HOUR).
var drives_light: bool = true


func configure(weather: WeatherScript, clock: DemoClockScript, world: Node) -> void:
	"""Draw this weather on this clock, dimming `world`'s sun and haze and laying its cover (none:
	particles only). Configured again with the world (tunnel_ext.gd), it keeps its particles and finds the
	world's surfaces afresh."""
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
	if _rain == null:
		_rain = _particles(RAIN_COUNT, _streak_mesh(), Vector3(0.0, -12.0, 0.0), 0.75)
		_snow = _particles(SNOW_COUNT, _flake_mesh(), Vector3(0.0, -1.2, 0.0), 3.8)
		_snow.spread = 25.0
	_build_cover(world)
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


func _build_cover(world: Node) -> void:
	"""Find what the cover lies on (see FROST AND SNOW): the ground's and the bank film's materials, and
	the village's buildings and props for the overlay; make the overlay."""
	_wear_overlay(false)
	_cover_materials.clear()
	_overlaid.clear()
	_overlay = ShaderMaterial.new()
	_overlay.shader = COVER_SHADER
	_overlay.set_shader_parameter(&"noise", _cover_noise())
	_cover_materials.append(_overlay)
	if world == null:
		_set_surface_targets()
		return
	var ground := world.find_child("Ground", true, false) as MeshInstance3D
	var bank := world.get_parent().find_child("WaterBank", true, false) as MeshInstance3D if world.get_parent() != null else null
	for surface: MeshInstance3D in [ground, bank]:
		var material := surface.get_active_material(0) as ShaderMaterial if surface != null else null
		if material != null:
			_cover_materials.append(material)
	_collect_overlaid(world)
	_set_surface_targets()


func _set_surface_targets() -> void:
	"""Every cover material's colour and the water line it stops at (the water's own level)."""
	var water_y: float = -WaterRules.to_m(WaterLayout.LEVEL_DROP_U)
	for material: ShaderMaterial in _cover_materials:
		material.set_shader_parameter(&"snow_color", COVER_COLOUR)
		material.set_shader_parameter(&"water_level_y", water_y)


func _collect_overlaid(world: Node) -> void:
	"""The meshes under the world's village that wear the overlay: every building, prop and dressing piece,
	not its trees (whose crowns are not roofs) nor the ground cover's MultiMeshes."""
	var village: Node = world.get_node_or_null(^"Village")
	if village == null:
		return
	var trees: Dictionary = {}
	var demo_world := world as DemoWorldScript
	if demo_world != null:
		for i: int in demo_world.trees().size():
			trees[demo_world.tree_node(i)] = true
	for piece: Node in village.get_children():
		if trees.has(piece) or piece is MultiMeshInstance3D:
			continue
		for node: Node in piece.find_children("*", "MeshInstance3D", true, false):
			_overlaid.append(node as GeometryInstance3D)
		if piece is MeshInstance3D:
			_overlaid.append(piece as GeometryInstance3D)


static func _cover_noise() -> NoiseTexture2D:
	"""The overlay's patchiness: a seamless, seeded noise."""
	var noise := FastNoiseLite.new()
	noise.seed = COVER_NOISE_SEED
	noise.frequency = 0.05
	var texture := NoiseTexture2D.new()
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture


func _process(_delta: float) -> void:
	"""Follow the view, run the particles at the game's speed (slower with reduced motion, decision 0471), and ease
	toward the weather's look."""
	if _weather == null:
		return
	_follow_view()
	var speed := (float(_clock.speed) if _clock != null else 1.0) * DemoMotion.veil_speed()
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
			particles.visible = true


func _apply_targets(weight: float) -> void:
	"""Ease the sun, the haze and the cover `weight` of the way toward the current condition's look."""
	var condition := _weather.condition()
	_share = lerpf(_share, SUN_SHARE[condition], weight)
	_fog_add = lerpf(_fog_add, FOG_ADD[condition], weight)
	_cover = lerpf(_cover, COVER[condition], weight)
	_frost = lerpf(_frost, FROSTY[condition], weight)
	_gloom = lerpf(_gloom, gloom_target(_weather), weight)
	if _sun != null and drives_light:
		_sun.light_energy = _sun_energy * _share
	if _environment != null and drives_light:
		_environment.fog_density = _fog + _fog_add
	for material: ShaderMaterial in _cover_materials:
		material.set_shader_parameter(PARAM_COVER, _cover)
		material.set_shader_parameter(PARAM_FROST, _frost)
	_wear_overlay(_cover > COVER_OFF)


func begin_prewarm() -> void:
	"""The boot prewarm's frame step (demo_prewarm.gd, decisions 0205/0206): the village wears the overlay
	for its frames -- drawn, so its pipelines compile, but with no cover, so nothing shows."""
	_prewarming = true
	_set_overlay(true)


func end_prewarm() -> void:
	"""Back to what the weather says (no overlay on a clear day)."""
	_prewarming = false
	_set_overlay(_cover > COVER_OFF)


func _wear_overlay(on: bool) -> void:
	"""Put the cover's overlay on the village's buildings and props, or take it off (only on a change)."""
	if on != _overlay_on and not _prewarming:
		_set_overlay(on)


func _set_overlay(on: bool) -> void:
	"""Put the overlay on every village mesh, or take it off."""
	_overlay_on = on
	for mesh: GeometryInstance3D in _overlaid:
		if is_instance_valid(mesh):
			mesh.material_overlay = _overlay if on else null


func _follow_view() -> void:
	"""Centre the sky box on where the camera looks at the ground."""
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


func sun_share() -> float:
	"""The sun's current energy as a share of the world's (the lighting cycle's multiplier, and checks)."""
	return _share


func fog_add() -> float:
	"""The haze the weather adds now, on top of the hour's (the lighting cycle's, and checks)."""
	return _fog_add


func gloom() -> float:
	"""How gloomy the sky is now, 0 (clear) .. 1 (a storm), eased (see THE WEATHER ON TOP OF THE HOUR)."""
	return _gloom


static func gloom_target(weather: WeatherScript) -> float:
	"""The gloom this hour's weather brings (see GLOOM_*): a storm, rain, snow, an overcast dry hour of a rainy day, or
	none."""
	var condition := weather.condition()
	if condition == WeatherScript.COND_RAIN:
		return GLOOM_STORM if weather.rain() >= WeatherScript.DOWNPOUR_RAIN else GLOOM_RAIN
	if condition == WeatherScript.COND_SNOW:
		return GLOOM_SNOW
	if condition == WeatherScript.COND_CLEAR and WeatherScript.falling_rain(weather.rain(), weather.season(),
			weather.season_day()) > 0:
		return GLOOM_OVERCAST
	return 0.0


func set_unlit_tint(tint: Color) -> void:
	"""What lights the unshaded falls now (the lighting cycle's UNLIT_TINT): their own colours times `tint`."""
	_tint_fall(_rain, RAIN_COLOUR, tint)
	_tint_fall(_snow, SNOW_COLOUR, tint)


static func _tint_fall(particles: CPUParticles3D, own: Color, tint: Color) -> void:
	"""One fall's material at its own colour times `tint` (its alpha kept)."""
	var material := (particles.mesh as PrimitiveMesh).material as StandardMaterial3D if particles != null else null
	if material != null:
		material.albedo_color = Color(own.r * tint.r, own.g * tint.g, own.b * tint.b, own.a)


func cover() -> float:
	"""How much frost or snow lies now, 0..1 (for checks)."""
	return _cover


func frost() -> float:
	"""How much of the cover is frost rather than snow, 0..1 (for checks)."""
	return _frost


func overlaid_count() -> int:
	"""How many of the village's meshes wear the cover's overlay now (for checks)."""
	return _overlaid.size() if _overlay_on else 0


func cover_materials() -> Array[ShaderMaterial]:
	"""The materials the cover is set on: the overlay, then the ground's and the bank's (for checks)."""
	return _cover_materials


func raining() -> bool:
	"""Whether rain is falling in the view."""
	return _rain.emitting


func snowing() -> bool:
	"""Whether snow is falling in the view."""
	return _snow.emitting

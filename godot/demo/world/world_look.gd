extends RefCounted
## The demo village's ground, sun and sky. Decision 0196 (live demo). Presentation only.
##
## Colours are blends of the locked ART-LOCK-001 pigments
## (`docs/design/ui_refinement/asset_generation_lock.json`), which allows interpolation between
## locked pigments but no new base hues. The light is a warm late-morning sun a little east of
## south -- behind an RTS camera that looks north over the square -- so the building fronts that
## face the square catch it and the shadows fall away up the screen.

const Layout := preload("res://demo/world/world_layout.gd")
const Scatter := preload("res://demo/world/world_scatter.gd")
const GROUND_SHADER := preload("res://demo/world/demo_ground.gdshader")

# ART-LOCK-001 pigments, sRGB.
const INK: Color = Color(0.145, 0.216, 0.176)
const OAT: Color = Color(0.918, 0.882, 0.784)
const SAGE: Color = Color(0.439, 0.506, 0.443)
const LEAF: Color = Color(0.275, 0.4, 0.278)
const BRASS: Color = Color(0.706, 0.604, 0.345)
const TIMBER: Color = Color(0.569, 0.38, 0.243)
const UMBER: Color = Color(0.349, 0.263, 0.196)
const CREAM: Color = Color(0.961, 0.941, 0.875)
const FLINT: Color = Color(0.541, 0.553, 0.518)

## The ground plane is far larger than the play area so its edge is never on screen.
const GROUND_SIZE_M: float = 400.0
const NOISE_SIZE_PX: int = 512
const MACRO_NOISE_SEED: int = 7
const DETAIL_NOISE_SEED: int = 11

## Where the sun sits (unit vector toward it): ~50 degrees up, a little east of south.
const SUN_TOWARD: Vector3 = Vector3(0.244, 0.766, 0.59)
const SUN_COLOR: Color = Color(1.0, 0.9, 0.76)
const SUN_ENERGY: float = 1.45
## Shadows only need to cover the ~40 m village seen from an RTS height.
const SHADOW_MAX_DISTANCE_M: float = 85.0


static func _noise_texture(seed_value: int, frequency: float, octaves: int,
		as_normal: bool) -> NoiseTexture2D:
	"""A seamless, seeded fractal-noise texture (optionally as a normal map)."""
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	var texture := NoiseTexture2D.new()
	texture.width = NOISE_SIZE_PX
	texture.height = NOISE_SIZE_PX
	texture.seamless = true
	texture.as_normal_map = as_normal
	texture.bump_strength = 6.0
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture


static func _ground_material() -> ShaderMaterial:
	"""The woodland ground: noise-blended grass, worn paths from the layout, leaf litter beyond."""
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter(&"macro_noise", _noise_texture(MACRO_NOISE_SEED, 0.006, 4, false))
	material.set_shader_parameter(&"detail_noise", _noise_texture(DETAIL_NOISE_SEED, 0.02, 5, false))
	material.set_shader_parameter(&"detail_normal", _noise_texture(DETAIL_NOISE_SEED, 0.03, 4, true))
	_set_ground_colors(material)
	material.set_shader_parameter(&"path_segments", PackedVector4Array(Layout.PATH_SEGMENTS))
	material.set_shader_parameter(&"path_radii", PackedFloat32Array(Layout.PATH_RADII))
	material.set_shader_parameter(&"path_count", Layout.PATH_SEGMENTS.size())
	material.set_shader_parameter(&"clearing_radius", Scatter.CLEARING_RADIUS_M)
	material.set_shader_parameter(&"clearing_wobble", Scatter.CLEARING_WOBBLE_M)
	material.set_shader_parameter(&"south_opening", Scatter.SOUTH_OPENING_M)
	return material


static func _set_ground_colors(material: ShaderMaterial) -> void:
	"""Ground pigments: warm grass, darker moss, earth, a muted worn path and leaf litter."""
	material.set_shader_parameter(&"grass_color", LEAF.lerp(BRASS, 0.28))
	material.set_shader_parameter(&"grass_sun_color", LEAF.lerp(BRASS, 0.56))
	material.set_shader_parameter(&"moss_color", LEAF.lerp(INK, 0.35))
	material.set_shader_parameter(&"earth_color", UMBER.lerp(TIMBER, 0.3))
	material.set_shader_parameter(&"path_color", TIMBER.lerp(BRASS, 0.55).lerp(OAT, 0.2))
	material.set_shader_parameter(&"path_worn_color", UMBER.lerp(TIMBER, 0.45))
	material.set_shader_parameter(&"litter_color", UMBER.lerp(LEAF, 0.35))


static func make_ground() -> MeshInstance3D:
	"""A flat ground plane at GROUND_Y, far larger than the play area."""
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE_M, GROUND_SIZE_M)
	plane.material = _ground_material()
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.position = Vector3(0.0, Layout.GROUND_Y, 0.0)
	return ground


static func make_sun() -> DirectionalLight3D:
	"""The warm late-morning sun, with soft shadows tuned for a ~40 m village."""
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis.looking_at(-SUN_TOWARD.normalized(), Vector3.UP), Vector3.ZERO)
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	sun.light_angular_distance = 1.2
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.1
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = SHADOW_MAX_DISTANCE_M
	sun.directional_shadow_blend_splits = true
	return sun


static func _sky() -> Sky:
	"""A soft procedural sky: clear blue overhead, a warm hazy horizon, mossy ground below."""
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color(0.36, 0.52, 0.7)
	material.sky_horizon_color = CREAM.lerp(SAGE, 0.25)
	material.ground_horizon_color = CREAM.lerp(SAGE, 0.35)
	material.ground_bottom_color = LEAF.lerp(INK, 0.5)
	material.sun_angle_max = 20.0
	material.sky_energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = material
	return sky


static func _environment() -> Environment:
	"""ACES tonemap, sky ambient, SSAO for contact shading and a light warm haze for depth."""
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = _sky()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.fog_enabled = true
	env.fog_light_color = CREAM.lerp(SAGE, 0.3)
	env.fog_density = 0.0022
	env.fog_aerial_perspective = 0.25
	env.fog_sky_affect = 0.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.04
	return env


static func make_environment() -> WorldEnvironment:
	"""The WorldEnvironment node carrying the sky, tonemap, SSAO and haze."""
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = _environment()
	return world_env

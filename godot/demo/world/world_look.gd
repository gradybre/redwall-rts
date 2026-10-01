extends RefCounted
## The demo village's ground, sun and sky. Decision 0196 (live demo). Presentation only.
##
## WORLD MATERIAL TARGETS (decision 0301, review F51). The world's colours answer to the approved
## world-art example -- DEC-038, `docs/art-reference/visual_direction_alignment.md` -- and NOT to the
## UI illustration lock (`docs/design/ui_refinement/asset_generation_lock.md`), whose twelve pigments
## "do not become global world-rendering rules". DEC-038 asks for "restrained moss green, oatmeal,
## ochre and earth tones with deliberate value grouping", a colour RELATIONSHIP, not a palette. So:
##   * the nine BASE TONES below are the world's own. They were first seeded (decision 0196) from the
##     UI lock's values; decision 0301 compared every ground and water target against the approved
##     example and kept them, because each already sits in its DEC-038 value group -- a new hue may be
##     added whenever the world reference calls for one, and nothing here limits the world to these;
##   * each MATERIAL TARGET (`ground_targets`, `bank_targets`, `water_targets`) is a named colour with a
##     declared VALUE GROUP (`value_group_of`): dark, mid, light or sky, by linear luminance. The
##     checks hold every target inside its group, and the path above the grass by PATH_OVER_GRASS.
## The light is a warm late-morning sun a little east of south -- behind an RTS camera that looks
## north over the square -- so the building fronts that face the square catch it and the shadows fall
## away up the screen.

const Layout := preload("res://demo/world/world_layout.gd")
const Scatter := preload("res://demo/world/world_scatter.gd")
const GROUND_SHADER := preload("res://demo/world/demo_ground.gdshader")

# The world's base tones, sRGB (see WORLD MATERIAL TARGETS).
const INK: Color = Color(0.145, 0.216, 0.176)
const OAT: Color = Color(0.918, 0.882, 0.784)
const SAGE: Color = Color(0.439, 0.506, 0.443)
const LEAF: Color = Color(0.275, 0.4, 0.278)
const BRASS: Color = Color(0.706, 0.604, 0.345)
const TIMBER: Color = Color(0.569, 0.38, 0.243)
const UMBER: Color = Color(0.349, 0.263, 0.196)
const CREAM: Color = Color(0.961, 0.941, 0.875)
const FLINT: Color = Color(0.541, 0.553, 0.518)

## DEC-038 value groups: linear-luminance ranges a material target is kept inside (decision 0301).
const VALUE_DARK: Vector2 = Vector2(0.0, 0.1)
const VALUE_MID: Vector2 = Vector2(0.1, 0.26)
const VALUE_LIGHT: Vector2 = Vector2(0.26, 0.5)
const VALUE_SKY: Vector2 = Vector2(0.5, 1.0)
## The worn path reads at least this much lighter than the grass (the approved example's dirt paths
## run 1.8-3.4x the value of its lit grass; decision 0301).
const PATH_OVER_GRASS: float = 1.4
## Each material target's value group (the names are the shaders' parameters).
const VALUE_GROUPS: Dictionary = {
	&"grass_color": VALUE_MID, &"grass_sun_color": VALUE_MID, &"moss_color": VALUE_DARK,
	&"earth_color": VALUE_DARK, &"path_color": VALUE_LIGHT, &"path_worn_color": VALUE_DARK,
	&"litter_color": VALUE_DARK, &"mud_dry": VALUE_DARK, &"mud_wet": VALUE_DARK, &"bed_color": VALUE_DARK,
	&"shallow_color": VALUE_MID, &"deep_color": VALUE_DARK, &"horizon_color": VALUE_SKY,
	&"foam_color": VALUE_SKY,
}

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
## SHADOW QUALITY. Brendan: the shadows "look good in form, but look a bit grainy". Godot's soft
## shadows blur with a few jittered taps at the default LOW filter quality, which reads as a
## checkerboard unless TAA hides it, and an 85 m range spread the 4096 map thin. Compared side by
## side on a resident and a bucket (decision 0196): ULTRA filter + an 8192 map + a range that
## follows the zoom gives solid, soft-edged shadows; HIGH alone still speckled.
const SHADOW_FILTER: RenderingServer.ShadowQuality = RenderingServer.SHADOW_QUALITY_SOFT_ULTRA
const SHADOW_ATLAS_SIZE: int = 8192
const SHADOW_BLUR: float = 1.0
## The range follows the camera: twice its distance to the focus covers what is on screen from
## the 50-degree default pitch; 22 m (the default) gives 44 m, the zoomed-out 70 m hits the cap.
const SHADOW_RANGE_PER_CAMERA_M: float = 2.0
const SHADOW_MIN_DISTANCE_M: float = 30.0


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
	"""The ground's material targets (`ground_targets`) onto its shader."""
	set_targets(material, ground_targets())


static func ground_targets() -> Dictionary:
	"""The ground's world material targets: warm grass, darker moss, earth, a muted worn path and leaf
	litter (see WORLD MATERIAL TARGETS)."""
	return {
		&"grass_color": LEAF.lerp(BRASS, 0.28), &"grass_sun_color": LEAF.lerp(BRASS, 0.56),
		&"moss_color": LEAF.lerp(INK, 0.35), &"earth_color": UMBER.lerp(TIMBER, 0.3),
		&"path_color": TIMBER.lerp(BRASS, 0.55).lerp(OAT, 0.2), &"path_worn_color": UMBER.lerp(TIMBER, 0.45),
		&"litter_color": UMBER.lerp(LEAF, 0.35),
	}


static func bank_targets() -> Dictionary:
	"""The bank film's targets (demo/water/water_bank.gdshader): dry and wet mud, and the bed."""
	return {
		&"mud_dry": UMBER.lerp(LEAF, 0.3).lerp(TIMBER, 0.1), &"mud_wet": UMBER.lerp(INK, 0.5),
		&"bed_color": UMBER.lerp(INK, 0.5).lerp(BRASS, 0.15),
	}


static func water_targets() -> Dictionary:
	"""The water surface's targets (demo/water/water.gdshader): sandy shallows, deep water darkening
	toward the shade tone, the sky's own hazy horizon in the fresnel, and foam."""
	return {
		&"shallow_color": SAGE.lerp(BRASS, 0.3), &"deep_color": INK.lerp(SAGE, 0.08).darkened(0.4),
		&"horizon_color": CREAM.lerp(SAGE, 0.25), &"foam_color": CREAM,
	}


static func set_targets(material: ShaderMaterial, targets: Dictionary) -> void:
	"""Every target onto the shader parameter of its name."""
	for key: StringName in targets:
		material.set_shader_parameter(key, targets[key])


static func value_of(colour: Color) -> float:
	"""A colour's value: its linear luminance (Rec. 709), 0..1."""
	var linear: Color = colour.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b


static func value_group_of(target: StringName) -> Vector2:
	"""The value group a named material target is kept inside (VALUE_GROUPS; the whole range if none)."""
	return VALUE_GROUPS.get(target, Vector2(0.0, 1.0))


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


static func apply_shadow_quality() -> void:
	"""The renderer-wide directional shadow filter and map size the demo's sun needs."""
	RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_FILTER)
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS_SIZE, true)


static func shadow_distance_for(camera_distance_m: float) -> float:
	"""How far the sun's shadows reach for a camera this far from its focus."""
	return clampf(camera_distance_m * SHADOW_RANGE_PER_CAMERA_M, SHADOW_MIN_DISTANCE_M, SHADOW_MAX_DISTANCE_M)


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
	sun.shadow_blur = SHADOW_BLUR
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

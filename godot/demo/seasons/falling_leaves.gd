extends Node3D
## Autumn's falling leaves, a few at a time, over where the camera looks. Decision 0551. Presentation only.
##
## ONE particle system, built once: MAX_LEAVES leaves at most (the system's own fixed pool; nothing is made per
## leaf or per frame), each a small leaf-shaped card in one of the autumn colours, tumbling down from a box of air
## AIR_HALF_M about the view's focus. season_view.gd says when they fall (season_look.gd `leaf_drop`) and moves the
## box each frame; they fall at the game's speed, so a pause holds them in the air. REDUCED MOTION (decision 0471)
## turns them off altogether -- they are decoration, so the reduced preset keeps none, rather than the
## PARTICLE_RATIO share the working particles keep.

const LookScript := preload("res://demo/seasons/season_look.gd")

const MAX_LEAVES: int = 40
const LIFETIME_S: float = 7.0
const AIR_HALF_M: float = 14.0
const AIR_HEIGHT_M: float = 7.0
const LEAF_SIZE_M: Vector2 = Vector2(0.24, 0.17)
const FALL_SPEED_M: float = 0.8
const TEXTURE_PX: int = 32

var _particles: CPUParticles3D = null
## Whether leaves are let fall (the system follows it while it is in the scene: a world-space system cannot start
## outside it).
var _falling: bool = false


func build() -> void:
	"""The one system, off until leaves fall."""
	name = "FallingLeaves"
	_particles = CPUParticles3D.new()
	_particles.name = "Leaves"
	_particles.amount = MAX_LEAVES
	_particles.lifetime = LIFETIME_S
	_particles.mesh = _leaf_mesh()
	_particles.local_coords = false
	_particles.emitting = false
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(AIR_HALF_M, 0.5, AIR_HALF_M)
	_particles.direction = Vector3(0.35, -1.0, 0.2)
	_particles.spread = 30.0
	_particles.gravity = Vector3(0.0, -0.25, 0.0)
	_particles.initial_velocity_min = FALL_SPEED_M * 0.7
	_particles.initial_velocity_max = FALL_SPEED_M * 1.3
	_particles.angular_velocity_min = -200.0
	_particles.angular_velocity_max = 200.0
	_particles.angle_min = 0.0
	_particles.angle_max = 360.0
	_particles.scale_amount_min = 0.7
	_particles.scale_amount_max = 1.3
	_particles.color_initial_ramp = _colours()
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)


func run(falling: bool, focus: Vector3, speed: float) -> void:
	"""This frame: leaves fall (or stop) over `focus` at the game's `speed` (0 paused: they hang)."""
	_falling = falling
	if _particles.emitting != falling and _particles.is_inside_tree():
		_particles.emitting = falling
	_particles.speed_scale = speed
	_particles.position = Vector3(focus.x, focus.y + AIR_HEIGHT_M, focus.z)


func burst(on: bool) -> void:
	"""Every leaf out at once (the boot prewarm: drawn in its frames), or back to a steady fall with none left in
	the air."""
	_particles.explosiveness = 1.0 if on else 0.0
	if not on and _particles.is_inside_tree():
		_particles.restart()
		_particles.emitting = false
		_falling = false


func is_falling() -> bool:
	"""Whether leaves are being let fall now."""
	return _falling


func particles() -> CPUParticles3D:
	"""The system (checks and the prewarm)."""
	return _particles


static func _colours() -> Gradient:
	"""Each leaf takes one of the autumn colours at random."""
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.6, 0.88])
	gradient.colors = PackedColorArray([LookScript.GOLD, LookScript.OCHRE, LookScript.RUSSET, LookScript.RED])
	return gradient


static func _leaf_mesh() -> QuadMesh:
	"""A small card cut to a leaf's shape, coloured per particle, turned to face the camera as it tumbles."""
	var material := StandardMaterial3D.new()
	material.albedo_texture = _leaf_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	var quad := QuadMesh.new()
	quad.size = LEAF_SIZE_M
	quad.material = material
	return quad


static func _leaf_texture() -> ImageTexture:
	"""A white leaf on transparent: a pointed oval with a stalk's notch, drawn once."""
	var image := Image.create(TEXTURE_PX, TEXTURE_PX, true, Image.FORMAT_RGBA8)
	var half: float = float(TEXTURE_PX) * 0.5
	for y: int in TEXTURE_PX:
		for x: int in TEXTURE_PX:
			var u: float = (float(x) + 0.5 - half) / half
			var v: float = (float(y) + 0.5 - half) / half
			var width: float = 0.62 * sqrt(maxf(0.0, 1.0 - v * v)) * (1.0 - 0.25 * v)
			var inside: bool = absf(u) <= width and absf(v) < 0.95
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0 if inside else 0.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

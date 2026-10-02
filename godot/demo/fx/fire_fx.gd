extends Node3D
## A fire that lightning starts: flames, smoke, embers and a flickering light, as ONE reusable effect. Art pass 3,
## decision 0971. Presentation only, and NOT WIRED IN: the livelier-weather work (#34) owns where and when a strike
## sets something alight, and what burning does; this only draws it.
##
## POOL-FRIENDLY. Everything is built in `configure` and nothing is allocated after it: three CPUParticles3D of fixed
## amounts (FLAME_AMOUNT + SMOKE_AMOUNT + EMBER_AMOUNT = `allocated()` particles at most, the way warren_particles.gd
## budgets) and one OmniLight3D. A pool keeps N of these and hands one out with `ignite`; `release` returns it idle
## at once. `is_idle` says whether it can be handed out again.
##
## ITS LIFE, on the demo clock (`set_speed`; 0 paused: the flames hang, the light holds):
##   CATCHING  the strike's first flicker grows to a full fire over CATCH_S
##   BURNING   full until `douse` (rain, a bucket chain) or `burn_for`'s time runs out
##   DYING     the flames sink over DIE_S while the smoke thickens
##   SMOULDER  smoke only for SMOULDER_S (its last puffs rising away), then IDLE (hidden, nothing emitting)
## `intensity()` (0..1) is how big the flames are now: the fire's node scale follows it, so a dying fire shrinks into
## its embers rather than vanishing. Size it to what burns with `ignite`'s `size_m` (a shrub 1, a woodpile 1.5, a
## thatched roof 3; demo values).
##
## REDUCED MOTION (demo_motion.gd): the particle counts are cut by demo_motion's own `apply_particles` like every other
## system; `set_reduced` also holds the light steady (no flicker).

enum Stage { IDLE, CATCHING, BURNING, DYING, SMOULDER }

const FLAME_AMOUNT: int = 28
const SMOKE_AMOUNT: int = 14
const EMBER_AMOUNT: int = 12
const FLAME_LIFE_S: float = 0.85
const SMOKE_LIFE_S: float = 3.2
const EMBER_LIFE_S: float = 1.6
const CATCH_S: float = 2.5
const DIE_S: float = 4.0
const SMOULDER_S: float = 6.0
## The flames' first flicker, as a share of a full fire, when a strike catches.
const SPARK_SHARE: float = 0.15
const LIGHT_COLOUR: Color = Color(1.0, 0.6, 0.28)
const LIGHT_ENERGY: float = 2.4
const LIGHT_RANGE_M: float = 7.0
const FLICKER: float = 0.25
const SMOKE_COLOUR: Color = Color(0.5, 0.48, 0.45, 0.3)
const EMBER_COLOUR: Color = Color(1.0, 0.72, 0.3)

## The billboards' shader: Godot's own particle billboard, its colour and alpha the particle's times the soft dot. A
## particle not yet born (a fire younger than the smoke's life) is drawn by CPUParticles3D at the emitter as black:
## it is discarded here (no flame, smoke or ember is ever black) -- a StandardMaterial3D drew it as a black ball.
const PUFF_SHADER: String = """
shader_type spatial;
render_mode unshaded, BLEND, depth_draw_never, cull_disabled;
uniform sampler2D dot : source_color, filter_linear_mipmap;
void vertex() {
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]),
			MODEL_MATRIX[3]);
	world = world * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0),
			vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	if (COLOR.a < 0.004 || COLOR.r + COLOR.g + COLOR.b < 0.02) {
		discard;
	}
	vec4 tex = texture(dot, UV);
	ALBEDO = COLOR.rgb * tex.rgb;
	ALPHA = COLOR.a * tex.a;
}
"""

static var _soft: GradientTexture2D = null
static var _puffs: Array[ShaderMaterial] = [null, null]

var _flames: CPUParticles3D = null
var _smoke: CPUParticles3D = null
var _embers: CPUParticles3D = null
var _light: OmniLight3D = null
var _stage: Stage = Stage.IDLE
var _stage_s: float = 0.0
var _burn_left_s: float = -1.0
var _size_m: float = 1.0
var _speed: float = 1.0
var _reduced: bool = false
var _clock_s: float = 0.0


static func allocated() -> int:
	"""The most particles one fire can have alive at once (a pool's budget is this times its size)."""
	return FLAME_AMOUNT + SMOKE_AMOUNT + EMBER_AMOUNT


func configure(layer: int = 1) -> void:
	"""Build the emitters and the light once, idle and hidden, on `layer`."""
	name = "FireFx"
	_flames = _emitter(FLAME_AMOUNT, FLAME_LIFE_S, _quad(0.42, true, 1.8), true, layer)
	_flames.color_ramp = _flame_ramp()
	_rise(_flames, Vector3(0.28, 0.05, 0.28), 12.0, Vector2(0.8, 1.4), 1.0)
	_flames.scale_amount_min = 0.7
	_flames.scale_amount_max = 1.3
	_flames.scale_amount_curve = _curve([Vector2(0.0, 0.7), Vector2(0.25, 1.0), Vector2(1.0, 0.15)])
	_smoke = _emitter(SMOKE_AMOUNT, SMOKE_LIFE_S, _quad(1.3, false), false, layer)
	_smoke.color_ramp = _smoke_ramp()
	_rise(_smoke, Vector3(0.25, 0.1, 0.25), 18.0, Vector2(0.3, 0.6), 0.35)
	_smoke.gravity.x = 0.2
	_smoke.position.y = 0.5
	_smoke.scale_amount_min = 0.7
	_smoke.scale_amount_max = 1.4
	_smoke.scale_amount_curve = _curve([Vector2(0.0, 0.5), Vector2(1.0, 2.4)])
	_embers = _emitter(EMBER_AMOUNT, EMBER_LIFE_S, _quad(0.05, true), false, layer)
	_embers.color_ramp = _fade_ramp(EMBER_COLOUR)
	_rise(_embers, Vector3(0.3, 0.1, 0.3), 35.0, Vector2(0.8, 1.8), 0.9)
	_build_light(layer)
	release()


func _build_light(layer: int) -> void:
	"""The fire's warm light, off."""
	_light = OmniLight3D.new()
	_light.light_color = LIGHT_COLOUR
	_light.omni_range = LIGHT_RANGE_M
	_light.position.y = 0.5
	_light.shadow_enabled = false
	_light.layers = layer
	_light.light_cull_mask = 0xFFFFFFFF
	add_child(_light)


func _rise(p: CPUParticles3D, box: Vector3, spread: float, speed: Vector2, lift: float) -> void:
	"""Emit `p` from a box of half-extents `box` at the base, upward within `spread` degrees at `speed` (min, max) m/s,
	lifted by `lift` m/s^2 (hot air) instead of falling."""
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0.0, lift, 0.0)


func _emitter(amount: int, life: float, mesh: Mesh, local: bool, layer: int) -> CPUParticles3D:
	"""One idle emitter of `amount` billboards living `life` seconds."""
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.mesh = mesh
	p.local_coords = local
	p.emitting = false
	p.layers = layer
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.randomness = 0.5
	add_child(p)
	return p


func ignite(at: Vector3, size_m: float = 1.0, burn_s: float = -1.0) -> void:
	"""Start a fire at `at` (its base on the ground), `size_m` across, burning `burn_s` seconds of demo time once
	caught (negative: until `douse`)."""
	position = at
	_size_m = size_m
	_burn_left_s = burn_s
	_enter(Stage.CATCHING)
	visible = true
	for p: CPUParticles3D in [_flames, _smoke, _embers]:
		p.restart()
		p.emitting = true
	_pose()


func douse() -> void:
	"""Put the fire out: it dies down, then smoulders (a fire already dying is left to it)."""
	if _stage == Stage.CATCHING or _stage == Stage.BURNING:
		_enter(Stage.DYING)


func release() -> void:
	"""Back to idle at once, hidden, nothing emitting: ready to be handed out again."""
	_enter(Stage.IDLE)
	visible = false
	for p: CPUParticles3D in [_flames, _smoke, _embers]:
		if p != null:
			p.emitting = false
	if _light != null:
		_light.light_energy = 0.0


func is_idle() -> bool:
	"""Whether this fire is free for a pool to hand out."""
	return _stage == Stage.IDLE


func stage() -> Stage:
	"""Where in its life the fire is."""
	return _stage


func set_speed(speed: float) -> void:
	"""The demo clock's speed (0: paused, the flames hang, the light holds)."""
	_speed = speed
	for p: CPUParticles3D in [_flames, _smoke, _embers]:
		if p != null:
			p.speed_scale = speed


func set_reduced(on: bool) -> void:
	"""Reduced motion: the light holds steady."""
	_reduced = on


func _enter(next: Stage) -> void:
	"""Move to stage `next`, its clock at 0."""
	_stage = next
	_stage_s = 0.0


func _process(delta: float) -> void:
	"""Advance the fire's life on the demo clock and pose it."""
	if _stage == Stage.IDLE or _speed <= 0.0:
		return
	var step := delta * _speed
	_stage_s += step
	_clock_s += step
	_advance(step)
	_pose()


func _advance(step: float) -> void:
	"""Move on from the current stage when its time is up."""
	match _stage:
		Stage.CATCHING:
			if _stage_s >= CATCH_S:
				_enter(Stage.BURNING)
		Stage.BURNING:
			if _burn_left_s >= 0.0:
				_burn_left_s -= step
				if _burn_left_s <= 0.0:
					_enter(Stage.DYING)
		Stage.DYING:
			if _stage_s >= DIE_S:
				_enter(Stage.SMOULDER)
				_flames.emitting = false
				_embers.emitting = false
		Stage.SMOULDER:
			if _stage_s >= SMOULDER_S - SMOKE_LIFE_S:
				_smoke.emitting = false
			if _stage_s >= SMOULDER_S:
				release()


func intensity() -> float:
	"""How big the flames are now, 0..1 (see the header)."""
	match _stage:
		Stage.CATCHING:
			return lerpf(SPARK_SHARE, 1.0, smoothstep(0.0, CATCH_S, _stage_s))
		Stage.BURNING:
			return 1.0
		Stage.DYING:
			return 1.0 - smoothstep(0.0, DIE_S, _stage_s)
	return 0.0


func _pose() -> void:
	"""Scale the flames to the fire's size and intensity; set the light (flickering unless reduced)."""
	var now := intensity()
	_flames.scale = Vector3.ONE * maxf(0.05, _size_m * now)
	_embers.scale = _flames.scale
	_smoke.scale = Vector3.ONE * _size_m
	var flicker := 0.0 if _reduced else FLICKER * (sin(_clock_s * 13.0) * 0.6 + sin(_clock_s * 7.3 + 1.7) * 0.4)
	_light.light_energy = LIGHT_ENERGY * now * (1.0 + flicker)
	_light.omni_range = LIGHT_RANGE_M * maxf(0.4, _size_m)


static func soft_dot() -> GradientTexture2D:
	"""A soft round dot, white in the middle fading to clear: every billboard's texture."""
	if _soft == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_soft = GradientTexture2D.new()
		_soft.gradient = gradient
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(0.5, 0.0)
		_soft.width = 64
		_soft.height = 64
	return _soft


func _quad(size_m: float, glow: bool, tall: float = 1.0) -> QuadMesh:
	"""A camera-facing quad `size_m` across (and `tall` times that high: a flame's tongue) with the soft dot, its colour
	from the particle: added light for flames and embers (`glow`), blended for smoke (see PUFF_SHADER)."""
	var quad := QuadMesh.new()
	quad.size = Vector2(size_m, size_m * tall)
	quad.material = puff_material(glow)
	return quad


static func puff_material(glow: bool) -> ShaderMaterial:
	"""The shared billboard material, added (`glow`) or blended."""
	var index := 1 if glow else 0
	if _puffs[index] == null:
		var shader := Shader.new()
		shader.code = PUFF_SHADER.replace("BLEND", "blend_add" if glow else "blend_mix")
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter(&"dot", soft_dot())
		_puffs[index] = material
	return _puffs[index]


static func _flame_ramp() -> Gradient:
	"""Flame colour over a particle's life: white-gold at the root, orange, a deep red, gone."""
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.86, 0.5, 0.55), Color(1.0, 0.55, 0.16, 0.5),
			Color(0.7, 0.2, 0.06, 0.3), Color(0.3, 0.08, 0.04, 0.0)])
	return ramp


static func _smoke_ramp() -> Gradient:
	"""Smoke over a puff's life: clear where it leaves the flames, thickest a third of the way up, thinning away."""
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([Color(SMOKE_COLOUR, 0.0), SMOKE_COLOUR, Color(SMOKE_COLOUR, 0.0)])
	return ramp


static func _fade_ramp(colour: Color) -> Gradient:
	"""`colour` fading in quickly and out slowly over a particle's life."""
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	ramp.colors = PackedColorArray([Color(colour, 0.0), colour, Color(colour, 0.0)])
	return ramp


static func _curve(points: Array[Vector2]) -> Curve:
	"""A curve through `points` (x 0..1)."""
	var curve := Curve.new()
	for point: Vector2 in points:
		curve.add_point(point)
	return curve

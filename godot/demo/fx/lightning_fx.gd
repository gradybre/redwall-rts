extends Node3D
## A lightning strike: a forked bolt from the sky to the ground and its flash. Art pass 3, decision 0971. Presentation
## only, and NOT WIRED IN: the livelier-weather work (#34) chooses when and where a storm strikes (and lights a
## fire_fx.gd there if the strike catches); this only draws it.
##
## THE BOLT is one of BOLT_VARIANTS meshes built once from fixed seeds (`bolt_mesh`): a main channel cut by midpoint
## displacement into 2^DETAIL segments, with BRANCHES shorter forks, each segment two crossed ribbons so it reads from
## any camera. They are built for a BOLT_HEIGHT_M sky; `strike` stretches the chosen one to span its two points. So a
## strike allocates nothing.
##
## THE FLASH (`flash()`, 0..1) is two strokes and a fade, as real return strokes come (STROKES: a full flash, a dip, a
## second stroke, gone by FLASH_S); the bolt shows while the flash is over BOLT_SHOWS (and through the first
## stroke's dip). An OmniLight3D at the strike
## carries it into the scene; a caller may also hand in the sun (`sky_light`), whose energy it lifts by SKY_LIFT x the
## flash and restores. The weather view can read `flash()` to brighten its sky.
##
## PHOTOSENSITIVITY. Strikes are at least MIN_GAP_S apart (`strike` refuses a sooner one), so the screen never flashes
## more than twice in any second -- under WCAG 2.3.1's three. With reduced motion (`set_reduced`) a strike is ONE soft
## swell to REDUCED_PEAK over FLASH_S, no restroke, and the bolt fades with it.
##
## THE CLOCK. `set_speed` takes the demo clock's speed; paused, the strike holds where it is (a still frame, not a
## flicker).

const BOLT_VARIANTS: int = 4
const BOLT_HEIGHT_M: float = 40.0
const BOLT_WIDTH_M: float = 0.35
const DETAIL: int = 6
const JAGGED: float = 0.11
const BRANCHES: int = 3
const BRANCH_WIDTH: float = 0.45
const SEED: int = 9710
const FLASH_S: float = 0.6
## (time s, flash) keys of a strike's flash, eased between.
const STROKES: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.03, 1.0), Vector2(0.1, 0.18), Vector2(0.17, 0.85),
		Vector2(0.3, 0.3), Vector2(0.6, 0.0)]
const BOLT_SHOWS: float = 0.12
const REDUCED_PEAK: float = 0.4
const MIN_GAP_S: float = 1.5
const BOLT_COLOUR: Color = Color(0.86, 0.9, 1.0)
const LIGHT_ENERGY: float = 9.0
const LIGHT_RANGE_M: float = 70.0
const SKY_LIFT: float = 1.6
const BOLT_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 bolt_colour : source_color;
uniform float glow = 0.0;
void fragment() {
	float core = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = mix(bolt_colour.rgb, vec3(1.0), core * core) * glow * 2.5;
	ALPHA = clamp(core * glow * 1.5, 0.0, 1.0);
}
"""

static var _bolts: Array[ArrayMesh] = []
static var _shader: Shader = null

var sky_light: DirectionalLight3D = null
var _bolt: MeshInstance3D = null
var _material: ShaderMaterial = null
var _light: OmniLight3D = null
var _since_s: float = 1e6
var _speed: float = 1.0
var _reduced: bool = false
var _sky_base: float = 0.0
var strikes: int = 0


func configure(layer: int = 1) -> void:
	"""The bolt node (its mesh picked per strike), its own material and the strike light; idle and hidden."""
	name = "LightningFx"
	_material = ShaderMaterial.new()
	_material.shader = bolt_shader()
	_material.set_shader_parameter(&"bolt_colour", BOLT_COLOUR)
	_bolt = MeshInstance3D.new()
	_bolt.mesh = bolt_mesh(0)
	_bolt.material_override = _material
	_bolt.layers = layer
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.visible = false
	add_child(_bolt)
	_light = OmniLight3D.new()
	_light.light_color = BOLT_COLOUR
	_light.omni_range = LIGHT_RANGE_M
	_light.light_energy = 0.0
	_light.layers = layer
	add_child(_light)


func strike(sky: Vector3, ground: Vector3, variant: int = -1) -> bool:
	"""Strike from `sky` down to `ground` with bolt `variant` (negative: the next in turn). False, and nothing drawn,
	when the last strike was under MIN_GAP_S ago (see PHOTOSENSITIVITY)."""
	if _since_s < MIN_GAP_S:
		return false
	var span := sky - ground
	var pick := strikes % BOLT_VARIANTS if variant < 0 else variant % BOLT_VARIANTS
	_bolt.mesh = bolt_mesh(pick)
	var up := span.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var stretch := span.length() / BOLT_HEIGHT_M
	_bolt.transform = Transform3D(Basis(side, up, side.cross(up)) * Basis.from_scale(Vector3.ONE * stretch), ground)
	_light.position = ground + Vector3(0.0, 6.0, 0.0)
	if sky_light != null and _since_s >= FLASH_S:
		_sky_base = sky_light.light_energy
	_since_s = 0.0
	strikes += 1
	_apply()
	return true


func flash() -> float:
	"""The strike's flash now, 0..1 (see THE FLASH)."""
	if _since_s >= FLASH_S:
		return 0.0
	if _reduced:
		return REDUCED_PEAK * sin(PI * _since_s / FLASH_S)
	for k in range(1, STROKES.size()):
		if _since_s <= STROKES[k].x:
			var from := STROKES[k - 1]
			var share := (_since_s - from.x) / (STROKES[k].x - from.x)
			return lerpf(from.y, STROKES[k].y, smoothstep(0.0, 1.0, share))
	return 0.0


func set_speed(speed: float) -> void:
	"""The demo clock's speed (0: paused, the strike holds)."""
	_speed = speed


func set_reduced(on: bool) -> void:
	"""Reduced motion: one soft swell, no restroke (see PHOTOSENSITIVITY)."""
	_reduced = on


func is_striking() -> bool:
	"""Whether a strike's flash is still on."""
	return _since_s < FLASH_S


func _process(delta: float) -> void:
	"""Run the flash down on the demo clock, and the gap after it (`strike` refuses until MIN_GAP_S has passed)."""
	if _speed <= 0.0 or _since_s >= MIN_GAP_S:
		return
	var was_lit := _since_s < FLASH_S
	_since_s += delta * _speed
	if was_lit:
		_apply()


func _apply() -> void:
	"""Draw the flash: the bolt's glow (shown while bright enough, or always with reduced motion), the light, the sky."""
	var now := flash()
	_bolt.visible = now > 0.02 if _reduced else (now > BOLT_SHOWS or (_since_s < 0.2 and now > 0.05))
	_material.set_shader_parameter(&"glow", now)
	_light.light_energy = LIGHT_ENERGY * now
	if sky_light != null:
		sky_light.light_energy = _sky_base * (1.0 + SKY_LIFT * now)


static func bolt_shader() -> Shader:
	"""The bolts' shared shader: a white-hot core over a blue-white glow, added light."""
	if _shader == null:
		_shader = Shader.new()
		_shader.code = BOLT_SHADER
	return _shader


static func bolt_mesh(variant: int) -> ArrayMesh:
	"""Bolt `variant`, built once (see THE BOLT): it runs from the origin up +Y to BOLT_HEIGHT_M."""
	if _bolts.is_empty():
		for k in BOLT_VARIANTS:
			_bolts.append(_build_bolt(SEED + k))
	return _bolts[variant % BOLT_VARIANTS]


static func _build_bolt(seed_value: int) -> ArrayMesh:
	"""One bolt: the main channel and its forks as crossed ribbons, in one surface."""
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var main := _channel(dice, Vector3(0.0, BOLT_HEIGHT_M, 0.0), Vector3.ZERO, DETAIL)
	_ribbons(tool, main, BOLT_WIDTH_M)
	@warning_ignore("integer_division") var first: int = main.size() / 5
	@warning_ignore("integer_division") var last: int = main.size() * 3 / 5
	for k in BRANCHES:
		var from := main[dice.randi_range(first, last)]
		var reach := BOLT_HEIGHT_M * dice.randf_range(0.15, 0.3)
		var away := Vector3(dice.randf_range(-1.0, 1.0), -1.2, dice.randf_range(-1.0, 1.0)).normalized() * reach
		_ribbons(tool, _channel(dice, from, from + away, DETAIL - 2), BOLT_WIDTH_M * BRANCH_WIDTH)
	return tool.commit()


static func _channel(dice: RandomNumberGenerator, top: Vector3, bottom: Vector3, levels: int) -> PackedVector3Array:
	"""A jagged path from `top` to `bottom`: midpoint displacement, `levels` deep, each level half as rough."""
	var points := PackedVector3Array([top, bottom])
	var rough := top.distance_to(bottom) * JAGGED
	for level in levels:
		var finer := PackedVector3Array()
		for k in points.size() - 1:
			finer.append(points[k])
			var middle := (points[k] + points[k + 1]) * 0.5
			finer.append(middle + Vector3(dice.randf_range(-rough, rough), 0.0, dice.randf_range(-rough, rough)))
		finer.append(points[points.size() - 1])
		points = finer
		rough *= 0.5
	return points


static func _ribbons(tool: SurfaceTool, points: PackedVector3Array, width: float) -> void:
	"""Two crossed ribbons along `points`, `width` across, tapering to a third at the end (UV.x across)."""
	for across: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		for k in points.size() - 1:
			var w0 := width * lerpf(1.0, 0.35, float(k) / float(points.size()))
			var w1 := width * lerpf(1.0, 0.35, float(k + 1) / float(points.size()))
			var quad: Array[Vector3] = [points[k] - across * w0, points[k] + across * w0, points[k + 1] + across * w1,
					points[k + 1] - across * w1]
			for index: int in [0, 1, 2, 0, 2, 3]:
				tool.set_uv(Vector2(1.0 if index == 1 or index == 2 else 0.0, 0.0))
				tool.add_vertex(quad[index])

extends Node3D
## Bees about a hive: a small swarm drawn as ONE MultiMesh. Art pass 3, decision 0971. Presentation only, and NOT WIRED
## IN: the hives work (ECO-008..015, group Y) places one per skep (`place`) and drives it on the demo clock.
##
## NO PARTICLES. The warren's budget (warren_particles.gd, decision 0211) is spent, and a bee is not a puff: it flies a
## path, faces where it flies and beats its wings. So each bee is a MultiMesh instance moved on its own seeded loop
## round the hive -- a low orbit, a bob, and every few seconds a forage run out and back along its own bearing -- and
## its wings flap in the vertex shader (WING_SHADER): INSTANCE_CUSTOM.x is the bee's own phase, .y the swarm's beat,
## so the one shared material holds no swarm's state. The bee mesh is
## built once and shared by every swarm (`bee_mesh`); a swarm allocates nothing after `configure`.
##
## SIZE (DEC-048, demo-only): a bee BEE_LENGTH_M long beside the 1.00 m mouse -- about half its true ratio to a mouse,
## so a swarm still reads at the village camera as moving specks over the skep (bee_skep, 0.75 m) and never as birds.
##
## THE CLOCK. `set_speed` takes the demo clock's speed (0 paused: the bees hang where they are, wings still). With
## reduced motion (`set_reduced`, demo_motion.gd) the bees keep close and slow: REDUCED_REACH of their range and
## REDUCED_PACE of their speed, and their wings blur rather than beat.

const BEES: int = 10
const BEE_LENGTH_M: float = 0.09
## The swarm's orbit (m from the hive's centre), its height band over the hive's base, a forage run's reach and how
## often one starts (s, per bee, staggered), and the orbit speed range (radians a second).
const ORBIT_MIN_M: float = 0.35
const ORBIT_MAX_M: float = 0.8
const HEIGHT_MIN_M: float = 0.25
const HEIGHT_MAX_M: float = 1.0
const FORAGE_REACH_M: float = 3.5
const FORAGE_EVERY_S: float = 7.0
const FORAGE_SHARE: float = 0.35
const SPIN_MIN: float = 1.4
const SPIN_MAX: float = 2.6
const BOB_M: float = 0.07
const FLAPS_PER_S: float = 9.0
const REDUCED_REACH: float = 0.5
const REDUCED_PACE: float = 0.5
const SEED: int = 971
const BODY_COLOUR: Color = Color(0.83, 0.62, 0.18)
const STRIPE_COLOUR: Color = Color(0.12, 0.09, 0.06)
const WING_COLOUR: Color = Color(0.9, 0.93, 0.97, 0.45)
const WING_SHADER: String = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_burley;
uniform vec4 wing_colour : source_color;
uniform float flap_angle = 0.9;
void vertex() {
	float ang = sin((INSTANCE_CUSTOM.y + INSTANCE_CUSTOM.x) * TAU) * flap_angle * sign(VERTEX.x);
	float q = VERTEX.y - UV2.y;
	VERTEX.xy = vec2(VERTEX.x * cos(ang) - q * sin(ang), VERTEX.x * sin(ang) + q * cos(ang) + UV2.y);
}
void fragment() {
	ALBEDO = wing_colour.rgb;
	ALPHA = wing_colour.a * (1.0 - 0.6 * UV.x);
	ROUGHNESS = 0.3;
}
"""

static var _mesh: ArrayMesh = null
static var _wing_material: ShaderMaterial = null

var _multi: MultiMeshInstance3D = null
## Per bee: orbit radius, height, spin, phase, forage bearing, forage offset (s) -- seeded once.
var _orbit: PackedFloat32Array = PackedFloat32Array()
var _height: PackedFloat32Array = PackedFloat32Array()
var _spin: PackedFloat32Array = PackedFloat32Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _bearing: PackedFloat32Array = PackedFloat32Array()
var _offset: PackedFloat32Array = PackedFloat32Array()
var _time_s: float = 0.0
var _flap: float = 0.0
var _speed: float = 1.0
var _reduced: bool = false


func configure(layer: int = 1) -> void:
	"""The swarm's MultiMesh and every bee's seeded loop, once; shown, on `layer`."""
	name = "BeeSwarm"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = bee_mesh()
	multimesh.instance_count = BEES
	_multi = MultiMeshInstance3D.new()
	_multi.multimesh = multimesh
	_multi.layers = layer
	_multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_multi)
	_seed_loops()
	_pose_all()


func _seed_loops() -> void:
	"""Every bee's orbit, height, spin, phase, forage bearing and stagger, from SEED (the same swarm every time)."""
	var dice := RandomNumberGenerator.new()
	dice.seed = SEED
	for column: PackedFloat32Array in [_orbit, _height, _spin, _phase, _bearing, _offset]:
		column.resize(BEES)
	for k in BEES:
		_orbit[k] = dice.randf_range(ORBIT_MIN_M, ORBIT_MAX_M)
		_height[k] = dice.randf_range(HEIGHT_MIN_M, HEIGHT_MAX_M)
		_spin[k] = dice.randf_range(SPIN_MIN, SPIN_MAX) * (1.0 if k % 2 == 0 else -1.0)
		_phase[k] = dice.randf()
		_bearing[k] = dice.randf_range(0.0, TAU)
		_offset[k] = dice.randf_range(0.0, FORAGE_EVERY_S)


func place(at: Vector3) -> void:
	"""Put the swarm over a hive whose base centre is `at`."""
	position = at


func set_speed(speed: float) -> void:
	"""The demo clock's speed (0: paused, the bees hang still)."""
	_speed = speed


func set_reduced(on: bool) -> void:
	"""Reduced motion: closer, slower bees, wings blurred (see the header)."""
	_reduced = on
	wing_material().set_shader_parameter(&"flap_angle", 0.25 if on else 0.9)


func set_active(on: bool) -> void:
	"""Show the swarm (a hive with bees, in season) or hide it (winter, or no hive)."""
	visible = on
	set_process(on)


func _process(delta: float) -> void:
	"""Advance the bees on the demo clock and pose them."""
	if _speed <= 0.0:
		return
	var pace := REDUCED_PACE if _reduced else 1.0
	_time_s += delta * _speed * pace
	_flap = fposmod(_flap + delta * _speed * FLAPS_PER_S, 1.0)
	_pose_all()


func _pose_all() -> void:
	"""Every bee at its place on its loop now, facing the way it flies."""
	var multimesh := _multi.multimesh
	for k in BEES:
		var here := bee_at(k, _time_s)
		var ahead := bee_at(k, _time_s + 0.05)
		var heading := ahead - here
		var facing := Basis.IDENTITY
		if heading.length_squared() > 1e-8:
			facing = Basis.looking_at(heading, Vector3.UP, true)
		multimesh.set_instance_transform(k, Transform3D(facing, here))
		multimesh.set_instance_custom_data(k, Color(_phase[k], _flap, 0.0, 0.0))


func bee_at(k: int, t: float) -> Vector3:
	"""Bee `k`'s position (m, about the hive's base) at swarm time `t`: its orbit and bob, plus, for FORAGE_SHARE of
	each FORAGE_EVERY_S, a run out along its bearing and back (an eased out-and-back)."""
	var reach := REDUCED_REACH if _reduced else 1.0
	var angle := _phase[k] * TAU + t * _spin[k]
	var at := Vector3(cos(angle) * _orbit[k], _height[k] + sin(t * 3.1 + _phase[k] * 9.0) * BOB_M,
			sin(angle) * _orbit[k]) * reach
	var cycle := fposmod(t + _offset[k], FORAGE_EVERY_S) / FORAGE_EVERY_S
	if cycle < FORAGE_SHARE:
		var out := sin(PI * cycle / FORAGE_SHARE) * FORAGE_REACH_M * reach
		at += Vector3(cos(_bearing[k]) * out, out * 0.15, sin(_bearing[k]) * out)
	return at


static func wing_material() -> ShaderMaterial:
	"""The wings' shared flapping material."""
	if _wing_material == null:
		var shader := Shader.new()
		shader.code = WING_SHADER
		_wing_material = ShaderMaterial.new()
		_wing_material.shader = shader
		_wing_material.set_shader_parameter(&"wing_colour", WING_COLOUR)
	return _wing_material


static func bee_mesh() -> ArrayMesh:
	"""One bee, BEE_LENGTH_M long, facing +Z (glTF front, as the library's models): surface 0 a striped body, surface 1
	two wings hinged on its back (UV2.y the hinge height, UV.x how far out along the wing)."""
	if _mesh != null:
		return _mesh
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _body_arrays())
	var body := StandardMaterial3D.new()
	body.vertex_color_use_as_albedo = true
	body.roughness = 0.55
	_mesh.surface_set_material(0, body)
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _wing_arrays())
	_mesh.surface_set_material(1, wing_material())
	return _mesh


static func _body_arrays() -> Array:
	"""The body: an ellipsoid along Z, 8 rings of 8, banded in BODY_COLOUR and STRIPE_COLOUR, the head end dark."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	var sides := 8
	var radius := BEE_LENGTH_M * 0.22
	for ring in rings:
		for side in sides:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var r := ring + corner.x
				var s := side + corner.y
				var along := float(r) / float(rings)
				var around := TAU * float(s) / float(sides)
				var girth := sin(PI * along) * radius
				var point := Vector3(cos(around) * girth, sin(around) * girth, (0.5 - along) * BEE_LENGTH_M)
				tool.set_color(_band(along))
				tool.set_normal(Vector3(point.x, point.y, point.z * 0.3).normalized())
				tool.add_vertex(point)
	return tool.commit_to_arrays()


static func _band(along: float) -> Color:
	"""The body's colour `along` it from the head (0) to the tail (1): a dark head, then ochre and black bands."""
	if along < 0.25:
		return STRIPE_COLOUR
	return STRIPE_COLOUR if int(along * 9.0) % 2 == 0 else BODY_COLOUR


static func _wing_arrays() -> Array:
	"""Two wings, each a flat four-sided blade from the hinge on the back out to the side, swept back a little."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hinge_y := BEE_LENGTH_M * 0.2
	var span := BEE_LENGTH_M * 0.6
	for side: float in [1.0, -1.0]:
		var blade: Array[Vector3] = [Vector3(0.0, hinge_y, BEE_LENGTH_M * 0.12), Vector3(side * span, hinge_y,
				-BEE_LENGTH_M * 0.05), Vector3(side * span * 0.8, hinge_y, -BEE_LENGTH_M * 0.3), Vector3(0.0, hinge_y,
				-BEE_LENGTH_M * 0.08)]
		for index: int in [0, 1, 2, 0, 2, 3]:
			tool.set_uv(Vector2(absf(blade[index].x) / span, 0.0))
			tool.set_uv2(Vector2(0.0, hinge_y))
			tool.set_normal(Vector3.UP)
			tool.add_vertex(blade[index])
	return tool.commit_to_arrays()

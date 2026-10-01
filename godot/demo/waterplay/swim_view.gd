extends Node3D
## What the water shows of its swimmers: a ripple ring round every head at the surface (clay for one
## in difficulty; a fainter blue one over a diver, marking where it went down), a stream of bubbles
## over anyone below the surface, and a rescuer's thrown line. Decision 0196 (live demo). Presentation
## only: it reads swim_state.gd and the brains, one node of each per resident made once; per frame it
## only moves and shows them (no allocation).

const StateScript := preload("res://demo/waterplay/swim_state.gd")
const MotionScript := preload("res://demo/waterplay/swim_motion.gd")
const RescueScript := preload("res://demo/waterplay/rescue.gd")
const Tasks := preload("res://demo/waterplay/rescue_tasks.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")

const RIPPLE_COLOUR: Color = Color(0.92, 0.96, 1.0, 0.55)
const DISTRESS_COLOUR: Color = Color(0.9, 0.45, 0.3, 0.75)
const BUBBLE_COLOUR: Color = Color(0.92, 0.98, 1.0, 0.95)
## A diver's ring on the surface over it, fainter and bluer than a swimmer's.
const DIVE_COLOUR: Color = Color(0.7, 0.88, 1.0, 0.45)
const LINE_COLOUR: Color = Color(0.72, 0.6, 0.4)
const RIPPLE_LIFT_M: float = 0.02
const RIPPLE_PULSE_HZ: float = 0.9
const RIPPLE_SCALE: float = 0.12
const BUBBLE_RISE_M_S: float = 0.6
const LINE_RADIUS_M: float = 0.018
const HAND_HEIGHT_SHARE: float = 0.6

var _cast: DemoCastScript = null
var _state: StateScript = null
var _motion: MotionScript = null
var _rescue: RescueScript = null
var _ripples: Array[MeshInstance3D] = []
var _bubbles: Array[CPUParticles3D] = []
var _lines: Array[MeshInstance3D] = []
var _ripple_ok: StandardMaterial3D = null
var _ripple_bad: StandardMaterial3D = null
var _ripple_dive: StandardMaterial3D = null
var _time: float = 0.0


func configure(cast: DemoCastScript, state: StateScript, motion: MotionScript, rescue: RescueScript) -> void:
	"""Draw `cast`'s swimmers."""
	name = "SwimView"
	_cast = cast
	_state = state
	_motion = motion
	_rescue = rescue
	_ripple_ok = _flat(RIPPLE_COLOUR)
	_ripple_bad = _flat(DISTRESS_COLOUR)
	_ripple_dive = _flat(DIVE_COLOUR)
	for who: int in cast.actor_count():
		_ripples.append(_make_ripple())
		_bubbles.append(_make_bubbles())
		_lines.append(_make_line())


func _process(delta: float) -> void:
	"""Follow every swimmer (real time, so ripples still breathe while paused; still with reduced motion, decision
	0471)."""
	_time += delta
	var pulse: float = DemoMotion.pulse(1.0 + RIPPLE_SCALE * sin(TAU * RIPPLE_PULSE_HZ * _time))
	for who: int in _ripples.size():
		var actor := _cast.actor(who) as DemoActorScript
		_place(who, actor, pulse)


func _place(who: int, actor: DemoActorScript, pulse: float) -> void:
	"""One resident's ripple, bubbles and line."""
	var brain: BrainScript = actor.brain
	var m: int = _state.mode[who]
	var below: bool = m == StateScript.MODE_DIVE or m == StateScript.MODE_DISTRESS_UNDER
	var ripple: MeshInstance3D = _ripples[who]
	ripple.visible = brain.in_water
	if brain.in_water:
		var r: float = (brain.radius + 0.25) * (pulse if not below else 2.0 - pulse)
		ripple.position = Vector3(brain.position.x, _motion.surface_y_m(brain.position) + RIPPLE_LIFT_M, brain.position.y)
		ripple.scale = Vector3(r, 1.0, r)
		ripple.material_override = _ripple_bad if _state.in_difficulty(who) else (_ripple_dive if below else _ripple_ok)
	var bubbles: CPUParticles3D = _bubbles[who]
	bubbles.emitting = below
	bubbles.visible = below
	if below:
		bubbles.position = Vector3(brain.position.x, brain.ground_y_m + actor.height_m * 0.3, brain.position.y)
		bubbles.lifetime = maxf((_motion.surface_y_m(brain.position) - bubbles.position.y) / BUBBLE_RISE_M_S, 0.2)
	_place_line(who, actor)


func _place_line(who: int, actor: DemoActorScript) -> void:
	"""A thrower's line, from its hands to the one it is hauling in."""
	var line: MeshInstance3D = _lines[who]
	var rescue: Tasks.LineRescue = _rescue.line_of(actor.brain) if _rescue != null else null
	line.visible = rescue != null
	if rescue == null:
		return
	var victim: BrainScript = rescue.victim
	var from := Vector3(actor.brain.position.x, actor.brain.ground_y_m + actor.height_m * HAND_HEIGHT_SHARE, actor.brain.position.y)
	var to := Vector3(victim.position.x, victim.ground_y_m + 0.3, victim.position.y)
	var length: float = maxf(from.distance_to(to), 0.05)
	var axis := Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, length, 1.0))
	line.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP) * axis, (from + to) * 0.5)


func ripple_shown(who: int) -> bool:
	"""Whether resident `who`'s ripple shows (checks)."""
	return _ripples[who].visible


func bubbles_shown(who: int) -> bool:
	"""Whether resident `who`'s bubbles show (checks)."""
	return _bubbles[who].visible


func line_shown(who: int) -> bool:
	"""Whether resident `who` has a line out (checks)."""
	return _lines[who].visible


func _make_ripple() -> MeshInstance3D:
	"""A thin flat ring of unit radius."""
	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 4
	var node := MeshInstance3D.new()
	node.mesh = torus
	node.scale = Vector3(1.0, 1.0, 1.0)
	node.material_override = _ripple_ok
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node


func _make_bubbles() -> CPUParticles3D:
	"""A small stream of rising bubbles."""
	var particles := CPUParticles3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = _flat(BUBBLE_COLOUR)
	particles.mesh = sphere
	particles.amount = 22
	particles.lifetime = 1.5
	particles.direction = Vector3.UP
	particles.spread = 12.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = BUBBLE_RISE_M_S * 0.8
	particles.initial_velocity_max = BUBBLE_RISE_M_S * 1.2
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.15
	particles.emitting = false
	particles.visible = false
	add_child(particles)
	return particles


func _make_line() -> MeshInstance3D:
	"""A unit-long rope (a cylinder along its Y), turned and stretched to its length when out."""
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = LINE_RADIUS_M
	cylinder.bottom_radius = LINE_RADIUS_M
	cylinder.height = 1.0
	cylinder.radial_segments = 6
	cylinder.material = _flat(LINE_COLOUR)
	var node := MeshInstance3D.new()
	node.mesh = cylinder
	node.visible = false
	add_child(node)
	return node


static func _flat(colour: Color) -> StandardMaterial3D:
	"""An unshaded, see-through material."""
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

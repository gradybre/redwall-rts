extends Node3D
## The woods' particles: wood chips flying where a tree is being chopped, gnawed or grubbed, and a burst
## of leaves (with a puff of dust) where a tree comes down. Decision 0196 (live demo). Presentation
## only. CPUParticles3D, a small fixed pool made once: CHIP_POOL emitters handed to the trees being
## worked, LEAF_POOL one-shot bursts reused in turn. They run on the demo clock (`set_speed`): paused,
## every chip and leaf hangs where it is; at 4x they fly four times as fast.


const CHIP_POOL: int = 4
const LEAF_POOL: int = 3
const CHIP_AMOUNT: int = 26
const LEAF_AMOUNT: int = 90
const DUST_AMOUNT: int = 26
const CHIP_SIZE_M: float = 0.06
const LEAF_SIZE_M: float = 0.2
const DUST_SIZE_M: float = 0.55
## Chips fly from this high up a trunk, and this far round it (m).
const CHIP_HEIGHT_M: float = 0.7
const LEAF_SPREAD_M: float = 3.2
const DUST_BOX_M: Vector3 = Vector3(2.2, 0.1, 2.2)
## One flat colour per emitter (albedo, not vertex colour -- the tunnels' overlay's way).
const CHIP_COLOUR: Color = Color("#8E6A42")
const LEAF_COLOUR: Color = Color("#5E7A3E")
const DUST_COLOUR: Color = Color(0.5, 0.42, 0.32, 0.5)

var _chips: Array[CPUParticles3D] = []
## Per chip emitter: the tree it is on (-1: idle).
var _chip_tree: PackedInt32Array = PackedInt32Array()
var _leaves: Array[CPUParticles3D] = []
var _dust: Array[CPUParticles3D] = []
var _next_burst: int = 0
## Bursts started, drawn or not (checks).
var _burst_count: int = 0
var _speed: float = 1.0


func build() -> void:
	"""Make the pools (once)."""
	if not _chips.is_empty():
		return
	name = "ForestFx"
	for k: int in CHIP_POOL:
		_chips.append(_emitter(CHIP_AMOUNT, CHIP_SIZE_M, CHIP_COLOUR, false))
	_chip_tree.resize(CHIP_POOL)
	_chip_tree.fill(-1)
	for k: int in LEAF_POOL:
		_leaves.append(_emitter(LEAF_AMOUNT, LEAF_SIZE_M, LEAF_COLOUR, true))
		_dust.append(_dust_emitter())


func _emitter(amount: int, size_m: float, colour: Color, is_burst: bool) -> CPUParticles3D:
	"""One emitter of small tumbling quads of this colour: steady chips, or a one-shot leaf burst."""
	var p := CPUParticles3D.new()
	p.amount = amount
	p.emitting = false
	p.one_shot = is_burst
	p.explosiveness = 0.85 if is_burst else 0.0
	p.lifetime = 2.6 if is_burst else 0.9
	p.mesh = _quad(size_m, colour)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = LEAF_SPREAD_M if is_burst else 0.25
	p.direction = Vector3.UP
	p.spread = 70.0 if is_burst else 55.0
	p.initial_velocity_min = 0.6 if is_burst else 1.8
	p.initial_velocity_max = 2.4 if is_burst else 3.4
	p.gravity = Vector3(0.0, -1.6 if is_burst else -9.0, 0.0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.damping_min = 0.8 if is_burst else 0.0
	p.damping_max = 1.6 if is_burst else 0.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	add_child(p)
	return p


func _dust_emitter() -> CPUParticles3D:
	"""A soft puff of earth where a trunk lands."""
	var p := CPUParticles3D.new()
	p.amount = DUST_AMOUNT
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 1.6
	p.mesh = _quad(DUST_SIZE_M, DUST_COLOUR)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = DUST_BOX_M
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0.0, -0.4, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	add_child(p)
	return p


static func _quad(size_m: float, colour: Color) -> QuadMesh:
	"""A small double-sided quad of one colour, see-through when the colour is."""
	var quad := QuadMesh.new()
	quad.size = Vector2(size_m, size_m * 0.7)
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = material
	return quad


func set_speed(speed: float) -> void:
	"""Follow the demo clock: 0 while paused, 2 or 4 at speed."""
	if is_equal_approx(speed, _speed):
		return
	_speed = speed
	for p: CPUParticles3D in _chips + _leaves + _dust:
		p.speed_scale = speed


func chip_at(trees: PackedInt32Array, positions: PackedVector3Array) -> void:
	"""Chips fly at each of these trees (index, and trunk foot); every other emitter stops. At most
	CHIP_POOL at once. Allocates nothing."""
	var drawn: bool = is_inside_tree()
	for k: int in CHIP_POOL:
		var wanted: bool = k < trees.size()
		if drawn and _chips[k].emitting != wanted:
			_chips[k].emitting = wanted
		if wanted:
			_chip_tree[k] = trees[k]
			_chips[k].position = positions[k] + Vector3(0.0, CHIP_HEIGHT_M, 0.0)
		else:
			_chip_tree[k] = -1


func chipping(tree: int) -> bool:
	"""Whether chips fly at `tree` now (checks)."""
	return _chip_tree.has(tree)


func burst(canopy: Vector3, landing: Vector3) -> void:
	"""Leaves scatter from a fallen canopy and dust puffs where the trunk landed."""
	var k: int = _next_burst
	_next_burst = (_next_burst + 1) % LEAF_POOL
	_burst_count += 1
	if not is_inside_tree():
		return
	_leaves[k].position = canopy
	_leaves[k].restart()
	_leaves[k].emitting = true
	_dust[k].position = landing
	_dust[k].restart()
	_dust[k].emitting = true


func bursts() -> int:
	"""How many leaf bursts have been started (checks)."""
	return _burst_count

extends Node3D
## THE DIG FACE: what the player sees where a tunnel or a room is being dug. Decision 0211 (the underground revamp's
## P5; design docs/design/underground_revamp.md §2 "Digging": "The Foremole's hand lantern lights the face. The face
## is a rough concave cut of darker, damp soil, and clods burst off it with each quantum"). Presentation only.
##
## A FACE is a segment being dug whose digger stands in it, below: a tunnel's bore at its dig face, or a room's body
## at the cell it is cutting. The face itself -- rough, hollowed into the earth ahead, dark and wet -- is the bore's
## own face wall (bore_mesh.gd `add_face`); a room's growing far wall is fresh-cut the same way (room_view.gd). Here,
## for at most FACE_SLOTS faces at once (the particle budget's, warren_particles.gd; the first dug keeps its slot):
##   * THE HAND LANTERN (warren_kit.gd) set down on the floor beside and behind the digger, and its light -- one of
##     the pooled lanterns (tunnel_lanterns.gd `set_face_spot`), a candle's warm white -- so the face is lit;
##   * CLODS: a burst off the face (a tunnel's, or the room's cell) every time a quantum's cut completes;
##   * the MOUND on the ground over the digger throws its clods from the same slot.
## A face past FACE_SLOTS digs on unlit by its own lantern and throws no clods. Everything is placed each frame from
## the network and the cast's positions; nothing is built after `configure`.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BoreCurveScript := preload("res://demo/tunnel/bore_curve.gd")
const Layers := preload("res://demo/demo_layers.gd")
const ParticlesScript := preload("res://demo/tunnel/warren_particles.gd")
const LanternsScript := preload("res://demo/tunnel/tunnel_lanterns.gd")
const KitScript := preload("res://demo/tunnel/warren_kit.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

const FACE_SLOTS: int = ParticlesScript.FACE_SLOTS
## The lantern stands this far behind the digger and this far to its left (m); its light this high over its base.
const LANTERN_BACK_M: float = 0.55
const LANTERN_SIDE_M: float = 0.28
const LIGHT_LIFT_M: float = 0.14
## Clods burst from this high up the face, just off it (m).
const CLOD_LIFT_M: float = 0.42
const CLOD_OFF_M: float = 0.08

var _network: GraphScript = null
var _space: CastSpaceScript = null
var _particles: ParticlesScript = null
var _lights: LanternsScript = null
var _mound_of: Callable = Callable()
## The demo's props, for the library hand lantern (decision 0371; null or unstaged: warren_kit.gd's stand-in).
var _props: PropsScript = null
## Per face slot: its segment (-1: free) and that segment's generation, the cuts it has seen, and its lantern.
var _slot_of: PackedInt32Array = PackedInt32Array()
var _gen_of: PackedInt32Array = PackedInt32Array()
var _cuts_seen: PackedInt32Array = PackedInt32Array()
var _lanterns: Array[MeshInstance3D] = []
## Per face slot: where its digger works and the way back out of its face, as last shown (checks and the camera).
var _face_at: PackedVector3Array = PackedVector3Array()
var _face_back: PackedVector3Array = PackedVector3Array()
var _sample: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
## Scratch for a face's frame: where it is (x, floor y, z), the way back out of it, and the digger's left.
var _at: Vector3 = Vector3.ZERO
var _back: Vector3 = Vector3.ZERO
var _left: Vector3 = Vector3.ZERO


func configure(network: GraphScript, space: CastSpaceScript, particles: ParticlesScript, lights: LanternsScript,
		mound_of: Callable, props: PropsScript = null) -> void:
	"""The faces of this network's digs, their diggers found in `space`, their clods from `particles`, their light
	from `lights`; `mound_of(slot) -> Node3D` is the overlay's mound over a segment's digger (null: none); the
	lanterns `props`' (warren_kit.gd). A lantern per face slot, made now, hidden."""
	name = "DigTheatre"
	_props = props
	_network = network
	_space = space
	_particles = particles
	_lights = lights
	_mound_of = mound_of
	_slot_of.resize(FACE_SLOTS)
	_slot_of.fill(-1)
	_gen_of.resize(FACE_SLOTS)
	_cuts_seen.resize(FACE_SLOTS)
	_face_at.resize(FACE_SLOTS)
	_face_back.resize(FACE_SLOTS)
	for k in FACE_SLOTS:
		var lantern := MeshInstance3D.new()
		lantern.mesh = KitScript.hand_lantern(props)
		lantern.layers = Layers.UNDERGROUND
		lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lantern.visible = false
		add_child(lantern)
		_lanterns.append(lantern)


func is_face(slot: int) -> bool:
	"""Whether segment `slot` is a FACE (see the header): being dug, ground broken, its digger standing in it below (a
	resident's bore is cleared when it comes up: cast_space.gd `set_underground`)."""
	if _network.phase[slot] != GraphScript.PHASE_DIGGING or _network.done(slot) <= 0:
		return false
	var d: int = _network.digger[slot]
	return d >= 0 and d < _space.resident_tunnel.size() and _space.resident_tunnel[d] == slot


func slot_of(k: int) -> int:
	"""The segment face slot `k` shows (-1: none; checks)."""
	return _slot_of[k]


func lantern(k: int) -> MeshInstance3D:
	"""Face slot `k`'s hand lantern (checks)."""
	return _lanterns[k]


func face_at(k: int) -> Vector3:
	"""Where face slot `k`'s digger works (x, floor y, z), as last shown (checks)."""
	return _face_at[k]


func face_back(k: int) -> Vector3:
	"""The way back out of face slot `k`'s face, as last shown (checks)."""
	return _face_back[k]


# --- each frame --------------------------------------------------------------------------------------

func refresh() -> void:
	"""Let go of faces that stopped, give free slots to new ones (in segment order), and show every slot's face."""
	for k in FACE_SLOTS:
		var slot := _slot_of[k]
		if slot >= 0 and (_network.generation[slot] != _gen_of[k] or not is_face(slot)):
			_release(k)
	for slot in Rules.MAX_SEGMENTS:
		if _network.phase[slot] == GraphScript.PHASE_DIGGING and not _slot_of.has(slot) and is_face(slot):
			var k := _slot_of.find(-1)
			if k < 0:
				break
			_slot_of[k] = slot
			_gen_of[k] = _network.generation[slot]
			_cuts_seen[k] = _network.cut_count(slot)
	for k in FACE_SLOTS:
		if _slot_of[k] >= 0:
			_show(k)


func _release(k: int) -> void:
	"""Face slot `k` is free: its lantern put away, its light out, its mound's clods stopped."""
	_slot_of[k] = -1
	_lanterns[k].visible = false
	_lights.set_face_spot(k, Vector3.ZERO, false)
	_particles.set_mound(k, Vector3.ZERO, false)


func _show(k: int) -> void:
	"""Face slot `k` as its dig stands: the lantern and its light beside the digger, a burst of clods for each new cut,
	and the mound's clods."""
	var slot := _slot_of[k]
	_face_frame(slot)
	_face_at[k] = _at
	_face_back[k] = _back
	var lantern_at := _at + _back * LANTERN_BACK_M + _left * LANTERN_SIDE_M
	if not _network.is_room_body(slot):
		lantern_at.y = _network.floor_y_at(slot, maxf(_network.face_m(slot) - LANTERN_BACK_M, 0.0))
	_lanterns[k].position = lantern_at
	_lanterns[k].rotation = Vector3(0.0, atan2(_back.x, _back.z), 0.0)
	_lanterns[k].layers = Layers.below(Layers.level_at(lantern_at.y))
	_lanterns[k].visible = true
	_lights.set_face_spot(k, lantern_at + Vector3(0.0, LIGHT_LIFT_M, 0.0), true)
	var cuts := _network.cut_count(slot)
	if cuts > _cuts_seen[k]:
		_cuts_seen[k] = cuts
		_particles.burst_clods(k, _clod_at(slot), _back)
	var mound := _mound_of.call(slot) as Node3D if _mound_of.is_valid() else null
	var over := mound != null and mound.visible
	_particles.set_mound(k, mound.position + Vector3(0.0, 0.1, 0.0) if over else Vector3.ZERO, over)


func _face_frame(slot: int) -> void:
	"""Segment `slot`'s face into the scratch: where the digger works (x, floor y, z), the way back out, its left."""
	if _network.is_room_body(slot):
		var d: int = _network.digger[slot]
		var digger := _space.resident_position[d]
		var door := _network.node_m(_network.node_a[slot])
		var back := (door - digger).normalized() if door.distance_to(digger) > 0.01 else Vector2(0.0, -1.0)
		_at = Vector3(digger.x, Layers.floor_y(_network.seg_level[slot]), digger.y)
		_back = Vector3(back.x, 0.0, back.y)
	else:
		var along := _network.face_m(slot)
		BoreCurveScript.of(_network, slot).sample(along, _sample)
		_at = Vector3(_sample[0].x, _network.floor_y_at(slot, along), _sample[0].y)
		_back = Vector3(-_sample[1].x, 0.0, -_sample[1].y)
	_left = Vector3(_back.z, 0.0, -_back.x)


func _clod_at(slot: int) -> Vector3:
	"""Where a cut's clods burst from: a room's cell being cut, else just off the bore's face, CLOD_LIFT_M up."""
	if _network.is_room_body(slot):
		var cell := _network.quantum_point_u(slot, mini(_network.face_quantum(slot), _network.timeline_count(slot) - 1))
		return Vector3(Rules.to_m(cell.x), Layers.floor_y(_network.seg_level[slot]) + CLOD_LIFT_M, Rules.to_m(cell.y))
	return _at + _back * CLOD_OFF_M + Vector3(0.0, CLOD_LIFT_M, 0.0)


func register(prewarm: RefCounted) -> void:
	"""The lantern and the pools' meshes, for the U view's prewarm (decision 0206)."""
	KitScript.register(prewarm, _props)
	for mesh in ParticlesScript.meshes():
		prewarm.add_multimesh(mesh)

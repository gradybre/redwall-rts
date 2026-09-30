extends Node3D
## The swept bores of the demo's tunnels, as the U view draws them. Decision 0207 (the underground
## revamp's P1; design docs/design/underground_revamp.md §6 "Tunnel geometry and art"), replacing
## decision 0206's interim trough. Presentation only.
##
## Each tunnel's dug length is a hand-dug horseshoe tube (bore_mesh.gd) swept along its drawn centreline
## (bore_curve.gd, the one every walker and mark in it follows too), on the UNDERGROUND layer, drawn in the underground's one earth (bore_earth.gdshader,
## the cap's own soil). It is built as the bore is dug, whatever the view -- never on a U press.
##
## CHUNKS. A tunnel is up to CHUNKS meshes of CHUNK_RINGS bands (16 m) each, on a fixed ring lattice
## (every RING_STEP_M from the entrance, and one at the dig face), so a chunk's rings never move. As the
## face advances only the chunk it is in is rebuilt -- the one it left too, the first time, to drop its
## face wall -- so a rebuild is at most one 16 m sweep however long the tunnel. A change of state (bore
## class, a widening's step, a flood, a fall, a new tunnel in the slot) rebuilds them all.
##
## THE DRYING HOOK. Every ring carries the game day its step was dug (the demo calendar), and the earth
## material the calendar's day now (`tick`): fresh walls are dark and damp and pale over a game day. P5's
## construction theatre builds on it.
##
## THE VOID. Every dug step is stamped into the cap's void mask (underground_cap.gd `stamp_disc`): its
## floor half-width, its floor's rise over the level's (a ramp's) and its crown, and at a dig face only the
## half behind it. The stamps only grow: a slot is freed only while no ground is broken (0196 items 27, 29).

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const Layers := preload("res://demo/demo_layers.gd")
const CapScript := preload("res://demo/tunnel/underground_cap.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")
const BoreCurveScript := preload("res://demo/tunnel/bore_curve.gd")
const DressingScript := preload("res://demo/tunnel/bore_dressing.gd")
const EARTH_SHADER := preload("res://demo/tunnel/bore_earth.gdshader")

const RING_STEP_M: float = BoreMeshScript.RING_STEP_M
const CHUNK_RINGS: int = 64
const CHUNKS: int = Rules.MAX_LENGTH_U / Rules.QUANTUM_U / 16 + 1
const MAX_STEPS: int = Rules.MAX_LENGTH_U / Rules.QUANTUM_U * 4 + 2
## A dig face this close past a lattice ring is that ring (no sliver of a band).
const FACE_SLACK_M: float = 0.01
## `now_days` is written when the calendar has moved this many days since the last write.
const DAY_WRITE_STEP: float = 0.001
## The earth's bedded stones: a noise texture, generated once (its grain is the cap's: `set_view`).
const CELLS_SEED: int = 2072

static var _material: ShaderMaterial = null

var _network: NetworkScript = null
var _cap: CapScript = null
var _calendar: CalendarScript = null
var _builder: BoreMeshScript = BoreMeshScript.new()
var _chunks: Array[MeshInstance3D] = []
var _built_m: PackedFloat32Array = PackedFloat32Array()
var _state: PackedInt64Array = PackedInt64Array()
var _step_day: PackedFloat32Array = PackedFloat32Array()
var _void_m: PackedFloat32Array = PackedFloat32Array()
var _void_wide_m: PackedFloat32Array = PackedFloat32Array()
var _sample: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _day_written: float = -1.0
var dressing: DressingScript = null
## Chunk sweeps so far (measurement and the tests).
var chunk_builds: int = 0


func configure(network: NetworkScript) -> void:
	"""Draw this network's bores: every slot's chunks built once, empty and hidden."""
	name = "Bores"
	_network = network
	for slot in Rules.MAX_TUNNELS:
		for k in CHUNKS:
			_chunks.append(_chunk_node())
	_built_m.resize(Rules.MAX_TUNNELS)
	_state.resize(Rules.MAX_TUNNELS)
	_state.fill(-1)
	_step_day.resize(Rules.MAX_TUNNELS * MAX_STEPS)
	_void_m.resize(Rules.MAX_TUNNELS)
	_void_wide_m.resize(Rules.MAX_TUNNELS)
	dressing = DressingScript.new()
	add_child(dressing)
	dressing.configure()


func _chunk_node() -> MeshInstance3D:
	"""One chunk's node: an empty mesh in the earth material, on the UNDERGROUND layer, hidden."""
	var node := MeshInstance3D.new()
	node.mesh = ArrayMesh.new()
	node.material_override = earth_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = Layers.UNDERGROUND
	node.visible = false
	add_child(node)
	return node


static func earth_material() -> ShaderMaterial:
	"""THE bores' material, shared by every chunk: the underground's earth (see the header)."""
	if _material != null:
		return _material
	_material = ShaderMaterial.new()
	_material.shader = EARTH_SHADER
	_material.set_shader_parameter(&"cells", _noise(CELLS_SEED, FastNoiseLite.TYPE_CELLULAR, 0.02))
	_material.set_shader_parameter(&"cut_y", Layers.CAP_Y_M)
	return _material


static func _noise(seed: int, kind: FastNoiseLite.NoiseType, frequency: float) -> NoiseTexture2D:
	"""A seamless, mipmapped 256 px noise texture."""
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = kind
	noise.frequency = frequency
	noise.fractal_octaves = 3
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture


func set_view(cap: CapScript, prewarm: PrewarmScript) -> void:
	"""The cap whose void mask the bores open and whose soil they share, and the U view's prewarm, which
	learns the bores' vertex format and material and the dressing's meshes (decision 0206)."""
	_cap = cap
	cap.share_earth(earth_material())
	_void_m.fill(0.0)
	_void_wide_m.fill(0.0)
	prewarm.add_mesh(BoreMeshScript.sample_mesh(), earth_material())
	dressing.register(prewarm)


func set_calendar(calendar: CalendarScript) -> void:
	"""The demo calendar the dig days and the drying are read from (none: every wall dry)."""
	_calendar = calendar
	tick()


func set_trees(trees: Array[Dictionary]) -> void:
	"""The mature trees whose roots poke into a bore passing near them (bore_dressing.gd)."""
	dressing.set_trees(trees)


func chunk(slot: int, k: int) -> MeshInstance3D:
	"""Chunk `k` of tunnel `slot`'s bore."""
	return _chunks[slot * CHUNKS + k]


func built_m(slot: int) -> float:
	"""How far tunnel `slot`'s bore was last built (m): the dig face at its last step."""
	return _built_m[slot]


func hide_slot(slot: int) -> void:
	"""Draw nothing of tunnel `slot` (a freed slot)."""
	for k in CHUNKS:
		chunk(slot, k).visible = false
	dressing.clear(slot)
	_state[slot] = -1
	_built_m[slot] = 0.0


# --- the dig day ------------------------------------------------------------------------------

func today() -> float:
	"""The calendar's day now (0 with none)."""
	return float(_calendar.tick) / float(SimClock.TICKS_PER_DAY) if _calendar != null else 0.0


func tick() -> void:
	"""Tell the earth the day, when it has moved on (see THE DRYING HOOK); with no calendar every wall is
	drawn dry."""
	var day := today() if _calendar != null else 1000000.0
	if absf(day - _day_written) < DAY_WRITE_STEP:
		return
	_day_written = day
	earth_material().set_shader_parameter(&"now_days", day)


func dug_day(slot: int, step: int) -> float:
	"""The game day step `step` of tunnel `slot` was dug."""
	return _step_day[slot * MAX_STEPS + mini(step, MAX_STEPS - 1)]


func _record_days(slot: int, from_m: float, to_m: float) -> void:
	"""Steps newly dug between from_m and to_m were dug today."""
	var day := today()
	var first := 0 if from_m <= 0.0 else floori((from_m + FACE_SLACK_M) / RING_STEP_M) + 1
	for step in range(first, mini(ceili(to_m / RING_STEP_M) + 1, MAX_STEPS)):
		_step_day[slot * MAX_STEPS + step] = day


# --- building ---------------------------------------------------------------------------------

static func state_key(network: NetworkScript, slot: int, widen_m: float) -> int:
	"""Everything but the face a slot's bore depends on, as one number: its generation, class, closure
	(and a fall's span) and the widening's step. A change rebuilds every chunk."""
	var closed := int(network.closed[slot])
	var fall := Vector2i(network.closed_from_u[slot], network.closed_to_u[slot]) if closed == NetworkScript.CLOSED_COLLAPSED else Vector2i.ZERO
	return absi([network.generation[slot], int(network.bore[slot]), closed, fall, floori(widen_m / RING_STEP_M)].hash())


func build(slot: int, dug_m: float, widen_m: float) -> void:
	"""Draw tunnel `slot` dug to `dug_m`, widened to `widen_m`: rebuild the chunks that changed (see
	CHUNKS), stamp the newly dug steps into the cap and dress them."""
	var key := state_key(_network, slot, widen_m)
	var full := key != _state[slot] or dug_m < _built_m[slot]
	_record_days(slot, _built_m[slot], dug_m)
	var rings := ring_count(dug_m)
	var last := last_chunk(rings)
	var first := 0 if full else mini(last_chunk(ring_count(_built_m[slot])), last)
	for k in CHUNKS:
		if k > last:
			chunk(slot, k).visible = false
		elif k >= first:
			_build_chunk(slot, k, dug_m, widen_m)
	dressing.place(slot, _network, 0.0 if full else _built_m[slot], dug_m, widen_m)
	_built_m[slot] = dug_m
	_state[slot] = key
	_stamp_void(slot, dug_m, widen_m)


static func ring_count(dug_m: float) -> int:
	"""How many rings a bore dug `dug_m` has: every lattice step, and the face when it is off the lattice."""
	var lattice := floori(dug_m / RING_STEP_M + FACE_SLACK_M / RING_STEP_M)
	var face := 1 if dug_m - float(lattice) * RING_STEP_M > FACE_SLACK_M else 0
	return lattice + 1 + face


static func last_chunk(rings: int) -> int:
	"""The chunk holding a bore's last band (-1: none)."""
	return -1 if rings < 2 else mini((rings - 2) / CHUNK_RINGS, CHUNKS - 1)


func ring_along(ring: int, rings: int, dug_m: float) -> float:
	"""Where ring `ring` of `rings` stands (m): on the lattice, the last at the face."""
	return dug_m if ring == rings - 1 else float(ring) * RING_STEP_M


func _build_chunk(slot: int, k: int, dug_m: float, widen_m: float) -> void:
	"""Sweep chunk `k` of tunnel `slot`: its rings on the lattice, and the face wall on the last chunk
	while it is being dug."""
	var rings := ring_count(dug_m)
	var from := k * CHUNK_RINGS
	var to := mini((k + 1) * CHUNK_RINGS, rings - 1)
	_builder.begin()
	var curve: BoreCurveScript = BoreCurveScript.of(_network, slot)
	var length := _network.length_m(slot)
	for ring in range(from, to + 1):
		var along := ring_along(ring, rings, dug_m)
		curve.sample(along, _sample)
		var bore := bore_class(slot, along, widen_m)
		var centre := Vector3(_sample[0].x, Rules.floor_y_m(along, length), _sample[0].y)
		_builder.add_ring(ring, centre, _sample[1], bore, _kind(slot, along), dug_day(slot, floori(along / RING_STEP_M)))
	if to == rings - 1 and not _network.is_open(slot):
		_builder.add_face(Vector3(_sample[0].x, Rules.floor_y_m(dug_m, length), _sample[0].y), _sample[1], bore_class(slot, dug_m, widen_m))
	var node := chunk(slot, k)
	node.visible = _builder.commit(node.mesh as ArrayMesh) > 0
	chunk_builds += 1


func bore_class(slot: int, along: float, widen_m: float) -> int:
	"""The bore class drawn `along` metres into tunnel `slot`: wide where it is, or a widening has reached."""
	return Rules.BORE_WIDE if _network.bore[slot] == Rules.BORE_WIDE or along < widen_m else Rules.BORE_STANDARD


func _kind(slot: int, along: float) -> int:
	"""A ring's colour kind: rubble through a fallen section, flooded when flooded, else plain."""
	var closed := _network.closed[slot]
	if closed == NetworkScript.CLOSED_COLLAPSED:
		var at := Rules.to_u(along)
		if at >= _network.closed_from_u[slot] - Rules.QUANTUM_U / 2 and at <= _network.closed_to_u[slot] + Rules.QUANTUM_U / 2:
			return BoreMeshScript.RUBBLE
	if closed == NetworkScript.CLOSED_FLOODED:
		return BoreMeshScript.FLOODED
	return BoreMeshScript.PLAIN


# --- the void ---------------------------------------------------------------------------------

func _stamp_void(slot: int, dug_m: float, widen_m: float) -> void:
	"""Open the cap over what is newly dug of tunnel `slot` (see THE VOID): the standard reach, and the
	wide reach again at the wide width."""
	if _cap == null:
		return
	var wide := dug_m if _network.bore[slot] == Rules.BORE_WIDE else minf(widen_m, dug_m)
	_void_wide_m[slot] = _stamp_run(slot, _void_wide_m[slot], wide, Rules.BORE_WIDE)
	_void_m[slot] = _stamp_run(slot, _void_m[slot], dug_m, Rules.BORE_STANDARD)
	_cap.commit_void()


func _stamp_run(slot: int, from_m: float, to_m: float, bore: int) -> float:
	"""Stamp class `bore`'s discs along tunnel `slot` from `from_m` to `to_m`: every lattice step, and
	`to_m` itself -- cut at the face while digging. Returns how far the stamps now reach."""
	if to_m <= from_m:
		return from_m
	var curve: BoreCurveScript = BoreCurveScript.of(_network, slot)
	var along := floorf(from_m / RING_STEP_M) * RING_STEP_M
	while along < to_m:
		_stamp_at(slot, along, bore, Vector2.ZERO)
		along += RING_STEP_M
	curve.sample(to_m, _sample)
	_stamp_at(slot, to_m, bore, Vector2.ZERO if _network.is_open(slot) else _sample[1])
	return to_m


func _stamp_at(slot: int, along: float, bore: int, face: Vector2) -> void:
	"""One disc of class `bore` at `along` on the drawn centreline, at its floor's rise."""
	BoreCurveScript.of(_network, slot).sample(along, _sample)
	var rise := Rules.floor_y_m(along, _network.length_m(slot)) - Layers.FLOOR_Y_M
	_cap.stamp_disc(_sample[0], BoreMeshScript.FLOOR_HALF_M[bore], face, rise, Rules.crown_m(bore))

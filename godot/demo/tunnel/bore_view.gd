extends Node3D
## The swept bores of the demo's tunnel network, and the hubs where they meet, as the U view draws them.
## Decisions 0207 (the underground revamp's P1; design docs/design/underground_revamp.md §6 "Tunnel geometry
## and art") and 0208 (P2: per segment, and the junctions' hubs). Presentation only.
##
## Each SEGMENT's dug length is a hand-dug horseshoe tube (bore_mesh.gd) swept along its drawn centreline
## (bore_curve.gd, the one every walker and mark in it follows too), on the UNDERGROUND layer, drawn in the
## underground's one earth (bore_earth.gdshader, the cap's own soil), its floor where the segment's is (a
## ramp down from its mouth, a level bore flat: underground_graph.gd `floor_y_at`). It is built as the bore
## is dug, whatever the view -- never on a U press.
##
## CHUNKS. A segment is up to CHUNKS meshes of CHUNK_RINGS bands (16 m) each, on a fixed ring lattice (every
## RING_STEP_M from its node A, and one at the dig face), so a chunk's rings never move. As the face advances
## only the chunk it is in is rebuilt -- the one it left too, the first time, to drop its face wall -- so a
## rebuild is at most one 16 m sweep however long the segment. A change of state (bore class, a widening's
## step, a flood, a fall, a split, a hub appearing at an end) rebuilds them all. A segment's chunks are made
## the first time it is dug (`_ensure`).
##
## HUBS (decision 0208). Where three or more segments have broken ground at a junction a HUB is drawn: a
## lathe of the bores' own horseshoe round the junction (bore_mesh.gd `build_hub`), HUB_SCALE times the
## widest bore's floor half-width across, its crown the widest's. Each segment ending there drops what lies
## inside the hub (bore_earth.gdshader), and the hub drops its wall where each bore opens into it
## (hub_earth.gdshader), by one shape test on each side of one surface: no seam, no gap. The bores' jitter
## fades to the clean profile at every end below ground (bore_mesh.gd THE JOIN), so a bore meets its hub, or
## the next segment in line at a ramp's foot, exactly. Each hub is stamped into the cap's void mask as a disc
## of its own radius, so the section opens over it.
##
## THE DRYING HOOK. Every ring carries the game day its step was dug (the demo calendar), and the earth
## material the calendar's day now (`tick`): fresh walls are dark and damp and pale over a game day.
##
## THE VOID. Every dug step is stamped into the cap's void mask (underground_cap.gd `stamp_disc`): its floor
## half-width, its floor's rise over the level's (a ramp's) and its crown, and at a dig face only the half
## behind it. The stamps only grow: a segment is freed only while no ground is broken.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Layers := preload("res://demo/demo_layers.gd")
const CapScript := preload("res://demo/tunnel/underground_cap.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")
const BoreCurveScript := preload("res://demo/tunnel/bore_curve.gd")
const DressingScript := preload("res://demo/tunnel/bore_dressing.gd")
const EARTH_SHADER := preload("res://demo/tunnel/bore_earth.gdshader")
const HUB_SHADER := preload("res://demo/tunnel/hub_earth.gdshader")

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
## Stones and roots keep this far clear of a hub's rim.
const HUB_DRESS_CLEAR_M: float = 0.3

static var _material: ShaderMaterial = null
static var _hub_material: ShaderMaterial = null

var _network: GraphScript = null
var _cap: CapScript = null
var _calendar: CalendarScript = null
var _builder: BoreMeshScript = BoreMeshScript.new()
var _chunks: Array[MeshInstance3D] = []
var _built_m: PackedFloat32Array = PackedFloat32Array()
var _state: PackedInt64Array = PackedInt64Array()
var _step_day: PackedFloat32Array = PackedFloat32Array()
var _void_m: PackedFloat32Array = PackedFloat32Array()
var _void_wide_m: PackedFloat32Array = PackedFloat32Array()
var _hubs: Array[MeshInstance3D] = []
var _hub_key: PackedInt64Array = PackedInt64Array()
var _openings: PackedFloat32Array = PackedFloat32Array()
var _sample: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
var _day_written: float = -1.0
var dressing: DressingScript = null
## Chunk sweeps and hub builds so far (measurement and the tests).
var chunk_builds: int = 0
var hub_builds: int = 0


func configure(network: GraphScript) -> void:
	"""Draw this network's bores and hubs: room for every segment's chunks and every node's hub, each made
	when first needed."""
	name = "Bores"
	_network = network
	_chunks.resize(Rules.MAX_SEGMENTS * CHUNKS)
	_built_m.resize(Rules.MAX_SEGMENTS)
	_state.resize(Rules.MAX_SEGMENTS)
	_state.fill(-1)
	_step_day.resize(Rules.MAX_SEGMENTS * MAX_STEPS)
	_void_m.resize(Rules.MAX_SEGMENTS)
	_void_wide_m.resize(Rules.MAX_SEGMENTS)
	_hubs.resize(Rules.MAX_NODES)
	_hub_key.resize(Rules.MAX_NODES)
	_hub_key.fill(-1)
	dressing = DressingScript.new()
	add_child(dressing)
	dressing.configure()


func _ensure(slot: int) -> void:
	"""Segment `slot`'s chunks, made once: empty meshes in the earth material, on the UNDERGROUND layer,
	hidden."""
	if _chunks[slot * CHUNKS] != null:
		return
	for k in CHUNKS:
		_chunks[slot * CHUNKS + k] = _mesh_node(earth_material())


func _mesh_node(material: ShaderMaterial) -> MeshInstance3D:
	"""A node for a bore chunk or a hub: an empty mesh in `material`, on the UNDERGROUND layer, hidden."""
	var node := MeshInstance3D.new()
	node.mesh = ArrayMesh.new()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = Layers.UNDERGROUND
	node.visible = false
	add_child(node)
	return node


static func earth_material() -> ShaderMaterial:
	"""THE bores' material, shared by every chunk: the underground's earth (see the header)."""
	if _material != null:
		return _material
	_material = _earth(EARTH_SHADER)
	return _material


static func hub_material() -> ShaderMaterial:
	"""THE hubs' material, shared by every hub: the same earth, cut where the bores open (see HUBS)."""
	if _hub_material != null:
		return _hub_material
	_hub_material = _earth(HUB_SHADER)
	return _hub_material


static func _earth(shader: Shader) -> ShaderMaterial:
	"""A material of the bores' earth over `shader`."""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"cells", _noise(CELLS_SEED, FastNoiseLite.TYPE_CELLULAR, 0.02))
	material.set_shader_parameter(&"cut_y", Layers.CAP_Y_M)
	material.set_shader_parameter(&"level_floor_y", Layers.FLOOR_Y_M)
	material.set_shader_parameter(&"bulge", BoreMeshScript.BULGE)
	material.set_shader_parameter(&"spring_share", BoreMeshScript.SPRING_SHARE)
	return material


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
	"""The cap whose void mask the bores open and whose soil they share, and the U view's prewarm, which learns
	the bores' and hubs' vertex formats and materials and the dressing's meshes (decision 0206)."""
	_cap = cap
	cap.share_earth(earth_material())
	cap.share_earth(hub_material())
	_void_m.fill(0.0)
	_void_wide_m.fill(0.0)
	prewarm.add_mesh(BoreMeshScript.sample_mesh(), earth_material())
	prewarm.add_mesh(BoreMeshScript.sample_hub(), hub_material())
	dressing.register(prewarm)


func set_calendar(calendar: CalendarScript) -> void:
	"""The demo calendar the dig days and the drying are read from (none: every wall dry)."""
	_calendar = calendar
	tick()


func set_trees(trees: Array[Dictionary]) -> void:
	"""The mature trees whose roots poke into a bore passing near them (bore_dressing.gd)."""
	dressing.set_trees(trees)


func chunk(slot: int, k: int) -> MeshInstance3D:
	"""Chunk `k` of segment `slot`'s bore (null before it is first dug)."""
	return _chunks[slot * CHUNKS + k]


func hub(node: int) -> MeshInstance3D:
	"""Node `node`'s hub (null before one is first drawn there)."""
	return _hubs[node]


func built_m(slot: int) -> float:
	"""How far segment `slot`'s bore was last built (m): the dig face at its last step."""
	return _built_m[slot]


func hide_slot(slot: int) -> void:
	"""Draw nothing of segment `slot` (a freed slot)."""
	if _chunks[slot * CHUNKS] != null:
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
	"""Tell the earth the day, when it has moved on (see THE DRYING HOOK); with no calendar every wall is drawn
	dry."""
	var day := today() if _calendar != null else 1000000.0
	if absf(day - _day_written) < DAY_WRITE_STEP:
		return
	_day_written = day
	earth_material().set_shader_parameter(&"now_days", day)
	hub_material().set_shader_parameter(&"now_days", day)


func dug_day(slot: int, step: int) -> float:
	"""The game day step `step` of segment `slot` was dug."""
	return _step_day[slot * MAX_STEPS + mini(step, MAX_STEPS - 1)]


func _record_days(slot: int, from_m: float, to_m: float) -> void:
	"""Steps newly dug between from_m and to_m were dug today."""
	var day := today()
	var first := 0 if from_m <= 0.0 else floori((from_m + FACE_SLACK_M) / RING_STEP_M) + 1
	for step in range(first, mini(ceili(to_m / RING_STEP_M) + 1, MAX_STEPS)):
		_step_day[slot * MAX_STEPS + step] = day


# --- building ---------------------------------------------------------------------------------

func state_key(slot: int, widen_m: float) -> int:
	"""Everything but the face a segment's bore depends on, as one number: its generation, class, closure (and
	a fall's span), the widening's step, its route's length (a split) and the hubs at its ends. A change
	rebuilds every chunk."""
	var network := _network
	var closed := int(network.closed[slot])
	var fall := Vector2i(network.closed_from_u[slot], network.closed_to_u[slot]) if closed == GraphScript.CLOSED_COLLAPSED else Vector2i.ZERO
	return absi([network.generation[slot], int(network.bore[slot]), closed, fall, floori(widen_m / RING_STEP_M),
		network.length_u[slot], hub_cut(slot, false), hub_cut(slot, true)].hash())


func hub_cut(slot: int, at_b: bool) -> Vector4:
	"""The hub at segment `slot`'s node A (or B) its bore drops what lies inside (x, z, floor radius, crown);
	zero when no hub is drawn there (see HUBS) -- or, at a room's door or socket, the room's wall as a PLANE
	(`room_cut`)."""
	var node := _network.end_node(slot, at_b)
	if _network.node_room[node] >= 0 and _network.node_mouth[node] < 0:
		return room_cut(node)
	if _network.node_mouth[node] >= 0 or _network.dug_degree(node) < 3:
		return Vector4.ZERO
	var widest := _widest_at(node)
	var at := _network.node_m(node)
	return Vector4(at.x, at.y, BoreMeshScript.FLOOR_HALF_M[widest] * BoreMeshScript.HUB_SCALE, Rules.crown_m(widest))


func room_cut(node: int) -> Vector4:
	"""A bore ending at a room's door (once the room breaks ground) or a socket (once the room is dug) is cut by
	a plane through the room's wall there (bore_surface.gdshaderinc: x, z the node, a radius of -1, the angle
	into the room); zero before (decision 0209)."""
	var r: int = _network.node_room[node]
	var rooms := _network.rooms
	var kind := _network.node_kind[node]
	var open := rooms.is_done(_network, r) if kind == GraphScript.NODE_SOCKET else rooms.dug_permille(_network, r) > 0
	if not open or (kind != GraphScript.NODE_SOCKET and kind != GraphScript.NODE_DOOR):
		return Vector4.ZERO
	var at := _network.node_m(node)
	var into := rooms.centre_m(r) - at
	return Vector4(at.x, at.y, -1.0, atan2(into.y, into.x))


func hub_bits(slot: int) -> int:
	"""Which ends of segment `slot` have a hub its bore is cut at, and how: 0..15 (a base-4 digit an end: none,
	standard, wide, a room's wall)."""
	var bits := 0
	for at_b: bool in [false, true]:
		var cut := hub_cut(slot, at_b)
		var digit := 0 if cut.z == 0.0 else (3 if cut.z < 0.0 else 1 + _widest_at(_network.end_node(slot, at_b)))
		bits = bits * 4 + digit
	return bits


func _widest_at(node: int) -> int:
	"""The widest bore class of the segments meeting at `node`."""
	var widest := Rules.BORE_STANDARD
	for k in GraphScript.DEGREE:
		var slot := _network.node_segment(node, k)
		if slot >= 0 and _network.bore[slot] == Rules.BORE_WIDE:
			widest = Rules.BORE_WIDE
	return widest


func build(slot: int, dug_m: float, widen_m: float) -> void:
	"""Draw segment `slot` dug to `dug_m`, widened to `widen_m`: rebuild the chunks that changed (see CHUNKS),
	stamp the newly dug steps into the cap and dress them."""
	_ensure(slot)
	var key := state_key(slot, widen_m)
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
	dressing.place(slot, _network, 0.0 if full else _built_m[slot], dug_m, widen_m, _dress_clear(slot, false),
		_dress_clear(slot, true))
	_built_m[slot] = dug_m
	_state[slot] = key
	_stamp_void(slot, dug_m, widen_m)


func _dress_clear(slot: int, at_b: bool) -> float:
	"""How far from its node A (B) a segment is left undressed: a hub's radius and a margin, else nothing."""
	var cut := hub_cut(slot, at_b)
	if cut.z < 0.0:
		return HUB_DRESS_CLEAR_M
	return cut.z * BoreMeshScript.BULGE + HUB_DRESS_CLEAR_M if cut.z > 0.0 else 0.0


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
	"""Sweep chunk `k` of segment `slot`: its rings on the lattice, and the face wall on the last chunk while it
	is being dug."""
	var rings := ring_count(dug_m)
	var from := k * CHUNK_RINGS
	var to := mini((k + 1) * CHUNK_RINGS, rings - 1)
	_builder.begin(hub_cut(slot, false), hub_cut(slot, true))
	var curve: BoreCurveScript = BoreCurveScript.of(_network, slot)
	var length := _network.length_m(slot)
	var clean_a := _network.node_mouth[_network.node_a[slot]] < 0
	var clean_b := _network.node_mouth[_network.node_b[slot]] < 0
	for ring in range(from, to + 1):
		var along := ring_along(ring, rings, dug_m)
		curve.sample(along, _sample)
		var centre := Vector3(_sample[0].x, _network.floor_y_at(slot, along), _sample[0].y)
		_builder.add_ring(ring, centre, _sample[1], bore_class(slot, along, widen_m), _kind(slot, along),
			dug_day(slot, floori(along / RING_STEP_M)), BoreMeshScript.jitter_at(along, length, clean_a, clean_b))
	if to == rings - 1 and not _network.is_open(slot):
		_builder.add_face(Vector3(_sample[0].x, _network.floor_y_at(slot, dug_m), _sample[0].y), _sample[1], bore_class(slot, dug_m, widen_m))
	var node := chunk(slot, k)
	node.visible = _builder.commit(node.mesh as ArrayMesh) > 0
	chunk_builds += 1


func bore_class(slot: int, along: float, widen_m: float) -> int:
	"""The bore class drawn `along` metres into segment `slot`: wide where it is, or a widening has reached."""
	return Rules.BORE_WIDE if _network.bore[slot] == Rules.BORE_WIDE or along < widen_m else Rules.BORE_STANDARD


func _kind(slot: int, along: float) -> int:
	"""A ring's colour kind: rubble through a fallen section, flooded when flooded, else plain."""
	var closed := _network.closed[slot]
	if closed == GraphScript.CLOSED_COLLAPSED:
		var at := Rules.to_u(along)
		if at >= _network.closed_from_u[slot] - Rules.QUANTUM_U / 2 and at <= _network.closed_to_u[slot] + Rules.QUANTUM_U / 2:
			return BoreMeshScript.RUBBLE
	if closed == GraphScript.CLOSED_FLOODED:
		return BoreMeshScript.FLOODED
	return BoreMeshScript.PLAIN


# --- hubs -----------------------------------------------------------------------------------

func refresh_hubs() -> void:
	"""Draw (or hide) the hub of every node where three or more segments meet, when what it depends on
	changed (see HUBS)."""
	for node in Rules.MAX_NODES:
		if _hub_key[node] < 0 and (not _network.is_node(node) or _network.degree(node) < 3):
			continue
		var key := _hub_state(node)
		if key == _hub_key[node]:
			continue
		_hub_key[node] = key
		_draw_hub(node, key >= 0)


func _hub_state(node: int) -> int:
	"""Everything a node's hub depends on, as one number (-1: no hub): its generation, the segments that
	have broken ground there, their ways out and classes -- folded from integers, as it is checked every
	frame."""
	if not _network.is_node(node) or _network.node_mouth[node] >= 0 or _network.node_room[node] >= 0 \
			or _network.dug_degree(node) < 3:
		return -1
	var key := _network.node_gen[node]
	for k in GraphScript.DEGREE:
		var slot := _network.node_segment(node, k)
		if slot >= 0 and _opens(slot, node):
			var out := _network.leaving_dir(slot, node)
			key = _mix(_mix(_mix(_mix(key, slot), out.x), out.y), int(_network.bore[slot]))
	return key & 0x3FFFFFFFFFFFFFFF


static func _mix(key: int, value: int) -> int:
	"""Fold one integer into a key (FNV-style, wrapping): no allocation, so a frame's check costs nothing."""
	return (key ^ value) * 1099511628211


func _opens(slot: int, node: int) -> bool:
	"""Whether segment `slot` has broken ground at `node` (it opens into the hub there)."""
	return _network.is_open(slot) or (_network.node_a[slot] == node and _network.done(slot) > 0)


func _draw_hub(node: int, show: bool) -> void:
	"""Build node `node`'s hub from the segments opening into it and stamp it into the cap, or hide it."""
	if not show:
		if _hubs[node] != null:
			_hubs[node].visible = false
		return
	if _hubs[node] == null:
		_hubs[node] = _mesh_node(hub_material())
	_openings.clear()
	for k in GraphScript.DEGREE:
		var slot := _network.node_segment(node, k)
		if slot >= 0 and _opens(slot, node):
			var out := _network.leaving_dir(slot, node)
			var bore := int(_network.bore[slot])
			_openings.append_array([atan2(float(out.y), float(out.x)), BoreMeshScript.FLOOR_HALF_M[bore], Rules.crown_m(bore)])
	var widest := _widest_at(node)
	var at := _network.node_m(node)
	var radius := BoreMeshScript.FLOOR_HALF_M[widest] * BoreMeshScript.HUB_SCALE
	var centre := Vector3(at.x, _network.node_floor_y(node), at.y)
	BoreMeshScript.build_hub(_hubs[node].mesh as ArrayMesh, centre, radius, Rules.crown_m(widest), _openings, today())
	_hubs[node].visible = true
	hub_builds += 1
	if _cap != null:
		_cap.stamp_disc(at, radius, Vector2.ZERO, 0.0, Rules.crown_m(widest))
		_cap.commit_void()


# --- the void ---------------------------------------------------------------------------------

func _stamp_void(slot: int, dug_m: float, widen_m: float) -> void:
	"""Open the cap over what is newly dug of segment `slot` (see THE VOID): the standard reach, and the wide
	reach again at the wide width."""
	if _cap == null:
		return
	var wide := dug_m if _network.bore[slot] == Rules.BORE_WIDE else minf(widen_m, dug_m)
	_void_wide_m[slot] = _stamp_run(slot, _void_wide_m[slot], wide, Rules.BORE_WIDE)
	_void_m[slot] = _stamp_run(slot, _void_m[slot], dug_m, Rules.BORE_STANDARD)
	_cap.commit_void()


func _stamp_run(slot: int, from_m: float, to_m: float, bore: int) -> float:
	"""Stamp class `bore`'s discs along segment `slot` from `from_m` to `to_m`: every lattice step, and `to_m`
	itself. While it is being dug, every disc that reaches `to_m` is cut at the face line, so nothing past
	the face is opened. Returns how far the stamps now reach."""
	if to_m <= from_m:
		return from_m
	BoreCurveScript.of(_network, slot).sample(to_m, _sample)
	var face := Vector2.ZERO if _network.is_open(slot) else _sample[1]
	var reach := BoreMeshScript.FLOOR_HALF_M[bore] * CapScript.RHO_REACH
	var along := floorf(from_m / RING_STEP_M) * RING_STEP_M
	while along < to_m:
		_stamp_at(slot, along, bore, face if to_m - along < reach else Vector2.ZERO, to_m - along)
		along += RING_STEP_M
	_stamp_at(slot, to_m, bore, face, 0.0)
	return to_m


func _stamp_at(slot: int, along: float, bore: int, face: Vector2, face_ahead_m: float) -> void:
	"""One disc of class `bore` at `along` on the drawn centreline, at its floor's rise; with a `face`, cut
	at the face line `face_ahead_m` on."""
	BoreCurveScript.of(_network, slot).sample(along, _sample)
	var rise := _network.floor_y_at(slot, along) - Layers.FLOOR_Y_M
	_cap.stamp_disc(_sample[0], BoreMeshScript.FLOOR_HALF_M[bore], face, rise, Rules.crown_m(bore), face_ahead_m)

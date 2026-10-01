extends "res://test/framework/test_case.gd"
## The weir fitted to its channel (demo/water/weir_fit.gd, water_dressing.gd THE WEIR; decision 0301,
## review F41): the span to each waterline, the ends moved out onto the banks with the gaps filled, the
## foot let down to the bed, the sill, and the placed weir against the real water map. Synthetic meshes
## and the authored map -- no staged assets.

const Fit := preload("res://demo/water/weir_fit.gd")
const Dressing := preload("res://demo/water/water_dressing.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const Rules := preload("res://demo/water/water_rules.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const EPS: float = 0.0001

var _nodes: Array[Object] = []


func after_each() -> void:
	"""Free every node a test made."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()


static func _tri_arrays(triangles: Array[PackedVector3Array]) -> Array:
	"""Unindexed surface arrays of these triangles (3 vertices each), with up normals and UVs = (x, y)."""
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for tri: PackedVector3Array in triangles:
		for v: Vector3 in tri:
			vertices.append(v)
			normals.append(Vector3(0.6, 0.8, 0.0))
			uvs.append(Vector2(v.x, v.y))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return arrays


static func _tri(x0: float, x1: float, y: float) -> PackedVector3Array:
	"""A triangle from x0 to x1 (its centre between them), standing at height y."""
	return PackedVector3Array([Vector3(x0, y, 0.0), Vector3(x1, y, 0.0), Vector3((x0 + x1) * 0.5, y + 0.2, 0.0)])


static func _ground(at: Vector2) -> float:
	"""A synthetic channel along z: bed -1.2 m within 2 m of x = 0, banks rising to the datum at 3.2 m."""
	return -1.2 + clampf((absf(at.x) - 2.0) / 1.2, 0.0, 1.0) * 1.2


# --- the span ----------------------------------------------------------------------------------------

func test_the_span_runs_to_each_waterline() -> void:
	"""channel_span: from inside a 2 m half-width channel at x = 10 to its waterline each way, to within a
	step; a dry centre has none."""
	var channel := func(p: Vector2) -> float: return 2.0 - absf(p.x - 10.0)
	var span: Vector2 = Fit.channel_span(Vector2(10.5, 0.0), Vector2.RIGHT, channel)
	assert_true(absf(span.x - (-2.5)) <= Fit.SPAN_STEP_M + EPS, "left waterline (%.3f)" % span.x)
	assert_true(absf(span.y - 1.5) <= Fit.SPAN_STEP_M + EPS, "right waterline (%.3f)" % span.y)
	assert_equal(Fit.channel_span(Vector2(20.0, 0.0), Vector2.RIGHT, channel), Vector2.ZERO, "dry: none")


func test_the_stream_margin_is_the_maps_own() -> void:
	"""stream_margin_m (pure, from the authored vertices) agrees with water_map.gd's inside margin along
	the weir's reach, to the map's own unit."""
	var map: WaterMapScript = WaterLayout.make_map()
	for k: int in 40:
		var p := Vector2(20.5 + 0.15 * float(k), -15.6)
		var mapped: float = Rules.to_m(map.inside_margin_u(Vector2i(Rules.to_u(p.x), Rules.to_u(p.y))))
		assert_true(absf(Fit.stream_margin_m(p) - mapped) < 0.004, "at x %.2f: %.4f against %.4f" % [p.x, Fit.stream_margin_m(p), mapped])


func test_the_ends_move_out_to_stand_past_each_waterline() -> void:
	"""gaps: each end's model x, scaled, lands ABUT_M past its waterline; an end already past stays."""
	var scale: float = 1.4
	var gap: Vector2 = Fit.gaps(Vector2(-2.1, 2.3), scale)
	assert_almost_equal((Fit.END_LEFT - gap.x) * scale, -2.1 - Fit.ABUT_M, "left end on the bank")
	assert_almost_equal((Fit.END_RIGHT + gap.y) * scale, 2.3 + Fit.ABUT_M, "right end on the bank")
	assert_equal(Fit.gaps(Vector2(-0.1, 0.1), scale), Vector2.ZERO, "a narrow channel: no move")


# --- the abutments -----------------------------------------------------------------------------------

func test_the_ends_move_and_the_plain_wall_fills_the_gaps() -> void:
	"""spread: the left part moves left by its gap, the right part right, the middle stays; the plain
	wall's copies tile each gap exactly, edge to edge, and carry their UVs."""
	var plain: PackedVector3Array = _tri(Fit.PLAIN_FROM, Fit.PLAIN_TO, 0.3)
	var source: Array = _tri_arrays([_tri(-0.8, -0.6, 0.3), plain, _tri(0.2, 0.4, 0.3), _tri(0.85, 0.9, 0.3)])
	var gap := Vector2(0.5, 0.31)
	var out: Array = Fit.spread(source, gap)
	var v: PackedVector3Array = out[Mesh.ARRAY_VERTEX]
	var copies: int = Fit.copies_for(gap.x) + Fit.copies_for(gap.y)
	assert_equal(v.size(), 3 * (4 + copies), "four triangles and the copies")
	assert_almost_equal(v[0].x, -0.8 - gap.x, "the left part moved left")
	assert_almost_equal(v[3].x, Fit.PLAIN_FROM, "the plain wall itself stays")
	assert_almost_equal(v[3 * (2 + copies)].x, 0.2, "the middle stays")
	assert_almost_equal(v[v.size() - 3].x, 0.85 + gap.y, "the right part moved right")
	var spans: Array[Vector2] = []
	for t: int in range(0, v.size(), 3):
		if t != 3 and absf((v[t + 2].y - v[t].y) - 0.2) < EPS and v[t].x < Fit.CUT_LEFT and v[t + 1].x <= Fit.CUT_LEFT + EPS and v[t].x >= Fit.CUT_LEFT - gap.x - EPS:
			spans.append(Vector2(v[t].x, v[t + 1].x))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	assert_equal(spans.size(), Fit.copies_for(gap.x), "the left copies")
	assert_almost_equal(spans[0].x, Fit.CUT_LEFT - gap.x, "from the moved end")
	assert_almost_equal(spans[spans.size() - 1].y, Fit.CUT_LEFT, "to the cut")
	for k: int in range(1, spans.size()):
		assert_almost_equal(spans[k].x, spans[k - 1].y, "edge to edge %d" % k)
	assert_true((out[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == v.size(), "UVs carried")


func test_a_stretched_copy_keeps_unit_normals() -> void:
	"""Normals follow the stretch and stay unit length."""
	var source: Array = _tri_arrays([_tri(Fit.PLAIN_FROM, Fit.PLAIN_TO, 0.3)])
	var out: Array = Fit.spread(source, Vector2(0.33, 0.0))
	for n: Vector3 in (out[Mesh.ARRAY_NORMAL] as PackedVector3Array):
		assert_almost_equal(n.length(), 1.0, "unit")


func test_no_gap_no_copies() -> void:
	"""A weir already reaching its banks is drawn as made."""
	var source: Array = _tri_arrays([_tri(-0.8, -0.6, 0.3), _tri(Fit.PLAIN_FROM, Fit.PLAIN_TO, 0.3)])
	var out: Array = Fit.spread(source, Vector2.ZERO)
	assert_equal((out[Mesh.ARRAY_VERTEX] as PackedVector3Array), source[Mesh.ARRAY_VERTEX], "unchanged")


# --- the foot and the sill ---------------------------------------------------------------------------

func test_the_foot_reaches_the_bed_and_the_crest_stays() -> void:
	"""let_down_foot: each foot vertex to FOOT_DEPTH_M under the ground or bed at its spot; the crest and
	the wall above the foot band do not move; a foot already deeper is not raised."""
	var placed := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.4), Vector3(0.0, -0.43, 0.0))
	var vertices := PackedVector3Array([Vector3(0.0, Fit.FOOT_Y, 0.0), Vector3(1.5, Fit.FOOT_Y + 0.01, 0.0),
		Vector3(0.0, 0.9, 0.0), Vector3(1.0, -5.0, 0.0)])
	var moved: int = Fit.let_down_foot(vertices, placed, _ground)
	assert_equal(moved, 2, "the two foot vertices")
	for k: int in 2:
		var world: Vector3 = placed * vertices[k]
		assert_almost_equal(world.y, _ground(Vector2(world.x, world.z)) - Fit.FOOT_DEPTH_M, "foot %d on the ground" % k)
	assert_almost_equal(vertices[2].y, 0.9, "the crest stays")
	assert_almost_equal(vertices[3].y, -5.0, "never raised")


func test_the_sill_spans_the_weir_and_stands_on_the_bed() -> void:
	"""sill_arrays: blocks from x_from to x_to; every block's foot FOOT_DEPTH_M under the lowest ground or
	bed beneath it; the upstream course's top at SILL_TOP_Y (within its jitter); a shade per block."""
	var placed := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.4), Vector3(0.0, -0.43, 0.0))
	var out: Array = Fit.sill_arrays(-2.6, 2.6, placed, _ground, Rect2(0.1, 0.2, 0.05, 0.05))
	var v: PackedVector3Array = out[Mesh.ARRAY_VERTEX]
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for p: Vector3 in v:
		lo = lo.min(p)
		hi = hi.max(p)
	assert_true(lo.x >= -2.6 - EPS and hi.x <= 2.6 + EPS and hi.x > 2.5 and lo.x < -2.5, "bank to bank")
	assert_true(absf(hi.y - Fit.SILL_TOP_Y) <= Fit.BLOCK_JITTER_Y, "the upstream course's top")
	for p: Vector3 in v:
		if p.y < 0.0:
			var world: Vector3 = placed * p
			assert_true(world.y <= _ground(Vector2(world.x, world.z)) - Fit.FOOT_DEPTH_M + EPS, "a foot under the ground at x %.2f" % world.x)
	assert_equal((out[Mesh.ARRAY_COLOR] as PackedColorArray).size(), v.size(), "a shade per vertex")
	for uv: Vector2 in (out[Mesh.ARRAY_TEX_UV] as PackedVector2Array):
		assert_true(Rect2(0.1, 0.2, 0.05, 0.05).grow(EPS).has_point(uv), "textured from the stone patch")


# --- the placed weir ---------------------------------------------------------------------------------

func _weir() -> Dictionary:
	"""The weir's placement (normalised)."""
	for p: Dictionary in Dressing.placements():
		if p["key"] == Dressing.WEIR_KEY:
			return p
	return {}


func test_the_placed_weir_reaches_both_banks_and_the_bed() -> void:
	"""Unstaged (the placeholder wall and sill) on the real map: from ABUT_M past one waterline to ABUT_M
	past the other; its lowest point at every 0.25 m across under the ground there; its crest well above
	the water -- it is fitted, not sunk."""
	var map: WaterMapScript = WaterLayout.make_map()
	var p: Dictionary = _weir()
	var piece: MeshInstance3D = _keep(Dressing.weir_piece({}, map, p)) as MeshInstance3D
	var span: Vector2 = Fit.channel_span(p["at"], Dressing.weir_axis(p))
	var at: Vector2 = p["at"]
	var lowest: Dictionary = {}
	var top: float = -INF
	var xs := Vector2(INF, -INF)
	for v: Vector3 in piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var w: Vector3 = piece.transform * v
		var strip: int = floori(w.x / 0.25)
		lowest[strip] = minf(float(lowest.get(strip, INF)), w.y)
		top = maxf(top, w.y)
		xs = Vector2(minf(xs.x, w.x), maxf(xs.y, w.x))
	assert_true(absf(xs.x - (at.x + span.x - Fit.ABUT_M)) < 0.05, "the west end on the bank (%.2f)" % xs.x)
	assert_true(absf(xs.y - (at.x + span.y + Fit.ABUT_M)) < 0.05, "the east end on the bank (%.2f)" % xs.y)
	for strip: int in lowest:
		var x: float = (float(strip) + 0.5) * 0.25
		var ground: float = Rules.to_m(map.ground_height_at(Vector2i(Rules.to_u(x), Rules.to_u(at.y))))
		assert_true(float(lowest[strip]) <= ground + 0.02, "touches at x %.2f (%.2f over %.2f)" % [x, float(lowest[strip]), ground])
	var water: float = -Rules.to_m(WaterLayout.LEVEL_DROP_U)
	assert_true(top - water > 0.8, "the crest stands clear of the water (%.2f m)" % (top - water))


func test_the_weir_stands_in_its_reach_clear_of_the_landings() -> void:
	"""On the stream, where it is 4-12 m wide (GDD §5.4), more than a metre from every landing's way in
	(the swimmers' `weir_bank` landing included), its footprint ringing both abutments."""
	var map: WaterMapScript = WaterLayout.make_map()
	var p: Dictionary = _weir()
	var at: Vector2 = p["at"]
	var width := IntMath.IntResult.new()
	assert_true(map.stream_width_at_into(Vector2i(Rules.to_u(at.x), Rules.to_u(at.y)), width), "measured")
	assert_true(width.value >= 4096 and width.value <= 12288, "4-12 m wide (%d u)" % width.value)
	var rect: Rect2 = Dressing.weir_rect(p)
	var circles: Array[Vector3] = Dressing.placement_circles(p)
	for k: int in map.landing_count():
		var water := Vector2(Rules.to_m(map.landing_water(k).x), Rules.to_m(map.landing_water(k).y))
		var clear: float = INF
		for c: Vector3 in circles:
			clear = minf(clear, Vector2(c.x, c.y).distance_to(water) - c.z)
		assert_true(clear > 0.3, "%s's way in is clear of the weir (%.2f m)" % [map.landing_name(k), clear])
	for end_x: float in [rect.position.x + 0.2, rect.end.x - 0.2]:
		var end := Vector2(at.x + end_x, at.y)
		var covered: bool = false
		for c: Vector3 in circles:
			covered = covered or Vector2(c.x, c.y).distance_to(end) <= c.z
		assert_true(covered, "the abutment at x %.2f is in the footprint" % end.x)


func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node

extends RefCounted
## The weir fitted to its channel: bank to bank, down to the bed, in the demo's one water. Decision
## 0301 (review F41), over decision 0196's water dressing. Presentation only; floats.
##
## WHY. The library weir is a diorama (its own earth slab, pool and tail water). Placed in the stream it
## stood as a raised block mid-channel -- 0.47-0.83 m over the bed, touching neither bank. The review:
## "integrate the mesh with banks/bed and one continuous water surface ... do not simply lower the whole
## weir enough to bury the working crest". So, from the derived STRUCTURE (tools/make_demo_weir.py: the
## L0 less its water and slab, cut through at CUT_LEFT, PLAIN_FROM, PLAIN_TO and CUT_RIGHT):
##   * THE SPAN (`channel_span`): along the weir's own axis from its centre to each waterline -- where the
##     stream's capsules (water_layout.gd STREAM_VERTICES; water_map.gd's own margin) end -- and on into
##     the bank by ABUT_M. Pure: the same with or without a map, so the dressing's footprint knows it too.
##   * THE ABUTMENTS (`spread`): the structure's ends (beyond the outer cuts: the left stone pier, the
##     right wall end) move out to those bank points, and the gaps are filled with copies of the plain
##     wall between the inner cuts, stretched a little to fit exactly. The gate, the wheel and the middle
##     pier stay as made; the crest stays at its height.
##   * THE FOOT (`let_down_foot`): every vertex within FOOT_BAND of the structure's lowest point is let
##     down to the ground or bed under it, FOOT_DEPTH_M into it -- piers and wall stand ON the bed and
##     the banks, wherever they are.
##   * THE SILL (`sill_arrays`): a course of stone blocks under the wall from bank to bank -- low
##     downstream (to the old tail water, just under the surface), up to SILL_TOP_Y upstream, where the
##     stripped pool's fringe leaves the wall's foot open -- each block's bottom on the ground or bed
##     under it. Textured from the structure's own stone (the manifest row's `stone_uv`), each block a
##     little different in height and shade.
## Model units are the glTF's: x across the stream, y up, +z downstream (the model's front).

const Rules := preload("res://demo/water/water_rules.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")

## The derived structure (tools/make_demo_weir.py CUTS and its manifest row), model units.
const CUT_LEFT: float = -0.41
const PLAIN_FROM: float = -0.38
const PLAIN_TO: float = -0.1
const CUT_RIGHT: float = 0.8
const END_LEFT: float = -0.9138
const END_RIGHT: float = 0.9409
const FOOT_Y: float = 0.1334
const FOOT_BAND: float = 0.05
## The wall's band (z), its crest, and how far downstream the piers reach, model units.
const WALL_BACK_Z: float = -0.124
const WALL_FRONT_Z: float = 0.095
const CREST_Y: float = 0.9
const PIER_FRONT_Z: float = 0.7152
## The sill's L-shaped section, model units: upstream face, step, downstream face; the upstream course's
## top (above the stripped pool fringe, 0.47) and the footing's (the old tail water, 0.15-0.17).
const SILL_BACK_Z: float = -0.17
const SILL_STEP_Z: float = -0.02
const SILL_FRONT_Z: float = 0.12
const SILL_TOP_Y: float = 0.52
const FOOTING_TOP_Y: float = 0.17
## A sill stone's length, the joint between two, and how much each varies (model units).
const BLOCK_X: float = 0.28
const JOINT_X: float = 0.012
const BLOCK_JITTER_Y: float = 0.02
## World metres: how far the ends reach past each waterline into the bank; how deep the foot and the sill
## go into the ground; how finely the waterline is found; the farthest it is looked for.
const ABUT_M: float = 0.7
const FOOT_DEPTH_M: float = 0.08
const SPAN_STEP_M: float = 0.02
const SPAN_MAX_M: float = 12.0


## Surface arrays being built (packed columns grow in place on an object's members; a packed array
## taken out of an Array is a copy).
class Builder extends RefCounted:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var tangents: PackedFloat32Array = PackedFloat32Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colours: PackedColorArray = PackedColorArray()
	var with_normals: bool = true
	var with_tangents: bool = false
	var with_uvs: bool = true
	var with_colours: bool = false

	func arrays() -> Array:
		"""The surface arrays for Mesh.add_surface_from_arrays (only the columns built)."""
		var out: Array = []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = vertices
		if with_normals:
			out[Mesh.ARRAY_NORMAL] = normals
		if with_tangents:
			out[Mesh.ARRAY_TANGENT] = tangents
		if with_uvs:
			out[Mesh.ARRAY_TEX_UV] = uvs
		if with_colours:
			out[Mesh.ARRAY_COLOR] = colours
		return out


# --- the span ----------------------------------------------------------------------------------------

static func stream_margin_m(p: Vector2) -> float:
	"""How far inside the stream a ground point lies (m; <= 0 out of it): water_map.gd's union of tapered
	capsules over water_layout.gd's STREAM_VERTICES -- the largest of r(t) - |p - c(t)|."""
	var best: float = -INF
	var v: Array[int] = WaterLayout.STREAM_VERTICES
	for k: int in range(1, v.size() / 4):
		var a := Vector2(Rules.to_m(v[k * 4 - 4]), Rules.to_m(v[k * 4 - 3]))
		var b := Vector2(Rules.to_m(v[k * 4]), Rules.to_m(v[k * 4 + 1]))
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var r: float = lerpf(Rules.to_m(v[k * 4 - 2]), Rules.to_m(v[k * 4 + 2]), t)
		best = maxf(best, r - p.distance_to(a + ab * t))
	return best


static func channel_span(centre: Vector2, axis: Vector2, margin: Callable = stream_margin_m) -> Vector2:
	"""From `centre` along the unit `axis` (-, +): the signed distances (m) to the waterline on each side
	-- the first step at which `margin(point)` is no longer positive. (0, 0) if the centre is dry."""
	if float(margin.call(centre)) <= 0.0:
		return Vector2.ZERO
	var out := Vector2.ZERO
	for side: int in [-1, 1]:
		var t: float = 0.0
		while t < SPAN_MAX_M and float(margin.call(centre + axis * (t + SPAN_STEP_M) * float(side))) > 0.0:
			t += SPAN_STEP_M
		if side < 0:
			out.x = -(t + SPAN_STEP_M)
		else:
			out.y = t + SPAN_STEP_M
	return out


static func gaps(span: Vector2, scale: float) -> Vector2:
	"""How far (model units) each end moves out so that it stands ABUT_M past its waterline: (left, right),
	never negative (an end already past it stays)."""
	var s: float = maxf(scale, 0.0001)
	return Vector2(maxf(END_LEFT - (span.x - ABUT_M) / s, 0.0), maxf((span.y + ABUT_M) / s - END_RIGHT, 0.0))


static func fitted_rect(gap: Vector2) -> Rect2:
	"""The fitted structure's footprint in its own XZ frame, model units (x across, y: z downstream)."""
	var x0: float = END_LEFT - gap.x
	return Rect2(Vector2(x0, SILL_BACK_Z), Vector2(END_RIGHT + gap.y - x0, PIER_FRONT_Z - SILL_BACK_Z))


# --- the abutments -----------------------------------------------------------------------------------

static func spread(arrays: Array, gap: Vector2) -> Array:
	"""The structure's surface arrays with its ends moved out by `gap` (left, right; model units) and the
	gaps filled with stretched copies of its plain wall. Unindexed, every triangle in the part its centre
	x falls in (the source is cut at the planes, so none straddles one)."""
	var out := Builder.new()
	out.with_normals = arrays[Mesh.ARRAY_NORMAL] != null
	out.with_tangents = arrays[Mesh.ARRAY_TANGENT] != null
	out.with_uvs = arrays[Mesh.ARRAY_TEX_UV] != null
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = _index_of(arrays)
	for k: int in range(0, index.size() - 2, 3):
		var cx: float = (vertices[index[k]].x + vertices[index[k + 1]].x + vertices[index[k + 2]].x) / 3.0
		var shift: float = -gap.x if cx < CUT_LEFT else (gap.y if cx > CUT_RIGHT else 0.0)
		_emit(out, arrays, index, k, shift, 1.0)
		if cx >= PLAIN_FROM and cx <= PLAIN_TO:
			_emit_copies(out, arrays, index, k, CUT_LEFT - gap.x, gap.x)
			_emit_copies(out, arrays, index, k, CUT_RIGHT, gap.y)
	return out.arrays()


static func copies_for(gap: float) -> int:
	"""How many plain-wall copies fill a gap (none for none; else enough that each is stretched by at most
	the plain wall's own width)."""
	return 0 if gap <= 0.0 else ceili(gap / (PLAIN_TO - PLAIN_FROM))


static func _emit_copies(out: Builder, arrays: Array, index: PackedInt32Array, k: int, start: float, gap: float) -> void:
	"""Triangle `k` once in each copy of the plain wall that fills [start, start + gap]."""
	var n: int = copies_for(gap)
	if n == 0:
		return
	var stretch: float = gap / (float(n) * (PLAIN_TO - PLAIN_FROM))
	for c: int in n:
		var offset: float = start + float(c) * (PLAIN_TO - PLAIN_FROM) * stretch
		_emit(out, arrays, index, k, offset - PLAIN_FROM * stretch, stretch)


static func _emit(out: Builder, arrays: Array, index: PackedInt32Array, k: int, shift: float, stretch: float) -> void:
	"""Append triangle `k`'s three corners, x scaled by `stretch` then moved by `shift`; normals and
	tangents follow the stretch."""
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for corner: int in 3:
		var i: int = index[k + corner]
		out.vertices.append(Vector3(vertices[i].x * stretch + shift, vertices[i].y, vertices[i].z))
		if out.with_normals:
			var n: Vector3 = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)[i]
			out.normals.append(Vector3(n.x / stretch, n.y, n.z).normalized())
		if out.with_tangents:
			_emit_tangent(out, arrays[Mesh.ARRAY_TANGENT], i, stretch)
		if out.with_uvs:
			out.uvs.append((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array)[i])


static func _emit_tangent(out: Builder, tangents: PackedFloat32Array, i: int, stretch: float) -> void:
	"""Append vertex `i`'s tangent, its x stretched, renormalised, its binormal sign kept."""
	var t := Vector3(tangents[i * 4] * stretch, tangents[i * 4 + 1], tangents[i * 4 + 2]).normalized()
	out.tangents.append(t.x)
	out.tangents.append(t.y)
	out.tangents.append(t.z)
	out.tangents.append(tangents[i * 4 + 3])


static func _index_of(arrays: Array) -> PackedInt32Array:
	"""The surface's index list (0, 1, 2, ... for an unindexed one)."""
	if arrays[Mesh.ARRAY_INDEX] != null:
		return arrays[Mesh.ARRAY_INDEX]
	var out := PackedInt32Array()
	for i: int in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
		out.append(i)
	return out


# --- the foot ----------------------------------------------------------------------------------------

static func let_down_foot(vertices: PackedVector3Array, placed: Transform3D, ground_at: Callable) -> int:
	"""Let every foot vertex (within FOOT_BAND of FOOT_Y) down to FOOT_DEPTH_M under the ground or bed at
	its spot (`ground_at(Vector2) -> float`, world m), through the piece's transform `placed` (uniform
	scale, a turn about Y). Never raises one. Returns how many moved."""
	var scale: float = placed.basis.get_scale().y
	var moved: int = 0
	for i: int in vertices.size():
		var v: Vector3 = vertices[i]
		if v.y > FOOT_Y + FOOT_BAND:
			continue
		var p: Vector3 = placed * v
		var foot: float = (float(ground_at.call(Vector2(p.x, p.z))) - FOOT_DEPTH_M - placed.origin.y) / scale
		if foot < v.y:
			vertices[i] = Vector3(v.x, foot, v.z)
			moved += 1
	return moved


# --- the sill ----------------------------------------------------------------------------------------

static func sill_arrays(x_from: float, x_to: float, placed: Transform3D, ground_at: Callable, stone: Rect2) -> Array:
	"""The stone sill under the wall from `x_from` to `x_to` (model units): blocks BLOCK_X long, each its
	two boxes (the upstream course and the downstream footing) with their bottoms FOOT_DEPTH_M under the
	lowest ground or bed beneath the block, every face textured from the `stone` UV patch; COLOR carries
	each block's shade. Surface arrays, model units."""
	var out := Builder.new()
	out.with_colours = true
	var count: int = maxi(1, ceili((x_to - x_from) / BLOCK_X))
	var length: float = (x_to - x_from) / float(count)
	for b: int in count:
		var x0: float = x_from + float(b) * length
		var bottom: float = _block_bottom(x0, x0 + length, placed, ground_at)
		var jitter: float = BLOCK_JITTER_Y * (_hash01(b) - 0.5)
		var shade: float = lerpf(0.82, 1.04, _hash01(b + 17))
		var half_joint: float = JOINT_X * 0.5
		_box(out, Vector3(x0 + half_joint, bottom, SILL_BACK_Z), Vector3(x0 + length - half_joint, SILL_TOP_Y + jitter, SILL_STEP_Z), stone, shade)
		_box(out, Vector3(x0 + half_joint, bottom, SILL_STEP_Z), Vector3(x0 + length - half_joint, FOOTING_TOP_Y + jitter * 0.5, SILL_FRONT_Z), stone, shade * 0.94)
	return out.arrays()


static func placeholder_arrays(x_from: float, x_to: float, placed: Transform3D, ground_at: Callable) -> Array:
	"""Unstaged: the sill (over the whole map's UVs) and a plain wall box on it up to CREST_Y."""
	var out: Array = sill_arrays(x_from, x_to, placed, ground_at, Rect2(0.0, 0.0, 1.0, 1.0))
	var wall := Builder.new()
	wall.with_colours = true
	_box(wall, Vector3(x_from, FOOTING_TOP_Y, WALL_BACK_Z), Vector3(x_to, CREST_Y, WALL_FRONT_Z), Rect2(0.0, 0.0, 1.0, 1.0), 1.0)
	for column: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR]:
		out[column] = out[column] + wall.arrays()[column]
	return out


static func _block_bottom(x0: float, x1: float, placed: Transform3D, ground_at: Callable) -> float:
	"""A block's bottom (model y): FOOT_DEPTH_M under the lowest ground or bed at its four corners."""
	var lowest: float = INF
	for x: float in [x0, x1]:
		for z: float in [SILL_BACK_Z, SILL_FRONT_Z]:
			var p: Vector3 = placed * Vector3(x, 0.0, z)
			lowest = minf(lowest, float(ground_at.call(Vector2(p.x, p.z))))
	return (lowest - FOOT_DEPTH_M - placed.origin.y) / placed.basis.get_scale().y


static func _hash01(n: int) -> float:
	"""A fixed pseudo-random 0..1 from an integer (each block's jitter and shade; no RNG state)."""
	var h: int = (n * 73856093) ^ (n * 19349663 + 83492791)
	return float(absi(h) % 1000) / 999.0


static func _box(out: Builder, lo: Vector3, hi: Vector3, stone: Rect2, shade: float) -> void:
	"""The five visible faces of the box lo..hi (not its bottom), each a quad over the whole stone patch."""
	var x0: float = lo.x
	var x1: float = hi.x
	_quad(out, Vector3(x0, hi.y, lo.z), Vector3(x1, hi.y, lo.z), Vector3(x1, hi.y, hi.z), Vector3(x0, hi.y, hi.z), Vector3.UP, stone, shade)
	_quad(out, Vector3(x0, lo.y, hi.z), Vector3(x0, hi.y, hi.z), Vector3(x1, hi.y, hi.z), Vector3(x1, lo.y, hi.z), Vector3.BACK, stone, shade)
	_quad(out, Vector3(x1, lo.y, lo.z), Vector3(x1, hi.y, lo.z), Vector3(x0, hi.y, lo.z), Vector3(x0, lo.y, lo.z), Vector3.FORWARD, stone, shade)
	_quad(out, Vector3(x0, lo.y, lo.z), Vector3(x0, hi.y, lo.z), Vector3(x0, hi.y, hi.z), Vector3(x0, lo.y, hi.z), Vector3.LEFT, stone, shade)
	_quad(out, Vector3(x1, lo.y, hi.z), Vector3(x1, hi.y, hi.z), Vector3(x1, hi.y, lo.z), Vector3(x1, lo.y, lo.z), Vector3.RIGHT, stone, shade)


static func _quad(out: Builder, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, stone: Rect2,
		shade: float) -> void:
	"""Two triangles a-b-c and a-c-d facing `normal`, the stone patch stretched over them, shaded."""
	var uvs: Array[Vector2] = [stone.position + Vector2(0.0, stone.size.y), stone.position,
		stone.position + Vector2(stone.size.x, 0.0), stone.end]
	var corners: Array[Vector3] = [a, b, c, d]
	for k: int in [0, 1, 2, 0, 2, 3]:
		out.vertices.append(corners[k])
		out.normals.append(normal)
		out.uvs.append(uvs[k])
		out.colours.append(Color(shade, shade, shade))

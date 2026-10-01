extends RefCounted
## Holes in the village ground where a tunnel's ramp is an open cutting. Decision 0371 (the underground revamp's P7;
## review F16: "a terrain aperture/ramp representation with consistent visual and traversal geometry"). Presentation
## only.
##
## WHY. The ground is one mesh (demo_world.gd's plane, carved on the water grid by water_terrain.gd), coarse -- 8 m
## cells over most of the village -- so a cutting cannot be a hole in its grid. Decision 0207 rejected discarding the
## ground's fragments in its shader (a discard on the whole ground, every frame, everywhere). This cuts its GEOMETRY,
## and only when a hole changes:
##   * every ground triangle that overlaps a hole is DROPPED from the ground's index array (the vertices stay; the
##     mesh is rebuilt from the cached arrays with the shorter index array);
##   * what of those triangles lies OUTSIDE every hole is drawn again as a COLLAR: each triangle minus each (convex)
##     hole, decomposed into convex pieces by the hole's edges in turn -- no piece has a hole -- fanned into triangles
##     on the triangle's own plane, its normals and tangents interpolated from its corners, wound as it was, in the
##     ground's own material (which reads world x, z, so the collar is the same grass). The collar meets the kept
##     ground on the dropped triangles' outer edges exactly.
## A hole is a convex polygon in world x, z (its winding does not matter). `apply()` does the work when something
## changed and does nothing otherwise; the triangles near each hole are found through a bucket grid built once a mesh.
## If the ground's mesh is replaced by someone else (water_terrain.gd's carving), it is read again as the uncut ground.

## The bucket grid's cell (m) for finding the triangles near a hole.
const BUCKET_M: float = 4.0
## A collar piece thinner than this (m²) is dropped as a sliver.
const SLIVER_M2: float = 1e-6

var _ground: MeshInstance3D = null
## The uncut ground: its surface arrays and material, the mesh this cut last built (to notice a replacement), its index
## array and the bucket grid of its triangles.
var _arrays: Array = []
var _material: Material = null
var _made: Mesh = null
var _indices: PackedInt32Array = PackedInt32Array()
var _buckets: Dictionary = {}
## hole id -> PackedVector2Array (convex, counter-clockwise in x, z).
var _holes: Dictionary = {}
var _dirty: bool = false
var collar: MeshInstance3D = null
## Triangles dropped by the last apply (checks).
var dropped: int = 0


func set_ground(ground: MeshInstance3D) -> void:
	"""Cut holes in `ground` (a MeshInstance3D of one surface; null: nothing to cut). Reads it now -- at the world's
	build, not on the first frame a mouth opens (a 58k-triangle ground takes tens of ms)."""
	_ground = ground
	_made = null
	_dirty = true
	if ground != null and ground.mesh != null:
		_read_ground()


func set_hole(id: int, polygon: PackedVector2Array) -> void:
	"""Hole `id` is this convex polygon (world x, z), or none when it is empty. Marks the cut to be redone only when it
	changed."""
	if polygon.is_empty():
		if _holes.erase(id):
			_dirty = true
		return
	var ccw := polygon if signed_area(polygon) >= 0.0 else _reversed(polygon)
	if _holes.has(id) and _holes[id] == ccw:
		return
	_holes[id] = ccw
	_dirty = true


func hole_count() -> int:
	"""How many holes are cut (checks)."""
	return _holes.size()


func apply() -> bool:
	"""Redo the cut when a hole or the ground changed; true when it did."""
	if _ground == null or _ground.mesh == null:
		return false
	if _ground.mesh != _made:
		_read_ground()
	elif not _dirty:
		return false
	_dirty = false
	var near := _candidates()
	var drop := {}
	var pieces: Array[PackedVector2Array] = []
	var from: PackedInt32Array = PackedInt32Array()
	for t: int in near:
		var cut := _subtract(_triangle_2d(t))
		if cut.size() == 1 and _same(cut[0], _triangle_2d(t)):
			continue
		drop[t] = true
		for piece: PackedVector2Array in cut:
			pieces.append(piece)
			from.append(t)
	dropped = drop.size()
	_rebuild_ground(drop)
	_rebuild_collar(pieces, from)
	return true


# --- reading the ground -----------------------------------------------------------------------------

func _read_ground() -> void:
	"""Take the ground's current mesh as the uncut ground, and bucket its triangles."""
	var mesh := _ground.mesh
	_arrays = mesh.surface_get_arrays(0)
	_material = mesh.surface_get_material(0)
	if _material == null and mesh is PrimitiveMesh:
		_material = (mesh as PrimitiveMesh).material
	_indices = _arrays[Mesh.ARRAY_INDEX] if _arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if _indices.is_empty():
		_indices.resize((_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		for k in _indices.size():
			_indices[k] = k
	_made = mesh
	_buckets.clear()
	var lists := {}
	var points: PackedVector3Array = _arrays[Mesh.ARRAY_VERTEX]
	for t in _indices.size() / 3:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for c in 3:
			var p: Vector3 = points[_indices[t * 3 + c]]
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
		for bx in range(floori(lo.x / BUCKET_M), floori(hi.x / BUCKET_M) + 1):
			for bz in range(floori(lo.y / BUCKET_M), floori(hi.y / BUCKET_M) + 1):
				var key := Vector2i(bx, bz)
				if not lists.has(key):
					lists[key] = []
				(lists[key] as Array).append(t)
	for key: Vector2i in lists:
		_buckets[key] = PackedInt32Array(lists[key])


func _candidates() -> PackedInt32Array:
	"""Every triangle in a bucket some hole's bound touches, once, in order."""
	var seen := {}
	for hole: PackedVector2Array in _holes.values():
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p: Vector2 in hole:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		for bx in range(floori(lo.x / BUCKET_M), floori(hi.x / BUCKET_M) + 1):
			for bz in range(floori(lo.y / BUCKET_M), floori(hi.y / BUCKET_M) + 1):
				for t: int in _buckets.get(Vector2i(bx, bz), PackedInt32Array()):
					seen[t] = true
	var out := PackedInt32Array(seen.keys())
	out.sort()
	return out


func _triangle_2d(t: int) -> PackedVector2Array:
	"""Triangle `t`'s corners in x, z, in its own winding."""
	var points: PackedVector3Array = _arrays[Mesh.ARRAY_VERTEX]
	var out := PackedVector2Array()
	for c in 3:
		var p: Vector3 = points[_indices[t * 3 + c]]
		out.append(Vector2(p.x, p.z))
	return out


# --- the cut ----------------------------------------------------------------------------------------

func _subtract(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	"""`polygon` (convex) minus every hole, as convex pieces (see the header)."""
	var pieces: Array[PackedVector2Array] = [polygon]
	var bound := _bound(polygon)
	for hole: PackedVector2Array in _holes.values():
		if not bound.intersects(_bound(hole)):
			continue
		var next: Array[PackedVector2Array] = []
		for piece: PackedVector2Array in pieces:
			next.append_array(difference(piece, hole))
		pieces = next
	return pieces


static func _bound(polygon: PackedVector2Array) -> Rect2:
	"""`polygon`'s bounding rectangle: a hole off a triangle's bound leaves it whole (its edge lines split nothing)."""
	var out := Rect2(polygon[0], Vector2.ZERO)
	for p: Vector2 in polygon:
		out = out.expand(p)
	return out


static func difference(piece: PackedVector2Array, hole: PackedVector2Array) -> Array[PackedVector2Array]:
	"""Convex `piece` minus convex counter-clockwise `hole`, as disjoint convex pieces: for each of the hole's edges in
	turn, what of the rest lies outside it is a piece, and the rest is what lies inside it."""
	var out: Array[PackedVector2Array] = []
	var rest := piece
	for k in hole.size():
		var a := hole[k]
		var b := hole[(k + 1) % hole.size()]
		var outside := clip(rest, a, b, false)
		if absf(signed_area(outside)) > SLIVER_M2:
			out.append(outside)
		rest = clip(rest, a, b, true)
		if rest.size() < 3:
			return out
	return out


static func clip(polygon: PackedVector2Array, a: Vector2, b: Vector2, keep_left: bool) -> PackedVector2Array:
	"""`polygon` cut by the line a->b, keeping the side to its left (or right): Sutherland-Hodgman, winding kept."""
	var out := PackedVector2Array()
	var count := polygon.size()
	for k in count:
		var p := polygon[k]
		var q := polygon[(k + 1) % count]
		var sp := _side(a, b, p) * (1.0 if keep_left else -1.0)
		var sq := _side(a, b, q) * (1.0 if keep_left else -1.0)
		if sp >= 0.0:
			out.append(p)
		if (sp > 0.0 and sq < 0.0) or (sp < 0.0 and sq > 0.0):
			out.append(p.lerp(q, sp / (sp - sq)))
	return out


static func _side(a: Vector2, b: Vector2, p: Vector2) -> float:
	"""How far left of the line a->b `p` is (the cross product; negative: right)."""
	return (b - a).cross(p - a)


static func signed_area(polygon: PackedVector2Array) -> float:
	"""The polygon's signed area (positive counter-clockwise in x, z read as x, y)."""
	var total := 0.0
	for k in polygon.size():
		total += polygon[k].cross(polygon[(k + 1) % polygon.size()])
	return total * 0.5


static func _reversed(polygon: PackedVector2Array) -> PackedVector2Array:
	"""The polygon wound the other way."""
	var out := polygon.duplicate()
	out.reverse()
	return out


static func _same(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	"""Whether two polygons are the same corners in the same order (a triangle no hole touched)."""
	if a.size() != b.size():
		return false
	for k in a.size():
		if a[k].distance_squared_to(b[k]) > 1e-12:
			return false
	return true


# --- rebuilding ---------------------------------------------------------------------------------------

func _rebuild_ground(drop: Dictionary) -> void:
	"""The ground's mesh again, its triangles in `drop` left out (slices of the cached index array between them)."""
	var kept := PackedInt32Array()
	var start := 0
	var gone := PackedInt32Array(drop.keys())
	gone.sort()
	for t: int in gone:
		kept.append_array(_indices.slice(start, t * 3))
		start = t * 3 + 3
	kept.append_array(_indices.slice(start))
	var mesh := ArrayMesh.new()
	if not kept.is_empty():
		var arrays := _arrays.duplicate()
		arrays[Mesh.ARRAY_INDEX] = kept
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, _material)
	_ground.mesh = mesh
	_made = mesh


func _rebuild_collar(pieces: Array[PackedVector2Array], from: PackedInt32Array) -> void:
	"""The collar (see the header): every piece fanned on its triangle's plane, in the ground's material, beside the
	ground; hidden when there is none."""
	if collar == null or not is_instance_valid(collar):
		collar = MeshInstance3D.new()
		collar.name = "GroundCollar"
	if collar.get_parent() != _ground:
		if collar.get_parent() != null:
			collar.get_parent().remove_child(collar)
		_ground.add_child(collar)
	collar.layers = _ground.layers
	collar.cast_shadow = _ground.cast_shadow
	collar.visible = not pieces.is_empty()
	if pieces.is_empty():
		collar.mesh = null
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in pieces.size():
		_fan(tool, pieces[k], from[k])
	var mesh := tool.commit()
	mesh.surface_set_material(0, _material)
	collar.mesh = mesh


func _fan(tool: SurfaceTool, piece: PackedVector2Array, t: int) -> void:
	"""One convex piece of triangle `t` as a fan of triangles on its plane. A piece is wound as `t` is: it is clipped
	from `t`'s own corners, and a clip keeps the winding."""
	for k in range(1, piece.size() - 1):
		_vertex(tool, piece[0], t)
		_vertex(tool, piece[k], t)
		_vertex(tool, piece[k + 1], t)


func _vertex(tool: SurfaceTool, p: Vector2, t: int) -> void:
	"""A collar vertex at `p` on triangle `t`'s plane, its normal and tangent interpolated from `t`'s corners."""
	var points: PackedVector3Array = _arrays[Mesh.ARRAY_VERTEX]
	var corner := [_indices[t * 3], _indices[t * 3 + 1], _indices[t * 3 + 2]]
	var w := barycentric(p, Vector2(points[corner[0]].x, points[corner[0]].z), Vector2(points[corner[1]].x, points[corner[1]].z),
		Vector2(points[corner[2]].x, points[corner[2]].z))
	var normals: Variant = _arrays[Mesh.ARRAY_NORMAL]
	if normals != null:
		var n := Vector3.ZERO
		for c in 3:
			n += (normals as PackedVector3Array)[corner[c]] * w[c]
		tool.set_normal(n.normalized())
	var tangents: Variant = _arrays[Mesh.ARRAY_TANGENT]
	if tangents != null:
		var tangent := Vector3.ZERO
		for c in 3:
			var at: int = corner[c] * 4
			tangent += Vector3(tangents[at], tangents[at + 1], tangents[at + 2]) * w[c]
		tool.set_tangent(Plane(tangent.normalized(), (tangents as PackedFloat32Array)[corner[0] * 4 + 3]))
	var y := 0.0
	for c in 3:
		y += points[corner[c]].y * w[c]
	tool.add_vertex(Vector3(p.x, y, p.y))


static func barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	"""`p`'s barycentric weights over the triangle a, b, c (x, z)."""
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var den := v0.cross(v1)
	if absf(den) < 1e-12:
		return Vector3(1.0, 0.0, 0.0)
	var wb := v2.cross(v1) / den
	var wc := v0.cross(v2) / den
	return Vector3(1.0 - wb - wc, wb, wc)

extends RefCounted
## Where a tree model's roots actually stand: a small support heightfield baked from its own mesh.
## Decision 0301 (review F40), over decision 0196's woods. Presentation only; floats never decide a row.
##
## WHY. forest_roots.gd's radial profile is the median vertex height in half-metre rings. The staged
## oak's roots are lobes, not a ring: the review found the profile lifting a walker 0.8 m where no
## surface stands at all, while 0.15 m away a root stands proud. Tree yaw never entered it.
##
## THE FIELD. Baked once per tree MODEL (`bake`), in TREE-LOCAL metres at size 1 after the world's sink
## (world_sizes.gd SINK_M): +X and +Z are the model's own axes, the ground is y = 0. A square grid of
## CELL_M cells out to the model's root reach holds, per cell centre, the highest surface of the mesh
## at or below CAP_M (anything higher is trunk wall or crown, never footing) -- the surface a foot
## coming down from above would meet -- or 0 where the mesh has nothing above the ground. `height_local`
## reads it bilinearly; `height_at` turns a world point into tree-local space by the tree's position,
## yaw (the same Basis the world turns the model by) and size, so the roots are where they are drawn.
##
## ROOT OBSTACLES. Where a root stands more than OBSTACLE_M proud there is no stable walk surface for a
## resident -- it would be hoisted onto a knuckle of root for a stride -- so those cells are covered by a
## few circles (`obstacles`) that the cast walks round like any other; `obstacles_at` places them for a
## tree. First a FLARE circle about the trunk, out to the farthest proud cell within FLARE_BAND_M of the
## trunk's own circle (the buttresses all round the trunk: one circle, not a ring of them); then the
## proudest lobes beyond it, OBSTACLE_RADIUS_M each, at most MAX_OBSTACLES in all. Lower roots are walked
## over, on the field.
##
## CHEAP. The bake is a triangle rasterisation, once per model; the lookup is a rotation, a bounds test
## and four array reads. The broad phase stays forest_lift.gd's bucket grid.

const Self := preload("res://demo/forestry/forest_root_field.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const Roots := preload("res://demo/forestry/forest_roots.gd")
const Layout := preload("res://demo/world/world_layout.gd")

## Grid cell (m, at size 1). A mouse's foot is about this long.
const CELL_M: float = 0.125
## Surfaces higher than this above the ground (m, size 1) are trunk or crown, not footing.
const CAP_M: float = 1.6
## A root standing prouder than this (m, size 1) is walked round, not over (see ROOT OBSTACLES).
const OBSTACLE_M: float = 0.45
const OBSTACLE_RADIUS_M: float = 0.5
const FLARE_BAND_M: float = 0.8
const MAX_OBSTACLES: int = 16
## A triangle whose XZ footprint is smaller than this (m^2) is a wall seen edge-on: no footing.
const MIN_AREA_M2: float = 0.000001

## Half the grid's side (m, size 1): the model's root reach.
var reach_m: float = 0.0
## Cells a side.
var side: int = 0
## Support height per cell (m above the ground, size 1), row-major from (-reach, -reach) in +X then +Z.
var heights: PackedFloat32Array = PackedFloat32Array()
## Root obstacle circles in tree-local metres at size 1: (x, z, radius).
var obstacles: PackedVector3Array = PackedVector3Array()


func bake(faces: PackedVector3Array, reach: float, trunk_radius: float) -> void:
	"""Rasterise `faces` (triangles, tree-local metres at size 1, ground at y = 0) into the field out to
	`reach`, then cover every too-proud cell outside `trunk_radius` with obstacle circles."""
	reach_m = maxf(reach, CELL_M)
	side = int(ceil(2.0 * reach_m / CELL_M))
	heights.resize(side * side)
	heights.fill(0.0)
	for k: int in range(0, faces.size() - 2, 3):
		_rasterise(faces[k], faces[k + 1], faces[k + 2])
	_cover_obstacles(trunk_radius)


func _rasterise(a: Vector3, b: Vector3, c: Vector3) -> void:
	"""Raise every cell centre under triangle abc to the triangle's height there, if at or below CAP_M."""
	if minf(a.y, minf(b.y, c.y)) > CAP_M or maxf(a.y, maxf(b.y, c.y)) <= 0.0:
		return
	var area: float = (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
	if absf(area) < MIN_AREA_M2:
		return
	var i0: int = maxi(_cell(minf(a.x, minf(b.x, c.x))), 0)
	var i1: int = mini(_cell(maxf(a.x, maxf(b.x, c.x))), side - 1)
	var j0: int = maxi(_cell(minf(a.z, minf(b.z, c.z))), 0)
	var j1: int = mini(_cell(maxf(a.z, maxf(b.z, c.z))), side - 1)
	for j: int in range(j0, j1 + 1):
		for i: int in range(i0, i1 + 1):
			var px: float = centre_of(i)
			var pz: float = centre_of(j)
			var u: float = ((b.x - px) * (c.z - pz) - (c.x - px) * (b.z - pz)) / area
			var v: float = ((c.x - px) * (a.z - pz) - (a.x - px) * (c.z - pz)) / area
			var w: float = 1.0 - u - v
			if u < 0.0 or v < 0.0 or w < 0.0:
				continue
			var y: float = u * a.y + v * b.y + w * c.y
			if y <= CAP_M and y > heights[j * side + i]:
				heights[j * side + i] = y


func _cell(x: float) -> int:
	"""The cell index a tree-local coordinate falls in (may be off the grid)."""
	return floori((x + reach_m) / CELL_M)


func centre_of(i: int) -> float:
	"""The tree-local coordinate of cell `i`'s centre."""
	return -reach_m + (float(i) + 0.5) * CELL_M


func _cover_obstacles(trunk_radius: float) -> void:
	"""The flare circle, then greedy circles over the proud cells it leaves: the proudest first (see
	ROOT OBSTACLES)."""
	obstacles.clear()
	var proud: Array = []
	var flare: float = trunk_radius
	for k: int in heights.size():
		var d: float = _cell_at(k).length()
		if heights[k] > OBSTACLE_M and d > trunk_radius:
			proud.append(k)
			if d <= trunk_radius + FLARE_BAND_M:
				flare = maxf(flare, d + CELL_M * 0.5)
	if flare > trunk_radius:
		obstacles.append(Vector3(0.0, 0.0, flare))
	proud.sort_custom(func(p: int, q: int) -> bool: return heights[p] > heights[q])
	for k: int in proud:
		var at: Vector2 = _cell_at(k)
		if obstacles.size() < MAX_OBSTACLES and not _covered(at):
			obstacles.append(Vector3(at.x, at.y, OBSTACLE_RADIUS_M))


func _cell_at(k: int) -> Vector2:
	"""Cell `k`'s centre in tree-local metres (x, z)."""
	return Vector2(centre_of(k % side), centre_of(k / side))


func _covered(at: Vector2) -> bool:
	"""Whether a cell centre lies inside an obstacle circle already placed."""
	for circle: Vector3 in obstacles:
		if Vector2(circle.x, circle.y).distance_to(at) <= circle.z:
			return true
	return false


func height_local(p: Vector2) -> float:
	"""The support height (m, size 1) under tree-local point `p`: bilinear between cell centres, 0 off
	the grid."""
	if side == 0:
		return 0.0
	var fx: float = (p.x + reach_m) / CELL_M - 0.5
	var fz: float = (p.y + reach_m) / CELL_M - 0.5
	if fx < -0.5 or fz < -0.5 or fx > float(side) - 0.5 or fz > float(side) - 0.5:
		return 0.0
	var i: int = clampi(floori(fx), 0, side - 2)
	var j: int = clampi(floori(fz), 0, side - 2)
	var tx: float = clampf(fx - float(i), 0.0, 1.0)
	var tz: float = clampf(fz - float(j), 0.0, 1.0)
	var near: float = lerpf(heights[j * side + i], heights[j * side + i + 1], tx)
	var far: float = lerpf(heights[(j + 1) * side + i], heights[(j + 1) * side + i + 1], tx)
	return lerpf(near, far, tz)


static func to_local(at: Vector2, tree_at: Vector2, yaw: float, size: float) -> Vector2:
	"""World ground point `at` in a tree's local metres at size 1: undo its position, its yaw (the world
	turns a model by Basis(UP, yaw)) and its size."""
	var d: Vector2 = at - tree_at
	var c: float = cos(yaw)
	var s: float = sin(yaw)
	return Vector2(c * d.x - s * d.y, s * d.x + c * d.y) / maxf(size, 0.001)


static func to_world(local: Vector2, tree_at: Vector2, yaw: float, size: float) -> Vector2:
	"""The inverse of `to_local`: a tree-local point (size 1) on the world's ground."""
	var c: float = cos(yaw)
	var s: float = sin(yaw)
	var p: Vector2 = local * size
	return tree_at + Vector2(c * p.x + s * p.y, -s * p.x + c * p.y)


func height_at(at: Vector2, tree_at: Vector2, yaw: float, size: float) -> float:
	"""The support height (m above the ground) at world point `at` under a tree standing at `tree_at`,
	turned by `yaw`, drawn at `size`."""
	return height_local(to_local(at, tree_at, yaw, size)) * size


func obstacles_at(tree_at: Vector2, yaw: float, size: float) -> Array[Vector3]:
	"""This model's root obstacles for a tree standing there, in the cast's public form (x, radius, z)."""
	var out: Array[Vector3] = []
	for circle: Vector3 in obstacles:
		var p: Vector2 = to_world(Vector2(circle.x, circle.y), tree_at, yaw, size)
		out.append(Vector3(p.x, circle.z * size, p.y))
	return out


static func faces_of(piece: Node3D, standing: Transform3D, yaw: float, size: float) -> PackedVector3Array:
	"""Every triangle a placed tree piece draws standing at `standing` (its full-size transform), in
	tree-local metres at size 1: its position across the ground, its yaw and its size taken off (the
	sink is kept)."""
	var root: Transform3D = standing
	root.origin = Vector3(0.0, root.origin.y, 0.0)
	var unturn := Transform3D(Basis(Vector3.UP, -yaw).scaled(Vector3.ONE / maxf(size, 0.001)), Vector3.ZERO)
	var out := PackedVector3Array()
	var start: Transform3D = unturn * root
	_collect_mesh(piece, start, out)
	for child: Node in piece.get_children():
		var child_3d := child as Node3D
		_collect(child, start * child_3d.transform if child_3d != null else start, out)
	return out


static func _collect(node: Node, xform: Transform3D, out: PackedVector3Array) -> void:
	"""Append `node`'s mesh triangles (and its children's) through `xform`."""
	_collect_mesh(node, xform, out)
	for child: Node in node.get_children():
		var child_3d := child as Node3D
		_collect(child, xform * child_3d.transform if child_3d != null else xform, out)


static func _collect_mesh(node: Node, xform: Transform3D, out: PackedVector3Array) -> void:
	"""Append `node`'s own mesh triangles through `xform` (none unless it is a MeshInstance3D)."""
	var mesh_node := node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		for v: Vector3 in mesh_node.mesh.get_faces():
			out.append(xform * v)


static func baked(piece: Node3D, standing: Transform3D, yaw: float, size: float, reach: float,
		trunk_radius: float) -> Self:
	"""A field baked from a placed tree piece standing at `standing` (see `faces_of`, `bake`)."""
	var field: Self = Self.new()
	field.bake(faces_of(piece, standing, yaw, size), reach, trunk_radius)
	return field


static func root_obstacles(trees: Array[Dictionary], node_of: Callable, reach: float) -> Array[Vector3]:
	"""The root obstacles (x, radius, z) of every staged oak and beech placement (`trees`: the world's
	trees() order; `node_of(i)`: its node) within `reach` of the square (Chebyshev), one field baked per
	model. None for a placeholder tree: it has no roots."""
	var fields: Array[Self] = []
	fields.resize(StandScript.LOOK_KEYS.size())
	var out: Array[Vector3] = []
	for i: int in trees.size():
		var p: Dictionary = trees[i]
		var look: int = StandScript.LOOK_KEYS.find(p["key"])
		var at: Vector2 = p["at"]
		var node: Node3D = node_of.call(i) as Node3D
		if look < 0 or absf(at.x) > reach or absf(at.y) > reach or node == null or String(node.name).begins_with("Placeholder"):
			continue
		if fields[look] == null:
			fields[look] = baked(node, node.transform, float(p["yaw"]), float(p["size"]), Roots.reach_m(look, 1.0),
				float(Layout.TRUNK_RADIUS_M[p["key"]]))
		out.append_array(fields[look].obstacles_at(at, float(p["yaw"]), float(p["size"])))
	return out

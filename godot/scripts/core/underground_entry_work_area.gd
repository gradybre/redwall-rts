extends RefCounted
## ADR1197 G1: runtime publication of the ADR1191 first-entry work area (9 Locations, 28 directed paths).
## Geometry is the accepted focus-4 work area relative to the entry origin; SurfaceAnchor and WorldRoutes keep
## every terrain, air, footing and profile proof. This publishes no Room, Site, Job or permission.

const Anchor := preload("res://scripts/core/underground_surface_anchor.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const ENDPOINTS: int = 9
const STORAGE: Array[int] = [1, 2]
const WORK: Array[int] = [0, 3, 4, 5, 6, 7, 8]
const GATEWAY_X: int = 2560
const GATEWAY_Z: int = 1536
const H_AIR: Array[int] = [-445, 0, -732, 910, 1036, 346]
const H_FOOT: Array[int] = [-274, -1, -274, 299, 0, 249]
const H_METADATA: Array[int] = [-4096, 0, -5120, 4096, 1, 4096]
const STORAGE_AIR: Array[int] = [-3816, 0, 280, 3816, 1036, 3304]
const STORAGE_FOOT: Array[int] = [-2966, -1, 238, 2966, 0, 2454]
const LEFT_PAIR_AIR: Array[int] = [-3816, 0, -3816, -280, 1422, 2792]
const RIGHT_PAIR_AIR: Array[int] = [280, 0, -3816, 3816, 1422, 2792]
const CUT_AIR: Array[int] = [-1256, 0, -1256, 1256, 1422, 1256]
const LEFT_FOOT: Array[int] = [-2966, -1, -4096, -1130, 0, 2454]
const RIGHT_FOOT: Array[int] = [1130, -1, -4096, 2966, 0, 2454]


class Published extends RefCounted:
	## Exact handles of the nine endpoints (0 H, 1 M, 2 R, 3-8 cut stations) and their shared section.
	var section: Vector2i = NULL_REF
	var endpoints: Array[Vector2i] = []


static func point(origin: Vector3i, index: int) -> Vector3i:
	"""Authored source points: H, material M, output R, then six cut stations at -/+1536."""
	if index == 0: return origin + Vector3i(-832, 0, 512)
	if index == 1: return origin + Vector3i(-832, 0, 2048)
	if index == 2: return origin + Vector3i(-832, 0, 1536)
	@warning_ignore("integer_division")
	return origin + Vector3i(-1536 if index % 2 == 1 else 1536, 0, -512 - ((index - 3) / 2) * 1024)


static func publish_locations(anchor: Anchor, origin: Vector3i, out: Published) -> StringName:
	"""H opens the shared surface section; every other endpoint joins it with its own complete survey."""
	if anchor == null or out == null: return &"ENTRY_WORK_AREA_OWNER"
	out.endpoints.clear()
	var created: Anchor.Result = anchor.create(point(origin, 0), _offset(H_AIR, point(origin, 0)),
		_offset(H_FOOT, point(origin, 0)), Locations.ROLE_WORK, _offset(H_METADATA, origin))
	if created.error != &"": return created.error
	out.section = created.section
	out.endpoints.append(created.location)
	for index: int in range(1, ENDPOINTS):
		var role: int = Locations.ROLE_STORAGE if index < 3 else Locations.ROLE_WORK
		var added: Anchor.Result = anchor.create_in_section(point(origin, index), _air(origin, index),
			_foot(origin, index), out.section, role)
		if added.error != &"": return added.error
		out.endpoints.append(added.location)
	return &""


static func _air(origin: Vector3i, index: int) -> PackedInt32Array:
	"""Storage and the first pair survey their outer corridors; later cut stations their full stroke air."""
	if index < 3: return _offset(STORAGE_AIR, origin)
	if index == 3: return _offset(LEFT_PAIR_AIR, origin)
	if index == 4: return _offset(RIGHT_PAIR_AIR, origin)
	return _offset(CUT_AIR, point(origin, index))


static func _foot(origin: Vector3i, index: int) -> PackedInt32Array:
	"""Ground footing strips lie outside all six canonical cut identities."""
	if index < 3: return _offset(STORAGE_FOOT, origin)
	return _offset(LEFT_FOOT if index % 2 == 1 else RIGHT_FOOT, origin)


static func _offset(box: Array[int], at: Vector3i) -> PackedInt32Array:
	"""Integer translation only."""
	return PackedInt32Array([box[0] + at.x, box[1] + at.y, box[2] + at.z, box[3] + at.x, box[4] + at.y, box[5] + at.z])


static func publish_paths(binding: WorldRoutes, routes: Routes, budget: Budget, owner: RefCounted,
		origin: Vector3i, published: Published, content_revision: int) -> StringName:
	"""Both directions between each storage endpoint and each work endpoint, sealed and published once."""
	var lease: int = budget.acquire(Budget.COLD_BYTES)
	if lease <= 0: return &"ENTRY_WORK_AREA_LEASE"
	var begun: Routes.Result = binding.begin_prepare(lease)
	var code: StringName = begun.error
	for storage: int in STORAGE:
		for work: int in WORK:
			if code == &"": code = routes.stage_add(begun.token, _edge(origin, published, storage, work, owner, content_revision)).error
			if code == &"": code = routes.stage_add(begun.token, _edge(origin, published, work, storage, owner, content_revision)).error
	if code == &"": code = binding.seal(begun.token)
	if code == &"": code = binding.publish(begun.token)
	binding.abort(begun.token)
	budget.release(lease)
	return code


static func _edge(origin: Vector3i, published: Published, first: int, last: int, owner: RefCounted,
		content_revision: int) -> Routes.Edge:
	"""One walking polyline: direct between H and storage, outside the gateways for every cut station."""
	var edge: Routes.Edge = Routes.Edge.new()
	edge.from_location = published.endpoints[first]
	edge.to_location = published.endpoints[last]
	edge.section = published.section
	edge.level = 0; edge.family = -1; edge.variant = 0
	edge.mode = Profiles.MODE_WALK; edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = content_revision
	edge.geometry_revision = owner.revision()
	var points: Array[Vector3i] = _perimeter(origin, first, last)
	for at: Vector3i in points: edge.points.append_array(PackedInt32Array([at.x, at.y, at.z]))
	edge.point_count = points.size()
	for i: int in range(1, points.size()):
		edge.length_u += absi(points[i].x - points[i - 1].x) + absi(points[i].z - points[i - 1].z)
	return edge


static func _perimeter(origin: Vector3i, first: int, last: int) -> Array[Vector3i]:
	"""Same-heading H approach has no invented turn; every cut path bends only on surveyed outer ground."""
	if first < 3 and last < 3: return [point(origin, first), point(origin, last)]
	var work: int = first if first >= 3 else last
	var storage: int = last if first >= 3 else first
	var root: Vector3i = point(origin, work)
	var start: Vector3i = point(origin, storage)
	var side: int = origin.x + (-GATEWAY_X if work % 2 == 1 else GATEWAY_X)
	var result: Array[Vector3i] = [start]
	var near: Vector3i = Vector3i(start.x, origin.y, origin.z + GATEWAY_Z)
	if near != start: result.append(near)
	result.append(Vector3i(side, origin.y, near.z))
	result.append(Vector3i(side, origin.y, root.z))
	result.append(root)
	if first >= 3: result.reverse()
	return result

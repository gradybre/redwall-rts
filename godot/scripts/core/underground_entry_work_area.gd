extends RefCounted
## ADR1197 G1: runtime publication of the ADR1191 first-entry work area (11 Locations, 36 directed paths).
## Geometry is the accepted focus-4 work area relative to the entry origin; SurfaceAnchor and WorldRoutes keep
## every terrain, air, footing and profile proof. This publishes no Room, Site, Job or permission.
## ADR1198 step 5 appends two haul stands beside M and R (indices 9, 10); the first nine keep their indices.
## ADR1217 step 5 (the claw bundle `qualified-claw-v6`): the six cut stations stand at x = -/+1430 (Brendan, step 1:
## 106 u in from 1536, so the tool-free stance edge lands on the dig area's edge at |x| = 1024), and H's surveyed air
## and footing are exactly the claw endpoint certificate's words (rows 43/47/52/59), which it compares for equality.
## ADR1229 (the T1-T6 bundle `qualified-stairs-v8`): eight more cut stations (indices 11-18) for the cube rows 4-7 the
## descent cuts (ADR 1209 D2), at the same +-1430 and row centres; the outer footing, pair air and the section reach
## the seventh row by the rule they were sized with (footing one cube past the last row, pair air 280 u inside it).

const Anchor := preload("res://scripts/core/underground_surface_anchor.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const ENDPOINTS: int = 19
## ADR1229: the descent cuts seven cube rows (rows 0-2 for L0/T0, rows 3-6 for T2-T6 and the stair foot).
const CUT_ROWS: int = 7
const FIRST_DEEP_STATION: int = 11
const STORAGE: Array[int] = [1, 2]
const WORK: Array[int] = [0, 3, 4, 5, 6, 7, 8]
## ADR1229: every Space phase and installation requalifies every live path inside one Space.MAX_CHECKS bound, which
## holds the first-entry work area's paths but not twice as many. So the descent's eight cut stations get their
## paths only when the first of them is about to be worked (T0 installed), in the same preparation that retires the
## paths of the four T0 cut stations, whose work is then done (L0's START retired the first pair, ADR1191). They are
## joined to M only: their inputs come from M, the spoil goes to R's container without a walk, and every
## station-to-station leg runs through M.
const DEEP_WORK: Array[int] = [11, 12, 13, 14, 15, 16, 17, 18]
const DEEP_STORAGE: Array[int] = [1]
const DONE_WORK: Array[int] = [5, 6, 7, 8]
const STAND_M: int = 9
const STAND_R: int = 10
## Stand = stock point + the content-5 grip offset R-S at yaw 16384: (0,0,576) turned a quarter is (576,0,0),
## so the worker at the stand faces -X onto the stock resting exactly on the storage point (ADR1198/1200).
const STAND_OFFSET: Vector3i = Vector3i(576, 0, 0)
const STAND_YAW: int = 16384
## Union of every floor box the stand must carry, relative to the stand: content-5 rows 30-32 (all-yaw stance and
## foot residual, x/z +-406) and rows 34/36 (stance, foot residual and the stock's floor contact at S, x -579..-573).
const STAND_FOOT: Array[int] = [-579, -1, -412, 406, 0, 412]
## ADR1198 step 5 haul edges (from, to, mode): the full symmetric set (ADR1205). Each storage endpoint and its
## stand are joined both ways over WALK, the stands both ways over CARRY (loaded) and WALK (empty), so a return
## trip walks stand M -> stand R directly instead of via H. ADR1205's incremental requalification keeps the entry
## confirmation's cost to the edges a change actually meets; the first three keep their original order.
const HAUL_EDGES: Array[Vector3i] = [
	Vector3i(2, STAND_R, Profiles.MODE_WALK),
	Vector3i(STAND_R, STAND_M, Profiles.MODE_CARRY),
	Vector3i(STAND_M, 1, Profiles.MODE_WALK),
	Vector3i(STAND_R, 2, Profiles.MODE_WALK),
	Vector3i(1, STAND_M, Profiles.MODE_WALK),
	Vector3i(STAND_M, STAND_R, Profiles.MODE_CARRY),
	Vector3i(STAND_M, STAND_R, Profiles.MODE_WALK),
	Vector3i(STAND_R, STAND_M, Profiles.MODE_WALK),
]
const GATEWAY_X: int = 2560
const GATEWAY_Z: int = 1536
const CUT_X: int = 1430
const H_AIR: Array[int] = [-485, 0, -578, 479, 930, 412]
const H_FOOT: Array[int] = [-276, -1, -274, 299, 0, 249]
const H_METADATA: Array[int] = [-4096, 0, -1024 * (CUT_ROWS + 2), 4096, 1, 4096]
const STORAGE_AIR: Array[int] = [-3816, 0, 280, 3816, 1036, 3304]
const STORAGE_FOOT: Array[int] = [-2966, -1, 238, 2966, 0, 2454]
const LEFT_PAIR_AIR: Array[int] = [-3816, 0, 280 - 1024 * (CUT_ROWS + 1), -280, 1422, 2792]
const RIGHT_PAIR_AIR: Array[int] = [280, 0, 280 - 1024 * (CUT_ROWS + 1), 3816, 1422, 2792]
## ADR1217 step 5: a cut station's air is the claw WALK 42's all-yaw body and turn sweep, which holds every box of
## the claw dig rows above the floor. The pick's +/-1256 (its held tool) would now reach 174 u from the entry axis,
## into the pending T0 bearer (x +/-256), because the stations stand 106 u nearer.
const CUT_AIR: Array[int] = [-712, 0, -712, 712, 930, 712]
const LEFT_FOOT: Array[int] = [-2966, -1, -1024 * (CUT_ROWS + 1), -1024, 0, 2454]
const RIGHT_FOOT: Array[int] = [1024, -1, -1024 * (CUT_ROWS + 1), 2966, 0, 2454]


class Published extends RefCounted:
	## Exact handles of the endpoints (0 H, 1 M, 2 R, 3-8 cut stations, 9/10 haul stands) and their section.
	var section: Vector2i = NULL_REF
	var endpoints: Array[Vector2i] = []


static func point(origin: Vector3i, index: int) -> Vector3i:
	"""Authored source points: H, material M, output R, six cut stations at -/+1430, then the M and R stands."""
	if index == 0: return origin + Vector3i(-832, 0, 512)
	if index == 1: return origin + Vector3i(-832, 0, 2048)
	if index == 2: return origin + Vector3i(-832, 0, 1536)
	if index == STAND_M or index == STAND_R: return point(origin, stock_of(index)) + STAND_OFFSET
	var ordinal: int = index - 3 if index < STAND_M else index - FIRST_DEEP_STATION + 6
	@warning_ignore("integer_division")
	return origin + Vector3i(-CUT_X if ordinal % 2 == 0 else CUT_X, 0, -512 - (ordinal / 2) * 1024)


static func _is_stand(index: int) -> bool:
	"""The two haul stands (9 beside M, 10 beside R)."""
	return index == STAND_M or index == STAND_R


static func stock_of(stand: int) -> int:
	"""The storage endpoint whose stock point a haul stand faces: M for stand 9, R for stand 10."""
	return 1 if stand == STAND_M else 2


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
		var role: int = Locations.ROLE_STORAGE if index == 1 or index == 2 else Locations.ROLE_WORK
		var added: Anchor.Result = anchor.create_in_section(point(origin, index), air(origin, index),
			foot(origin, index), out.section, role)
		if added.error != &"": return added.error
		out.endpoints.append(added.location)
	return &""


static func air(origin: Vector3i, index: int) -> PackedInt32Array:
	"""Storage, stands and the first pair survey their outer corridors; later cut stations their full stroke air."""
	if index == 0: return _offset(H_AIR, point(origin, 0))
	if index < 3 or index == STAND_M or index == STAND_R: return _offset(STORAGE_AIR, origin)
	if index == 3: return _offset(LEFT_PAIR_AIR, origin)
	if index == 4: return _offset(RIGHT_PAIR_AIR, origin)
	return _offset(CUT_AIR, point(origin, index))


static func foot(origin: Vector3i, index: int) -> PackedInt32Array:
	"""Ground footing strips lie outside all six canonical cut identities; a stand carries its own floor and S."""
	if index == 0: return _offset(H_FOOT, point(origin, 0))
	if index == STAND_M or index == STAND_R: return _offset(STAND_FOOT, point(origin, index))
	if index < 3: return _offset(STORAGE_FOOT, origin)
	return _offset(LEFT_FOOT if point(origin, index).x < origin.x else RIGHT_FOOT, origin)


static func _offset(box: Array[int], at: Vector3i) -> PackedInt32Array:
	"""Integer translation only."""
	return PackedInt32Array([box[0] + at.x, box[1] + at.y, box[2] + at.z, box[3] + at.x, box[4] + at.y, box[5] + at.z])


static func publish_paths(binding: WorldRoutes, routes: Routes, budget: Budget, owner: RefCounted,
		origin: Vector3i, published: Published, content_revision: int) -> StringName:
	"""Both directions between each storage and work endpoint plus the haul stands, sealed and published once; the
	descent's stations wait for open_deep_paths."""
	var lease: int = budget.acquire(Budget.COLD_BYTES)
	if lease <= 0: return &"ENTRY_WORK_AREA_LEASE"
	var begun: Routes.Result = binding.begin_prepare(lease)
	var code: StringName = _stage_pairs(routes, begun.token, origin, published, owner, content_revision, STORAGE, WORK) \
		if begun.error == &"" else begun.error
	for pair: Vector3i in HAUL_EDGES:
		if code == &"": code = routes.stage_add(begun.token, _edge(origin, published, pair.x, pair.y, owner, content_revision, pair.z)).error
	return _finish_batch(binding, budget, lease, begun.token, code)


static func open_deep_paths(binding: WorldRoutes, routes: Routes, budget: Budget, owner: RefCounted,
		origin: Vector3i, published: Published, content_revision: int) -> StringName:
	"""ADR1229: retire every path of the done T0 cut stations, then join M to each descent station both ways."""
	var lease: int = budget.acquire(Budget.COLD_BYTES)
	if lease <= 0: return &"ENTRY_WORK_AREA_LEASE"
	var begun: Routes.Result = binding.begin_prepare(lease)
	var code: StringName = _stage_retirements(routes, begun.token, published) if begun.error == &"" else begun.error
	if code == &"":
		code = _stage_pairs(routes, begun.token, origin, published, owner, content_revision, DEEP_STORAGE, DEEP_WORK)
	return _finish_batch(binding, budget, lease, begun.token, code)


static func deep_paths_open(routes: Routes, published: Published) -> bool:
	"""Whether M already has its path to the first descent station (open_deep_paths ran)."""
	var edge: Routes.Edge = Routes.Edge.new()
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		if routes.edge_metadata_into(Vector2i(row, routes._live.fields[Routes.E_GENERATION * routes._edge_capacity + row]),
				edge) != &"": continue
		if edge.from_location == published.endpoints[STORAGE[0]] and edge.to_location == published.endpoints[DEEP_WORK[0]]:
			return true
	return false


static func is_deep_station(published: Published, station: Vector2i) -> bool:
	"""A descent cut station's handle (endpoints 11-18)."""
	for index: int in DEEP_WORK:
		if published.endpoints.size() > index and published.endpoints[index] == station: return true
	return false


static func _stage_pairs(routes: Routes, token: int, origin: Vector3i, published: Published, owner: RefCounted,
		content_revision: int, storages: Array[int], works: Array[int]) -> StringName:
	"""Each storage <-> work pair, both ways, on the perimeter polyline."""
	for storage: int in storages:
		for work: int in works:
			var code: StringName = routes.stage_add(token, _edge(origin, published, storage, work, owner, content_revision)).error
			if code == &"": code = routes.stage_add(token, _edge(origin, published, work, storage, owner, content_revision)).error
			if code != &"": return code
	return &""


static func _stage_retirements(routes: Routes, token: int, published: Published) -> StringName:
	"""Remove every live path that starts or ends at one of the done T0 cut stations."""
	var edge: Routes.Edge = Routes.Edge.new()
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, routes._live.fields[Routes.E_GENERATION * routes._edge_capacity + row])
		var code: StringName = routes.edge_metadata_into(ref, edge)
		if code == &"" and (_done_station(published, edge.from_location) or _done_station(published, edge.to_location)):
			code = routes.stage_remove(token, ref)
		if code != &"": return code
	return &""


static func _done_station(published: Published, location: Vector2i) -> bool:
	"""One of the four T0 cut stations."""
	for index: int in DONE_WORK:
		if published.endpoints[index] == location: return true
	return false


static func _finish_batch(binding: WorldRoutes, budget: Budget, lease: int, token: int, staged: StringName) -> StringName:
	"""Seal and publish a staged preparation, or abort it; the lease is returned either way."""
	var code: StringName = staged
	if code == &"": code = binding.seal(token)
	if code == &"": code = binding.publish(token)
	binding.abort(token)
	budget.release(lease)
	return code


static func _edge(origin: Vector3i, published: Published, first: int, last: int, owner: RefCounted,
		content_revision: int, mode: int = Profiles.MODE_WALK) -> Routes.Edge:
	"""One ground polyline: direct between H, storage and stands, outside the gateways for every cut station."""
	var edge: Routes.Edge = Routes.Edge.new()
	edge.from_location = published.endpoints[first]
	edge.to_location = published.endpoints[last]
	edge.section = published.section
	edge.level = 0; edge.family = -1; edge.variant = 0
	edge.mode = mode; edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = content_revision
	edge.geometry_revision = owner.revision()
	var points: Array[Vector3i] = _carry_approach(origin, first, last) if mode == Profiles.MODE_CARRY \
		else _perimeter(origin, first, last)
	for at: Vector3i in points: edge.points.append_array(PackedInt32Array([at.x, at.y, at.z]))
	edge.point_count = points.size()
	for i: int in range(1, points.size()):
		edge.length_u += absi(points[i].x - points[i - 1].x) + absi(points[i].z - points[i - 1].z)
	return edge


static func _carry_approach(origin: Vector3i, first: int, last: int) -> Array[Vector3i]:
	"""A loaded worker cannot turn in place (ground turns admit STAND/WALK only, and no loaded turn is authored), so
	the CARRY edge arrives already on the grip heading: it steps out by the stand offset on +X, runs along, and enters
	the destination stand moving -X (yaw 16384)."""
	var start: Vector3i = point(origin, first)
	var stand: Vector3i = point(origin, last)
	return [start, start + STAND_OFFSET, stand + STAND_OFFSET, stand]


static func _perimeter(origin: Vector3i, first: int, last: int) -> Array[Vector3i]:
	"""Same-heading H approach has no invented turn; every cut path bends only on surveyed outer ground."""
	if (first < 3 and last < 3) or _is_stand(first) or _is_stand(last): return [point(origin, first), point(origin, last)]
	var work: int = first if first >= 3 else last
	var storage: int = last if first >= 3 else first
	var root: Vector3i = point(origin, work)
	var start: Vector3i = point(origin, storage)
	var side: int = origin.x + (-GATEWAY_X if point(origin, work).x < origin.x else GATEWAY_X)
	var result: Array[Vector3i] = [start]
	var near: Vector3i = Vector3i(start.x, origin.y, origin.z + GATEWAY_Z)
	if near != start: result.append(near)
	result.append(Vector3i(side, origin.y, near.z))
	result.append(Vector3i(side, origin.y, root.z))
	result.append(root)
	if first >= 3: result.reverse()
	return result

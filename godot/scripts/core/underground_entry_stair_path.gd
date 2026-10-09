extends RefCounted
## ADR1229: the descent's stair edges between the installed stair stops, and the retraction of the one stop a pending
## tread bearer covers. Stateless: every call reads the live Locations and Routes it is handed.
## The stops (all INSTALLED_CONTACT Locations of the T1-T6 bundle, in its source frame) are:
## - X, the crossing arrival on L0 (0, 0, -664), the way between M and the stair;
## - on L0, P (310 u behind its far edge, the walk-in stop), A (169, the descent's start) and U (343, the ascent's end);
## - on each standing tread T_j, A (169, a descent's arrival and the half-turn's start), S (310, the tread station of
##   T_{j+1}) and U (343, the half-turn's end and the ascent's start).
## Its edges are each approved motion over exactly its span (ADR 1209, DEC-050): X->P on the narrow approach,
## P->A(L0) and S->A on the step forward, A->S on the step back, A(j-1)->A(j) on the descent, A->U on the half-turn,
## U(j)->U(j-1) on the ascent and U(L0)->X on the yaw-32768 approach. WorldRoutes decides which rows each edge admits.

const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Tread := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/tread_geometry.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const LEVELS: int = Tread.TREADS + 1 # L0 (level -1) and T0..T5 carry stops; the sill carries none.
const CROSSING_Z: int = -664
const REFUSE_LEASE: StringName = &"ENTRY_STAIR_PATH_LEASE"
const REFUSE_OWNER: StringName = &"ENTRY_STAIR_PATH_OWNER"
## Edge kinds in Stops.edges: [from kind, from level, to kind, to level, family].
const KIND_X: int = 0
const KIND_P: int = 1
const KIND_A: int = 2
const KIND_S: int = 3
const KIND_U: int = 4


class Stops extends RefCounted:
	## Live stop handles by kind and level index (level + 1); NULL_REF where the stop is not (yet) live.
	var x: Vector2i = NULL_REF
	var p: Vector2i = NULL_REF
	var a: Array[Vector2i] = []
	var s: Array[Vector2i] = []
	var u: Array[Vector2i] = []

	func _init() -> void:
		"""Every level starts absent."""
		for index: int in LEVELS:
			a.append(NULL_REF)
			s.append(NULL_REF)
			u.append(NULL_REF)

	func at(kind: int, level: int) -> Vector2i:
		"""One stop handle, or NULL_REF."""
		if kind == KIND_X: return x
		if kind == KIND_P: return p
		if level < -1 or level >= LEVELS - 1: return NULL_REF
		return a[level + 1] if kind == KIND_A else (s[level + 1] if kind == KIND_S else u[level + 1])


static func classify(point: Vector3i) -> Vector2i:
	"""(kind, level) of a source-local stop point, or (-1, 0) for any other point."""
	if point.x != 0: return Vector2i(-1, 0)
	if point.y == 0 and point.z == CROSSING_Z: return Vector2i(KIND_X, -1)
	if point.y > 0 or point.y % Tread.RISE != 0: return Vector2i(-1, 0)
	@warning_ignore("integer_division") var level: int = -point.y / Tread.RISE - 1
	if level >= LEVELS - 1: return Vector2i(-1, 0)
	var behind: int = point.z - Tread.far_z(level)
	if behind == Tread.ARRIVAL: return Vector2i(KIND_A, level)
	if behind == Tread.ASCENT_START: return Vector2i(KIND_U, level)
	if behind == Tread.STATION: return Vector2i(KIND_P if level < 0 else KIND_S, level)
	return Vector2i(-1, 0)


static func record(stops: Stops, kind_level: Vector2i, handle: Vector2i) -> void:
	"""File one live stop under its kind and level."""
	match kind_level.x:
		KIND_X: stops.x = handle
		KIND_P: stops.p = handle
		KIND_A: stops.a[kind_level.y + 1] = handle
		KIND_S: stops.s[kind_level.y + 1] = handle
		KIND_U: stops.u[kind_level.y + 1] = handle


static func edge_plan() -> PackedInt32Array:
	"""Every stair edge as [from kind, from level, to kind, to level, family], in a fixed order."""
	var out: PackedInt32Array = PackedInt32Array([KIND_X, -1, KIND_P, -1, -1, KIND_P, -1, KIND_A, -1, -1,
		KIND_U, -1, KIND_X, -1, -1])
	for level: int in LEVELS - 1:
		out.append_array(PackedInt32Array([KIND_A, level - 1, KIND_A, level, 0, KIND_A, level, KIND_S, level, -1,
			KIND_S, level, KIND_A, level, -1, KIND_A, level, KIND_U, level, 0, KIND_U, level, KIND_U, level - 1, 0]))
	return out


static func publish(binding: WorldRoutes, routes: Routes, budget: Budget, owner: RefCounted, locations: Locations,
		stops: Stops, content_revision: int) -> StringName:
	"""Stage every planned edge whose two stops are live and which no live edge already joins, then seal and
	publish them once; nothing is staged when every edge exists."""
	if binding == null or routes == null or budget == null or owner == null or locations == null or stops == null:
		return REFUSE_OWNER
	var plan: PackedInt32Array = edge_plan()
	if _missing_count(routes, stops, plan) == 0: return &""
	var lease: int = budget.acquire(Budget.COLD_BYTES)
	if lease <= 0: return REFUSE_LEASE
	var begun: Routes.Result = binding.begin_prepare(lease)
	var code: StringName = begun.error
	for at: int in range(0, plan.size(), 5):
		if code != &"": break
		var first: Vector2i = stops.at(plan[at], plan[at + 1])
		var last: Vector2i = stops.at(plan[at + 2], plan[at + 3])
		if first == NULL_REF or last == NULL_REF or _joined(routes, first, last): continue
		code = _stage_edge(routes, begun.token, locations, owner, [first, last], plan[at + 4], content_revision)
	if code == &"": code = binding.seal(begun.token)
	if code == &"": code = binding.publish(begun.token)
	binding.abort(begun.token)
	budget.release(lease)
	return code


static func _missing_count(routes: Routes, stops: Stops, plan: PackedInt32Array) -> int:
	"""Planned edges with both stops live and no live edge between them."""
	var count: int = 0
	for at: int in range(0, plan.size(), 5):
		var first: Vector2i = stops.at(plan[at], plan[at + 1])
		var last: Vector2i = stops.at(plan[at + 2], plan[at + 3])
		if first != NULL_REF and last != NULL_REF and not _joined(routes, first, last): count += 1
	return count


static func _joined(routes: Routes, first: Vector2i, last: Vector2i) -> bool:
	"""Whether a live edge already runs from `first` to `last`."""
	var edge: Routes.Edge = Routes.Edge.new()
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		if routes.edge_metadata_into(Vector2i(row, routes._live.fields[Routes.E_GENERATION * routes._edge_capacity + row]),
				edge) == &"" and edge.from_location == first and edge.to_location == last:
			return true
	return false


static func _stage_edge(routes: Routes, token: int, locations: Locations, owner: RefCounted, ends: Array[Vector2i],
		family: int, content_revision: int) -> StringName:
	"""One straight two-point span in its start stop's section, Room and level."""
	var first: Locations.Record = _record(locations, ends[0])
	var last: Locations.Record = _record(locations, ends[1])
	if first == null or last == null: return REFUSE_OWNER
	var edge: Routes.Edge = Routes.Edge.new()
	edge.from_location = ends[0]
	edge.to_location = ends[1]
	edge.section = first.section
	edge.room = first.room
	edge.level = first.level; edge.family = family; edge.variant = 0
	edge.mode = Profiles.MODE_WALK; edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = content_revision
	edge.geometry_revision = owner.revision()
	edge.point_count = 2
	edge.points = PackedInt32Array([first.point.x, first.point.y, first.point.z, last.point.x, last.point.y, last.point.z])
	edge.length_u = Routes._segment_length(first.point, last.point)
	return routes.stage_add(token, edge).error


static func _record(locations: Locations, ref: Vector2i) -> Locations.Record:
	"""One complete live Location record, or null."""
	var out: Locations.Record = Locations.Record.new()
	out.envelope.resize(6)
	out.support.resize(6)
	return out if locations.read_location_into(ref, out) == &"" else null


static func retract(binding: WorldRoutes, routes: Routes, locations: Locations, budget: Budget,
		stop: Vector2i) -> StringName:
	"""Remove every live edge that starts or ends at `stop`, publish, then remove the stop itself: a pending tread
	bearer is staged where it stands (ADR 1209 step 5). The bundle re-creates it when that tread commits."""
	if binding == null or routes == null or locations == null or budget == null: return REFUSE_OWNER
	var lease: int = budget.acquire(Budget.COLD_BYTES)
	if lease <= 0: return REFUSE_LEASE
	var begun: Routes.Result = binding.begin_prepare(lease)
	var code: StringName = _stage_incident_removals(routes, begun.token, stop) if begun.error == &"" else begun.error
	if code == &"": code = binding.seal(begun.token)
	if code == &"": code = binding.publish(begun.token)
	binding.abort(begun.token)
	if code == &"": code = _remove_location(locations, lease, stop)
	budget.release(lease)
	return code


static func _stage_incident_removals(routes: Routes, token: int, stop: Vector2i) -> StringName:
	"""Every live edge touching the stop leaves the graph, and so does the ascent leaving the stop its half-turn
	reaches (U on the same tread): that climb starts with the body's tail over the staged bearer."""
	var turned: Vector2i = _turned_from(routes, stop)
	var edge: Routes.Edge = Routes.Edge.new()
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, routes._live.fields[Routes.E_GENERATION * routes._edge_capacity + row])
		var code: StringName = routes.edge_metadata_into(ref, edge)
		if code == &"" and (edge.from_location == stop or edge.to_location == stop
				or (turned != NULL_REF and edge.from_location == turned and edge.family == 0)):
			code = routes.stage_remove(token, ref)
		if code != &"": return code
	return &""


static func _turned_from(routes: Routes, stop: Vector2i) -> Vector2i:
	"""The stop a connector edge leads to from `stop` while the tread below is pending: only the half-turn can (the
	descent from it needs the stop below, which that tread's commit creates), or NULL_REF."""
	var edge: Routes.Edge = Routes.Edge.new()
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, routes._live.fields[Routes.E_GENERATION * routes._edge_capacity + row])
		if routes.edge_metadata_into(ref, edge) == &"" and edge.from_location == stop and edge.family == 0:
			return edge.to_location
	return NULL_REF


static func _remove_location(locations: Locations, lease: int, stop: Vector2i) -> StringName:
	"""The now-disconnected stop leaves the Locations bank in its own preparation."""
	var begun: Locations.Result = locations.begin_prepare(lease)
	var code: StringName = begun.error
	if code == &"": code = locations.stage_remove(begun.token, stop)
	if code == &"": code = locations.seal(begun.token)
	if code == &"" and not locations.publish(begun.token): code = &"ENTRY_STAIR_PATH_PUBLISH"
	if code != &"": locations.abort(begun.token)
	return code

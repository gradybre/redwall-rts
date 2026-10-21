extends RefCounted
## Decision 1936: a room builder's parking, off the access. A body standing on the access closes every later station
## chain (decision 1935), so each builder parks on a TRANSIT endpoint two or three cells from it along the access's
## own floor, away from the room, joined to it by two straight WALK spans (ADR1213 "Parking"). An endpoint already at
## the point is reused, so repeated digs never add endpoints there. Only the Locations and Routes public staging calls
## are used; their own proofs decide (air, footing, span certificates).
##
## Decision 1991 (review H-1): a second builder's parking had landed in the corridor between the access and the room,
## where its body stood on the first builder's way to the station (ROOM_FOREMAN_CREW_BLOCKED), or on another route's
## TRANSIT endpoint. A parking now never lies between the access and the room, and an existing endpoint is reused only
## when it is a parking (every span touching it runs to or from the access).

const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Itinerary := preload("res://scripts/core/underground_room_itinerary.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
## Parking is tried two and three Sites quanta (`Contract.QUANTUM_SIDE_U`) from the access: a layout choice, no rule.
const CELL_U: int = Contract.QUANTUM_SIDE_U
const REFUSE_NONE: StringName = &"ROOM_PARKING_NONE"
const DIRECTIONS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


class Request extends RefCounted:
	## The access endpoint, the travel rows (forward in, retreat out), the room's cells to keep clear (x0, z0, x1, z1)
	## and the parking already taken (by other builders) to skip.
	var access: Vector2i = NULL_REF
	var forward: int = -1
	var backward: int = -1
	var content: int = 0
	var room_box: PackedInt32Array = PackedInt32Array()
	var taken: Array[Vector2i] = []
	## Decision 1991 (review H-1): the locations of the room's containers, where the crew fetches and drops; never a
	## parking (a body parked there blocks every fetch: ROOM_FOREMAN_CREW_BLOCKED).
	var keep_clear: Array[Vector2i] = []


static func find_into(owners: RefCounted, request: Request, out: Array[Vector2i]) -> StringName:
	"""The first candidate point, away from the room first, whose endpoint exists or is published and is joined to the
	access both ways on the travel rows; failing that, an authored parking (`_authored_parking`)."""
	var access: Locations.Record = _record()
	var code: StringName = owners.locations.read_location_into(request.access, access)
	if code != &"": return code
	for direction: Vector3i in _ordered(access.point, request.room_box):
		for cells: int in [2, 3]:
			var point: Vector3i = access.point + direction * (cells * CELL_U)
			if not _between(access.point, request.room_box, point) and _clear(owners.profiles, request, access, point):
				var found: Vector2i = _parking_at(owners, request, access, point)
				if found != NULL_REF:
					out.assign([found])
					return &""
	var parked: Vector2i = _authored_parking(owners, request, access)
	if parked == NULL_REF: return REFUSE_NONE
	out.assign([parked])
	return &""


static func _authored_parking(owners: RefCounted, request: Request, access: Locations.Record) -> Vector2i:
	"""Decision 1991 (review H-1): with no point free along the access's floor, an endpoint already published as a
	parking anywhere in the access's air (TRANSIT or STORAGE in its section, not a container's location, every span
	to or from the access, joined both ways, off the room's way and its cells, not taken) is used; nothing is
	published here."""
	var locations: Locations = owners.locations
	var stride: int = locations._capacity
	for row: int in stride:
		var ref: Vector2i = Vector2i(row, locations._live.i32[Locations.GENERATION * stride + row])
		if ref == request.access or request.taken.has(ref) or request.keep_clear.has(ref) \
				or _existing(locations, access, _point(locations, row)) != ref: continue
		var point: Vector3i = _point(locations, row)
		if _between(access.point, request.room_box, point) or not _clear(owners.profiles, request, access, point): continue
		if not _routed_elsewhere(owners.routes, ref, request.access) and _joined(owners, request, ref): return ref
	return NULL_REF


static func _record() -> Locations.Record:
	"""A Location packet with its fixed box shapes."""
	var record: Locations.Record = Locations.Record.new()
	record.envelope.resize(6)
	record.support.resize(6)
	return record


static func _ordered(at: Vector3i, room: PackedInt32Array) -> Array[Vector3i]:
	"""The four floor directions, the one leading furthest from the room's centre first."""
	var centre: Vector3i = Vector3i((room[0] + room[2]) >> 1, at.y, (room[1] + room[3]) >> 1)
	var away: Vector3i = at - centre
	var out: Array[Vector3i] = []
	out.assign(DIRECTIONS)
	out.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.x * away.x + a.z * away.z > b.x * away.x + b.z * away.z)
	return out


static func _between(at: Vector3i, room: PackedInt32Array, point: Vector3i) -> bool:
	"""The point lies in the floor box spanned by the access and the room's cells (bounds included): the way a builder
	walks to its station."""
	return point.x >= mini(at.x, room[0]) and point.x <= maxi(at.x, room[2]) \
		and point.z >= mini(at.z, room[1]) and point.z <= maxi(at.z, room[3])


static func _clear(profiles: Profiles, request: Request, access: Locations.Record, point: Vector3i) -> bool:
	"""The travel row's whole body at the point lies in the access's surveyed air and off the room's cells."""
	var box: PackedInt32Array = _extent(profiles, request.forward, point)
	if not Space.contains_box(access.envelope, box): return false
	return box[3] <= request.room_box[0] or box[0] >= request.room_box[2] \
		or box[5] <= request.room_box[1] or box[2] >= request.room_box[3]


static func _extent(profiles: Profiles, row: int, point: Vector3i) -> PackedInt32Array:
	"""The union of every published box of the row, standing at the point, above its floor."""
	var stride: int = profiles._profile_capacity
	var cap: int = profiles._box_capacity
	var out: PackedInt32Array = PackedInt32Array([point.x, point.y, point.z, point.x + 1, point.y + 1, point.z + 1])
	var first: int = profiles._live.fields[Profiles.F_FIRST_BOX * stride + row]
	for box: int in range(first, first + profiles._live.fields[Profiles.F_BOX_COUNT * stride + row]):
		for axis: int in 3:
			out[axis] = mini(out[axis], point[axis] + profiles._live.boxes[axis * cap + box])
			out[axis + 3] = maxi(out[axis + 3], point[axis] + profiles._live.boxes[(axis + 3) * cap + box])
	out[1] = maxi(out[1], point.y)
	return out


static func _parking_at(owners: RefCounted, request: Request, access: Locations.Record, point: Vector3i) -> Vector2i:
	"""An endpoint at the point (existing, not WORK and not taken, or newly published), joined to the access."""
	var found: Vector2i = _existing(owners.locations, access, point)
	if found != NULL_REF and _routed_elsewhere(owners.routes, found, request.access): return NULL_REF
	if found == NULL_REF and _occupied(owners.locations, point): return NULL_REF
	if found == NULL_REF: found = _publish_endpoint(owners, request, access, point)
	if found == NULL_REF or request.taken.has(found) or request.keep_clear.has(found): return NULL_REF
	if _joined(owners, request, found): return found
	# Decision 1991 (decision 1937's review M5): spans already published between the two that still do not join are
	# never published again; the candidate is passed over, so a failed parking adds nothing on later orders.
	if _span_between(owners.routes, found, request.access): return NULL_REF
	return found if _publish_spans(owners, request, found, access) else NULL_REF


static func _span_between(routes: Routes, a: Vector2i, b: Vector2i) -> bool:
	"""Some live authored span already runs from `a` to `b` (Routes' own edge columns; a scan when a dig starts)."""
	var stride: int = routes._edge_capacity
	for row: int in stride:
		if routes._live.present[row] != 1: continue
		if routes._edge_pair(routes._live, Routes.E_FROM_SLOT, row) == a \
				and routes._edge_pair(routes._live, Routes.E_TO_SLOT, row) == b: return true
	return false


static func _routed_elsewhere(routes: Routes, found: Vector2i, access: Vector2i) -> bool:
	"""Some live span touches the endpoint and runs to or from anywhere but the access: a route's TRANSIT node, which a
	parked body would block."""
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		var from: Vector2i = routes._edge_pair(routes._live, Routes.E_FROM_SLOT, row)
		var to: Vector2i = routes._edge_pair(routes._live, Routes.E_TO_SLOT, row)
		if (from == found and to != access) or (to == found and from != access): return true
	return false


static func _existing(locations: Locations, access: Locations.Record, point: Vector3i) -> Vector2i:
	"""A live TRANSIT or STORAGE endpoint exactly at the point, in the access's section."""
	var stride: int = locations._capacity
	for row: int in stride:
		var ref: Vector2i = Vector2i(row, locations._live.i32[Locations.GENERATION * stride + row])
		if not locations._live_ref(locations._live, ref) or _point(locations, row) != point: continue
		var role: int = locations._live.i32[Locations.ROLE * stride + row]
		var section: Vector2i = Vector2i(locations._live.i32[Locations.SECTION_SLOT * stride + row],
			locations._live.i32[(Locations.SECTION_SLOT + 1) * stride + row])
		if section == access.section and (role == Locations.ROLE_TRANSIT or role == Locations.ROLE_STORAGE): return ref
	return NULL_REF


static func _occupied(locations: Locations, point: Vector3i) -> bool:
	"""Some other live endpoint (a WORK station, or one in another section) already stands at the point."""
	var stride: int = locations._capacity
	for row: int in stride:
		if locations._live.present[row] == 1 and _point(locations, row) == point: return true
	return false


static func _point(locations: Locations, row: int) -> Vector3i:
	"""One endpoint's integer point."""
	var stride: int = locations._capacity
	return Vector3i(locations._live.i32[Locations.X * stride + row], locations._live.i32[Locations.Y * stride + row],
		locations._live.i32[Locations.Z * stride + row])


static func _publish_endpoint(owners: RefCounted, request: Request, access: Locations.Record, point: Vector3i) -> Vector2i:
	"""A TRANSIT endpoint in the access's air with the travel rows' own footing at the point; Locations proves both."""
	var row: Locations.Record = _record()
	row.point = point; row.section = access.section; row.room = access.room; row.level = access.level
	row.role = Locations.ROLE_TRANSIT
	for axis: int in 6: row.envelope[axis] = access.envelope[axis]
	if not _footing(owners.profiles, request, row): return NULL_REF
	var cold: int = owners.budget.acquire(Budget.COLD_BYTES)
	if cold == 0: return NULL_REF
	var started: Locations.Result = owners.locations.begin_prepare(cold)
	var added: Locations.Result = owners.locations.stage_add(started.token, row) if started.error == &"" else started
	var published: bool = added.error == &"" and owners.locations.seal(started.token) == &"" \
		and owners.locations.publish(started.token)
	if not published and started.token != 0: owners.locations.abort(started.token)
	owners.budget.release(cold)
	return added.location if published else NULL_REF


static func _footing(profiles: Profiles, request: Request, row: Locations.Record) -> bool:
	"""The union of both travel rows' stance boxes below the point; it must hold the root on its top plane."""
	var box: Profiles.Box = Profiles.Box.new()
	var first: bool = true
	for profile: int in [request.forward, request.backward]:
		var revision: int = profiles._live.quantities[profile]
		var count: int = profiles._live.fields[Profiles.F_BOX_COUNT * profiles._profile_capacity + profile]
		for ordinal: int in count:
			if profiles.box_into(profile, revision, request.content, ordinal, box) != &"": return false
			if box.role != Profiles.STANCE_SUPPORT: continue
			for axis: int in 3:
				var low: int = row.point[axis] + int(box.low[axis])
				var high: int = row.point[axis] + int(box.high[axis])
				row.support[axis] = low if first else mini(row.support[axis], low)
				row.support[axis + 3] = high if first else maxi(row.support[axis + 3], high)
			first = false
	return not first and Locations.support_covers_root(row.point, row.support)


static func _joined(owners: RefCounted, request: Request, parking: Vector2i) -> bool:
	"""The parking already reaches the access on the retreat row and is reached from it on the forward row."""
	var remaining: PackedInt32Array = PackedInt32Array([0])
	var revision: int = owners.profiles._live.quantities[request.backward]
	if Itinerary.reachability_refusal(owners.binding, parking, request.access, request.backward, revision,
			request.content, Space.MAX_CHECKS, remaining) != &"": return false
	revision = owners.profiles._live.quantities[request.forward]
	return Itinerary.reachability_refusal(owners.binding, request.access, parking, request.forward, revision,
		request.content, Space.MAX_CHECKS, remaining) == &""


static func _publish_spans(owners: RefCounted, request: Request, parking: Vector2i, access: Locations.Record) -> bool:
	"""Two straight WALK spans, parking to access and back, certified by WorldRoutes' own seal; then they must join."""
	var cold: int = owners.budget.acquire(Budget.COLD_BYTES)
	if cold == 0: return false
	var begun: Routes.Result = owners.binding.begin_prepare(cold)
	var code: StringName = begun.error
	for reverse: bool in [false, true]:
		if code == &"": code = owners.routes.stage_add(begun.token, _span(owners, request, parking, access, reverse)).error
	if code == &"": code = owners.binding.seal(begun.token)
	if code == &"": code = owners.binding.publish(begun.token)
	if code != &"" and begun.token != 0: owners.binding.abort(begun.token)
	owners.budget.release(cold)
	return code == &"" and _joined(owners, request, parking)


static func _span(owners: RefCounted, request: Request, parking: Vector2i, access: Locations.Record,
		reverse: bool) -> Routes.Edge:
	"""One ground span in the access's section (as a station chain's first leg is)."""
	var point: Vector3i = _point(owners.locations, parking.x)
	var at: Vector3i = access.point
	var edge: Routes.Edge = Routes.Edge.new()
	edge.from_location = parking if reverse else request.access
	edge.to_location = request.access if reverse else parking
	edge.section = access.section; edge.room = access.room; edge.level = access.level
	edge.family = -1; edge.variant = 0; edge.rotation = 0
	edge.mode = Profiles.MODE_WALK; edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = request.content; edge.geometry_revision = owners.owner.revision(); edge.point_count = 2
	var first: Vector3i = point if reverse else at
	var last: Vector3i = at if reverse else point
	edge.points = PackedInt32Array([first.x, first.y, first.z, last.x, last.y, last.z])
	edge.length_u = absi(last.x - first.x) + absi(last.z - first.z)
	return edge

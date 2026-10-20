extends RefCounted
## Decision 2052 P-2052-1 (a) (Brendan, 2026-10-20): A PAINTED ROOM'S FRONT STATION AT THE FOOT OF A WAY DOWN.
## RoomOrders admits a room only through an approach witness from the access to a published WORK endpoint whose wall
## row's contact patch lies on one of the room's cubes (decision 1150; `underground_room_approach.gd`). The room's own
## station planner works only on Sites, which exist only after admission, so the way in places that first station:
## in front of the room's cell nearest the access, on the side facing the open floor, where the wall row's patch lies
## exactly on that cell's face. A heading-exact travel row walks in a straight line, so the station is reached from a
## corner on the access's own line (the access itself when the two line up), joined to the access on the all-yaw
## ground row: the claw Kitchen fixture's `_joined_work` shape (decision 1991 E12), made production.
##
## Stateless and cold. Geometry comes from the mounted content's own published boxes and the access's surveyed air;
## nothing here invents a row, reach or offset. Publication uses Locations' and WorldRoutes' public staging calls, as
## `underground_room_parking.gd` does; their own proofs decide (air, footing, span certificates). An endpoint or span
## already at the point is reused, so ordering the same room again publishes nothing. What one call publishes is
## listed, so a refused room's station can be withdrawn (`withdraw`, decision 1942's retirement path).

const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Itinerary := preload("res://scripts/core/underground_room_itinerary.gd")
const Retirement := preload("res://scripts/core/underground_room_station_retirement.gd")
const EntryRuntime := preload("res://scripts/core/underground_entry_runtime.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const CELL_U: int = Contract.QUANTUM_SIDE_U
## No heading's wall row can face any of the room's cells from the access's open floor.
const REFUSE_NO_FRONT: StringName = &"WAY_IN_NO_FRONT"
## The front station or its corner was published but the travel rows do not reach it both ways.
const REFUSE_UNJOINED: StringName = &"WAY_IN_FRONT_UNJOINED"
## A point the way in would publish at is already taken by another kind of endpoint.
const REFUSE_TAKEN: StringName = &"WAY_IN_POINT_TAKEN"
const HORIZONTAL: Array[int] = [0, 2]


class Candidate extends RefCounted:
	## One front: its heading's rows, the wall patch, the cube and face it strikes, the station and its corner.
	var wall: int = -1
	var wall_revision: int = 0
	var forward: int = -1
	var forward_revision: int = 0
	var yaw: int = -1
	var axis: int = -1 # The patch's planar axis (0 x, 2 z): the heading's axis.
	var ahead: int = 0 # +1 or -1: the patch lies ahead of the root along `axis`.
	var patch_low: Vector3i = Vector3i.ZERO
	var patch_high: Vector3i = Vector3i.ZERO
	var cube: Vector3i = Vector3i.ZERO
	var face: int = -1
	var point: Vector3i = Vector3i.ZERO
	var corner: Vector3i = Vector3i.ZERO
	var station: Vector2i = NULL_REF # Once published (or found): the station's endpoint.


static func record() -> Locations.Record:
	"""A Location packet with its fixed box shapes."""
	var out: Locations.Record = Locations.Record.new()
	out.envelope.resize(6)
	out.support.resize(6)
	return out


static func find_into(owners: RefCounted, foot: RefCounted, request: Approach.Request, access: Locations.Record,
		out: Candidate) -> StringName:
	"""The first front, heading by heading in the foot's order, then by the room cell nearest the access (ties by
	cell order); REFUSE_NO_FRONT when none fits. Pure geometry: nothing is published."""
	for heading: int in foot.wall_rows.size():
		if heading_into(owners.profiles, foot, heading, out) != &"": continue
		for cell: int in cells_by_distance(request, access.point):
			if place(owners.profiles, foot, request, access, cell, out): return &""
	return REFUSE_NO_FRONT


static func heading_into(profiles: Profiles, foot: RefCounted, heading: int, out: Candidate) -> StringName:
	"""The heading's wall row (a WORK row with one horizontal planar contact patch) and its forward travel row, which
	must walk at the wall row's yaw (the approach's own rule); its patch read from the published boxes."""
	var wall: Profiles.Descriptor = Profiles.Descriptor.new()
	var walk: Profiles.Descriptor = Profiles.Descriptor.new()
	var code: StringName = profiles.descriptor_into(foot.wall_rows[heading], foot.content, wall)
	if code == &"": code = profiles.descriptor_into(foot.forward_rows[heading], foot.content, walk)
	if code != &"": return code
	if wall.mode != Profiles.MODE_WORK or (walk.yaw_kind != Profiles.YAW_ALL and walk.yaw != wall.yaw):
		return REFUSE_NO_FRONT
	out.wall = wall.profile_id; out.wall_revision = wall.profile_revision; out.yaw = wall.yaw
	out.forward = walk.profile_id; out.forward_revision = walk.profile_revision
	return patch_into(profiles, foot.content, wall, out)


static func patch_into(profiles: Profiles, content: int, wall: Profiles.Descriptor, out: Candidate) -> StringName:
	"""The wall row's first CONTACT_PATCH box, which must be planar on one horizontal axis, ahead of its root."""
	var box: Profiles.Box = Profiles.Box.new()
	for ordinal: int in wall.box_count:
		var code: StringName = profiles.box_into(wall.profile_id, wall.profile_revision, content, ordinal, box)
		if code != &"": return code
		if box.role != Profiles.CONTACT_PATCH: continue
		for axis: int in HORIZONTAL:
			if box.low[axis] == box.high[axis] and box.low[axis] != 0:
				out.axis = axis
				out.ahead = 1 if box.low[axis] > 0 else -1
				out.patch_low = box.low; out.patch_high = box.high
				return &""
		return REFUSE_NO_FRONT
	return REFUSE_NO_FRONT


static func cells_by_distance(request: Approach.Request, from: Vector3i) -> PackedInt32Array:
	"""The room's cell indices (into its pairs), nearest the point first by the cells' centres, ties by cell order."""
	var keyed: Array[Vector2i] = []
	for at: int in range(0, request.cells.size(), 2):
		var centre: Vector3i = cube_of(request, at) + Vector3i(CELL_U >> 1, 0, CELL_U >> 1)
		keyed.append(Vector2i(absi(centre.x - from.x) + absi(centre.z - from.z), at))
	keyed.sort()
	var out: PackedInt32Array = PackedInt32Array()
	for key: Vector2i in keyed: out.append(key.y)
	return out


static func cube_of(request: Approach.Request, at: int) -> Vector3i:
	"""The floor cube of the room's cell at pair index `at`: the room's origin plus whole cells."""
	return request.origin_u + Vector3i(request.cells[at] * CELL_U, 0, request.cells[at + 1] * CELL_U)


static func place(profiles: Profiles, foot: RefCounted, request: Approach.Request, access: Locations.Record,
		at: int, out: Candidate) -> bool:
	"""Whether the heading's station can face the cell at `at`: the cell is on the room's edge on the station's side,
	the patch lies exactly on its face, the station and its corner stand on the access's floor in its surveyed air off
	the room, and the station lies ahead of the corner. Fills the cube, face, station point and corner."""
	var cube: Vector3i = cube_of(request, at)
	var behind: Vector2i = Vector2i(request.cells[at], request.cells[at + 1])
	behind[out.axis >> 1] -= out.ahead
	if has_cell(request, behind) or access.point.y != cube.y: return false
	var plane: int = cube[out.axis] + (0 if out.ahead > 0 else CELL_U)
	var across: int = 2 - out.axis
	var point: Vector3i = Vector3i(0, cube.y, 0)
	point[out.axis] = plane - out.patch_low[out.axis]
	point[across] = cube[across] + (CELL_U >> 1) # On the cell's centre line, as a station chain stands.
	if not patch_on_face(out, point, cube, plane): return false
	var corner: Vector3i = point
	corner[out.axis] = access.point[out.axis]
	if (point[out.axis] - corner[out.axis]) * out.ahead < 0: return false
	if not body_clear(profiles, out.forward, request, access, point): return false
	if corner != access.point and not body_clear(profiles, out.forward, request, access, corner): return false
	out.cube = cube; out.point = point; out.corner = corner
	out.face = out.axis * 2 + (0 if out.ahead > 0 else 1)
	return true


static func has_cell(request: Approach.Request, cell: Vector2i) -> bool:
	"""Whether the room's pairs hold the cell."""
	for at: int in range(0, request.cells.size(), 2):
		if request.cells[at] == cell.x and request.cells[at + 1] == cell.y: return true
	return false


static func patch_on_face(c: Candidate, point: Vector3i, cube: Vector3i, plane: int) -> bool:
	"""The patch, stood at the point, is closed on the face plane and lies within the cube on the other two axes (as
	the approach's own patch-to-target rule reads it)."""
	if point[c.axis] + c.patch_low[c.axis] != plane: return false
	for axis: int in 3:
		if axis == c.axis: continue
		if point[axis] + c.patch_low[axis] < cube[axis] or point[axis] + c.patch_high[axis] > cube[axis] + CELL_U \
				or c.patch_high[axis] <= c.patch_low[axis]: return false
	return true


static func body_clear(profiles: Profiles, row: int, request: Approach.Request, access: Locations.Record,
		point: Vector3i) -> bool:
	"""The row's whole body at the point lies in the access's surveyed air and off the room's cells."""
	var box: PackedInt32Array = extent(profiles, row, point)
	if not Space.contains_box(access.envelope, box): return false
	for at: int in range(0, request.cells.size(), 2):
		var cube: Vector3i = cube_of(request, at)
		if box[0] < cube.x + CELL_U and box[3] > cube.x and box[2] < cube.z + CELL_U and box[5] > cube.z: return false
	return true


static func extent(profiles: Profiles, row: int, point: Vector3i) -> PackedInt32Array:
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


static func publish_into(owners: RefCounted, foot: RefCounted, access: Locations.Record, c: Candidate,
		published: PackedInt32Array) -> Vector2i:
	"""The station and its corner (existing or published) and the straight spans joining the access, the corner and
	the station; the forward row must reach the station from the corner and the retreat row the corner from the
	station (the approach's and the builder's own rows; WorldRoutes certifies which rows walk the access-corner span).
	Returns the corner (the admission's access), or NULL_REF with every endpoint this call published listed in
	`published`."""
	# The station's footing holds every row that stands on it, as a planner's WORK station's does (decision 1161):
	# both travel rows and the wall row.
	var rows: PackedInt32Array = PackedInt32Array([c.forward, foot.travel, c.wall])
	var station: Vector2i = endpoint_at(owners, foot, access, c.point, Locations.ROLE_WORK, rows, published)
	var corner: Vector2i = foot.access
	if station != NULL_REF and c.corner != access.point:
		corner = endpoint_at(owners, foot, access, c.corner, Locations.ROLE_TRANSIT,
			PackedInt32Array([foot.ground]), published)
	if station == NULL_REF or corner == NULL_REF: return NULL_REF
	if not span_pair(owners, foot, access, corner, station): return NULL_REF
	if corner != foot.access and not span_pair(owners, foot, access, foot.access, corner): return NULL_REF
	if not joined(owners, foot, corner, station, c.forward) or not joined(owners, foot, station, corner, foot.travel):
		return NULL_REF
	c.station = station
	return corner


static func endpoint_at(owners: RefCounted, foot: RefCounted, access: Locations.Record, point: Vector3i, role: int,
		rows: PackedInt32Array, published: PackedInt32Array) -> Vector2i:
	"""The live endpoint of `role` at the point in the access's section, or one published there with the rows' own
	footing; NULL_REF when another endpoint already stands there or Locations refuses."""
	var found: Vector2i = existing(owners.locations, access, point, role)
	if found != NULL_REF: return found
	if occupied(owners.locations, point): return NULL_REF
	var row: Locations.Record = record()
	row.point = point; row.section = access.section; row.room = access.room; row.level = access.level
	row.role = role
	for axis: int in 6: row.envelope[axis] = access.envelope[axis]
	if not footing(owners.profiles, foot.content, rows, row): return NULL_REF
	var made: Vector2i = publish_location(owners, row)
	if made != NULL_REF: published.append_array(PackedInt32Array([made.x, made.y]))
	return made


static func existing(locations: Locations, access: Locations.Record, point: Vector3i, role: int) -> Vector2i:
	"""A live endpoint exactly at the point, in the access's section, of the role (TRANSIT also takes a STORAGE
	endpoint, as a parking does)."""
	var stride: int = locations._capacity
	for row: int in stride:
		var ref: Vector2i = Vector2i(row, locations._live.i32[Locations.GENERATION * stride + row])
		if not locations._live_ref(locations._live, ref) or point_of(locations, row) != point: continue
		var found: int = locations._live.i32[Locations.ROLE * stride + row]
		var section: Vector2i = Vector2i(locations._live.i32[Locations.SECTION_SLOT * stride + row],
			locations._live.i32[(Locations.SECTION_SLOT + 1) * stride + row])
		if section == access.section and (found == role
				or (role == Locations.ROLE_TRANSIT and found == Locations.ROLE_STORAGE)): return ref
	return NULL_REF


static func occupied(locations: Locations, point: Vector3i) -> bool:
	"""Some live endpoint already stands at the point."""
	for row: int in locations._capacity:
		if locations._live.present[row] == 1 and point_of(locations, row) == point: return true
	return false


static func point_of(locations: Locations, row: int) -> Vector3i:
	"""One endpoint's integer point."""
	var stride: int = locations._capacity
	return Vector3i(locations._live.i32[Locations.X * stride + row], locations._live.i32[Locations.Y * stride + row],
		locations._live.i32[Locations.Z * stride + row])


static func footing(profiles: Profiles, content: int, rows: PackedInt32Array, row: Locations.Record) -> bool:
	"""The union of the rows' stance boxes below the point; it must hold the root on its top plane."""
	var box: Profiles.Box = Profiles.Box.new()
	var first: bool = true
	for profile: int in rows:
		var revision: int = profiles._live.quantities[profile]
		var count: int = profiles._live.fields[Profiles.F_BOX_COUNT * profiles._profile_capacity + profile]
		for ordinal: int in count:
			if profiles.box_into(profile, revision, content, ordinal, box) != &"": return false
			if box.role != Profiles.STANCE_SUPPORT: continue
			for axis: int in 3:
				var low: int = row.point[axis] + int(box.low[axis])
				var high: int = row.point[axis] + int(box.high[axis])
				row.support[axis] = low if first else mini(row.support[axis], low)
				row.support[axis + 3] = high if first else maxi(row.support[axis + 3], high)
			first = false
	return not first and Locations.support_covers_root(row.point, row.support)


static func publish_location(owners: RefCounted, row: Locations.Record) -> Vector2i:
	"""One Locations publication under one cold lease; NULL_REF when refused (nothing changed)."""
	var cold: int = owners.budget.acquire(Budget.COLD_BYTES)
	if cold == 0: return NULL_REF
	var started: Locations.Result = owners.locations.begin_prepare(cold)
	var added: Locations.Result = owners.locations.stage_add(started.token, row) if started.error == &"" else started
	var published: bool = added.error == &"" and owners.locations.seal(started.token) == &"" \
		and owners.locations.publish(started.token)
	if not published and started.token != 0: owners.locations.abort(started.token)
	owners.budget.release(cold)
	return added.location if published else NULL_REF


static func span_pair(owners: RefCounted, foot: RefCounted, access: Locations.Record, a: Vector2i,
		b: Vector2i) -> bool:
	"""Two straight WALK spans, `a` to `b` and back, certified by WorldRoutes' own seal; a direction already spanned
	is not published again."""
	var cold: int = owners.budget.acquire(Budget.COLD_BYTES)
	if cold == 0: return false
	var begun: Routes.Result = owners.binding.begin_prepare(cold)
	var code: StringName = begun.error
	var staged: int = 0
	for reverse: bool in [false, true]:
		var from: Vector2i = b if reverse else a
		var to: Vector2i = a if reverse else b
		if code != &"" or span_between(owners.routes, from, to): continue
		code = owners.routes.stage_add(begun.token, span(owners, foot, access, from, to)).error
		staged += 1
	if code == &"" and staged > 0: code = owners.binding.seal(begun.token)
	if code == &"" and staged > 0: code = owners.binding.publish(begun.token)
	if (code != &"" or staged == 0) and begun.token != 0: owners.binding.abort(begun.token)
	owners.budget.release(cold)
	return code == &""


static func span_between(routes: Routes, from: Vector2i, to: Vector2i) -> bool:
	"""Some live span already runs from `from` to `to`."""
	for row: int in routes._edge_capacity:
		if routes._live.present[row] == 1 and routes._edge_pair(routes._live, Routes.E_FROM_SLOT, row) == from \
				and routes._edge_pair(routes._live, Routes.E_TO_SLOT, row) == to: return true
	return false


static func span(owners: RefCounted, foot: RefCounted, access: Locations.Record, from: Vector2i,
		to: Vector2i) -> Routes.Edge:
	"""One straight ground span in the access's section."""
	var first: Vector3i = point_of(owners.locations, from.x)
	var last: Vector3i = point_of(owners.locations, to.x)
	var edge: Routes.Edge = Routes.Edge.new()
	edge.from_location = from; edge.to_location = to
	edge.section = access.section; edge.room = access.room; edge.level = access.level
	edge.family = -1; edge.variant = 0; edge.rotation = 0
	edge.mode = Profiles.MODE_WALK; edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = foot.content; edge.geometry_revision = owners.owner.revision(); edge.point_count = 2
	edge.points = PackedInt32Array([first.x, first.y, first.z, last.x, last.y, last.z])
	edge.length_u = EntryRuntime.ceil_length(last - first)
	return edge


static func joined(owners: RefCounted, foot: RefCounted, from: Vector2i, to: Vector2i, row: int) -> bool:
	"""The row reaches `to` from `from` over the live graph (Itinerary's own search, one cold bound)."""
	var remaining: PackedInt32Array = PackedInt32Array([0])
	return Itinerary.reachability_refusal(owners.binding, from, to, row, owners.profiles._live.quantities[row],
		foot.content, Space.MAX_CHECKS, remaining) == &""


static func withdraw(owners: RefCounted, published: PackedInt32Array) -> StringName:
	"""Retire the endpoints one call published and every span touching them (decision 1942's two publications);
	nothing when none was published."""
	if published.is_empty(): return &""
	return Retirement.retire(owners.binding, owners.routes, owners.locations, owners.budget, published)

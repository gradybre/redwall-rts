extends RefCounted
## Decision 2054 (slice D2 phase 2): A WAY DOWN'S FOOT MADE READY FOR ROOMS. Stateless and cold; every endpoint and
## span goes through Locations' and WorldRoutes' public staging calls, whose own proofs decide (air, footing, span
## certificates), and anything already at its point is found again, so a load needs no save field (decision 2052 E1).
##
## The foot of M5's flight is the bottom stop F' (decision 2044), which publishes only the stair's own air: one body,
## facing down the flight, with no ground joins and no room for a turn beside the sill (the 2054 probe). So the way in
## makes, in the run-out's floor air (`Foot.open`, from the flight's geometry):
## - the floor hub, the rooms' access (P-1936-1 (a): one per World), where the all-yaw ground row can turn, joined to
##   F' by two straight spans down the flight;
## - one parking for the crew (decision 2052 §2.2 row 8: the planner's own candidates leave the 2 m slot), joined to the
##   hub on the retreat row's family, which the parking planner then takes as an authored parking;
## - the level-1 store and the spoil pile (P-2052-2 (a)), ground staging at their points; and the store's grip stand at
##   `Grip.stock_offset(QUARTER)` from it with one CARRY span entering it on the grip heading (P-2091-7 (a), Brendan
##   2026-10-21, for stair-leg Delivery), from the hub: F''s own air holds no loaded row (decision 2054 §2). No new
##   motion: the content's own rows.
## On the claw Kitchen fixture (phase 1) the access is given; only the store and the pile are made, joined to it.

const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Front := preload("res://scripts/core/underground_way_in_front.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const CELL_U: int = Front.CELL_U
const REFUSE_FOOT: StringName = &"WAY_IN_SCOPE"
## The store, the spoil pile or the store's stand could not be made or reached at its point.
const REFUSE_CONTAINER: StringName = &"WAY_IN_CONTAINER"
## Decision 2054: the floor hub or the parking could not be made at its point, or not joined.
const REFUSE_HUB: StringName = &"WAY_IN_HUB"
## Decision 2054 (P-2091-7 (a)): the store's grip stand could not be made at its point.
const REFUSE_STAND: StringName = &"WAY_IN_STAND"
## Decision 2054 (P-2091-7 (a)): WorldRoutes certifies no loaded row on the span from the stair stop into the stand.
const REFUSE_LOADED_SPAN: StringName = &"WAY_IN_LOADED_SPAN"


class Foot extends RefCounted:
	## The foot of one way down, as its level's way in sees it.
	var level: int = -1
	var access: Vector2i = NULL_REF # The rooms' access: given (the fixture), or the hub once made (M5).
	var travel: int = -1 # The room contacts' retreat travel row: Order.travel.
	var ground: int = -1 # The all-yaw ground WALK row joining a corner, the store and the pile to the access.
	var content: int = 0
	## The headings a room may be dug from, in preference order: parallel wall (WORK), forward and backward rows.
	var wall_rows: PackedInt32Array = PackedInt32Array()
	var forward_rows: PackedInt32Array = PackedInt32Array()
	var backward_rows: PackedInt32Array = PackedInt32Array()
	var store_point: Vector3i = Vector3i.ZERO
	var pile_point: Vector3i = Vector3i.ZERO
	var staging: Vector2i = NULL_REF # The staging container a short store hauls from (the surface R), or none.
	## Decision 2054, a stair's foot (all unset on the fixture):
	var stair: Vector2i = NULL_REF # The stair's own bottom stop (M5's F'(5)), the hub's and the stand's way in.
	var open: PackedInt32Array = PackedInt32Array() # The run-out's floor air: every endpoint here is published in it.
	var hub_point: Vector3i = Vector3i.ZERO
	var hub_rows: PackedInt32Array = PackedInt32Array() # The rows standing on the hub (its footing).
	var parking_point: Vector3i = Vector3i.ZERO
	var parking_rows: PackedInt32Array = PackedInt32Array() # Empty: no parking is made.
	var store_rows: PackedInt32Array = PackedInt32Array() # The store's footing; empty: the ground row's.
	var stand_rows: PackedInt32Array = PackedInt32Array() # Empty: no stand is made.
	var join_containers: bool = true # Join the store and the pile to the access by straight ground spans.

	func refusal() -> StringName:
		"""REFUSE_FOOT unless every field a room order reads is set and the heading rows pair up."""
		if level < 1 or travel < 0 or ground < 0 or content <= 0 or wall_rows.is_empty() \
				or wall_rows.size() != forward_rows.size() or wall_rows.size() != backward_rows.size() \
				or store_point == pile_point: return REFUSE_FOOT
		if stair == NULL_REF: return &"" if access != NULL_REF else REFUSE_FOOT
		return &"" if open.size() == 6 and not hub_rows.is_empty() else REFUSE_FOOT


static func air_record(owners: Builder.Owners, foot: Foot, out: Locations.Record) -> StringName:
	"""The record new endpoints copy their section, room, level and air from: the access's on the fixture; on a
	stair's foot the stair stop's, with the run-out's floor air."""
	var from: Vector2i = foot.stair if foot.stair != NULL_REF else foot.access
	var code: StringName = owners.locations.read_location_into(from, out)
	if code != &"" or foot.stair == NULL_REF: return code
	for axis: int in 6: out.envelope[axis] = foot.open[axis]
	return &""


static func access_record(owners: Builder.Owners, foot: Foot, out: Locations.Record) -> StringName:
	"""The rooms' access as a front is found from it, publishing nothing: the given access's record, or on a stair's
	foot the hub's as it is (or will be) published at its point, in the run-out's air."""
	if foot.stair == NULL_REF: return owners.locations.read_location_into(foot.access, out)
	var code: StringName = air_record(owners, foot, out)
	out.point = foot.hub_point
	out.role = Locations.ROLE_TRANSIT
	return code


static func access_ready(owners: Builder.Owners, foot: Foot) -> StringName:
	"""The rooms' access: given, or on a stair's foot the hub (made once, then found by its point) joined to the
	stair stop both ways, then the parking joined to it."""
	if foot.stair == NULL_REF: return &"" if foot.access != NULL_REF else REFUSE_FOOT
	var air: Locations.Record = Front.record()
	var code: StringName = air_record(owners, foot, air)
	if code != &"": return code
	var made: PackedInt32Array = PackedInt32Array()
	var hub: Vector2i = Front.endpoint_at(owners, foot, air, foot.hub_point, Locations.ROLE_TRANSIT, foot.hub_rows,
		made)
	if hub == NULL_REF or not Front.span_pair(owners, foot, air, foot.stair, hub): return REFUSE_HUB
	foot.access = hub
	if foot.parking_rows.is_empty(): return &""
	var parking: Vector2i = Front.endpoint_at(owners, foot, air, foot.parking_point, Locations.ROLE_TRANSIT,
		foot.parking_rows, made)
	return &"" if parking != NULL_REF and Front.span_pair(owners, foot, air, hub, parking) else REFUSE_HUB


static func access_found(owners: Builder.Owners, foot: Foot) -> bool:
	"""The rooms' access as it stands, publishing nothing (after a load): given, or the hub found at its point."""
	if foot.stair == NULL_REF or foot.access != NULL_REF: return foot.access != NULL_REF
	var air: Locations.Record = Front.record()
	if air_record(owners, foot, air) != &"": return false
	foot.access = Front.existing(owners.locations, air, foot.hub_point, Locations.ROLE_TRANSIT)
	return foot.access != NULL_REF


static func containers_into(owners: Builder.Owners, foot: Foot, order: Composer.Order) -> StringName:
	"""The store and the spoil pile at the foot's points (P-2052-2 (a)), made on first use; the order's storage and
	output. The store's grip stand is `stand_ready`'s, which no room order needs."""
	var air: Locations.Record = Front.record()
	var code: StringName = air_record(owners, foot, air)
	if code != &"": return code
	var rows: PackedInt32Array = foot.store_rows if not foot.store_rows.is_empty() else PackedInt32Array([foot.ground])
	order.storage = _container_at(owners, foot, air, foot.store_point, rows)
	order.output = _container_at(owners, foot, air, foot.pile_point, PackedInt32Array([foot.ground]))
	return REFUSE_CONTAINER if order.storage == NULL_REF or order.output == NULL_REF else &""


static func _container_at(owners: Builder.Owners, foot: Foot, air: Locations.Record, point: Vector3i,
		rows: PackedInt32Array) -> Vector2i:
	"""The ground staging on the STORAGE endpoint at the point (its footing the rows'), joined to the access by a
	straight span each way where the foot joins its containers; each part is made only when missing."""
	var made: PackedInt32Array = PackedInt32Array()
	var spot: Vector2i = Front.endpoint_at(owners, foot, air, point, Locations.ROLE_STORAGE, rows, made)
	if spot == NULL_REF: return NULL_REF
	if foot.join_containers and not Front.span_pair(owners, foot, air, foot.access, spot): return NULL_REF
	var found: Vector2i = owners.inventory.spatial_ground_container_at(spot)
	if found != NULL_REF: return found
	var created: Inventory.OpResult = owners.inventory.create_spatial_ground_staging(spot)
	return created.ref if created.ok else NULL_REF


static func stand_point(foot: Foot) -> Vector3i:
	"""The store's grip stand: the certified stand offset from its stock point, where the hauler and Delivery look
	(`underground_entry_hauler.gd` `_stand_beside`; the worker faces -X onto the stock)."""
	return foot.store_point - Grip.stock_offset(Grip.QUARTER)


static func stand_ready(owners: Builder.Owners, foot: Foot) -> StringName:
	"""P-2091-7 (a): the store's grip stand (a WORK endpoint with the grip and carry rows' footing) and the one CARRY
	span into it on the grip heading, each made only when missing. The span leaves the hub, not F'(5): F''s surveyed
	air holds no loaded row (the 2054 probe; widening it is M5's, decision 2054 §2), and the hub, joined to F', has the
	run-out's. REFUSE_STAND when the stand cannot stand there; REFUSE_LOADED_SPAN when WorldRoutes certifies no loaded
	row on the span. Call after `access_ready`."""
	if foot.stand_rows.is_empty() or foot.stair == NULL_REF: return &""
	if foot.access == NULL_REF: return REFUSE_HUB
	var air: Locations.Record = Front.record()
	var code: StringName = air_record(owners, foot, air)
	if code != &"": return code
	var made: PackedInt32Array = PackedInt32Array()
	var stand: Vector2i = Front.endpoint_at(owners, foot, air, stand_point(foot), Locations.ROLE_WORK, foot.stand_rows,
		made)
	if stand == NULL_REF: return REFUSE_STAND
	return &"" if carry_span(owners, foot, air, foot.access, stand) else REFUSE_LOADED_SPAN


static func carry_span(owners: Builder.Owners, foot: Foot, air: Locations.Record, from: Vector2i,
		to: Vector2i) -> bool:
	"""One straight CARRY span `from` -> `to`, certified by WorldRoutes' own seal; nothing when one runs already."""
	if carried(owners.routes, from, to): return true
	var cold: int = owners.budget.acquire(Front.Budget.COLD_BYTES)
	if cold == 0: return false
	var begun: Front.Routes.Result = owners.binding.begin_prepare(cold)
	var code: StringName = begun.error
	if code == &"": code = owners.routes.stage_add(begun.token, loaded_span(owners, foot, air, from, to)).error
	if code == &"": code = owners.binding.seal(begun.token)
	if code == &"": code = owners.binding.publish(begun.token)
	if code != &"" and begun.token != 0: owners.binding.abort(begun.token)
	owners.budget.release(cold)
	return code == &""


static func loaded_span(owners: Builder.Owners, foot: Foot, air: Locations.Record, from: Vector2i,
		to: Vector2i) -> Front.Routes.Edge:
	"""A ground CARRY span that enters `to` moving along x (the grip heading at a stand, as the work area's
	`_carry_approach` does): straight when the two share a z, else first along z to the stand's line, then along x."""
	var edge: Front.Routes.Edge = Front.span(owners, foot, air, from, to)
	edge.mode = Profiles.MODE_CARRY
	var first: Vector3i = Front.point_of(owners.locations, from.x)
	var last: Vector3i = Front.point_of(owners.locations, to.x)
	if first.z == last.z or first.x == last.x: return edge
	var bend: Vector3i = Vector3i(first.x, first.y, last.z)
	edge.points = PackedInt32Array([first.x, first.y, first.z, bend.x, bend.y, bend.z, last.x, last.y, last.z])
	edge.point_count = 3
	edge.length_u = absi(bend.z - first.z) + absi(last.x - bend.x)
	return edge


static func carried(routes: Front.Routes, from: Vector2i, to: Vector2i) -> bool:
	"""Some live CARRY span already runs from `from` to `to`."""
	var edge: Front.Routes.Edge = Front.Routes.Edge.new()
	for row: int in routes._edge_capacity:
		if routes._live.present[row] != 1: continue
		var stride: int = routes._edge_capacity
		var handle: Vector2i = Vector2i(row, routes._live.fields[Front.Routes.E_GENERATION * stride + row])
		if routes.edge_metadata_into(handle, edge) == &"" and edge.from_location == from and edge.to_location == to \
				and edge.mode == Profiles.MODE_CARRY: return true
	return false


static func rooms_on_level(sites: Sites, level_floor_y: int) -> Array[Vector2i]:
	"""Every room with Sites whose lowest cube stands at `level_floor_y` (its floor), in Site order, once each."""
	var rooms: Array[Vector2i] = []
	var lowest: PackedInt32Array = PackedInt32Array()
	for row: int in sites._count:
		if sites._present[row] != 1 or sites._room(row) == NULL_REF: continue
		var y: int = sites.origin_of(Vector2i(row, Sites.SITE_GENERATION)).y
		var at: int = rooms.find(sites._room(row))
		if at < 0:
			rooms.append(sites._room(row))
			lowest.append(y)
		elif y < lowest[at]: lowest[at] = y
	var out: Array[Vector2i] = []
	for at: int in rooms.size():
		if lowest[at] == level_floor_y: out.append(rooms[at])
	return out


static func request_of_room(sites: Sites, room: Vector2i, level: int) -> Approach.Request:
	"""The room's floor cells as a painted request (origin at its lowest corner), or null when it has no Sites."""
	var cubes: Array[Vector3i] = []
	for row: int in sites._count:
		if sites._present[row] == 1 and sites._room(row) == room:
			var cube: Vector3i = sites.origin_of(Vector2i(row, Sites.SITE_GENERATION))
			if cubes.is_empty() or cube.y == cubes[0].y: cubes.append(cube)
			elif cube.y < cubes[0].y: cubes.assign([cube])
	if cubes.is_empty(): return null
	var request: Approach.Request = Approach.Request.new()
	request.level = level; request.cell_size_u = CELL_U
	request.origin_u = cubes[0]
	for cube: Vector3i in cubes:
		request.origin_u = Vector3i(mini(request.origin_u.x, cube.x), cube.y, mini(request.origin_u.z, cube.z))
	for cube: Vector3i in cubes:
		@warning_ignore("integer_division") var x: int = (cube.x - request.origin_u.x) / CELL_U
		@warning_ignore("integer_division") var z: int = (cube.z - request.origin_u.z) / CELL_U
		if not Front.has_cell(request, Vector2i(x, z)): request.cells.append_array(PackedInt32Array([x, z]))
	return request

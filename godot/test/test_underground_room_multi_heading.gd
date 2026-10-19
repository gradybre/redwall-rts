extends "res://test/framework/test_case.gd"
## Decision 1943: rooms on every side of their access are dug. The claw Kitchen fixture (decision 1939, content 12,
## the game's ground-pace catalog: decision 1942's LargeRoom) with a Kitchen painted on each side of the Corridor:
## east (straight out from the access, as before), north, south and west. Each is admitted from a WORK station in
## the Corridor in front of its first cube, on the content's own rows at that heading (fixture geometry only), and
## dug by the room runtime from the one access, the planner trying the access's bound heading first.

const RetirementTests := preload("res://test/test_underground_room_station_retirement.gd")
const ClawTests := preload("res://test/test_underground_room_claw_kitchen.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Planner := preload("res://scripts/core/underground_room_station_planner.gd")
const Itinerary := preload("res://scripts/core/underground_room_itinerary.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TICK_BOUND: int = 60000
const EAST: int = 0
const NORTH: int = 1
const SOUTH: int = 2
const WEST: int = 3


class SideRooms extends RetirementTests.LargeRoom:
	## The claw Kitchen's owners and Corridor with no room confirmed yet; rooms are painted on any side.

	func prepared() -> bool:
		"""Owners, paths, stock (topped up while digging), the spoil pile; no room."""
		location_capacity = 512; edge_capacity = 512; lot_capacity = 4096; site_capacity = 1024
		stocked = true
		_actual_fixture(); connect_source_paths(); finite_stock_and_worker()
		if not failures.is_empty(): return false
		var pile: Inventory.OpResult = _inventory.create_spatial_ground_staging(_first)
		assert_true(pile.ok, "the spoil pile: %s" % pile.error)
		spoil = pile.ref
		return failures.is_empty()

	func side_room(side: int, width: int, depth: int) -> Vector2i:
		"""A Kitchen of width x depth cells on one side of the Corridor, admitted from a WORK station in front of its
		first cube on that heading's own claw rows. Width runs along the Corridor wall, depth away from it."""
		var plan: Dictionary = _side_plan(side, width, depth)
		var yaw: int = plan["yaw"]
		var forward: int = Itinerary.family_row(_profiles, ClawTests.CLAW_FORWARD, yaw, Profiles.POLICY_READY_FORWARD)
		var wall: int = _wall_row(yaw)
		assert_true(forward >= 0 and wall >= 0, "content 12's own rows at yaw %d: %d, %d" % [yaw, forward, wall])
		var anchor: Vector3i = _contact_point(wall)
		var face: int = Planner.facing_face(provider, yaw)
		@warning_ignore("integer_division") var axis: int = face / 2
		var lateral: int = 2 if axis == 0 else 0
		var first: Vector3i = plan["first"]
		var station: Vector3i = first
		station[axis] = int(first[axis]) + (0 if face % 2 == 0 else Contract.QUANTUM_SIDE_U) - anchor[axis]
		station[lateral] = int(first[lateral]) + (Contract.QUANTUM_SIDE_U >> 1) # The root on the cell's centre line.
		station.y = Phase.FLOOR
		var access: Vector2i = _first # East: the Kitchen's own admission (ADR 1161's authored first contact).
		var work: Vector2i = _last
		if side != EAST:
			access = _station_access(station, axis)
			work = _endpoint(station, Locations.ROLE_WORK)
			_spans(access, work)
		var request: Approach.Request = room_request()
		request.space_revision = _owner.revision()
		request.origin_u = plan["origin"]
		request.cells = _grid(width, depth, side)
		request.target_origin = first
		request.access = access; request.work_location = work
		request.travel_profile = forward; request.travel_revision = _profiles._live.quantities[forward]
		request.work_profile = wall; request.work_revision = _profiles._live.quantities[wall]
		request.height_u = mini(4096, Approach.reachable_height_u(_profiles, wall))
		request.face = face; request.yaw = yaw
		var made: Buildings.OpResult = orders.confirm_room(request)
		assert_true(made.ok, "the %s Kitchen confirmed: %s" % [["east", "north", "south", "west"][side], made.error])
		return made.ref if made.ok else NULL_REF

	func _side_plan(side: int, width: int, depth: int) -> Dictionary:
		"""Origin (the lowest corner), the first cube struck (the one touching the Corridor) and the heading."""
		match side:
			NORTH:
				return {"origin": Vector3i(Phase.X - 2048, Phase.FLOOR, Phase.Z + 4096),
					"first": Vector3i(Phase.X - 2048, Phase.FLOOR, Phase.Z + 4096), "yaw": 32768}
			SOUTH:
				return {"origin": Vector3i(Phase.X - 2048, Phase.FLOOR, Phase.Z - 2048 - depth * 1024),
					"first": Vector3i(Phase.X - 2048, Phase.FLOOR, Phase.Z - 3072), "yaw": 0}
			WEST:
				return {"origin": Vector3i(Phase.X - 4096 - depth * 1024, Phase.FLOOR, Phase.Z + 2048),
					"first": Vector3i(Phase.X - 5120, Phase.FLOOR, Phase.Z + 2048), "yaw": 16384}
		return {"origin": Vector3i(Phase.X + 2048, Phase.FLOOR, Phase.Z), "first": Vector3i(Phase.X + 2048, Phase.FLOOR,
			Phase.Z), "yaw": 49152}

	static func _grid(width: int, depth: int, side: int) -> PackedInt32Array:
		"""The painted cells, x then z; depth runs along x for the east and west rooms, along z for the others."""
		var cells: PackedInt32Array = PackedInt32Array()
		var along_x: bool = side == EAST or side == WEST
		for row: int in (width if along_x else depth):
			for column: int in (depth if along_x else width):
				cells.append(column); cells.append(row)
		return cells

	func _wall_row(yaw: int) -> int:
		"""The claw's BUILD wall row at that yaw (decision 1972's rows 67-70): the Kitchen's wall row's sibling."""
		var stride: int = _profiles._profile_capacity
		for row: int in range(ClawTests.CLAW_WALL - 3, ClawTests.CLAW_WALL + 1):
			var same: bool = true
			for field: int in 10:
				same = same and _profiles._live.fields[field * stride + row] \
					== _profiles._live.fields[field * stride + ClawTests.CLAW_WALL]
			if same and _profiles._live.fields[Profiles.F_MODE * stride + row] == Profiles.MODE_WORK \
					and _profiles._live.fields[Profiles.F_WORK_KIND * stride + row] == Jobs.JOB_KIND_BUILD \
					and _profiles._live.fields[Profiles.F_CONTACT_KIND * stride + row] == Profiles.CONTACT_ANCHOR_AND_PATCH \
					and _profiles._live.fields[Profiles.F_YAW_KIND * stride + row] == Profiles.YAW_EXACT \
					and _profiles._live.fields[Profiles.F_YAW * stride + row] == yaw \
					and _profiles._live.fields[Profiles.F_TOOL * stride + row] < 0:
				return row
		return -1

	func _contact_point(row: int) -> Vector3i:
		"""The row's published CONTACT_POINT offset (its anchor) from the root."""
		var stride: int = _profiles._box_capacity
		for index: int in _profiles._live.fields[Profiles.F_BOX_COUNT * _profiles._profile_capacity + row]:
			var box: int = _profiles._live.fields[Profiles.F_FIRST_BOX * _profiles._profile_capacity + row] + index
			if _profiles._live.boxes[6 * stride + box] == Profiles.CONTACT_POINT:
				return Vector3i(_profiles._live.boxes[box], _profiles._live.boxes[stride + box], _profiles._live.boxes[2 * stride + box])
		return Vector3i.ZERO

	func _station_access(station: Vector3i, axis: int) -> Vector2i:
		"""The admission's access: a Corridor endpoint on the access line (z) or column (x) level with the station,
		joined to the access by a ground span, from which the station lies straight along the heading."""
		var corner: Vector3i = Vector3i(Phase.X - 1024, Phase.FLOOR, station.z) if axis == 0 \
			else Vector3i(station.x, Phase.FLOOR, Phase.Z + 512)
		return _joined_endpoint(corner)

	func _spans(a: Vector2i, b: Vector2i) -> void:
		"""Two straight spans, both ways, between two endpoints."""
		var pa: Vector3i = Builder.Claim.point_of(endpoints, a)
		var pb: Vector3i = Builder.Claim.point_of(endpoints, b)
		var token: int = _begin()
		for reverse: bool in [false, true]:
			var edge: Routes.Edge = _edge()
			edge.from_location = b if reverse else a; edge.to_location = a if reverse else b
			var from: Vector3i = pb if reverse else pa
			var to: Vector3i = pa if reverse else pb
			edge.points = PackedInt32Array([from.x, from.y, from.z, to.x, to.y, to.z])
			edge.length_u = absi(to.x - from.x) + absi(to.z - from.z)
			assert_equal(_routes.stage_add(token, edge).error, &"", "a station span")
		assert_equal(_binding.seal(token), &"", "station spans certified")
		assert_equal(_binding.publish(token), &"", "station spans published")
		_end(token)


var _h: SideRooms = null


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % _h.failures)
	_h = null


func _dig(room: Vector2i) -> Array[StringName]:
	"""Order the room with the fixture's mole and run the runtime to its end; the refusals seen."""
	var runtime: Runtime = Runtime.new(_h._residents.directory())
	assert_true(runtime.bind_owners(_h.owners()), "owners")
	assert_equal(runtime.order_room(room, _h.material, _h.spoil, NULL_REF), &"", "ordered")
	assert_equal(runtime.start_room(room, runtime.bound_owners(), [_h.crew_member()] as Array[Builder.Crew]), &"", "started")
	var seen: Array[StringName] = []
	for step: int in TICK_BOUND:
		_h.top_up()
		_h.tick += 1
		seen.append_array(runtime.advance(_h.tick))
		if not runtime.is_running(): break
	return seen


func _dug(room: Vector2i) -> int:
	"""A room's Sites that are supported voids with no live phase."""
	var count: int = 0
	for row: int in _h.sites._count:
		if _h.sites._present[row] == 1 and _h.sites._room(row) == room and _h.sites._phase[row] == Sites.SUPPORTED_VOID \
				and _h.sites.project_of(Vector2i(row, Sites.SITE_GENERATION)) == NULL_REF:
			count += 1
	return count


func _side(side: int) -> void:
	"""One 2 x 2 Kitchen on that side, dug whole with no refusal."""
	_h = SideRooms.new()
	if not _h.prepared(): return
	var room: Vector2i = _h.side_room(side, 2, 2)
	if room == NULL_REF: return
	assert_equal(_dig(room), [] as Array[StringName], "no refusal")
	assert_equal(_dug(room), 16, "every cube dug")
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")


func test_a_kitchen_east_of_its_access_is_dug() -> void:
	"""Straight out from the access, on its bound heading, as before."""
	_side(EAST)


func test_a_kitchen_north_of_its_access_is_dug() -> void:
	"""Across the Corridor's north end: the planner turns at the gateway and digs on the +Z heading."""
	_side(NORTH)


func test_a_kitchen_south_of_its_access_is_dug() -> void:
	"""Across the Corridor's south end, on the -Z heading."""
	_side(SOUTH)


func test_a_kitchen_west_of_its_access_is_dug() -> void:
	"""Behind the access, on the -X heading."""
	_side(WEST)


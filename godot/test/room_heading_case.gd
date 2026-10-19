extends "res://test/framework/test_case.gd"
## Decision 1943: rooms on every side of their access, of every size the coverage matrix names, are dug.
##
## The claw Kitchen fixture (decision 1939, content 12, the game's ground-pace catalog: decision 1942's LargeRoom)
## with no room confirmed; `side_room` paints a room of any type and size on any side of the Corridor. Each room is
## admitted from a WORK station in the Corridor in front of its first cube, on the content's own rows at that heading
## (fixture geometry only), and dug by the room runtime from the one access, the planner trying the access's bound
## heading first. With `pick` the fixture's mole digs with a held pick on content 12's pick rows instead of its claws.
##
## SHARED FIXTURE, NOT A SUITE (as `settlement_save_parity_case.gd`): each large room digs for several minutes, so
## the matrix is split over `test_underground_room_matrix_*.gd` for CI's shards; `test_underground_room_multi_heading.gd`
## holds the small cases.

const RetirementTests := preload("res://test/test_underground_room_station_retirement.gd")
const ClawTests := preload("res://test/test_underground_room_claw_kitchen.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Planner := preload("res://scripts/core/underground_room_station_planner.gd")
const Itinerary := preload("res://scripts/core/underground_room_itinerary.gd")
const Retirement := preload("res://scripts/core/underground_room_station_retirement.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TICK_BOUND: int = 120000
const EAST: int = 0
const NORTH: int = 1
const SOUTH: int = 2
const WEST: int = 3
const SIDE_NAMES: Array[String] = ["east", "north", "south", "west"]
const KITCHEN: int = Buildings.ROOM_TYPE_KITCHEN
## Content 12's pick rows: READY forward and backward at +X (rows 2-5 and 6-9 run the four yaws).
const PICK_FORWARD: int = 5
const PICK_BACKWARD: int = 9
## The pick's floor-band wall row at +X, row 27, holds its anchor 768 u ahead of the root.
const PICK_REACH: int = 768
## One chain's edges at most: each station joined both ways to the one before it.
const CHAIN_EDGES: int = 2 * Retirement.MAX_CHAIN


class SideRooms extends RetirementTests.LargeRoom:
	## The claw Kitchen's owners and Corridor with no room confirmed yet; rooms are painted on any side.
	var pick: bool = false
	var wood_made: int = 0
	var painted_cubes: int = 0
	var painted: PackedInt32Array = PackedInt32Array() # Cells to paint instead of the width x depth grid (x then z).

	func prepared() -> bool:
		"""Owners, paths, stock (topped up while digging), the spoil pile; no room. A pick mole retreats on the pick's
		own backward row and its first contact stands at the pick wall row's reach."""
		location_capacity = 512; edge_capacity = 512; lot_capacity = 4096; site_capacity = 1024
		stocked = true
		if pick:
			retreat_row = PICK_BACKWARD
			work_x = Phase.X + 2048 - PICK_REACH
		_actual_fixture(); connect_source_paths(); finite_stock_and_worker()
		if not failures.is_empty(): return false
		if pick: assert_equal(_contact_point(_wall_row(49152)).x, PICK_REACH, "the pick wall row's reach")
		if pick:
			spoil = material # The access holds one container: M takes the spoil too.
		else:
			var pile: Inventory.OpResult = _inventory.create_spatial_ground_staging(_first)
			assert_true(pile.ok, "the spoil pile: %s" % pile.error)
			spoil = pile.ref
		return failures.is_empty()

	func stock(key: StringName, quantity: int) -> Vector2i:
		"""Every lot of wood made, counted: what the digs consume is what was made less what M still holds."""
		if key == &"wood": wood_made += quantity
		return super.stock(key, quantity)

	func finite_stock_and_worker() -> void:
		"""The claw Kitchen's M and worker. A pick mole also carries a basic pick, and its M is the access itself (as
		ADR 1161's Kitchen keeps it), so no input is carried: content 12's CARRY rows hold no tool."""
		if not pick:
			super.finite_stock_and_worker()
			return
		storage_binding = Locations.InventoryLocations.new(endpoints)
		assert_true(_inventory.bind_spatial_locations(storage_binding, 4).ok, "actual storage authority")
		storage = _first
		var made: Inventory.OpResult = _inventory.create_spatial_ground_staging(storage)
		assert_true(made.ok, "the room's storage M: %s" % made.error)
		material = made.ref
		stock_wood = stock(&"wood", 16 * Contract.BRACE_WOOD_MILLI)
		stock_stone = stock(&"stone", 16 * Contract.BRACE_STONE_MILLI)
		var worker: int = _residents.directory().get_typed_row(_worker)
		assert_true(_jobs.priorities().spawn(worker).ok, "actual priorities")
		assert_true(_jobs.schedule().spawn(worker, _jobs.schedule().default_template_id().value).ok, "actual schedule")
		assert_true(_jobs.schedule().resolve(worker, 8, false).ok and _jobs.spawn_agent(worker).ok, "actual worker availability")
		tool = stock(&"tool", 1000)
		assert_true(_gear.create_gear(_inventory, _items, tool, Gear.MANUFACTURE_BASIC).ok, "a basic pick")
		assert_true(_gear.equip(tool, _worker).ok, "the pick carried")

	func side_room(side: int, width: int, depth: int, room_type: int = KITCHEN) -> Vector2i:
		"""A room of width x depth cells on one side of the Corridor, admitted from a WORK station in front of its
		first cube on that heading's own rows. Width runs along the Corridor wall, depth away from it."""
		var plan: Dictionary = _side_plan(side, width, depth)
		var yaw: int = plan["yaw"]
		var forward: int = Itinerary.family_row(_profiles, PICK_FORWARD if pick else ClawTests.CLAW_FORWARD, yaw,
			Profiles.POLICY_READY_FORWARD)
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
		request.room_type = room_type
		request.space_revision = _owner.revision()
		request.origin_u = plan["origin"]
		request.cells = painted if not painted.is_empty() else _grid(width, depth, side)
		request.target_origin = first
		request.access = access; request.work_location = work
		request.travel_profile = forward; request.travel_revision = _profiles._live.quantities[forward]
		request.work_profile = wall; request.work_revision = _profiles._live.quantities[wall]
		request.height_u = mini(4096, Approach.reachable_height_u(_profiles, wall))
		request.face = face; request.yaw = yaw
		@warning_ignore("integer_division") var cubes_high: int = request.height_u / Contract.QUANTUM_SIDE_U
		@warning_ignore("integer_division") var cells: int = request.cells.size() / 2
		painted_cubes = cells * cubes_high
		var made: Buildings.OpResult = orders.confirm_room(request)
		assert_true(made.ok, "the %s room confirmed: %s" % [SIDE_NAMES[side], made.error])
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
		"""The lowest BUILD wall row of the digging mole (claws, or the held pick) at that yaw: its CONTACT_PATCH flat on
		the face the heading strikes and its anchor in the floor band (the Kitchen's own wall row, at +X)."""
		var stride: int = _profiles._profile_capacity
		@warning_ignore("integer_division") var axis: int = Planner.facing_face(provider, yaw) / 2
		for row: int in _profiles._live.header[1]:
			var same: bool = true
			for field: int in [Profiles.F_SOURCE, Profiles.F_SPECIES, Profiles.F_STAGE, Profiles.F_RIG, Profiles.F_TOOL,
					Profiles.F_TOOL_VARIANT, Profiles.F_CARGO, Profiles.F_CARGO_VARIANT]:
				same = same and _profiles._live.fields[field * stride + row] == _profiles._live.fields[field * stride + retreat_row]
			if not same or _profiles._live.fields[Profiles.F_MODE * stride + row] != Profiles.MODE_WORK \
					or _profiles._live.fields[Profiles.F_WORK_KIND * stride + row] != Jobs.JOB_KIND_BUILD \
					or _profiles._live.fields[Profiles.F_CONTACT_KIND * stride + row] != Profiles.CONTACT_ANCHOR_AND_PATCH \
					or _profiles._live.fields[Profiles.F_YAW_KIND * stride + row] != Profiles.YAW_EXACT \
					or _profiles._live.fields[Profiles.F_YAW * stride + row] != yaw: continue
			var anchor: Vector3i = _contact_point(row)
			if anchor.y > 0 and anchor.y < Contract.QUANTUM_SIDE_U and _patch_flat(row, axis): return row
		return -1

	func _patch_flat(row: int, axis: int) -> bool:
		"""The row's CONTACT_PATCH is flat along the axis."""
		var stride: int = _profiles._box_capacity
		for index: int in _profiles._live.fields[Profiles.F_BOX_COUNT * _profiles._profile_capacity + row]:
			var box: int = _profiles._live.fields[Profiles.F_FIRST_BOX * _profiles._profile_capacity + row] + index
			if _profiles._live.boxes[6 * stride + box] == Profiles.CONTACT_PATCH:
				return _profiles._live.boxes[axis * stride + box] == _profiles._live.boxes[(axis + 3) * stride + box]
		return false

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


class Dig extends RefCounted:
	## What one dig did, sampled after every tick.
	var refusals: Array[StringName] = []
	var ticks: int = 0
	var peak_edges: int = 0
	var peak_locations: int = 0
	var peak_checks: int = 0


var _h: SideRooms = null


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % _h.failures)
	_h = null


func _prepared(pick: bool = false) -> bool:
	"""A fresh fixture, its mole digging with its claws or with a held pick."""
	_h = SideRooms.new()
	_h.pick = pick
	return _h.prepared()


func _runtime(room: Vector2i, crew: Array[Builder.Crew]) -> Runtime:
	"""A runtime over the fixture's owners with the room ordered (spoil to its own pile) and started."""
	var runtime: Runtime = Runtime.new(_h._residents.directory())
	assert_true(runtime.bind_owners(_h.owners()), "owners")
	assert_equal(runtime.order_room(room, _h.material, _h.spoil, NULL_REF), &"", "ordered")
	assert_equal(runtime.start_room(room, runtime.bound_owners(), crew), &"", "started")
	return runtime


func _dig(runtime: Runtime, hook: Callable = Callable()) -> Dig:
	"""Every fixed tick to the end, topping M up, sampling the live graph and the last sealed route proof's checks."""
	var run: Dig = Dig.new()
	for step: int in TICK_BOUND:
		_h.top_up()
		_h.tick += 1
		run.refusals.append_array(runtime.advance(_h.tick))
		run.ticks += 1
		run.peak_edges = maxi(run.peak_edges, _h._routes._live.edge_count)
		run.peak_locations = maxi(run.peak_locations, _h.endpoints._live.count)
		run.peak_checks = maxi(run.peak_checks, _h._binding._proof_checks)
		if hook.is_valid(): hook.call(runtime)
		if not runtime.is_running(): break
	return run


func _dug(room: Vector2i) -> int:
	"""A room's Sites that are supported voids with no live phase."""
	var count: int = 0
	for row: int in _h.sites._count:
		if _h.sites._present[row] == 1 and _h.sites._room(row) == room and _h.sites._phase[row] == Sites.SUPPORTED_VOID \
				and _h.sites.project_of(Vector2i(row, Sites.SITE_GENERATION)) == NULL_REF:
			count += 1
	return count


func dig_matrix(side: int, width: int, depth: int, room_type: int = KITCHEN, pick: bool = false,
		cells: PackedInt32Array = PackedInt32Array()) -> void:
	"""One room of the matrix (the width x depth grid, or the cells given), dug whole by one mole with no refusal,
	every BRACE paid once, the live graph and the route proof kept under their bounds by retirement."""
	if not _prepared(pick): return
	_h.painted = cells
	var room: Vector2i = _h.side_room(side, width, depth, room_type)
	if room == NULL_REF: return
	var run: Dig = _dig(_runtime(room, [_h.crew_member()] as Array[Builder.Crew]))
	print("ROOM-MATRIX %s %dx%d type=%d pick=%s cubes=%d ticks=%d peak_edges=%d peak_locations=%d peak_checks=%d" % [
		SIDE_NAMES[side], width, depth, room_type, pick, _h.painted_cubes, run.ticks, run.peak_edges, run.peak_locations,
		run.peak_checks])
	assert_equal(run.refusals, [] as Array[StringName], "no refusal")
	assert_equal(_dug(room), _h.painted_cubes, "every cube dug")
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")
	assert_true(_h._budget.is_quiescent(), "no cold lease left")
	assert_equal(_h.wood_made - _h.free_milli(_h.material, &"wood"), _h.painted_cubes * Contract.BRACE_WOOD_MILLI,
		"every BRACE's wood paid exactly once")
	assert_true(run.peak_edges <= Retirement.RETIRE_FROM_EDGES + CHAIN_EDGES,
		"the live graph stays within one chain of the retirement bound: %d" % run.peak_edges)
	assert_true(run.peak_checks < Space.MAX_CHECKS, "every route proof within its checks: %d" % run.peak_checks)

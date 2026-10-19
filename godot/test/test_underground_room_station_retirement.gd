extends "res://test/framework/test_case.gd"
## Decision 1942: retiring a finished column's station chain. The claw Kitchen fixture (decision 1939: content 12's
## claw rows, the painted 4 quanta of each cell) with its room painted larger. Every owner is the real one; the only
## fixture logistics are the stock M is topped up with (a BRACE's wood and stone; the game hauls them in) and larger
## fixture arenas for the larger room.

const ClawTests := preload("res://test/test_underground_room_claw_kitchen.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Retirement := preload("res://scripts/core/underground_room_station_retirement.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Needs := preload("res://scripts/core/needs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TICK_BOUND: int = 200000
## The large room (decision 1942's proof): on master its dig refuses at cube 72 of 96, its route proof out of budget
## at 100 live edges (SPACE_COMPANION_PREPARATION_REFUSED).
const LARGE_WIDTH: int = 6
const LARGE_DEPTH: int = 4
## A crowded level: the edges of other paths already published elsewhere in the Corridor, so a Kitchen-size dig runs
## with retirement due from its first cube (fixture geometry only: parallel ground spans between two endpoints far
## from the room, which no builder walks).
const CROWD_EDGES: int = Retirement.RETIRE_FROM_EDGES
const CROWD_A: Vector3i = Vector3i(Phase.X - 3584, Phase.FLOOR, Phase.Z - 1536)
const CROWD_B: Vector3i = Vector3i(Phase.X - 2560, Phase.FLOOR, Phase.Z - 1536)
## One chain's edges at most: each station joined both ways to the one before it.
const CHAIN_EDGES: int = 2 * Retirement.MAX_CHAIN


class LargeRoom extends ClawTests.ClawKitchen:
	## The claw Kitchen with `width` x `depth` cells painted, its spoil on its own pile, and larger fixture arenas.
	var width: int = 2
	var depth: int = 2
	var spoil: Vector2i = NULL_REF
	var crowd_a: Vector2i = NULL_REF
	var crowd_b: Vector2i = NULL_REF

	func _actual_profiles() -> void:
		"""The claw Kitchen's own profile owners, with a reservation pool as large as the fixture's lot arena."""
		_pool = Pool.new(64, Pool.JOB_CAPACITY, lot_capacity); _piles = Piles.new()
		assert_true(_piles.bind_stores(_inventory, _buildings, StockAge.new(_inventory)), "actual piles")
		assert_true(_piles.bind_world(_world_ref), "exact World")
		_carry = Carry.new(); assert_true(_carry.bind(_inventory, _pool, _residents, _piles), "actual cargo")
		_gear = Gear.new(16)
		assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear")
		_work = Work.new(_jobs); assert_true(_work.bind_gear(_gear).ok, "actual Work")
		_profiles = Profiles.new()
		assert_equal(_profiles.configure(ClawTests.ProfileCatalog.PROFILE_COUNT, ClawTests.ProfileCatalog.BOX_COUNT,
			ClawTests.ProfileCatalog.SOURCE_COUNT, ClawTests.ProfileCatalog.PAIRED_BANK_BYTES
			+ ClawTests.ProfileCatalog.CONTROL_RESERVE), &"", "the mounted profile bank")
		assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"",
			"actual source owners")
		assert_equal(_profiles.load_file(ClawTests.Bundle.PROFILE_PATH, ClawTests.Bundle.PROFILE_SHA, ClawTests.CLAW_CONTENT),
			&"", "mounted content-12 wire")

	func _load_catalog(revision: int) -> StringName:
		"""The game's ground-pace catalog's own 26 paced rows (`qualified-stairs-v10/ground-pace.ugconn`: 1-12, 31,
		32, 37 and 42-52), each at the existing Movement rate: no pace is authored. Every paced row an edge admits is
		certified on it, so the route proof's cost per edge is the game's (decision 1942 §1)."""
		var bytes: PackedByteArray = Phase.GroupFixture._catalog_wire(4, revision)
		var rows: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 31, 32, 37, 42, 43, 44, 45,
			46, 47, 48, 49, 50, 51, 52])
		bytes.encode_u32(44, rows.size()); bytes.encode_s64(48, ClawTests.CLAW_CONTENT)
		bytes.resize(bytes.size() - 80)
		for profile: int in rows:
			Phase.GroupFixture.Fixture._append_row(bytes, PackedInt32Array([profile, -1, 0, 1, 1, 0, Catalog.RATE_GROUND_CAP]), 1)
		var digest: PackedByteArray = PackedByteArray(); digest.resize(32)
		assert_true(_profiles.source_hash_into(0, ClawTests.CLAW_CONTENT, digest), "actual original actor source")
		for index: int in 32: bytes[72 + index] = digest[index]
		bytes.append_array("UGCEND01".to_ascii_buffer())
		return _catalog.load_file(TEMP, _write(TEMP, bytes), revision)

	func room_request() -> Approach.Request:
		"""The Kitchen's request with the larger painted grid (cells z-major, as the order reads them)."""
		var request: Approach.Request = super.room_request()
		var cells: PackedInt32Array = PackedInt32Array()
		for z: int in depth:
			for x: int in width:
				cells.append(x); cells.append(z)
		request.cells = cells
		return request

	func confirmed_room() -> Vector2i:
		"""Arenas sized for the larger room, then the Kitchen's own confirmation, with a spoil pile at the access."""
		location_capacity = 512; edge_capacity = 512; lot_capacity = 4096; site_capacity = 1024
		stocked = true
		_actual_fixture(); connect_source_paths(); finite_stock_and_worker()
		if not failures.is_empty(): return NULL_REF
		var pile: Inventory.OpResult = _inventory.create_spatial_ground_staging(_first)
		assert_true(pile.ok, "the spoil pile: %s" % pile.error)
		spoil = pile.ref
		var made: Buildings.OpResult = orders.confirm_room(room_request())
		assert_true(made.ok, "confirmation: %s" % made.error)
		return made.ref if made.ok else NULL_REF

	func crowd(edges: int) -> void:
		"""`edges` parallel ground spans, both ways in turn, between two Corridor endpoints, in one publication."""
		if crowd_a == NULL_REF:
			crowd_a = _endpoint(CROWD_A, Locations.ROLE_TRANSIT)
			crowd_b = _endpoint(CROWD_B, Locations.ROLE_TRANSIT)
		var a: Vector2i = crowd_a
		var b: Vector2i = crowd_b
		var token: int = _begin()
		for index: int in edges:
			var reverse: bool = index % 2 == 1
			var edge: Routes.Edge = _edge()
			edge.from_location = b if reverse else a; edge.to_location = a if reverse else b
			var from: Vector3i = CROWD_B if reverse else CROWD_A
			var to: Vector3i = CROWD_A if reverse else CROWD_B
			edge.points = PackedInt32Array([from.x, from.y, from.z, to.x, to.y, to.z])
			edge.length_u = absi(to.x - from.x)
			assert_equal(_routes.stage_add(token, edge).error, &"", "a crowding span")
		assert_equal(_binding.seal(token), &"", "crowding spans certified")
		assert_equal(_binding.publish(token), &"", "crowding spans published")
		_end(token)

	func top_up() -> void:
		"""Fixture logistics: M never holds fewer than four BRACEs of wood and of stone."""
		if _inventory.lot_quantity_milli(stock_wood) < 4 * Contract.BRACE_WOOD_MILLI:
			stock_wood = stock(&"wood", 40 * Contract.BRACE_WOOD_MILLI)
		if _inventory.lot_quantity_milli(stock_stone) < 4 * Contract.BRACE_STONE_MILLI:
			stock_stone = stock(&"stone", 40 * Contract.BRACE_STONE_MILLI)


var _h: LargeRoom = null
var _kitchen: Vector2i = NULL_REF


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % _h.failures)
	_h = null
	_kitchen = NULL_REF


func _room(width: int, depth: int, crowded: bool = false) -> Vector2i:
	"""A confirmed claw room of width x depth cells, on a crowded level when asked."""
	_h = LargeRoom.new()
	_h.width = width; _h.depth = depth
	var room: Vector2i = _h.confirmed_room()
	if room != NULL_REF and crowded: _h.crowd(CROWD_EDGES)
	return room


func _runtime(room: Vector2i, crew: Array[Builder.Crew]) -> Runtime:
	"""A runtime over the fixture's owners with the room ordered (spoil to its own pile) and started."""
	var runtime: Runtime = Runtime.new(_h._residents.directory())
	assert_true(runtime.bind_owners(_h.owners()), "owners")
	assert_equal(runtime.order_room(room, _h.material, _h.spoil, NULL_REF), &"", "ordered")
	assert_equal(runtime.start_room(room, runtime.bound_owners(), crew), &"", "started")
	return runtime


class Run extends RefCounted:
	## What one dig did, sampled after every tick.
	var refusals: Array[StringName] = []
	var peak_edges: int = 0
	var peak_locations: int = 0
	var peak_checks: int = 0
	var retirements: int = 0
	var ticks: int = 0


func _dig(runtime: Runtime, hook: Callable = Callable()) -> Run:
	"""Every fixed tick to the end, topping M up; the route proof's checks are read after each tick (the last sealed
	proof), and a retirement is a tick whose live Location count fell."""
	var run: Run = Run.new()
	for step: int in TICK_BOUND:
		_h.top_up()
		_h.tick += 1
		var before: int = _h.endpoints._live.count
		run.refusals.append_array(runtime.advance(_h.tick))
		if _h.endpoints._live.count < before: run.retirements += 1
		run.peak_edges = maxi(run.peak_edges, _h._routes._live.edge_count)
		run.peak_locations = maxi(run.peak_locations, _h.endpoints._live.count)
		run.peak_checks = maxi(run.peak_checks, _h._binding._proof_checks)
		run.ticks += 1
		if hook.is_valid(): hook.call(runtime)
		if not runtime.is_running(): break
	return run


func _work_stations() -> Array[Vector2i]:
	"""Every live WORK endpoint (the Kitchen's stations; the Corridor's fixture endpoints are TRANSIT or STORAGE)."""
	var out: Array[Vector2i] = []
	var bank: Locations.Bank = _h.endpoints._live
	for row: int in _h.endpoints._capacity:
		if bank.present[row] == 1 and bank.i32[Locations.ROLE * _h.endpoints._capacity + row] == Locations.ROLE_WORK:
			out.append(Vector2i(row, bank.i32[Locations.GENERATION * _h.endpoints._capacity + row]))
	return out


func test_the_kitchen_digs_as_before_below_the_edge_bound() -> void:
	"""The 16-Site claw Kitchen never reaches RETIRE_FROM_EDGES: nothing is retired and its graph ends as on master
	(20 edges, 11 Locations, decision 1934's measurement)."""
	var room: Vector2i = _room(2, 2)
	if room == NULL_REF: return
	var runtime: Runtime = _runtime(room, [_h.crew_member()] as Array[Builder.Crew])
	var run: Run = _dig(runtime)
	assert_equal(run.refusals, [] as Array[StringName], "no refusal")
	assert_true(run.peak_edges < Retirement.RETIRE_FROM_EDGES, "below the bound: %d edges" % run.peak_edges)
	assert_equal(run.retirements, 0, "nothing retired")
	assert_equal(_h._routes._live.edge_count, 20, "every chain kept")
	assert_equal(_h.endpoints._live.count, 11, "every station kept")


class Published extends RefCounted:
	## Counts every Location row allocated after a snapshot (a new row, or a reused row's new generation), however a
	## tick nets publications against retirements.
	var generations: PackedInt32Array = PackedInt32Array()
	var added: int = 0

	func _init(locations: Locations) -> void:
		"""The live rows' generations now (-1 for a free row)."""
		generations.resize(locations._capacity)
		_read(locations)

	func count(_runtime: Runtime, locations: Locations) -> void:
		"""After a tick: every row live now that was not live, or was live at another generation, is a publication."""
		var bank: Locations.Bank = locations._live
		for row: int in locations._capacity:
			var now: int = bank.i32[Locations.GENERATION * locations._capacity + row] if bank.present[row] == 1 else -1
			if now >= 0 and now != generations[row]: added += 1
			generations[row] = now

	func _read(locations: Locations) -> void:
		"""Snapshot."""
		for row: int in locations._capacity:
			generations[row] = locations._live.i32[Locations.GENERATION * locations._capacity + row] \
				if locations._live.present[row] == 1 else -1


var _held_stations: Array[Vector2i] = []
var _held_sites: Array[Vector2i] = []
var _early: int = 0


func _watch_column(runtime: Runtime, room: Vector2i, published: Published) -> void:
	"""After each tick: count publications, and for each builder whose station of the tick before is gone, every Site
	in its cube's column is dug (the test's own reading of the Sites, not the foreman's)."""
	if published != null: published.count(runtime, _h.endpoints)
	for at: int in _held_stations.size():
		if _held_stations[at] != NULL_REF and not _h.endpoints.is_live_location(_held_stations[at]) \
				and not _column_dug(_held_sites[at]):
			_early += 1
	_held_stations.clear(); _held_sites.clear()
	var foreman: Foreman = runtime.foreman_of(room)
	if foreman == null: return
	for builder: Builder in foreman.builders():
		_held_stations.append(builder.station()); _held_sites.append(builder.last_site())


func _column_dug(site: Vector2i) -> bool:
	"""Every Site keyed in the same column as `site` is a supported void with no live phase."""
	if site == NULL_REF: return false
	var plane: int = _h.sites._domain.size_quanta.x * _h.sites._domain.size_quanta.z
	var column: int = _h.sites._site_key[site.x] % plane
	for row: int in _h.sites._count:
		if _h.sites._present[row] != 1 or _h.sites._site_key[row] % plane != column: continue
		if _h.sites._phase[row] != Sites.SUPPORTED_VOID or _h.sites.project_of(Vector2i(row, Sites.SITE_GENERATION)) != NULL_REF:
			return false
	return true


func _published_in_dig(crowded: bool) -> Array[int]:
	"""One claw Kitchen dug by one builder: the Locations it published, the chains retired and those retired before
	their column was dug."""
	var room: Vector2i = _room(2, 2, crowded)
	if room == NULL_REF: return [-1, -1, -1] as Array[int]
	var published: Published = Published.new(_h.endpoints)
	_held_stations.clear(); _held_sites.clear(); _early = 0
	var runtime: Runtime = _runtime(room, [_h.crew_member()] as Array[Builder.Crew])
	var run: Run = _dig(runtime, _watch_column.bind(room, published))
	assert_equal(run.refusals, [] as Array[StringName], "no refusal")
	after_each()
	return [published.added, run.retirements, _early] as Array[int]


func test_a_column_is_retired_only_once_it_is_done() -> void:
	"""Each column's chain goes only once the column is dug: on a crowded level (retirement due from the first cube) no
	station is retired while a cube of its column is still to dig, and the dig publishes exactly the Locations an
	uncrowded one does."""
	var plain: Array[int] = _published_in_dig(false)
	var crowded: Array[int] = _published_in_dig(true)
	assert_true(crowded[1] > 0, "the crowded dig retired chains: %d" % crowded[1])
	assert_equal(plain[1], 0, "the plain dig retired none")
	assert_equal(crowded[2], 0, "no station retired before its column was dug")
	assert_equal(crowded[0], plain[0], "the same publications however crowded")


func test_retirement_is_due_from_the_bound() -> void:
	"""`due` holds from RETIRE_FROM_EDGES live edges, not one fewer."""
	var room: Vector2i = _room(2, 2)
	if room == NULL_REF: return
	var missing: int = Retirement.RETIRE_FROM_EDGES - 1 - _h._routes._live.edge_count
	_h.crowd(missing)
	assert_equal(_h._routes._live.edge_count, Retirement.RETIRE_FROM_EDGES - 1, "one short of the bound")
	assert_false(Retirement.due(_h._routes), "not due")
	_h.crowd(1)
	assert_true(Retirement.due(_h._routes), "due at the bound")


func test_retiring_every_finished_chain_returns_the_graph_to_its_start() -> void:
	"""After the Kitchen is dug and its crew is out, each chain walked back from a WORK station ends next to the gateway
	and holds only stations; retiring all of them leaves exactly the graph and Locations the dig started from, less
	the fixture's own first contact (ADR 1161's authored WORK station on the access line, `_last`, and its two spans):
	that is a station of the first column too."""
	var room: Vector2i = _room(2, 2)
	if room == NULL_REF: return
	var edges: int = _h._routes._live.edge_count
	var locations: int = _h.endpoints._live.count
	var runtime: Runtime = _runtime(room, [_h.crew_member()] as Array[Builder.Crew])
	assert_equal(_dig(runtime).refusals, [] as Array[StringName], "dug")
	var stations: Array[Vector2i] = _work_stations()
	assert_equal(stations.size(), 4, "one WORK station a column")
	assert_true(stations.has(_h._last), "the authored first contact is one of them")
	var none: Array[Foreman] = []
	var chain: PackedInt32Array = PackedInt32Array()
	for work: Vector2i in stations:
		var count: int = Retirement.chain_into(_h.endpoints, _h._routes, work, _h.provider._ordinary_retreat, none, chain)
		assert_true(count >= 1 and count <= Retirement.MAX_CHAIN, "a chain of %d stations" % count)
		assert_equal(Vector2i(chain[0], chain[1]), work, "the walk starts at the WORK station")
		assert_equal(Retirement.retire(_h._binding, _h._routes, _h.endpoints, _h._budget, chain), &"", "retired")
		for at: int in range(0, chain.size(), 2):
			assert_false(_h.endpoints.is_live_location(Vector2i(chain[at], chain[at + 1])), "station gone")
	assert_equal(_h._routes._live.edge_count, edges - 2, "the start's edges, less the first contact's two")
	assert_equal(_h.endpoints._live.count, locations - 1, "the start's Locations, less the first contact")
	assert_true(_h._budget.is_quiescent(), "no cold lease outlives a retirement")


func _dug_kitchen() -> bool:
	"""The 16-Site claw Kitchen dug to the end, its crew out."""
	var room: Vector2i = _room(2, 2)
	_kitchen = room
	if room == NULL_REF: return false
	var runtime: Runtime = _runtime(room, [_h.crew_member()] as Array[Builder.Crew])
	var run: Run = _dig(runtime)
	assert_equal(run.refusals, [] as Array[StringName], "dug")
	return run.refusals.is_empty() and not runtime.is_running()


func _longest_chain(chain: PackedInt32Array) -> Vector2i:
	"""The WORK station whose chain is longest, with that chain in `chain`."""
	var none: Array[Foreman] = []
	var best: Vector2i = NULL_REF
	var most: int = 0
	for work: Vector2i in _work_stations():
		var count: int = Retirement.chain_into(_h.endpoints, _h._routes, work, _h.provider._ordinary_retreat, none, chain)
		if count > most:
			most = count; best = work
	Retirement.chain_into(_h.endpoints, _h._routes, best, _h.provider._ordinary_retreat, none, chain)
	return best


func test_a_retirement_refused_before_either_publication_changes_nothing() -> void:
	"""A busy cold lease, a station a route actor stands on, an empty chain or a missing owner: every refusal comes
	before either publication, so the graph, the Locations and the lease are exactly as they were."""
	if not _dug_kitchen(): return
	var chain: PackedInt32Array = PackedInt32Array()
	_longest_chain(chain)
	var edges: int = _h._routes._live.edge_count
	var locations: int = _h.endpoints._live.count
	var lease: int = _h._budget.acquire(Budget.COLD_BYTES)
	assert_equal(Retirement.retire(_h._binding, _h._routes, _h.endpoints, _h._budget, chain), Budget.REFUSE_BUSY, "busy")
	assert_equal(_h._budget.release(lease), &"", "the other lease")
	var staged: int = _h._owner.begin_stage(_h._owner.revision()).token # An open Space transaction: Locations can't follow.
	assert_true(staged != 0, "a Space stage open")
	assert_equal(Retirement.retire(_h._binding, _h._routes, _h.endpoints, _h._budget, chain), &"LOCATION_GEOMETRY_BUSY",
		"refused before the graph publication, foreseen from Locations")
	assert_true(_h._owner.abort(staged), "the stage closed")
	_h.endpoints._contact_retirement = Locations.ContactRetirementContext.new() # Negative-only: the entry's bracket.
	assert_equal(Retirement.retire(_h._binding, _h._routes, _h.endpoints, _h._budget, chain), Budget.REFUSE_BUSY,
		"the entry's own retirement bracket is open")
	_h.endpoints._contact_retirement = null
	var empty: PackedInt32Array = PackedInt32Array()
	assert_equal(Retirement.retire(_h._binding, _h._routes, _h.endpoints, _h._budget, empty), Retirement.REFUSE_EMPTY, "empty")
	assert_equal(Retirement.retire(null, _h._routes, _h.endpoints, _h._budget, chain), Retirement.REFUSE_OWNER, "owner")
	var work: Vector2i = Vector2i(chain[0], chain[1])
	var mole: Vector2i = _h._worker # The Kitchen's own mole, out of the underground again.
	var at: Vector3i = Retirement.Builder.Claim.point_of(_h.endpoints, work)
	assert_true(_h._transforms.place(mole, at.x, at.y, at.z, ClawTests.StationTests.YAW_PLUS_X), "a mole on the station")
	assert_equal(_h._routes.admit_travel_actor(mole, NULL_REF, work, ClawTests.CLAW_FORWARD,
		_h._profiles._live.quantities[ClawTests.CLAW_FORWARD], ClawTests.CLAW_CONTENT, 0, -1), &"", "standing there")
	assert_equal(Retirement.retire(_h._binding, _h._routes, _h.endpoints, _h._budget, chain), Retirement.REFUSE_RETAINED,
		"retained by the actor standing on it")
	assert_equal(_h._routes._live.edge_count, edges, "no edge removed")
	assert_equal(_h.endpoints._live.count, locations, "no Location removed")
	assert_true(_h._budget.is_quiescent(), "no lease kept")


func test_the_walk_stops_at_a_junction_and_takes_it_once_it_is_free() -> void:
	"""A TRANSIT station another span also leaves from is a junction: the walk stops before it (ADR 1215's gateway
	reuse). Once that span is gone the same walk goes on through it to the gateway."""
	if not _dug_kitchen(): return
	var chain: PackedInt32Array = PackedInt32Array()
	var work: Vector2i = _longest_chain(chain)
	var count: int = chain.size() >> 1
	assert_true(count >= 2, "a chain with a TRANSIT station: %d" % count)
	var transit: Vector2i = Vector2i(chain[chain.size() - 2], chain[chain.size() - 1]) # The one next to the gateway.
	var point: Vector3i = Retirement.Builder.Claim.point_of(_h.endpoints, transit)
	var spot: Vector2i = _h._endpoint(Vector3i(point.x - 1024, point.y, point.z), Locations.ROLE_TRANSIT)
	var spans: PackedInt32Array = _join(transit, spot)
	var none: Array[Foreman] = []
	assert_equal(Retirement.chain_into(_h.endpoints, _h._routes, work, _h.provider._ordinary_retreat, none, chain),
		count - 1, "every station before the junction")
	var token: int = _h._begin()
	for at: int in range(0, spans.size(), 2):
		assert_equal(_h._routes.stage_remove(token, Vector2i(spans[at], spans[at + 1])), &"", "span removed")
	assert_equal(_h._binding.seal(token), &"", "sealed")
	assert_equal(_h._binding.publish(token), &"", "published")
	_h._end(token)
	assert_equal(Retirement.chain_into(_h.endpoints, _h._routes, work, _h.provider._ordinary_retreat, none, chain), count,
		"the whole chain again")
	var foreman: Foreman = Foreman.new()
	var member: Builder.Crew = Builder.Crew.new()
	member.worker = _h._worker; member.parking = transit # A builder parked on the chain's last station holds it.
	var owners: Builder.Owners = _h.owners()
	owners.extents = Builder.Footprint.RowExtents.new()
	assert_equal(foreman.configure(owners, _kitchen, _h.material, _h.spoil,
		NULL_REF, [member] as Array[Builder.Crew]), &"", "a foreman whose builder parks on the chain")
	var holders: Array[Foreman] = [foreman]
	assert_equal(Retirement.chain_into(_h.endpoints, _h._routes, work, _h.provider._ordinary_retreat, holders, chain),
		count - 1, "every station before the one a builder holds")
	var first: Vector3i = Retirement.Builder.Claim.point_of(_h.endpoints, _h._last) # The first column's station.
	assert_equal(Retirement.chain_into(_h.endpoints, _h._routes, _h._last, _h.provider._ordinary_retreat, none, chain), 1,
		"the first column's chain is its station alone, next to the gateway")
	var beside: Vector2i = _h._endpoint(Vector3i(first.x - 1024, first.y, first.z), Locations.ROLE_TRANSIT)
	_join(_h._last, beside)
	assert_equal(Retirement.chain_into(_h.endpoints, _h._routes, _h._last, _h.provider._ordinary_retreat, none, chain), 0,
		"a WORK station another span leaves from is no chain's end")


func _join(from: Vector2i, to: Vector2i) -> PackedInt32Array:
	"""Two straight ground spans between two endpoints (fixture geometry); their edge refs."""
	var a: Vector3i = Retirement.Builder.Claim.point_of(_h.endpoints, from)
	var b: Vector3i = Retirement.Builder.Claim.point_of(_h.endpoints, to)
	var token: int = _h._begin()
	var refs: PackedInt32Array = PackedInt32Array()
	for reverse: bool in [false, true]:
		var edge: Routes.Edge = _h._edge()
		edge.from_location = to if reverse else from; edge.to_location = from if reverse else to
		var p: Vector3i = b if reverse else a
		var q: Vector3i = a if reverse else b
		edge.points = PackedInt32Array([p.x, p.y, p.z, q.x, q.y, q.z])
		edge.length_u = LargeRoom._ceil_length(p - q)
		var added: Routes.Result = _h._routes.stage_add(token, edge)
		assert_equal(added.error, &"", "a joining span")
		refs.append(added.ref.x); refs.append(added.ref.y)
	assert_equal(_h._binding.seal(token), &"", "joining spans sealed")
	assert_equal(_h._binding.publish(token), &"", "joining spans published")
	_h._end(token)
	return refs


func test_a_room_past_the_edge_bound_digs_to_the_end_with_its_finished_chains_retired() -> void:
	"""The large room: once the graph reaches RETIRE_FROM_EDGES each finished column's chain is retired, the live
	graph stays near the bound, and every cube is dug with no refusal, no live Project and no cold lease left."""
	var room: Vector2i = _room(LARGE_WIDTH, LARGE_DEPTH)
	if room == NULL_REF: return
	var runtime: Runtime = _runtime(room, [_h.crew_member()] as Array[Builder.Crew])
	var foreman: Foreman = runtime.foreman_of(room)
	var run: Run = _dig(runtime)
	print("ROOM-RETIREMENT large ticks=%d peak_edges=%d peak_locations=%d peak_checks=%d retired=%d" % [run.ticks,
		run.peak_edges, run.peak_locations, run.peak_checks, run.retirements])
	assert_equal(run.refusals, [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), foreman.total_cubes(), "every cube dug")
	assert_true(run.retirements > 0, "chains retired: %d" % run.retirements)
	assert_true(run.peak_edges <= Retirement.RETIRE_FROM_EDGES + CHAIN_EDGES,
		"the live graph stays within one chain of the bound: %d" % run.peak_edges)
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")
	assert_true(_h._budget.is_quiescent(), "no cold lease outlives the dig")
	assert_equal(runtime.state_of(room), Runtime.RECORD_NONE, "finished, out and released")


func test_without_retirement_the_large_room_runs_out_of_route_budget() -> void:
	"""The same large room dug by its foreman alone (retirement runs in the room runtime, so none happens): every
	finished chain stays, and at 100 live edges a phase commit's route proof exhausts Space.MAX_CHECKS. This is
	master's behaviour, kept as the proof that the room needs retirement."""
	var room: Vector2i = _room(LARGE_WIDTH, LARGE_DEPTH)
	if room == NULL_REF: return
	var foreman: Foreman = Foreman.new()
	var owners: Builder.Owners = _h.owners()
	owners.extents = Builder.Footprint.RowExtents.new()
	assert_equal(foreman.configure(owners, room, _h.material, _h.spoil, NULL_REF, [_h.crew_member()] as Array[Builder.Crew]),
		&"", "configured")
	var code: StringName = &""
	var peak: int = 0
	for step: int in TICK_BOUND:
		_h.top_up()
		_h.tick += 1
		code = foreman.advance(_h.tick)
		peak = maxi(peak, _h._binding._proof_checks)
		if not foreman.is_running(): break
	print("ROOM-RETIREMENT without ticks=%d edges=%d peak_checks=%d done=%d code=%s" % [_h.tick,
		_h._routes._live.edge_count, peak, foreman.done_cubes(), code])
	assert_equal(code, &"SPACE_COMPANION_PREPARATION_REFUSED", "the route proof ran out of checks")
	assert_true(foreman.done_cubes() < foreman.total_cubes(), "the room is not finished: %d" % foreman.done_cubes())
	assert_true(_h._routes._live.edge_count >= 95, "every chain kept: %d edges" % _h._routes._live.edge_count)
	assert_true(peak * 20 > Retirement.Space.MAX_CHECKS * 19, "the last proof spent over 95%% of the budget: %d" % peak)


func test_two_builders_dig_and_only_finished_unheld_chains_go() -> void:
	"""Two claw builders on a crowded level: a chain is retired only once its column is done and neither builder holds
	any of it; both dig, and the Kitchen is finished with no refusal."""
	var room: Vector2i = _room(2, 2, true)
	if room == NULL_REF: return
	var crew: Array[Builder.Crew] = [_h.crew_member(), _h.second_member(ClawTests.SECOND_PARKING)]
	var runtime: Runtime = _runtime(room, crew)
	var foreman: Foreman = runtime.foreman_of(room)
	var builders: Array[Builder] = []
	builders.assign(foreman.builders())
	_held_stations.clear(); _held_sites.clear(); _early = 0
	var run: Run = _dig(runtime, _two_builder_watch.bind(room, builders))
	assert_equal(run.refusals, [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), foreman.total_cubes(), "every cube dug")
	assert_equal(_early, 0, "no station retired before its column was dug")
	assert_true(builders[0].cubes() > 0 and builders[1].cubes() > 0, "both dug")
	assert_true(run.retirements > 0, "chains retired: %d" % run.retirements)
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")


func _two_builder_watch(runtime: Runtime, room: Vector2i, builders: Array[Builder]) -> void:
	"""Both after-tick checks of the two-builder dig."""
	_assert_nothing_held_was_retired(runtime, builders)
	_watch_column(runtime, room, null)


func _assert_nothing_held_was_retired(_runtime_now: Runtime, builders: Array[Builder]) -> void:
	"""After every tick, every endpoint any builder names is live: what a builder at work holds is never retired, and
	an idle builder that named a retired station has forgotten it (a save names only live endpoints)."""
	for builder: Builder in builders:
		if not builder.underground(): continue
		var named: PackedInt32Array = PackedInt32Array()
		for at: Vector2i in [builder.station(), builder._at, builder._plan.start, builder._plan.store]:
			named.append(at.x); named.append(at.y)
		for legs: PackedInt32Array in [builder._legs, builder._plan.home_legs, builder._plan.approach_legs,
				builder._plan.store_legs, builder._plan.stands]:
			named.append_array(legs)
		for at: int in range(0, named.size(), 2):
			var ref: Vector2i = Vector2i(named[at], named[at + 1])
			if ref != NULL_REF and not _h.endpoints.is_live_location(ref):
				assert_true(false, "builder %d names a retired endpoint %s (stage %d)" % [builders.find(builder), ref,
					builder.stage()])
				return

func test_a_room_stopped_after_retirements_and_ordered_again_is_finished() -> void:
	"""The Kitchen on a crowded level stopped partway, after chains were retired, while its builder earns a paid phase: the stopped
	dig keeps that phase and its station (the builder holds it), the crew walks out, and the room ordered again with
	another mole takes the phase over and is dug to the end, retiring chains as before. (The stop is the negative-only
	injection decision 1938's resume test uses, a death; C3 adds the player's own "Stop digging".)"""
	var room: Vector2i = _room(2, 2, true)
	if room == NULL_REF: return
	var runtime: Runtime = _runtime(room, [_h.crew_member()] as Array[Builder.Crew])
	var foreman: Foreman = runtime.foreman_of(room)
	var builder: Builder = foreman.builders()[0]
	var retired: int = 0
	for step: int in TICK_BOUND:
		_h.top_up()
		_h.tick += 1
		var before: int = _h.endpoints._live.count
		assert_equal(runtime.advance(_h.tick), [] as Array[StringName], "no refusal before the stop")
		retired += 1 if _h.endpoints._live.count < before else 0
		if retired >= 2 and builder.stage() == Builder.STAGE_EARN and builder.accepted_mwu() > 0: break
	assert_equal(builder.stage(), Builder.STAGE_EARN, "earning a paid phase after %d retirements" % retired)
	var station: Vector2i = builder.station()
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	_h._jobs.needs()._status[row] = Needs.STATUS_DEAD # Negative-only: the dig stops mid-phase (decision 1938's way).
	_h._jobs.needs()._health[row] = 0
	var stopped: Run = _dig(runtime)
	assert_equal(stopped.refusals, [Builder.REFUSE_LOST] as Array[StringName], "stopped by the loss")
	assert_equal(runtime.state_of(room), Runtime.RECORD_STOPPED, "stopped, its crew out")
	assert_true(_h.endpoints.is_live_location(station), "the paid phase's station kept")
	assert_equal(_h._construction.live_project_count(), 1, "the paid phase kept")
	assert_equal(stopped.retirements, 0, "a stopped dig offers no chain")
	assert_true(_h.endpoints.is_live_location(station), "its station still live after the walk out")
	assert_equal(runtime.release_room(room), &"", "released")
	var second: Builder.Crew = _h.second_member(ClawTests.SECOND_PARKING)
	assert_equal(runtime.order_room(room, _h.material, _h.spoil, NULL_REF), &"", "ordered again")
	assert_equal(runtime.start_room(room, runtime.bound_owners(), [second] as Array[Builder.Crew]), &"", "started again")
	var again: Foreman = runtime.foreman_of(room)
	var run: Run = _dig(runtime)
	assert_equal(run.refusals, [] as Array[StringName], "no refusal after the re-order")
	assert_equal(again.done_cubes(), again.total_cubes(), "every cube dug")
	assert_true(run.retirements > 0, "chains retired after the re-order: %d" % run.retirements)
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")
	assert_true(_h._budget.is_quiescent(), "no cold lease left")


func test_a_retiring_dig_restored_before_every_tick_ends_as_the_uninterrupted_dig() -> void:
	"""ARCH-SAVE-006 through retirement: two worlds dig the Kitchen on a crowded level, so retirement is due throughout;
	A's runtime is saved and restored into a fresh runtime before every tick. Retirement reads only saved state (the record, Routes,
	Locations and Sites), so both retire the same chains on the same ticks: after every tick the two records are the
	same bytes, and at the end so are the two graphs and Locations banks."""
	var b_fixture: LargeRoom = LargeRoom.new()
	var room_b: Vector2i = b_fixture.confirmed_room()
	if room_b != NULL_REF: b_fixture.crowd(CROWD_EDGES)
	var room_a: Vector2i = _room(2, 2, true)
	if room_a == NULL_REF or room_b == NULL_REF:
		b_fixture.after_each()
		return
	var a: Runtime = _runtime(room_a, [_h.crew_member()] as Array[Builder.Crew])
	var b: Runtime = Runtime.new(b_fixture._residents.directory())
	assert_true(b.bind_owners(b_fixture.owners()), "owners b")
	assert_equal(b.order_room(room_b, b_fixture.material, b_fixture.spoil, NULL_REF), &"", "ordered b")
	assert_equal(b.start_room(room_b, b.bound_owners(), [b_fixture.crew_member()] as Array[Builder.Crew]), &"", "started b")
	var swaps: int = 0
	var retired: int = 0
	for step: int in TICK_BOUND:
		if Retirement.due(_h._routes):
			a = _swap(a)
			swaps += 1
		for fixture: LargeRoom in [_h, b_fixture]:
			fixture.top_up()
			fixture.tick += 1
		var before: int = _h.endpoints._live.count
		assert_equal(a.advance(_h.tick).duplicate(), b.advance(b_fixture.tick).duplicate(), "same refusals")
		retired += 1 if _h.endpoints._live.count < before else 0
		if not _same_record(a, b): break
		if not a.is_running() and not b.is_running(): break
	assert_false(a.is_running() or b.is_running(), "both digs finished")
	assert_true(swaps > 1000 and retired >= 3, "restored before %d ticks, %d retirements" % [swaps, retired])
	assert_true(_image(_h._routes) == _image(b_fixture._routes, b_fixture._budget), "the same graph")
	assert_true(_image(_h.endpoints) == _image(b_fixture.endpoints, b_fixture._budget), "the same Locations")
	b_fixture.after_each()
	assert_true(b_fixture.failures.is_empty(), "fixture b: %s" % b_fixture.failures)


func _swap(runtime: Runtime) -> Runtime:
	"""Save the runtime and restore it into a fresh one over the same owners; the restored one saves the same bytes."""
	var bytes: PackedByteArray = PackedByteArray()
	assert_equal(runtime.capture(bytes), &"", "captured")
	var fresh: Runtime = Runtime.new(_h._residents.directory())
	assert_true(fresh.bind_owners(runtime.bound_owners()), "owners bound")
	assert_equal(fresh.restore(bytes), &"", "restored")
	var again: PackedByteArray = PackedByteArray()
	assert_equal(fresh.capture(again), &"", "captured again")
	assert_true(again == bytes, "the restored runtime saves the same record")
	return fresh


func _same_record(a: Runtime, b: Runtime) -> bool:
	"""Both runtimes save the same bytes."""
	var bytes_a: PackedByteArray = PackedByteArray()
	var bytes_b: PackedByteArray = PackedByteArray()
	assert_equal(a.capture(bytes_a), &"", "a captured")
	assert_equal(b.capture(bytes_b), &"", "b captured")
	assert_true(bytes_a == bytes_b, "the same record")
	return bytes_a == bytes_b


func _image(owner: Object, budget: Budget = null) -> PackedByteArray:
	"""An owner's own capture under a cold lease (Routes or Locations)."""
	var lease_owner: Budget = budget if budget != null else _h._budget
	var cold: int = lease_owner.acquire(Budget.COLD_BYTES)
	var image: PackedByteArray = PackedByteArray()
	assert_equal(owner.call(&"capture_state_into", cold, image), &"", "captured")
	assert_equal(lease_owner.release(cold), &"", "lease returned")
	return image

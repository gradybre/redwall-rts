extends "res://test/framework/test_case.gd"
## ADR1213 Room-station planner over the ADR1161 Room geometry (2x2 level-1 Kitchen, old Corridor). DEC-054 clamps the
## painted 4 m to the 2 m the published WORK rows dig from the floor, so the Kitchen has 8 cubes.
## The literal v3 fixture keeps its historical content; the loop fixture swaps in the mounted content-6 rows only.
## Every plan is proved by the actual publish_into, contact_into and paid phase owners; nothing is injected.

const Phase := preload("res://test/test_underground_room_world_phases.gd")
const PublicationTests := preload("res://test/test_underground_room_frontier_publication.gd")
const Planner := preload("res://scripts/core/underground_room_station_planner.gd")
const Itinerary := preload("res://scripts/core/underground_room_itinerary.gd")
const Publication := preload("res://scripts/core/underground_room_frontier_publication.gd")
const Frontier := preload("res://scripts/core/underground_room_frontier.gd")
const Face := preload("res://scripts/core/underground_work_face.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const MoleCatalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const StonePins := preload("res://data/underground/mole-worker/qualified-stone-v7/catalog_source.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const CONTENT: int = MoleCatalog.CONTENT_REVISION
const KITCHEN_SITES: int = 8 # DEC-054: 2 x 2 x the two reachable levels.
const YAW_PLUS_X: int = 49152


class StepFixture extends Phase.SourceFixture:
	## Mounted content-6 rows (finite 232u step, canonical ground) over the unchanged ADR1161 Room geometry.
	var parking: Vector2i = NULL_REF
	var contact_location: Vector2i = NULL_REF
	var legs: Array[Vector2i] = []
	var leg_profiles: PackedInt32Array = PackedInt32Array()
	var work_profile: int = -1
	var published: PackedInt32Array = PackedInt32Array() # Station count of each publication, in loop order.
	var admitted: bool = false
	var last_key: int = -1
	var last_site: Vector2i = NULL_REF
	var completed: PackedInt32Array = PackedInt32Array()
	var refusals: Dictionary = {}
	var peaks: PackedInt64Array = PackedInt64Array([0, 0, 0, 0]) # publication route/Location, phase route/Location

	func _actual_profiles() -> void:
		"""The exact mounted wire, pinned by its published digest; no box, flag or policy is edited."""
		_pool = Pool.new(64, Pool.JOB_CAPACITY, 64); _piles = Piles.new()
		assert_true(_piles.bind_stores(_inventory, _buildings, StockAge.new(_inventory)), "actual piles")
		assert_true(_piles.bind_world(_world_ref), "exact World")
		_carry = Carry.new(); assert_true(_carry.bind(_inventory, _pool, _residents, _piles), "actual cargo")
		_gear = Gear.new(16)
		assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear")
		_work = Work.new(_jobs); assert_true(_work.bind_gear(_gear).ok, "actual Work")
		_profiles = Profiles.new()
		assert_equal(_profiles.configure(MoleCatalog.PROFILE_COUNT, MoleCatalog.BOX_COUNT, MoleCatalog.SOURCE_COUNT,
			MoleCatalog.PAIRED_BANK_BYTES + Profiles.CONTROL_RESERVE), &"", "content-6 two-bank arena")
		assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual source owners")
		assert_equal(_profiles.load_file(MoleCatalog.WIRE_PATH, StonePins.WIRE_SHA, CONTENT), &"", "mounted content-6 wire")

	func _load_catalog(revision: int) -> StringName:
		"""Selected, finite-step and canonical-ground rows inherit the existing Movement rate (RATE_GROUND_CAP)."""
		var bytes: PackedByteArray = Phase.GroupFixture._catalog_wire(4, revision)
		var rows: PackedInt32Array = PackedInt32Array([5, 9, 10, 11, 12])
		bytes.encode_u32(44, rows.size()); bytes.encode_s64(48, CONTENT)
		bytes.resize(bytes.size() - 80)
		for profile: int in rows:
			Phase.GroupFixture.Fixture._append_row(bytes, PackedInt32Array([profile, -1, 0, 1, 1, 0, Catalog.RATE_GROUND_CAP]), 1)
		var digest: PackedByteArray = PackedByteArray(); digest.resize(32)
		assert_true(_profiles.source_hash_into(0, CONTENT, digest), "actual original actor source")
		for index: int in 32: bytes[72 + index] = digest[index]
		bytes.append_array("UGCEND01".to_ascii_buffer())
		return _catalog.load_file(TEMP, _write(TEMP, bytes), revision)

	func _edge() -> Routes.Edge:
		"""Only the source revision differs from the historical corridor span."""
		var edge: Routes.Edge = super._edge()
		edge.content_revision = CONTENT
		return edge

	func room_request() -> Approach.Request:
		"""The content-6 FRONT row at the historical yaw is v3 row 24 shifted by the three new travel rows."""
		var request: Approach.Request = super.room_request()
		request.work_profile = 27; request.content_revision = CONTENT
		return request

	func connect_source_paths() -> void:
		"""As in ADR1161's lateral test: a real Corridor parking endpoint keeps new spans free of the worker."""
		parking = _endpoint(Vector3i(Phase.X - 3072, Phase.FLOOR, Phase.Z + 512), Locations.ROLE_TRANSIT)
		super.connect_source_paths()
		var token: int = _begin()
		for reverse: bool in [false, true]:
			var edge: Routes.Edge = _edge()
			edge.from_location = parking if reverse else _first; edge.to_location = _first if reverse else parking
			edge.points = PackedInt32Array([Phase.X - 3072 if reverse else Phase.X - 1024, Phase.FLOOR, Phase.Z + 512,
				Phase.X - 1024 if reverse else Phase.X - 3072, Phase.FLOOR, Phase.Z + 512]); edge.length_u = 2048
			assert_equal(_routes.stage_add(token, edge).error, &"", "complete real parking span")
		assert_equal(_binding.seal(token), &"", "parking certificates")
		assert_equal(_binding.publish(token), &"", "parking graph publication")
		_end(token)

	func finite_stock_and_worker() -> void:
		"""One brace bill per Kitchen Site, so material never decides which cubes the loop reaches."""
		storage_binding = Locations.InventoryLocations.new(endpoints)
		assert_true(_inventory.bind_spatial_locations(storage_binding, 4).ok, "actual storage authority")
		var made: Inventory.OpResult = _inventory.create_spatial_ground_staging(_first)
		assert_true(made.ok, "finite material/refund/spoil store: %s" % made.error)
		material = made.ref; storage = _first
		stock_wood = stock(&"wood", KITCHEN_SITES * Contract.BRACE_WOOD_MILLI)
		stock_stone = stock(&"stone", KITCHEN_SITES * Contract.BRACE_STONE_MILLI)
		tool = stock(&"tool", 1000)
		assert_true(_gear.create_gear(_inventory, _items, tool, Gear.MANUFACTURE_BASIC).ok, "actual basic pick")
		assert_true(_gear.equip(tool, _worker).ok, "actual carried pick")
		var worker: int = _residents.directory().get_typed_row(_worker)
		assert_true(_jobs.priorities().spawn(worker).ok, "actual priorities")
		assert_true(_jobs.schedule().spawn(worker, _jobs.schedule().default_template_id().value).ok, "actual schedule")
		assert_true(_jobs.schedule().resolve(worker, 8, false).ok and _jobs.spawn_agent(worker).ok, "actual worker availability")

	func confirmed_room() -> Vector2i:
		"""Actual Kitchen confirmation over the explicit Corridor bootstrap, with arenas for a whole-Kitchen chain set."""
		location_capacity = 64; edge_capacity = 128
		_actual_fixture(); connect_source_paths(); finite_stock_and_worker()
		if not failures.is_empty(): return NULL_REF
		var made: Buildings.OpResult = orders.confirm_room(room_request())
		assert_true(made.ok, "actual Kitchen confirmation: %s" % made.error)
		return made.ref if made.ok else NULL_REF

	func face_for(job: Vector2i, profile: int) -> void:
		"""An exact-heading row needs the body already facing its yaw; the current all-yaw row turns in place."""
		var stride: int = _profiles._profile_capacity
		if _profiles._live.fields[Profiles.F_YAW_KIND * stride + profile] != Profiles.YAW_EXACT: return
		var actor: Routes.Actor = Routes.Actor.new()
		assert_equal(_routes.read_actor_into(_worker, actor), &"", "actual actor")
		var yaw: int = _profiles._live.fields[Profiles.F_YAW * stride + profile]
		if actor.yaw == yaw: return
		assert_equal(Phase.WorldFixture.Binding.turn_actor(_binding, _worker, job, yaw, Space.MAX_CHECKS), &"", "stationary all-yaw turn")
		tick += 1
		_routes.advance_tick(tick)

	func walk_leg(job: Vector2i, to: Vector2i, profile: int) -> void:
		"""READY handoff to one leg's source, one actual route, then canonical READY at its endpoint."""
		face_for(job, profile)
		assert_equal(_routes.refresh_travel_actor(_worker, job, profile, 1, CONTENT, 0, -1, tool), &"", "handoff to %d" % profile)
		assert_equal(_routes.request_route(_worker, to, tick), &"", "route on %d" % profile)
		wait_on(job, profile)

	func wait_on(job: Vector2i, profile: int) -> void:
		"""Canonical 30 Hz ticks until the source reports READY."""
		var end: int = tick + 400
		while Routes.source_ready_leaf_refusal(_routes, _worker, job, profile, 1, CONTENT) != &"" and tick < end:
			tick += 1
			assert_equal(_routes.advance_tick(tick), 1, "actual headless tick")
			if not failures.is_empty(): return
		assert_equal(Routes.source_ready_leaf_refusal(_routes, _worker, job, profile, 1, CONTENT), &"", "READY on %d" % profile)

	func approach(job: Vector2i) -> void:
		"""From parking (or the initial access pose) along the actual forward-anchored itinerary to the contact."""
		if admitted: walk_leg(job, _first, 5)
		plan_legs(_first, contact_location, 5)
		if not admitted and failures.is_empty():
			assert_equal(_routes.admit_travel_actor(_worker, job, _first, leg_profiles[0], 1, CONTENT, 0, -1, tool), &"", "admit")
			admitted = true
		for index: int in legs.size():
			if failures.is_empty(): walk_leg(job, legs[index], leg_profiles[index])

	func retreat() -> void:
		"""The actual backward-anchored itinerary to the retreat, then real travel to parking."""
		plan_legs(contact_location, _first, 9)
		for index: int in legs.size():
			if failures.is_empty(): walk_leg(NULL_REF, legs[index], leg_profiles[index])
		if failures.is_empty(): walk_leg(NULL_REF, parking, 9)

	func plan_legs(from: Vector2i, to: Vector2i, anchor: int) -> void:
		"""Copy the static itinerary's edges and each edge's first certified family row before anyone moves."""
		var remaining: PackedInt32Array = PackedInt32Array([0])
		assert_equal(Itinerary.reachability_refusal(_binding, from, to, anchor, 1, CONTENT, Space.MAX_CHECKS, remaining), &"", "itinerary")
		legs.clear(); leg_profiles.clear()
		for index: int in _routes._proposed_count:
			var row: int = _routes._proposed_edges[(_routes._proposed_count - index - 1) * 2]
			legs.append(_routes._edge_pair(_routes._live, Routes.E_TO_SLOT, row))
			for profile: int in _profiles._live.header[1]:
				if _binding._live.admits(row, profile) and Itinerary._compatible(_profiles, anchor, profile):
					leg_profiles.append(profile); break

	func enter_source_work(job: Vector2i) -> void:
		"""READY to WORK on the selected contact's exact row."""
		assert_equal(_routes.refresh_work_actor(_worker, job, work_profile, 1, CONTENT, 0, -1, tool), &"", "ready-to-work handoff")
		var end: int = tick + 100
		while Routes.source_work_leaf_refusal(_routes, _worker, job, work_profile, 1, CONTENT) != &"" and tick < end:
			tick += 1
			assert_equal(_routes.advance_tick(tick), 1, "actual source entry tick")
		assert_equal(Routes.source_work_leaf_refusal(_routes, _worker, job, work_profile, 1, CONTENT), &"", "exact source WORK")

	func earn(job: Vector2i) -> void:
		"""Work owns WU; the source recovers to READY before settlement."""
		var remaining: Phase.IntMath.IntResult = Phase.IntMath.IntResult.new()
		var row: int = _residents.directory().get_typed_row(job)
		var end: int = tick + 1000
		while _jobs.remaining_mwu_into(row, remaining) and remaining.value > 0 and tick < end and failures.is_empty():
			tick += 1
			assert_equal(_routes.advance_tick(tick), 1, "actual WORK tick")
			var worked: Phase.WorldFixture.Work.TickResult = _work.tick_solo(row)
			assert_true(worked.ok, "actual paid Work: %s" % worked.error)
			accepted_mwu += worked.accepted_mwu if worked.ok else 0
		assert_equal(_routes.request_source_ready(_worker, job), &"", "loop-boundary recovery")
		wait_on(job, work_profile)

	func work_phase(site: Vector2i, operation: int) -> bool:
		"""Open, approach (BRACE only), enter, START, earn, recover and settle one paid operation."""
		var job: Vector2i = open_phase_job(site, operation)
		if job == NULL_REF or not failures.is_empty(): return false
		if operation == Contract.OP_BRACE: approach(job)
		if failures.is_empty(): enter_source_work(job)
		if failures.is_empty(): start_phase(site, operation, job)
		sample(2)
		if failures.is_empty(): earn(job)
		if not failures.is_empty(): return false
		var settled: Construction.OpResult = sites.settle_phase(site)
		assert_true(settled.ok, "actual settlement %d: %s" % [operation, settled.error])
		sample(2)
		return settled.ok and failures.is_empty()

	func sample(at: int) -> void:
		"""Last sealed route proof and last Location preparation, against the 1,048,576 budget."""
		var location: int = endpoints._domain._checks - endpoints._remaining
		peaks[at] = maxi(peaks[at], _binding._proof_checks)
		peaks[at + 1] = maxi(peaks[at + 1], location)
		print("ROOM-LOOP-SAMPLE %s edges=%d locations=%d route=%d location=%d" % ["publication" if at == 0 else "phase",
			_routes._live.edge_count, endpoints._live.count, _binding._proof_checks, location])

	func loop_step(room: Vector2i, after: int) -> StringName:
		"""One foreman step under one original cold lease that dies before any paid phase."""
		var cold: int = _budget.acquire(Budget.COLD_BYTES)
		var candidate: Frontier.Candidate = Frontier.Candidate.new()
		var contact: Face.Request = Face.Request.new()
		var request: Publication.Request = Publication.Request.new()
		var result: Publication.Result = Publication.Result.new()
		result.locations.resize(6); result.edges.resize(12)
		var code: StringName = Planner.next_contact_into(provider, room, after, cold, Space.MAX_CHECKS,
			candidate, contact, request, result)
		last_key = candidate.key; last_site = candidate.site
		if code == &"": adopt_chain(contact, request, result)
		candidate = null; contact = null; request = null; result = null
		assert_equal(_budget.release(cold), &"", "original step lease released")
		return code

	func adopt_chain(contact: Face.Request, request: Publication.Request, result: Publication.Result) -> void:
		"""Keep the proved contact; a fresh publication's WORK row must be that contact."""
		contact_location = contact.location; work_profile = contact.profile_id
		if result.count == 0: return
		sample(0)
		published.append(request.count)
		assert_equal(result.work, contact.location, "the published WORK row is the proved contact")

	func work_cube() -> bool:
		"""All three paid operations at the proved contact, then the full reverse chain."""
		for operation: int in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]:
			if not work_phase(last_site, operation): return false
		retreat()
		completed.append(last_key)
		return failures.is_empty()

	func room_loop(room: Vector2i, cube_limit: int = KITCHEN_SITES) -> void:
		"""Repeat next/plan/publish/contact/phases until a full canonical pass makes no progress (or the limit)."""
		var after: int = -1
		var progressed: bool = false
		for guard: int in KITCHEN_SITES * KITCHEN_SITES:
			if completed.size() >= cube_limit: return
			var code: StringName = loop_step(room, after)
			if code == Frontier.REFUSE_END:
				if not progressed: return
				progressed = false; after = -1
			elif code != &"":
				refusals[last_key] = code; after = last_key
			elif work_cube():
				refusals.erase(last_key); progressed = true; after = -1
			else: return
		assert_true(false, "loop terminates within its bound")


var _h: Phase.SourceFixture = null


func after_each() -> void:
	"""Propagate actual fixture assertions and free every owner."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "actual fixture: %s" % _h.failures)
	_h = null


static func _key(sites: Sites, x: int, y: int, z: int) -> int:
	"""Canonical Site key of a Kitchen cube given relative to the fixture datum."""
	return sites._site_key[sites.site_at(Vector3i(Phase.X + x, Phase.FLOOR + y, Phase.Z + z)).x]


func _candidate(room: Vector2i, cold: int, x: int, y: int, z: int) -> Frontier.Candidate:
	"""The exact canonical candidate for one cube, skipping earlier keys as a foreman does."""
	var out: Frontier.Candidate = Frontier.Candidate.new()
	var key: int = _key(_h.sites, x, y, z)
	assert_equal(Frontier.next_site_into(_h.provider, room, key - 1, cold, Space.MAX_CHECKS, out), &"", "actual candidate")
	assert_equal(out.key, key, "same canonical cube")
	return out


func _sentinel() -> Publication.Request:
	"""A recognisable caller packet; refusals must leave every field untouched."""
	var out: Publication.Request = Publication.Request.new()
	out.count = 7; out.work_profile = 99; out.points = PackedInt32Array([1, 2, 3])
	return out


func _assert_sentinel(out: Publication.Request, label: String) -> void:
	"""Every scalar and packed field of the sentinel is unchanged."""
	assert_equal(out.count, 7, "%s: count unchanged" % label)
	assert_equal(out.work_profile, 99, "%s: work row unchanged" % label)
	assert_equal(out.points, PackedInt32Array([1, 2, 3]), "%s: points unchanged" % label)
	assert_equal(out.gateway, NULL_REF, "%s: gateway unchanged" % label)


func _point(request: Publication.Request, index: int) -> Vector3i:
	"""One planned station relative to the fixture datum."""
	return Vector3i(request.points[index * 3] - Phase.X, request.points[index * 3 + 1] - Phase.FLOOR,
		request.points[index * 3 + 2] - Phase.Z)


func test_first_cube_plan_rederives_the_authored_bootstrap_station_from_boxes() -> void:
	"""v3: the gateway line admits FRONT24 at 768u from the face, exactly the hand-authored WORK endpoint."""
	_h = Phase.SourceFixture.new()
	_h._actual_fixture(); _h.connect_source_paths()
	if not _h.failures.is_empty(): return
	var made: Phase.Buildings.OpResult = _h.orders.confirm_room(_h.room_request())
	assert_true(made.ok, "actual Kitchen confirmation: %s" % made.error)
	var cold: int = _h._budget.acquire(Budget.COLD_BYTES)
	var candidate: Frontier.Candidate = _candidate(made.ref, cold, 2048, 0, 0)
	var request: Publication.Request = Publication.Request.new()
	assert_equal(Planner.facing_face(_h.provider, YAW_PLUS_X), 0, "+X workers strike the low-X face")
	assert_equal(Planner.plan_into(_h.provider, candidate, 0, YAW_PLUS_X, cold, Space.MAX_CHECKS, request), &"", "actual plan")
	assert_equal(request.count, 1, "one forward leg, no turn")
	assert_equal(_point(request, 0), Vector3i(1280, 0, 512), "the authored _last root")
	assert_equal(request.profiles.slice(0, 4), PackedInt64Array([5, 1, 9, 1]), "selected forward/backward pair")
	assert_equal(request.work_profile, 24, "FRONT row")
	assert_equal(request.gateway, _h._first, "the provider's bound retreat anchors the chain")
	candidate = null
	assert_equal(_h._budget.release(cold), &"", "plan dies inside its lease")


func test_refusals_are_named_and_preserve_the_callers_request() -> void:
	"""Unbound, malformed, vertical, foreign-heading, stale and starved plans write nothing."""
	_h = Phase.SourceFixture.new()
	_h._actual_fixture(); _h.connect_source_paths()
	if not _h.failures.is_empty(): return
	var room: Vector2i = _h.orders.confirm_room(_h.room_request()).ref
	var cold: int = _h._budget.acquire(Budget.COLD_BYTES)
	var candidate: Frontier.Candidate = _candidate(room, cold, 2048, 0, 0)
	var out: Publication.Request = _sentinel()
	assert_equal(Planner.plan_into(null, candidate, 0, YAW_PLUS_X, cold, Space.MAX_CHECKS, out), Frontier.REFUSE_BINDING, "unbound")
	assert_equal(Planner.plan_into(_h.provider, candidate, 6, YAW_PLUS_X, cold, Space.MAX_CHECKS, out), Planner.REFUSE_SCOPE, "face")
	assert_equal(Planner.plan_into(_h.provider, candidate, 2, YAW_PLUS_X, cold, Space.MAX_CHECKS, out), Planner.REFUSE_VERTICAL, "floor face")
	assert_equal(Planner.plan_into(_h.provider, candidate, 0, YAW_PLUS_X, cold, 20000, out), Planner.REFUSE_CAPACITY, "finite checks")
	assert_equal(Planner.plan_into(_h.provider, candidate, 0, YAW_PLUS_X, cold + 1, Space.MAX_CHECKS, out), Frontier.REFUSE_LEASE, "foreign lease")
	var lateral: Frontier.Candidate = _candidate(room, cold, 2048, 0, 1024)
	_h._profiles._live.flags[1] = 0 # Negative-only: the all-yaw ground row loses its certificate flags.
	assert_equal(Planner.plan_into(_h.provider, lateral, 0, YAW_PLUS_X, cold, Space.MAX_CHECKS, out), Planner.REFUSE_GROUND, "turn needs ground")
	_h._profiles._live.flags[1] = Profiles.CERT_REQUIRED
	lateral = null
	assert_equal(_h._budget.release(cold), &"", "expire the original lease")
	cold = _h._budget.acquire(Budget.COLD_BYTES)
	assert_equal(Planner.plan_into(_h.provider, candidate, 0, YAW_PLUS_X, cold, Space.MAX_CHECKS, out), Frontier.REFUSE_STALE, "stale candidate")
	_assert_sentinel(out, "every refusal")
	candidate = null
	assert_equal(_h._budget.release(cold), &"", "no retained lease")


func _v3_first_cube() -> Vector2i:
	"""The literal ADR1161 lateral fixture: first cube paid, worker parked in the old Corridor."""
	var fixture: PublicationTests.LateralFixture = PublicationTests.LateralFixture.new()
	_h = fixture
	fixture._actual_fixture(); fixture.connect_source_paths(); fixture.finite_stock_and_worker()
	if not fixture.failures.is_empty(): return NULL_REF
	var made: Phase.Buildings.OpResult = fixture.orders.confirm_room(fixture.room_request())
	if not made.ok: return NULL_REF
	var site: Vector2i = fixture.sites.site_at(Vector3i(Phase.X + 2048, Phase.FLOOR, Phase.Z))
	for operation: int in [Contract.OP_BRACE, Contract.OP_CUT, Contract.OP_FINISH]:
		if not fixture.complete_source_phase(site, operation, operation == Contract.OP_BRACE): return NULL_REF
	fixture.retreat_after_settlement(); fixture.park_after_settlement()
	return made.ref if fixture.failures.is_empty() else NULL_REF


func _plan(room: Vector2i, cold: int, x: int, y: int, z: int, out: Publication.Request) -> StringName:
	"""Plan one named cube at the fixture's single +X heading."""
	var candidate: Frontier.Candidate = _candidate(room, cold, x, y, z)
	return Planner.plan_into(_h.provider, candidate, 0, YAW_PLUS_X, cold, Space.MAX_CHECKS, out)


func test_adr1161_v3_fixture_lateral_publishes_but_its_ground_leg_cannot_hand_off() -> void:
	"""v3 plans and publishes the lateral chain with automatic ground; Routes then refuses the automatic handoff."""
	var room: Vector2i = _v3_first_cube()
	if room == NULL_REF: return
	var cold: int = _h._budget.acquire(Budget.COLD_BYTES)
	var request: Publication.Request = Publication.Request.new()
	assert_equal(_plan(room, cold, 2048, 0, 1024, request), &"", "lateral plan")
	assert_equal([_point(request, 0), _point(request, 1)], [Vector3i(-1024, 0, 1530), Vector3i(1280, 0, 1530)], "turn, then FRONT root")
	assert_equal(request.profiles.slice(0, 8), PackedInt64Array([1, 1, 1, 1, 5, 1, 9, 1]), "all-yaw ground then selected pair")
	var result: Publication.Result = Publication.Result.new(); result.locations.resize(6); result.edges.resize(12)
	var candidate: Frontier.Candidate = _candidate(room, cold, 2048, 0, 1024)
	assert_equal(Publication.publish_into(_h.provider, candidate, request, cold, Space.MAX_CHECKS, result), &"", "actual publication")
	var contact: Face.Request = Face.Request.new()
	candidate = _candidate(room, cold, 2048, 0, 1024)
	assert_equal(Frontier.contact_into(_h.provider, candidate, _h._first, 5, 1, cold, Space.MAX_CHECKS, contact), &"", "actual contact")
	assert_equal(contact.location, result.work, "the planned WORK row")
	for cube: Vector3i in [Vector3i(2048, 1024, 0), Vector3i(3072, 0, 0)]:
		var out: Publication.Request = _sentinel()
		assert_equal(_plan(room, cold, cube.x, cube.y, cube.z, out), Planner.REFUSE_CLOSED, "v3 %s" % cube)
		_assert_sentinel(out, "v3 refusal")
	candidate = null
	assert_equal(_h._budget.release(cold), &"", "no retained lease")
	_assert_v3_ground_handoff_refused(result)


func _assert_v3_ground_handoff_refused(result: Publication.Result) -> void:
	"""Static eligibility is not motion: the switch at rest is allowed (ADR1210), but its full admission re-proof
	still refuses the selected v3 source on automatic ground."""
	var fixture: PublicationTests.LateralFixture = _h as PublicationTests.LateralFixture
	assert_equal(fixture._routes.refresh_travel_actor(fixture._worker, NULL_REF, 5, 1, 2, 0, -1, fixture.tool), &"", "READY 9 to 5")
	assert_equal(fixture._routes.request_route(fixture._worker, fixture._first, fixture.tick), &"", "parking to access")
	fixture.wait_ready(NULL_REF, 5)
	assert_equal(fixture._routes.refresh_actor(fixture._worker, NULL_REF, Profiles.MODE_WALK, 0, -1, fixture.tool), &"", "READY to automatic")
	var turn: Vector2i = Vector2i(result.locations[0], result.locations[1])
	assert_equal(fixture._routes.request_route(fixture._worker, turn, fixture.tick), &"", "automatic lateral leg")
	var actor: Routes.Actor = Routes.Actor.new()
	for step: int in 300:
		fixture._routes.read_actor_into(fixture._worker, actor)
		if actor.location == turn and actor.edge == NULL_REF: break
		fixture.tick += 1; fixture._routes.advance_tick(fixture.tick)
	assert_equal(actor.location, turn, "arrived on automatic ground")
	assert_equal(fixture._routes.refresh_travel_actor(fixture._worker, NULL_REF, 5, 1, 2, 0, -1, fixture.tool),
		&"PROFILE_VARIANT_UNAUTHORED", "the ADR1161 runtime seam stands in v3")


func test_room_loop_digs_both_lower_levels_with_exact_ledgers() -> void:
	"""Content 6 with per-motion air and the DEC-054 height: all eight cubes are paid, with no refusal left."""
	var fixture: StepFixture = StepFixture.new()
	_h = fixture
	var room: Vector2i = fixture.confirmed_room()
	if room == NULL_REF: return
	var locations: int = fixture.endpoints._live.count
	var edges: int = fixture._routes._live.edge_count
	fixture.room_loop(room)
	if not fixture.failures.is_empty(): return
	var sites: Sites = fixture.sites
	var expected: PackedInt32Array = PackedInt32Array()
	for cube: Vector3i in [Vector3i(2048, 0, 0), Vector3i(2048, 0, 1024), Vector3i(2048, 1024, 0), Vector3i(2048, 1024, 1024),
			Vector3i(3072, 0, 0), Vector3i(3072, 0, 1024), Vector3i(3072, 1024, 0), Vector3i(3072, 1024, 1024)]:
		expected.append(_key(sites, cube.x, cube.y, cube.z))
	assert_equal(fixture.completed, expected, "paid cubes in loop order")
	assert_equal(fixture.refusals.size(), 0, "the whole clamped Kitchen digs")
	_assert_ledgers(fixture, 8)
	var stations: int = 0
	for count: int in fixture.published: stations += count
	print("ROOM-LOOP-PUBLISHED ", fixture.published)
	assert_equal(fixture.endpoints._live.count, locations + stations, "every planned station published once")
	assert_equal(fixture._routes._live.edge_count, edges + 2 * stations, "two directed spans per station")
	assert_true(_multi_air_rows(fixture) > 0, "upper WORK stations claim per-motion air")
	print("ROOM-LOOP-PEAKS publication route=%d location=%d phase route=%d location=%d" % Array(fixture.peaks))
	for peak: int in fixture.peaks: assert_true(peak > 0 and peak < Space.MAX_CHECKS, "measured below the cold check budget")


func _multi_air_rows(fixture: StepFixture) -> int:
	"""Live Locations with at least one extra air box."""
	var count: int = 0
	var record: Locations.Record = Locations.Record.new()
	record.envelope.resize(6); record.support.resize(6)
	for row: int in fixture.endpoints._capacity:
		if fixture.endpoints._live.present[row] != 1: continue
		var ref: Vector2i = Vector2i(row, fixture.endpoints._get32(fixture.endpoints._live, Locations.GENERATION, row))
		assert_equal(fixture.endpoints.read_location_into(ref, record), &"", "actual Location")
		count += 1 if record.air_count > 0 else 0
	return count


func test_upper_cube_needs_per_motion_air_and_the_finite_step() -> void:
	"""After the near lower cubes: one AABB refuses, the planned per-motion air publishes, no step names the step."""
	var fixture: StepFixture = StepFixture.new()
	_h = fixture
	var room: Vector2i = fixture.confirmed_room()
	if room == NULL_REF: return
	fixture.room_loop(room, 2)
	if not fixture.failures.is_empty(): return
	_assert_step_rows_decide_the_upper_reason(fixture, room)
	_assert_upper_chain_refused_by_publication(fixture, room)
	var cold: int = fixture._budget.acquire(Budget.COLD_BYTES)
	var request: Publication.Request = Publication.Request.new()
	assert_equal(_plan(room, cold, 2048, 1024, 0, request), &"", "planned per-motion air")
	assert_equal(request.count, 2, "step start, then HIGH root")
	assert_equal([_point(request, 0), _point(request, 1)], [Vector3i(1280, 0, 512), Vector3i(1512, 0, 512)], "ADR1161 roots")
	assert_equal(request.air_counts[0], 0, "the step start keeps one AABB")
	assert_true(request.air_counts[1] > 1, "the HIGH station claims more than one air box")
	var result: Publication.Result = Publication.Result.new(); result.locations.resize(6); result.edges.resize(12)
	assert_equal(Publication.publish_into(fixture.provider, _candidate(room, cold, 2048, 1024, 0), request, cold, Space.MAX_CHECKS, result),
		&"", "actual per-motion air publication")
	var work: Locations.Record = Locations.Record.new(); work.envelope.resize(6); work.support.resize(6)
	assert_equal(fixture.endpoints.read_location_into(result.work, work), &"", "published WORK row")
	assert_equal(work.air_count, request.air_counts[1] - 1, "extra boxes stored beside the envelope")
	assert_equal(fixture._budget.release(cold), &"", "lease released")


func test_bound_retreat_row_has_a_backward_sibling_for_every_heading() -> void:
	"""Content keeps backward rows for all four yaws; the planner no longer refuses another heading by binding."""
	var fixture: StepFixture = StepFixture.new()
	_h = fixture
	var room: Vector2i = fixture.confirmed_room()
	if room == NULL_REF: return
	var siblings: PackedInt32Array = PackedInt32Array()
	for yaw: int in [0, 16384, 32768, 49152]:
		siblings.append(Itinerary.family_row(fixture._profiles, 9, yaw, Profiles.POLICY_READY_BACKWARD))
	assert_equal(siblings, PackedInt32Array([6, 7, 8, 9]), "one backward row per heading, same actor/tool/cargo")
	assert_equal(Itinerary.family_row(fixture._profiles, 9, 49152, Profiles.POLICY_READY_FORWARD), 5, "forward partner")
	var cold: int = fixture._budget.acquire(Budget.COLD_BYTES)
	var out: Publication.Request = _sentinel()
	var code: StringName = Planner.plan_into(fixture.provider, _candidate(room, cold, 2048, 0, 1024), 4, 32768, cold, Space.MAX_CHECKS, out)
	assert_true(code != Planner.REFUSE_HEADING and code in Planner.RANKED, "a +Z face is planned, then refused on geometry: %s" % code)
	_assert_sentinel(out, "other heading")
	assert_equal(fixture._budget.release(cold), &"", "lease released")


func _assert_ledgers(fixture: StepFixture, cubes: int) -> void:
	"""Exact bills, work, earth, support and Site phases for the paid cubes only."""
	var room_void: int = 0
	for row: int in fixture.sites._count:
		if fixture.sites._phase[row] == Sites.SUPPORTED_VOID and fixture.sites.room_of(Vector2i(row, Sites.SITE_GENERATION)) != fixture.corridor:
			room_void += 1
	assert_equal(room_void, cubes, "Kitchen Sites finished")
	assert_equal(fixture.sites._ever_cut.count(1), cubes, "only paid cubes were cut")
	assert_equal(fixture._inventory.lot_quantity_milli(fixture.stock_wood), (KITCHEN_SITES - cubes) * Contract.BRACE_WOOD_MILLI, "wood")
	assert_equal(fixture._inventory.lot_quantity_milli(fixture.stock_stone), (KITCHEN_SITES - cubes) * Contract.BRACE_STONE_MILLI, "stone")
	assert_equal(fixture.sites.virgin_sourced_milli(), cubes * Contract.EARTH_MILLI, "only CUT made earth")
	assert_equal(fixture.accepted_mwu, cubes * (Contract.BRACE_WORK_MWU + Contract.CUT_WORK_MWU + Contract.FINISH_WORK_MWU), "work")
	assert_equal(fixture.sites.support_conservation_refusal(), &"", "support conserved")
	assert_equal(fixture.sites.earth_conservation_refusal(), &"", "earth conserved")
	assert_equal(fixture._construction.live_project_count(), 0, "no live Project")
	assert_true(fixture._budget.is_quiescent(), "no cold lease outlives the loop")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(fixture._routes.read_actor_into(fixture._worker, actor), &"", "actual worker")
	assert_equal(actor.location, fixture.parking, "worker parked by real travel")


func _assert_upper_chain_refused_by_publication(fixture: StepFixture, room: Vector2i) -> void:
	"""The step chain for (2048,1024,0) published with one AABB per station is refused by the actual prover."""
	var cold: int = fixture._budget.acquire(Budget.COLD_BYTES)
	var candidate: Frontier.Candidate = _candidate(room, cold, 2048, 1024, 0)
	var request: Publication.Request = Publication.Request.new()
	request.gateway = fixture._first; request.count = 2
	request.sections = PackedInt32Array([fixture._floor.x, fixture._floor.y, fixture._floor.x, fixture._floor.y, -1, 0])
	request.points = PackedInt32Array([Phase.X + 1512 - 232, Phase.FLOOR, Phase.Z + 512, Phase.X + 1512, Phase.FLOOR, Phase.Z + 512, 0, 0, 0])
	request.profiles = PackedInt64Array([5, 1, 9, 1, 10, 1, 11, 1, 0, 0, 0, 0])
	request.work_profile = 26; request.work_revision = 1; request.face = 0; request.yaw = YAW_PLUS_X
	var result: Publication.Result = Publication.Result.new(); result.locations.resize(6); result.edges.resize(12)
	var before: int = fixture.endpoints._live.count
	assert_equal(Publication.publish_into(fixture.provider, candidate, request, cold, Space.MAX_CHECKS, result),
		&"LOCATION_ENVELOPE_BLOCKED", "HIGH26 one-AABB air enters the solid target")
	assert_equal(fixture.endpoints._live.count, before, "nothing published")
	candidate = null
	assert_equal(fixture._budget.release(cold), &"", "lease released")


func _assert_step_rows_decide_the_upper_reason(fixture: StepFixture, room: Vector2i) -> void:
	"""Negative-only: without finite-step policies the same opened geometry names the missing step, not the envelope."""
	var cold: int = fixture._budget.acquire(Budget.COLD_BYTES)
	var flags: PackedByteArray = fixture._profiles._live.flags
	var at: int = fixture._profiles._profile_capacity
	var original: PackedByteArray = flags.slice(at + 10, at + 12)
	flags[at + 10] = Profiles.POLICY_READY_FORWARD; flags[at + 11] = Profiles.POLICY_READY_BACKWARD
	var out: Publication.Request = _sentinel()
	assert_equal(_plan(room, cold, 2048, 1024, 0, out), Planner.REFUSE_STEP, "full travel blocked, no finite step pair")
	_assert_sentinel(out, "missing step")
	flags[at + 10] = original[0]; flags[at + 11] = original[1]
	assert_equal(_plan(room, cold, 2048, 1024, 0, out), &"", "restored rows plan the step chain")
	assert_equal(fixture._budget.release(cold), &"", "lease released")


func test_confirmation_refuses_a_height_no_floor_station_digs() -> void:
	"""DEC-054: content 6 digs 2,048u from the floor; the painted 4 m refuses unclaimed, the clamp claims 8 Sites only."""
	var fixture: StepFixture = StepFixture.new()
	_h = fixture
	fixture.location_capacity = 64; fixture.edge_capacity = 128
	fixture._actual_fixture(); fixture.connect_source_paths(); fixture.finite_stock_and_worker()
	if not fixture.failures.is_empty(): return
	assert_equal(Approach.reachable_height_u(fixture._profiles, 27), 2048, "FRONT 707u and HIGH 1039u: levels 0-1")
	assert_equal(Approach.reachable_height_u(fixture._profiles, 33), 0, "the haul identity publishes no dig row")
	assert_equal(Approach.reachable_height_u(fixture._profiles, 99), 0, "an absent row reaches nothing")
	var painted: Phase.Approach.Request = fixture.room_request()
	assert_equal(painted.height_u, 2048, "the fixture clamps its painted 4 m")
	var sites: int = fixture.sites._count
	painted.height_u = 4096
	var refused: Phase.Buildings.OpResult = fixture.orders.confirm_room(painted)
	assert_false(refused.ok, "the painted 4 m is not confirmed")
	assert_equal(refused.error, Approach.REFUSE_HEIGHT, "named: the upper band is unreachable")
	assert_equal(fixture.sites._count, sites, "nothing above the band is claimed")
	assert_true(fixture.orders.confirm_room(fixture.room_request()).ok, "the clamped Kitchen confirms")
	assert_equal(fixture.sites._count, sites + KITCHEN_SITES, "8 Kitchen Sites, none above 2,048u")
	assert_equal(fixture.sites.site_at(Vector3i(Phase.X + 2048, Phase.FLOOR + 2048, Phase.Z)), NULL_REF, "no level-2 Site")

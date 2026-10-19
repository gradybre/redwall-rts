extends "res://test/framework/test_case.gd"
## Decision 1936: an order on the Kitchen fixture. The composer keeps the room phases' contacts to one access
## (P-1936-1 (a)), picks one idle toolless mole (P-1936-2 (a)), parks it off the access, away from the room (an
## endpoint already there is reused; a taken one is skipped and a new TRANSIT endpoint published and joined), and
## starts the dig. The composite dispatcher answers for both runtimes.

const ForemanTests := preload("res://test/test_underground_room_foreman.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Parking := preload("res://scripts/core/underground_room_parking.gd")
const Dispatch := preload("res://scripts/core/underground_dispatch.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Residents := preload("res://scripts/core/residents.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _h: ForemanTests.Kitchen = null
var _room: Vector2i = NULL_REF
var _runtime: Runtime = null


func before_each() -> void:
	"""One confirmed Kitchen and a runtime over its owners."""
	_h = ForemanTests.Kitchen.new()
	_room = _h.confirmed_room()
	_runtime = Runtime.new(_h._residents.directory())
	assert_true(_runtime.bind_owners(_h.owners()), "owners")


func after_each() -> void:
	"""Free the fixture, propagating its assertions."""
	_runtime = null
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % _h.failures)
	_h = null


func _order(access: Vector2i) -> Composer.Order:
	"""An order for the Kitchen from an access on the fixture's retreat row."""
	var order: Composer.Order = Composer.Order.new()
	order.room = _room; order.access = access; order.travel = _h.provider._ordinary_travel
	order.storage = _h.material; order.output = _h.material
	return order


func _idle_mole() -> Vector2i:
	"""A new adult mole holding nothing, scheduled and available (the pick mole is passed over: it holds a tool)."""
	var mole: Vector2i = _h._residents.ref_of(_h._residents.spawn(&"mole").value)
	var row: int = _h._residents.directory().get_typed_row(mole)
	assert_true(_h._transforms.place(mole, Phase.X - 1024, Phase.FLOOR, Phase.Z + 512 + 60000, 0), "far off")
	assert_true(_h._jobs.priorities().spawn(row).ok, "priorities")
	assert_true(_h._jobs.schedule().spawn(row, _h._jobs.schedule().default_template_id().value).ok, "schedule")
	assert_true(_h._jobs.schedule().resolve(row, 8, false).ok and _h._jobs.spawn_agent(row).ok, "available")
	return mole


func test_an_order_picks_an_idle_mole_parks_it_off_the_access_and_starts_the_dig() -> void:
	"""The contacts already bound to the access are kept and noted; the toolless mole is picked (no tool: claws); its
	parking is off the access and away from the room, joined both ways; the dig is under way."""
	if _room == NULL_REF: return
	var mole: Vector2i = _idle_mole()
	assert_equal(Composer.order(_runtime, _h.placements, _order(_h._first)), &"", "ordered")
	assert_equal(_runtime.contacts_access(), _h._first, "the contacts' access noted for a load")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_DIGGING, "digging")
	var crew: Builder.Crew = _runtime.foreman_of(_room).builders()[0].crew()
	assert_equal(crew.worker, mole, "the idle toolless mole")
	assert_equal(crew.tool, NULL_REF, "no tool")
	assert_false(crew.parking == _h._first, "not on the access")
	assert_equal(crew.parking, _h.parking, "the endpoint already there, away from the room, is reused")


func test_a_taken_parking_is_skipped_and_none_is_made_between_the_access_and_the_room() -> void:
	"""With the existing endpoint taken, the only clear point left on the access's floor lies between the access and
	the room, on the builder's way to its station (decision 1991, review H-1): it is never made a parking, so there is
	none, and nothing is published there. Untaken, the existing endpoint is reused, not added again."""
	if _room == NULL_REF: return
	var ctx: Builder.Context = Foreman._context(_runtime.bound_owners(), _h.material, _h.material)
	var ask: Parking.Request = Parking.Request.new()
	ask.access = _h._first; ask.forward = ctx.forward; ask.backward = ctx.backward; ask.content = ctx.content
	ask.room_box = Composer._room_box(_h.sites, _room)
	ask.taken = [_h.parking]
	var access: Vector3i = Parking._point(_h.endpoints, _h._first.x)
	var toward: Vector3i = access + Vector3i(2 * Parking.CELL_U, 0, 0)
	assert_true(Parking._between(access, ask.room_box, toward), "the point toward the room is between")
	assert_true(Parking._clear(_h._profiles, ask, _record_of(_h._first), toward), "and clear of the room's cells")
	var found: Array[Vector2i] = []
	assert_equal(Parking.find_into(_runtime.bound_owners(), ask, found), Parking.REFUSE_NONE, "no parking")
	assert_false(Parking._occupied(_h.endpoints, toward), "nothing published between")
	ask.taken = []
	assert_equal(Parking.find_into(_runtime.bound_owners(), ask, found), &"", "untaken")
	assert_equal(found[0], _h.parking, "the existing endpoint is reused")


func _record_of(location: Vector2i) -> Locations.Record:
	"""One endpoint's Location packet."""
	var record: Locations.Record = Parking._record()
	assert_equal(_h.endpoints.read_location_into(location, record), &"", "read")
	return record


func test_another_access_no_idle_mole_and_no_sites_are_refused() -> void:
	"""P-1936-1 (a): one access for every room until a per-access binding exists; P-1936-2 (a): no idle toolless
	mole, no dig; a room with no Sites has nothing to dig."""
	if _room == NULL_REF: return
	assert_equal(Composer.order(_runtime, _h.placements, _order(_h._first)), Composer.REFUSE_NO_MOLE, "only the pick mole")
	_idle_mole()
	assert_equal(Composer.order(_runtime, _h.placements, _order(_h._last)), Composer.REFUSE_OTHER_ACCESS, "another access")
	var empty: Composer.Order = _order(_h._first)
	empty.room = _h._residents.directory().create(Directory.KIND_ROOM)
	assert_equal(Composer.order(_runtime, _h.placements, empty), Composer.REFUSE_NO_CELLS, "no Sites")
	assert_equal(_runtime.kept(), 0, "nothing recorded")
	var refused: Composer.Order = _order(_h._first)
	refused.staging = _h.material # The same container as the storage: the foreman's configure refuses it.
	assert_false(Composer.order(_runtime, _h.placements, refused) == &"", "a start refused after parking")
	assert_equal(_runtime.kept(), 0, "leaves no queued record behind (decision 1937)")
	assert_equal(Composer.order(_runtime, _h.placements, _order(_h._first)), &"", "so the room can be ordered again")
	assert_equal(Composer.order(Runtime.new(_h._residents.directory()), _h.placements, _order(_h._first)),
		Composer.REFUSE_SCOPE, "no owners bound")


func test_the_composite_answers_for_the_room_runtime() -> void:
	"""Bound to Jobs, the composite reserves a dig's builder and owns its excavation Jobs, and nothing else. The crew
	is the fixture's pick mole: the Kitchen's mounted rows are content 6's pick rows, which a claws builder (the
	composer's pick) is refused (PROFILE_VARIANT_UNAUTHORED) until the claw content is active."""
	if _room == NULL_REF: return
	var dispatch: Dispatch = Dispatch.new()
	var none: Callable = func() -> RefCounted: return null
	var rooms: Callable = func() -> RefCounted: return _runtime
	assert_true(dispatch.configure(none, rooms), "configured")
	assert_false(dispatch.configure(none, rooms), "once")
	assert_equal(dispatch.bind(_h._jobs), &"", "bound")
	assert_true(Dispatch.bound_to(_h._jobs), "Jobs' dispatcher")
	var idle: Vector2i = _idle_mole()
	assert_equal(_runtime.order_room(_room, _h.material, _h.material, NULL_REF), &"", "ordered")
	assert_equal(_runtime.start_room(_room, _runtime.bound_owners(), [_h.crew_member()]), &"", "started")
	var builder: Builder = _runtime.foreman_of(_room).builders()[0]
	assert_true(dispatch.reserves_resident(builder.worker_row()), "its builder reserved")
	assert_false(dispatch.reserves_resident(_h._residents.directory().get_typed_row(idle)), "an idle mole is not")
	var tick: int = 0
	var codes: Array[StringName] = []
	while builder._job < 0 and tick < 4000 and _runtime.is_running():
		tick += 1
		codes = _runtime.advance(tick)
	assert_true(builder._job >= 0, "the builder took its first phase's Job: %s" % [codes])
	assert_true(dispatch.owns_job(builder._job), "its excavation Job is owned")
	var opened: Jobs.OpResult = _h._jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, 1000, tick)
	assert_false(dispatch.owns_job(opened.value), "a Job no excavation Project requests is not")
	_h._jobs.clear_dispatcher()


func test_a_busy_mole_is_waited_for_and_the_room_starts_once_it_is_free() -> void:
	"""Decision 1991: P-1936-2 (a)'s rule for who may start now (no Job, not reserved by another dispatcher, not
	building another dig), but a busy mole is waited for: the record stays QUEUED, no parking or foreman is made, and
	`start_waiting` starts it on the first call the mole is free. A room with no Sites is refused before anything."""
	if _room == NULL_REF: return
	var mole: Vector2i = _idle_mole()
	var row: int = _h._residents.directory().get_typed_row(mole)
	var empty: Composer.Order = _order(_h._first)
	empty.room = _h._residents.directory().create(Directory.KIND_ROOM)
	assert_equal(Composer.order(_runtime, _h.placements, empty), Composer.REFUSE_NO_CELLS, "no Sites, nothing kept")
	var reserving: Callable = func(slot: int) -> bool: return slot == row
	var owning: Callable = func(_slot: int) -> bool: return false
	assert_true(_h._jobs.bind_dispatcher(owning, reserving).ok, "another dispatcher reserves the mole")
	assert_equal(Composer.order(_runtime, _h.placements, _order(_h._first)), &"", "accepted")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_QUEUED, "waiting for the reserved mole")
	assert_null(_runtime.foreman_of(_room), "no foreman yet")
	assert_equal(Composer.start_waiting(_runtime, _h.placements), [] as Array[StringName], "still waiting, no alert")
	_h._jobs.clear_dispatcher()
	var held: Jobs.OpResult = _h._jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, 1000, 0)
	assert_true(_h._jobs.assign_worker(row, held.value).ok, "the mole takes another Job")
	assert_equal(Composer.start_waiting(_runtime, _h.placements), [] as Array[StringName], "holding a Job: waits")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_QUEUED, "still queued")
	assert_true(_h._jobs.release_worker(row).ok, "released")
	assert_equal(Composer.start_waiting(_runtime, _h.placements), [] as Array[StringName], "started")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_DIGGING, "now it digs the Kitchen")
	assert_equal(_runtime.foreman_of(_room).builders()[0].crew().worker, mole, "the mole it waited for")


func test_a_named_crew_waits_for_its_own_busy_member_not_for_any_idle_mole() -> void:
	"""Decision 1991, P-1990-4 (a): a named crew whose member is busy waits for that member; another idle mole is not
	sent in its place. Once the member is free, it is the one that digs."""
	if _room == NULL_REF: return
	var named: Vector2i = _idle_mole()
	var row: int = _h._residents.directory().get_typed_row(named)
	var other: Vector2i = _idle_mole()
	var held: Jobs.OpResult = _h._jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, 1000, 0)
	assert_true(_h._jobs.assign_worker(row, held.value).ok, "the named mole is busy")
	var order: Composer.Order = _order(_h._first)
	order.crew = PackedInt32Array([named.x, named.y])
	assert_equal(Composer.order(_runtime, _h.placements, order), &"", "accepted")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_QUEUED, "waiting for its own member")
	assert_null(_runtime.foreman_of(_room), "the idle mole not sent instead")
	assert_true(_h._jobs.release_worker(row).ok, "free")
	assert_equal(Composer.start_waiting(_runtime, _h.placements), [] as Array[StringName], "started")
	assert_equal(_runtime.foreman_of(_room).builders()[0].crew().worker, named, "by the named mole")
	assert_false(_runtime.reserves_resident(_h._residents.directory().get_typed_row(other)), "not the other")


func test_on_the_tick_a_waiting_room_looks_for_its_idle_mole_in_that_ticks_window_only() -> void:
	"""Review C-1: a room waiting for "the first idle mole" scans one eighth of the resident slots on each fixed tick,
	the window keyed by the tick, so the mole is found on the tick whose window holds its slot, and not before."""
	if _room == NULL_REF: return
	var mole: Vector2i = _idle_mole()
	var slot: int = _h._residents.directory().get_typed_row(mole)
	@warning_ignore("integer_division") var width: int = Residents.RESIDENT_CAPACITY / Composer.IDLE_WINDOWS
	@warning_ignore("integer_division") var mine: int = slot / width
	var reserving: Callable = func(row: int) -> bool: return row == slot
	assert_true(_h._jobs.bind_dispatcher(func(_row: int) -> bool: return false, reserving).ok, "reserved")
	assert_equal(Composer.order(_runtime, _h.placements, _order(_h._first)), &"", "waits")
	_h._jobs.clear_dispatcher()
	var other: int = (mine + 1) % Composer.IDLE_WINDOWS
	assert_equal(Composer.start_waiting(_runtime, _h.placements, other), [] as Array[StringName], "another window")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_QUEUED, "not found there")
	assert_equal(Composer.start_waiting(_runtime, _h.placements, Composer.IDLE_WINDOWS * 3 + mine),
		[] as Array[StringName], "its window")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_DIGGING, "found on its window's tick")
	assert_equal(_runtime.foreman_of(_room).builders()[0].crew().worker, mole, "that mole")


func test_one_scan_serves_every_waiting_room_on_a_tick() -> void:
	"""Review C-1: the idle diggers are scanned once per call and handed out in slot order, each checked again when
	handed out; a mole who becomes free after the scan is found on a later call, not by rescanning."""
	if _room == NULL_REF: return
	var first: Vector2i = _idle_mole()
	var idle: Composer.Idle = Composer.Idle.new()
	idle.mole = Composer._mole_id(_h._residents)
	var owners: Builder.Owners = _runtime.bound_owners()
	var slot: int = _h._residents.directory().get_typed_row(first)
	assert_equal(Composer._first_idle(_runtime, owners, idle.mole, idle), slot, "the idle mole")
	assert_true(idle.scanned, "scanned")
	var second: Vector2i = _idle_mole()
	assert_equal(Composer._first_idle(_runtime, owners, idle.mole, idle), -1, "not rescanned within the call")
	assert_equal(Composer._first_idle(_runtime, owners, idle.mole, null),
		_h._residents.directory().get_typed_row(first), "a fresh scan finds the first again")
	assert_false(second == first, "two moles")


func test_a_crew_reference_of_another_kind_is_not_a_resident() -> void:
	"""Review H-2: a crew named by a Room's reference (whose typed row is a resident's row) is refused, never resolved
	to the resident at that row (ARCH-ID-003)."""
	if _room == NULL_REF: return
	_idle_mole()
	var room_ref: Vector2i = _room
	while not _h._residents.is_present(_h._residents.directory().get_typed_row(room_ref)):
		room_ref = _h._residents.directory().create(Directory.KIND_ROOM)
	assert_true(_h._residents.is_present(_h._residents.directory().get_typed_row(room_ref)), "a resident at that row")
	assert_equal(Composer.crew_refusal(_runtime.bound_owners(), PackedInt32Array([room_ref.x, room_ref.y])),
		Composer.REFUSE_CREW_MEMBER, "not a digger")
	assert_equal(Composer._slot_of(_h._residents, room_ref), -1, "no slot")


func test_the_way_in_refusals_are_read_before_admission() -> void:
	"""Review M-3: what `order` would refuse about the way in is read without binding: another access, a retreat row
	out of range before the first bind, and a full record pool."""
	if _room == NULL_REF: return
	assert_equal(Composer.access_refusal(_runtime, _order(_h._first)), &"", "the bound access")
	assert_equal(Composer.access_refusal(_runtime, _order(_h._last)), Composer.REFUSE_OTHER_ACCESS, "another access")
	var unbound: Runtime = Runtime.new(_h._residents.directory())
	var owners: Builder.Owners = _runtime.bound_owners()
	var provider: RefCounted = owners.provider
	var routes: RefCounted = provider._ordinary_routes
	provider._ordinary_routes = null
	var far: Composer.Order = _order(_h._first)
	far.travel = owners.profiles._live.header[1]
	assert_true(unbound.bind_owners(owners), "owners")
	assert_equal(Composer.access_refusal(unbound, far), Composer.REFUSE_SCOPE, "row out of range before a bind")
	far.travel = _h.provider._ordinary_travel
	assert_equal(Composer.access_refusal(unbound, far), &"", "in range")
	provider._ordinary_routes = routes
	for at: int in Runtime.MAX_KEPT:
		assert_equal(_runtime.order_room(_h._residents.directory().create(Directory.KIND_ROOM), _h.material,
			_h.material), &"", "queued")
	assert_equal(Composer.access_refusal(_runtime, _order(_h._first)), Runtime.REFUSE_CAPACITY, "the pool is full")

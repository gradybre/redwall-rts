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


func test_a_taken_parking_is_skipped_and_a_new_one_published_and_joined() -> void:
	"""With the existing endpoint taken, the next candidate away from the room gets a new TRANSIT endpoint on the
	access's floor and two spans, and the travel rows reach it both ways."""
	if _room == NULL_REF: return
	var ctx: Builder.Context = Foreman._context(_runtime.bound_owners(), _h.material, _h.material)
	var ask: Parking.Request = Parking.Request.new()
	ask.access = _h._first; ask.forward = ctx.forward; ask.backward = ctx.backward; ask.content = ctx.content
	ask.room_box = Composer._room_box(_h.sites, _room)
	ask.taken = [_h.parking]
	var found: Array[Vector2i] = []
	assert_equal(Parking.find_into(_runtime.bound_owners(), ask, found), &"", "a parking")
	var parking: Vector2i = found[0]
	assert_false(parking == _h.parking or parking == _h._first, "a new endpoint")
	var row: int = parking.x
	var stride: int = _h.endpoints._capacity
	assert_equal(_h.endpoints._live.i32[Locations.ROLE * stride + row], Locations.ROLE_TRANSIT, "TRANSIT")
	assert_true(Parking._joined(_runtime.bound_owners(), ask, parking), "joined both ways")
	var again: Array[Vector2i] = []
	assert_equal(Parking.find_into(_runtime.bound_owners(), ask, again), &"", "asked again")
	assert_equal(again[0], parking, "the endpoint it published is reused, not added again")


func test_another_access_no_idle_mole_and_no_sites_are_refused() -> void:
	"""P-1936-1 (a): one access for every room until a per-access binding exists; P-1936-2 (a): no idle toolless
	mole, no dig; a room with no Sites has nothing to dig."""
	if _room == NULL_REF: return
	assert_equal(Composer.order(_runtime, _h.placements, _order(_h._last)), Composer.REFUSE_OTHER_ACCESS, "another access")
	assert_equal(Composer.order(_runtime, _h.placements, _order(_h._first)), Composer.REFUSE_NO_MOLE, "only the pick mole")
	_idle_mole()
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

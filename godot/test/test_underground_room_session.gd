extends "res://test/underground_host_case.gd"
## Decision 1936: room digs composed in the running game. Mounting binds one composite Jobs dispatcher; composing
## the room owners builds the runtime (its record allocated); composing the entry owners binds the owners it
## borrows; an order is refused, named, until then. The live entry chain runs under the composite exactly as before
## (its own suites), and its crew is reserved by it.

const Dispatch := preload("res://scripts/core/underground_dispatch.gd")
const RoomRuntime := preload("res://scripts/core/underground_room_runtime.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Construction := preload("res://scripts/core/construction.gd")


func _compose_all() -> void:
	"""Every Session owner, through the host's own composers."""
	_generate_and_mount()
	assert_true(_host.compose_underground_room_owners() and _host.compose_underground_route_owners()
		and _host.compose_underground_surface_anchor() and _host.compose_underground_entry_owners(), "every owner composed")


func test_mounting_binds_the_composite_dispatcher_once() -> void:
	"""Jobs' one dispatcher is the composite from the mount on; it reads the host's runtimes, so it answers for
	none before either exists."""
	_generate_and_mount()
	assert_true(Dispatch.bound_to(_host._jobs), "the composite is Jobs' dispatcher")
	assert_false(_host._underground_dispatch.owns_job(0), "no runtime owns anything yet")
	assert_false(_host._underground_dispatch.reserves_resident(0), "nor reserves anyone")


func test_the_room_runtime_is_built_with_the_room_owners_and_bound_with_the_entry_owners() -> void:
	"""The runtime exists once the room owners are composed (its whole record allocated, ROOM_CAPACITY rows) and
	borrows the Session's owners once the entry owners are; an order before then is a named refusal and alert."""
	_generate_and_mount()
	assert_null(_host.underground_rooms(), "none at mount")
	assert_true(_host.compose_underground_room_owners(), "room owners")
	var runtime: RoomRuntime = _host.underground_rooms()
	assert_not_null(runtime, "built with the room owners")
	assert_equal(runtime._generation.size(), RoomRuntime.MAX_KEPT, "its record pool allocated (decision 1937)")
	assert_null(runtime.bound_owners(), "no owners borrowed yet")
	var order: Composer.Order = Composer.Order.new()
	assert_false(_host.order_underground_room(order), "refused before the owners")
	assert_equal(_host.last_refusal(), Composer.REFUSE_SCOPE, "named")
	assert_true(_host.compose_underground_route_owners() and _host.compose_underground_surface_anchor()
		and _host.compose_underground_entry_owners(), "the rest composed")
	assert_not_null(runtime.bound_owners(), "owners borrowed")
	assert_equal(runtime.bound_owners().delivery, _host.underground_session()._retirement_owners.delivery, "the Session's")


func test_an_order_naming_no_way_in_is_refused_and_binds_nothing() -> void:
	"""In the game no level has a way in yet (slice D): an order naming none is refused by the room phases' own
	binding, nothing is bound, recorded or picked, and the refusal is an alert."""
	_compose_all()
	var order: Composer.Order = Composer.Order.new()
	order.room = _host.directory().create(Directory.KIND_ROOM)
	order.travel = 0
	assert_false(_host.order_underground_room(order), "refused")
	var runtime: RoomRuntime = _host.underground_rooms()
	assert_equal(runtime.contacts_access(), Composer.NULL_REF, "no contacts noted")
	assert_equal(runtime.kept(), 0, "no record")
	assert_null(_host.underground_session()._retirement_owners.world_bindings._ordinary_routes, "no binding made")


func test_the_entry_crew_is_reserved_through_the_composite() -> void:
	"""The entry binds itself only when no composite is bound (ADR1223); under the composite its crew is still
	reserved from the JobSelector and its excavation Jobs are still owned."""
	var live: Array = _begin_live_entry()
	var entry: Settlement.UndergroundEntryRuntime = live[1]
	assert_true(Dispatch.bound_to(_host._jobs), "the composite stayed bound")
	var row: int = _host.directory().get_typed_row(live[2])
	assert_true(_host._underground_dispatch.reserves_resident(row), "the entry crew is reserved")
	assert_true(entry.reserves_resident(row), "as the entry itself says")
	var tick: int = 1
	while _host._jobs.job_of(row) == Vector2i(-1, 0) and tick < 4000:
		assert_true(_host.run_tick(tick), "tick %d" % tick)
		tick += 1
	var job: int = _host._jobs.directory().get_typed_row(_host._jobs.job_of(row))
	assert_true(job >= 0 and entry.owns_job(job), "the crew holds an entry Job")
	assert_true(_host._underground_dispatch.owns_job(job), "which the composite owns through the entry runtime")
	var o: Session.Retirement.Owners = _host.underground_session()._retirement_owners
	var purpose: IntMath.IntResult = IntMath.IntResult.new()
	var other: int = -1
	while other < 0 and tick < 3000:
		assert_true(_host.run_tick(tick), "tick %d" % tick)
		tick += 1
		var held: int = _host._jobs.directory().get_typed_row(_host._jobs.job_of(row))
		if held >= 0 and o.construction.purpose_into(_host._jobs.requester_of(held), purpose) \
				and purpose.value != Construction.PURPOSE_EXCAVATION: other = held
	assert_true(other >= 0, "the crew reaches a Job no excavation Project requests (the installation)")
	assert_false(_host.underground_rooms().owns_job(other), "the room runtime does not own it")
	assert_true(_host._underground_dispatch.owns_job(other), "the composite owns it through the entry alone")

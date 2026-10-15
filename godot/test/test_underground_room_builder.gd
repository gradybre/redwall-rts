extends "res://test/framework/test_case.gd"
## Decision 1931 (C2.1): the room foreman's and builders' contracts that need no whole dig: configuration refusals,
## the tool gate the bound row decides, arrival and registration on the parking, the idle builder's readings, the
## stuck room and a lost crew member. Kitchen fixture (retired content-6 pick rows, tests only).

const ForemanTests := preload("res://test/test_underground_room_foreman.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const DigOrder := preload("res://scripts/core/underground_room_dig_order.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)

var _h: ForemanTests.Kitchen = null
var _room: Vector2i = NULL_REF


func before_each() -> void:
	"""One confirmed Kitchen per test."""
	_h = ForemanTests.Kitchen.new()
	_room = _h.confirmed_room()


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "actual fixture: %s" % _h.failures)
	_h = null


func _one() -> Array[Builder.Crew]:
	"""The fixture's mole as a one-member crew."""
	var crew: Array[Builder.Crew] = [_h.crew_member()]
	return crew


func test_the_bound_work_row_decides_the_tool_gate() -> void:
	"""DEC-052: a row naming no tool needs none; the retired pick rows name the tool item."""
	if _room == NULL_REF: return
	assert_equal(Builder.tool_gate_of(_h._profiles, 27), Jobs.GATE_SATISFIED, "pick FRONT row names tool 54")
	assert_equal(Builder.tool_gate_of(_h._profiles, 31), Jobs.GATE_NOT_REQUIRED, "a tool-free row")
	assert_equal(Builder.tool_gate_of(_h._profiles, -1), Jobs.GATE_NOT_REQUIRED, "no row")
	assert_equal(Builder.tool_gate_of(_h._profiles, _h._profiles._live.header[1]), Jobs.GATE_NOT_REQUIRED, "past the bank")
	assert_equal(Builder.tool_gate_of(null, 27), Jobs.GATE_NOT_REQUIRED, "no profiles")


func test_configuration_refuses_bad_scope_and_crews() -> void:
	"""Missing owners or containers, and crews outside ECON-001's 1-4 distinct builders, are named refusals."""
	if _room == NULL_REF: return
	var foreman: Foreman = Foreman.new()
	var o: Builder.Owners = _h.owners()
	assert_equal(foreman.configure(null, _room, _h.material, _h.material, _one()), Foreman.REFUSE_SCOPE, "no owners")
	assert_equal(foreman.configure(o, NULL_REF, _h.material, _h.material, _one()), Foreman.REFUSE_SCOPE, "no room")
	assert_equal(foreman.configure(o, _room, NULL_REF, _h.material, _one()), Foreman.REFUSE_SCOPE, "no storage")
	assert_equal(foreman.configure(o, _room, _h.material, NULL_REF, _one()), Foreman.REFUSE_SCOPE, "no spoil container")
	var none: Array[Builder.Crew] = []
	assert_equal(foreman.configure(o, _room, _h.material, _h.material, none), Foreman.REFUSE_CREW, "nobody")
	var member: Builder.Crew = _h.crew_member()
	var twice: Array[Builder.Crew] = [member, member]
	assert_equal(foreman.configure(o, _room, _h.material, _h.material, twice), Foreman.REFUSE_CREW, "the same worker twice")
	var five: Array[Builder.Crew] = []
	for index: int in Foreman.MAX_BUILDERS + 1: five.append(_member(Vector2i(index + 100, 1), Vector2i(index, 1)))
	assert_equal(foreman.configure(o, _room, _h.material, _h.material, five), Foreman.REFUSE_CREW, "more than four")
	var holes: Array[Builder.Crew] = [member, null]
	assert_equal(foreman.configure(o, _room, _h.material, _h.material, holes), Foreman.REFUSE_CREW, "an empty place")
	var shared: Array[Builder.Crew] = [member, _member(Vector2i(99, 1), member.parking)]
	assert_equal(foreman.configure(o, _room, _h.material, _h.material, shared), Foreman.REFUSE_CREW, "one parking for two")
	assert_false(foreman.is_running(), "nothing configured")
	assert_equal(foreman.state(), Foreman.STATE_FAILED, "unconfigured")


func _member(worker: Vector2i, parking: Vector2i) -> Builder.Crew:
	"""A crew record with the given worker and parking."""
	var member: Builder.Crew = Builder.Crew.new()
	member.worker = worker; member.parking = parking
	return member


func test_configuration_passes_on_the_owners_own_refusals() -> void:
	"""A stale worker, a room with no Sites and an unbound retreat row are refused before anything is touched."""
	if _room == NULL_REF: return
	var o: Builder.Owners = _h.owners()
	var stale: Array[Builder.Crew] = [_member(Vector2i(_h._worker.x, _h._worker.y + 1), _h.parking)]
	assert_equal(Foreman.new().configure(o, _room, _h.material, _h.material, stale), Builder.REFUSE_LOST, "stale worker")
	assert_equal(Foreman.new().configure(o, Vector2i(_room.x, _room.y + 1), _h.material, _h.material, _one()),
		DigOrder.REFUSE_EMPTY, "a room with no Sites")
	o.residents = null
	assert_equal(Foreman.new().configure(o, _room, _h.material, _h.material, _one()), Foreman.REFUSE_SCOPE, "no residents")
	o = _h.owners()
	var travel: int = _h.provider._ordinary_travel
	_h.provider._ordinary_travel = -1 # Negative-only: an unbound retreat row.
	assert_equal(Foreman.new().configure(o, _room, _h.material, _h.material, _one()), Foreman.REFUSE_ROWS, "no travel rows")
	_h.provider._ordinary_travel = travel
	assert_equal(_h._construction.live_project_count(), 0, "nothing opened")


func test_a_configured_foreman_reads_its_plan_and_its_idle_builders() -> void:
	"""Digging, eight cubes planned and none done; the builder is parked and idle with nothing taken."""
	if _room == NULL_REF: return
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), _room, _h.material, _h.material, _one()), &"", "configured")
	assert_true(foreman.is_running(), "digging")
	assert_equal(foreman.state(), Foreman.STATE_DIGGING, "state")
	assert_equal(foreman.error(), &"", "no refusal")
	assert_equal(foreman.room(), _room, "its room")
	assert_equal(foreman.total_cubes(), ForemanTests.KITCHEN_SITES, "eight cubes")
	assert_equal(foreman.done_cubes(), 0, "none done")
	assert_equal(foreman.order().keys.size(), ForemanTests.KITCHEN_SITES, "the dig order")
	var builder: Builder = foreman.builders()[0]
	assert_true(builder.idle() and not builder.failed(), "idle")
	assert_equal(builder.stage(), Builder.STAGE_IDLE, "stage")
	assert_equal([builder.error(), builder.cubes(), builder.accepted_mwu(), builder.target_index()], [&"", 0, 0, -1], "nothing yet")
	assert_equal([builder.take_finished(), builder.last_index(), builder.column_cubes()], [-1, -1, 0], "nothing finished")
	assert_false(builder.walking_next() or builder.in_motion() or builder.at_column_end(), "not on the way")
	assert_equal(builder.crew().worker, _h._worker, "its crew member")
	assert_equal(builder.advance(1), &"", "an idle builder does nothing")
	assert_equal(builder.continue_column(1, NULL_REF, 0, 1), Builder.REFUSE_STATE, "not at a column's end")
	assert_equal(builder.go_home(), Builder.REFUSE_STATE, "not at a station")


func test_registration_places_the_builder_on_its_parking_once() -> void:
	"""ADR1219's arrival: the Transform is placed on the parking point, the route actor registered there, once."""
	if _room == NULL_REF: return
	assert_true(_h._transforms.place(_h._worker, Phase.X + 60000, 512, Phase.Z, ForemanTests.StationTests.YAW_PLUS_X), "far off")
	var member: Builder.Crew = Builder.Crew.new()
	member.worker = _h._worker; member.tool = _h.tool; member.parking = _h.parking
	var foreman: Foreman = Foreman.new()
	var crew: Array[Builder.Crew] = [member]
	assert_equal(foreman.configure(_h.owners(), _room, _h.material, _h.material, crew), &"", "configured")
	var builder: Builder = foreman.builders()[0]
	assert_equal(builder.register(), &"", "arrived and registered")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_h._routes.read_actor_into(_h._worker, actor), &"", "a route actor")
	assert_equal(actor.location, _h.parking, "on its parking")
	assert_equal(actor.point, Vector3i(Phase.X - 3072, Phase.FLOOR, Phase.Z + 512), "at the parking point")
	assert_equal(builder.register(), &"", "a second call is a no-op")
	var body: PackedInt32Array = PackedInt32Array()
	builder.occupied_into(body)
	assert_equal(body.size(), 6, "a parked builder occupies one body box")
	assert_true(body[0] < actor.point.x and body[3] > actor.point.x and body[2] < actor.point.z and body[5] > actor.point.z, "around its point")
	assert_equal(builder.claim().size(), 0, "no cube claimed")


func test_a_room_whose_every_open_cube_is_refused_stops_with_the_last_refusal() -> void:
	"""Negative-only: with the two lower near cubes marked done in the dispatch record (not in Sites), every cube
	left is refused from parking; with all builders parked the room stops, named, and nothing is paid."""
	if _room == NULL_REF: return
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), _room, _h.material, _h.material, _one()), &"", "configured")
	foreman._cube[0] = Foreman.CUBE_DONE
	foreman._cube[2] = Foreman.CUBE_DONE
	var code: StringName = _h.run(foreman, 50)
	assert_equal(code, &"ROOM_STATION_GEOMETRY_CLOSED", "the last refusal names why")
	assert_equal(foreman.state(), Foreman.STATE_FAILED, "stopped")
	assert_equal(_h._construction.live_project_count(), 0, "nothing opened")
	assert_equal(foreman.advance(_h.tick + 1), &"ROOM_STATION_GEOMETRY_CLOSED", "a stopped room keeps its code")


func test_a_lost_builder_stops_the_room_with_its_code() -> void:
	"""The crew member leaves mid-approach: the builder fails, the room stops, the open BRACE stays unpaid."""
	if _room == NULL_REF: return
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), _room, _h.material, _h.material, _one()), &"", "configured")
	var builder: Builder = foreman.builders()[0]
	for step: int in 400:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "running")
		if builder.in_motion(): break
	assert_true(builder.in_motion(), "on its way")
	assert_true(_h._residents.despawn(_h._worker).ok, "the mole leaves")
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Builder.REFUSE_LOST, "named")
	assert_true(builder.failed(), "the builder failed")
	assert_equal(foreman.state(), Foreman.STATE_FAILED, "the room stopped")
	assert_equal(_h.sites._ever_cut.count(1), 0, "nothing cut")

extends "res://test/framework/test_case.gd"
## Decision 1933 (C2.1): the room foreman's and builders' contracts that need no whole dig: configuration refusals,
## the tool gate the bound row decides, arrival and registration on the parking, the idle builder's readings, the
## stuck room and a lost crew member. Kitchen fixture (retired content-6 pick rows, tests only).

const ForemanTests := preload("res://test/test_underground_room_foreman.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Frontier := preload("res://scripts/core/underground_room_frontier.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const DigOrder := preload("res://scripts/core/underground_room_dig_order.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Needs := preload("res://scripts/core/needs.gd")
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
	assert_equal(foreman.configure(null, _room, _h.material, _h.material, NULL_REF, _one()), Foreman.REFUSE_SCOPE, "no owners")
	assert_equal(foreman.configure(o, NULL_REF, _h.material, _h.material, NULL_REF, _one()), Foreman.REFUSE_SCOPE, "no room")
	assert_equal(foreman.configure(o, _room, NULL_REF, _h.material, NULL_REF, _one()), Foreman.REFUSE_SCOPE, "no storage")
	assert_equal(foreman.configure(o, _room, _h.material, NULL_REF, NULL_REF, _one()), Foreman.REFUSE_SCOPE, "no spoil container")
	var none: Array[Builder.Crew] = []
	assert_equal(foreman.configure(o, _room, _h.material, _h.material, NULL_REF, none), Foreman.REFUSE_CREW, "nobody")
	var member: Builder.Crew = _h.crew_member()
	var twice: Array[Builder.Crew] = [member, member]
	assert_equal(foreman.configure(o, _room, _h.material, _h.material, NULL_REF, twice), Foreman.REFUSE_CREW, "the same worker twice")
	var five: Array[Builder.Crew] = []
	for index: int in Foreman.MAX_BUILDERS + 1: five.append(_member(Vector2i(index + 100, 1), Vector2i(index, 1)))
	assert_equal(foreman.configure(o, _room, _h.material, _h.material, NULL_REF, five), Foreman.REFUSE_CREW, "more than four")
	var holes: Array[Builder.Crew] = [member, null]
	assert_equal(foreman.configure(o, _room, _h.material, _h.material, NULL_REF, holes), Foreman.REFUSE_CREW, "an empty place")
	var shared: Array[Builder.Crew] = [member, _member(Vector2i(99, 1), member.parking)]
	assert_equal(foreman.configure(o, _room, _h.material, _h.material, NULL_REF, shared), Foreman.REFUSE_CREW, "one parking for two")
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
	assert_equal(Foreman.new().configure(o, _room, _h.material, _h.material, NULL_REF, stale), Builder.REFUSE_LOST, "stale worker")
	assert_equal(Foreman.new().configure(o, Vector2i(_room.x, _room.y + 1), _h.material, _h.material, NULL_REF, _one()),
		DigOrder.REFUSE_EMPTY, "a room with no Sites")
	o.residents = null
	assert_equal(Foreman.new().configure(o, _room, _h.material, _h.material, NULL_REF, _one()), Foreman.REFUSE_SCOPE, "no residents")
	o = _h.owners()
	var travel: int = _h.provider._ordinary_travel
	_h.provider._ordinary_travel = -1 # Negative-only: an unbound retreat row.
	assert_equal(Foreman.new().configure(o, _room, _h.material, _h.material, NULL_REF, _one()), Foreman.REFUSE_ROWS, "no travel rows")
	_h.provider._ordinary_travel = travel
	assert_equal(_h._construction.live_project_count(), 0, "nothing opened")


func test_a_configured_foreman_reads_its_plan_and_its_idle_builders() -> void:
	"""Digging, eight cubes planned and none done; the builder is parked and idle with nothing taken."""
	if _room == NULL_REF: return
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), _room, _h.material, _h.material, NULL_REF, _one()), &"", "configured")
	assert_true(foreman.is_running(), "digging")
	assert_equal(foreman.state(), Foreman.STATE_DIGGING, "state")
	assert_equal(foreman.error(), &"", "no refusal")
	assert_equal(foreman.room(), _room, "its room")
	assert_equal(foreman.total_cubes(), ForemanTests.KITCHEN_SITES, "eight cubes")
	assert_equal(foreman.done_cubes(), 0, "none done")
	assert_equal(foreman.order().rows.size(), ForemanTests.KITCHEN_SITES, "the dig order")
	assert_true(foreman.order().keys.is_empty() and foreman.order().distance.is_empty(), "only the rows are kept")
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
	assert_equal(foreman.configure(_h.owners(), _room, _h.material, _h.material, NULL_REF, crew), &"", "configured")
	var builder: Builder = foreman.builders()[0]
	assert_equal(builder.register(), &"", "arrived and registered")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_h._routes.read_actor_into(_h._worker, actor), &"", "a route actor")
	assert_equal(actor.location, _h.parking, "on its parking")
	assert_equal(actor.point, Vector3i(Phase.X - 3072, Phase.FLOOR, Phase.Z + 512), "at the parking point")
	assert_equal(builder.register(), &"", "a second call is a no-op")
	var body: PackedInt32Array = builder.occupied()
	assert_equal(body.size(), 6, "a parked builder occupies one body box")
	assert_true(body[0] < actor.point.x and body[3] > actor.point.x and body[2] < actor.point.z and body[5] > actor.point.z, "around its point")
	assert_equal(builder.claim().size(), 0, "no cube claimed")


func test_a_room_whose_every_open_cube_is_refused_stops_with_the_last_refusal() -> void:
	"""Negative-only: with the two near columns' bottom cubes marked done in the dispatch record (not in Sites), every
	cube left is refused from parking; with all builders parked the room stops, named, and nothing is paid."""
	if _room == NULL_REF: return
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), _room, _h.material, _h.material, NULL_REF, _one()), &"", "configured")
	foreman._cube[0] = Foreman.CUBE_DONE
	foreman._cube[4] = Foreman.CUBE_DONE
	var code: StringName = _h.run(foreman, 50)
	assert_equal(code, &"ROOM_STATION_GEOMETRY_CLOSED", "the last refusal names why")
	assert_equal(foreman.state(), Foreman.STATE_FAILED, "stopped")
	assert_equal(_h._construction.live_project_count(), 0, "nothing opened")
	assert_equal(foreman.advance(_h.tick + 1), &"ROOM_STATION_GEOMETRY_CLOSED", "a stopped room keeps its code")


func test_a_lost_builder_stops_the_room_with_its_code() -> void:
	"""The crew member leaves mid-approach: the builder fails, the room stops, the open BRACE stays unpaid."""
	if _room == NULL_REF: return
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), _room, _h.material, _h.material, NULL_REF, _one()), &"", "configured")
	var builder: Builder = foreman.builders()[0]
	for step: int in 400:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "running")
		if builder.in_motion(): break
	assert_true(builder.in_motion(), "on its way")
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	assert_equal(_h._work.tool_lot_of(row), NULL_REF, "no tool claimed on the way (it is claimed at the station)")
	assert_true(_h._jobs.release_worker(row).ok, "departure: its Job released first (decision 0017)")
	assert_true(_h._residents.despawn(_h._worker).ok, "the mole leaves")
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Builder.REFUSE_LOST, "named")
	assert_true(builder.failed(), "the builder failed")
	assert_equal(foreman.state(), Foreman.STATE_FAILED, "the room stopped")
	assert_equal(_h.sites._ever_cut.count(1), 0, "nothing cut")
	assert_equal(foreman.abandon_error(), &"", "released cleanly")
	assert_equal(_h._construction.live_project_count(), 0, "the unstarted BRACE was cancelled")
	var gone: Vector2i = _h._worker
	assert_true(foreman.crew_out(), "the departed resident's route actor is still registered (decision 1937)")
	_h.tick += 1
	assert_equal(foreman.advance_out(_h.tick), &"", "it leaves")
	assert_equal(_h._routes._lost_actor_row(gone), -1, "its actor removed (ADR1225), so its body blocks nothing")
	assert_false(foreman.crew_out(), "nobody left underground")


func test_a_builder_lost_while_parked_or_dead_at_its_station_stops_the_room() -> void:
	"""ADR1223's crew-loss rule in every stage: a mole that leaves before its arrival, or dies, stops the room."""
	if _room == NULL_REF: return
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), _room, _h.material, _h.material, NULL_REF, _one()), &"", "configured")
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	var builder: Builder = foreman.builders()[0]
	assert_false(builder.lost(), "alive and present")
	_h._jobs.needs()._status[row] = Needs.STATUS_DEAD # Negative-only: the mole dies before it is sent.
	_h._jobs.needs()._health[row] = 0
	assert_true(builder.lost(), "dead counts as lost")
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Builder.REFUSE_LOST, "named")
	assert_equal(foreman.state(), Foreman.STATE_FAILED, "stopped")
	assert_equal(_h._construction.live_project_count(), 0, "nothing opened")


func _configured(crew: Array[Builder.Crew]) -> Foreman:
	"""A configured foreman over the Kitchen."""
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), _room, _h.material, _h.material, NULL_REF, crew), &"", "configured")
	return foreman


func test_begin_refuses_a_site_that_is_not_the_next_unpaid_one_there() -> void:
	"""The contact step is aimed at one Site: a key that leads elsewhere is refused, nothing is opened."""
	if _room == NULL_REF: return
	var foreman: Foreman = _configured(_one())
	var builder: Builder = foreman.builders()[0]
	var order: DigOrder.Order = foreman.order()
	var other: Vector2i = Vector2i(order.rows[2], Sites.SITE_GENERATION)
	assert_equal(builder.begin(0, other, foreman._key(0), 1), Builder.REFUSE_TARGET, "a key and a Site that disagree")
	assert_true(builder.idle(), "still idle")
	assert_equal(_h._construction.live_project_count(), 0, "nothing opened")
	assert_equal(foreman.configure(_h.owners(), _room, _h.material, _h.material, NULL_REF, _one()), Foreman.REFUSE_STATE, "no re-configure while digging")


func test_a_row_that_needs_a_tool_is_refused_for_a_crew_member_without_one() -> void:
	"""DEC-052's gate from the other side: the retired pick rows name the tool, so Routes refuses to register a
	tool-less member, the room stops with Routes' own name, and nothing is opened."""
	if _room == NULL_REF: return
	var member: Builder.Crew = _h.crew_member()
	member.tool = NULL_REF
	var foreman: Foreman = _configured([member])
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), &"PROFILE_TOOL_REQUIRED", "named by the owner")
	assert_equal(_h._construction.live_project_count(), 0, "nothing opened")
	assert_equal(foreman.abandon_error(), &"", "nothing to release")


func test_a_busy_cold_lease_is_waited_out_not_counted_as_a_refusal() -> void:
	"""Another owner holding the one cold lease delays the contact step; the cube stays open and is taken next tick."""
	if _room == NULL_REF: return
	var foreman: Foreman = _configured(_one())
	var lease: int = _h._budget.acquire(Phase.Budget.COLD_BYTES)
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), &"", "nothing refused")
	assert_equal(foreman._cube[0], Foreman.CUBE_OPEN, "the first cube is still open")
	assert_true(foreman.builders()[0].idle(), "the builder waits")
	assert_equal(_h._budget.release(lease), &"", "lease returned")
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), &"", "taken")
	assert_equal(foreman._cube[0], Foreman.CUBE_TAKEN, "the first cube is taken")


func test_done_is_never_taken_from_the_counter_alone() -> void:
	"""Negative-only: a count that says every cube is done while Sites says otherwise stops the room, named."""
	if _room == NULL_REF: return
	var foreman: Foreman = _configured(_one())
	foreman._done = foreman.total_cubes()
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Foreman.REFUSE_NOT_DONE, "Sites decides")


func test_a_builder_that_dies_mid_phase_keeps_the_paid_phase_for_a_resume() -> void:
	"""A started phase is not cancelled when the room stops: its Project stays live (C2.3 resumes it) and only the
	worker is released, so the resident holds no Job."""
	if _room == NULL_REF: return
	var foreman: Foreman = _configured(_one())
	var builder: Builder = foreman.builders()[0]
	for step: int in 2000:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "running")
		if builder.stage() == Builder.STAGE_EARN: break
	assert_equal(builder.stage(), Builder.STAGE_EARN, "earning a started BRACE")
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	_h._jobs.needs()._status[row] = Needs.STATUS_DEAD # Negative-only: death mid-phase.
	_h._jobs.needs()._health[row] = 0
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Builder.REFUSE_LOST, "named")
	assert_equal(foreman.abandon_error(), &"", "released cleanly")
	assert_equal(_h._construction.live_project_count(), 1, "the paid BRACE is kept")
	assert_equal(_h._jobs.job_of(row), NULL_REF, "no Job held")


func test_a_raw_departure_that_skips_jobs_is_reported_not_hidden() -> void:
	"""A resident removed without decision 0017's departure (its Job still names it) cannot be released by Sites; the
	room stops with the loss and keeps the release refusal apart, rather than claiming a clean stop."""
	if _room == NULL_REF: return
	var foreman: Foreman = _configured(_one())
	var builder: Builder = foreman.builders()[0]
	for step: int in 400:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "running")
		if builder.in_motion(): break
	assert_true(_h._residents.despawn(_h._worker).ok, "removed with its Job still assigned")
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Builder.REFUSE_LOST, "named")
	assert_equal(foreman.abandon_error(), Sites.REFUSE_WORKER, "the release refusal is kept")


func test_a_brace_reserves_its_inputs_when_the_builder_sets_off() -> void:
	"""Decision 1934: the inputs are claimed for the BRACE Job at dispatch, before the walk, so a second builder never
	plans against stock the first one will use at START."""
	if _room == NULL_REF: return
	var foreman: Foreman = _configured(_one())
	var wood: int = _h._items.compiled_id(&"wood")
	var before: int = _free(wood)
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), &"", "dispatched")
	assert_equal(foreman.builders()[0].stage(), Builder.STAGE_TRAVEL, "on its way")
	assert_equal(_free(wood), before - Phase.Contract.BRACE_WOOD_MILLI, "the BRACE's wood is reserved")


func _free(item: int) -> int:
	"""Unreserved quantity of one item in the room's storage."""
	var total: int = 0
	var lot: Vector2i = _h._inventory.container_first_lot(_h.material)
	while lot != NULL_REF:
		if _h._inventory.lot_item_id(lot) == item: total += _h._inventory.lot_available_milli(lot)
		lot = _h._inventory.container_next_lot(lot)
	return total


func test_a_builder_sent_home_from_its_column_has_not_set_off() -> void:
	"""Going home starts a new walk: until it takes its first step the foreman's footprint check comes first."""
	if _room == NULL_REF: return
	var foreman: Foreman = _configured(_one())
	var builder: Builder = foreman.builders()[0]
	for step: int in 4000:
		if builder.at_column_end(): break
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "running")
	assert_true(builder.at_column_end() and builder._departed, "at the first cube's end, having walked there")
	assert_equal(builder.go_home(), &"", "sent home")
	assert_false(builder.in_motion(), "not yet set off")



func test_only_a_started_phase_is_taken_over() -> void:
	"""P-1933-2 (a): Frontier's resume contact takes a Site's live phase only once it is WORKING or done; a BRACE
	opened but not yet started (its builder still on the way) is refused as active, as before."""
	if _room == NULL_REF: return
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), _room, _h.material, _h.material, NULL_REF, _one()), &"", "configured")
	var builder: Builder = foreman.builders()[0]
	for step: int in 400:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "running")
		if builder.in_motion(): break
	var site: Vector2i = builder._site
	assert_true(site != NULL_REF and _h.sites.project_of(site) != NULL_REF, "its BRACE is open")
	assert_false(builder._phase_started(), "and not started")
	assert_equal(builder._contact(site, _h.sites._site_key[site.x]), Frontier.REFUSE_ACTIVE, "not taken over")

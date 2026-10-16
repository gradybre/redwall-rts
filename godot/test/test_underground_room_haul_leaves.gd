extends "res://test/framework/test_case.gd"
## Decision 1935: focused tests of the room haul's guards that the end-to-end Kitchen run cannot reach on its own.
## Delivery's room leaves are called on a real pinned operation while the world is changed under them (negative-only
## pokes, each restored); the builder's stage machine is driven directly for the column haul, the stall bound, a rest
## at a stand, the pose and Job after the haul and the haul ledgers; the trip claim is checked box by box, on a
## hand-built variant of the haul spans. Same Kitchen fixture as `test_underground_room_haul.gd`.

const HaulTests := preload("res://test/test_underground_room_haul.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Delivery := preload("res://scripts/core/underground_connector_delivery.gd")
const HaulPlanner := preload("res://scripts/core/haul_planner.gd")
const Hauler := preload("res://scripts/core/underground_entry_hauler.gd")
const Installer := preload("res://scripts/core/underground_entry_installer.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Needs := preload("res://scripts/core/needs.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REST_HOUR: int = 2
const WORK_HOUR: int = 8

var _h: HaulTests.HaulKitchen = null
var _room: Vector2i = NULL_REF


func before_each() -> void:
	"""One Kitchen with its haul stands and Delivery per test."""
	_h = HaulTests.HaulKitchen.new()
	_room = _h.haul_room()


func after_each() -> void:
	"""No Delivery packet escapes; the fixture's own assertions propagate."""
	if _h != null:
		if _h.delivery != null: assert_false(_h.delivery._busy, "no escaped delivery packet")
		_h.after_each()
		assert_true(_h.failures.is_empty(), "actual fixture: %s" % _h.failures)
	_h = null


func _foreman() -> Foreman:
	"""A configured foreman over the haul owners, the mole parked on M."""
	var foreman: Foreman = Foreman.new()
	var crew: Array[Builder.Crew] = [_h.store_member()]
	assert_equal(foreman.configure(_h.haul_owners(), _room, _h.material, _h.material, _h.staging, crew), &"", "configured")
	return foreman


func _set_off(foreman: Foreman) -> Builder:
	"""Register, plan the first cube's haul and put the pick into M (the haul rows hold no tool)."""
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), &"", "dispatched")
	assert_true(_h._gear.unequip(_h.tool, _h.material, false).ok, "pick put into M")
	return foreman.builders()[0]


func _run_until(foreman: Foreman, done: Callable, bound: int = 4000) -> void:
	"""Advance the foreman with no refusal until the condition holds."""
	for step: int in bound:
		if done.call(): return
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "running")
	assert_true(done.call(), "reached within the bound")


func _hauled(builder: Builder) -> bool:
	"""The haul has landed and the builder is on its way to the station."""
	return builder.stage() == Builder.STAGE_TRAVEL and builder.haul_trips() == 2


func _take_pick_back() -> void:
	"""Fixture step after the haul, as in the end-to-end test: turn empty-handed, take the pick, select its row."""
	var job: Vector2i = _h._jobs.job_of(_worker_row())
	assert_equal(Phase.WorldFixture.Binding.turn_actor(_h._binding, _h._worker, job, HaulTests.StationTests.YAW_PLUS_X,
		HaulTests.Space.MAX_CHECKS), &"", "turned")
	assert_true(_h._gear.equip(_h.tool, _h._worker).ok, "pick taken back")
	assert_equal(_h._routes.refresh_travel_actor(_h._worker, job, 5, 1, HaulTests.StationTests.CONTENT, 0, -1, _h.tool),
		&"", "pick travel row")


func _worker_row() -> int:
	"""The mole's Resident row."""
	return _h._residents.directory().get_typed_row(_h._worker)


func _kill() -> void:
	"""Negative-only: the mole dies."""
	_h._jobs.needs()._status[_worker_row()] = Needs.STATUS_DEAD
	_h._jobs.needs()._health[_worker_row()] = 0


# --- Delivery's room leaves on a real pinned operation ------------------------------------------------------------

func _pinned() -> Builder:
	"""A HAUL Job for the first BRACE, assigned to the toolless mole, and Delivery pinned on it (room branch)."""
	var builder: Builder = _set_off(_foreman())
	var project: Vector2i = _h.sites.project_of(builder._site)
	var made: Jobs.OpResult = _h._jobs.create_job(Jobs.JOB_KIND_HAUL, 0, 0, HaulPlanner.HAUL_LOAD_MILLI_WU, 0)
	assert_true(_h._jobs.set_requester(made.value, project).ok and _h._jobs.set_source(made.value, project).ok, "source")
	assert_true(_h._jobs.assign_worker(_worker_row(), made.value).ok, "assigned")
	assert_equal(_h.delivery._enter(), &"", "one operation")
	assert_equal(_h.delivery._pin_job(made.ref, Delivery.ADMIT), &"", "pinned")
	assert_true(_h.delivery._room_haul, "the room branch")
	assert_equal(Delivery._room_source_leaf(_h.delivery), &"", "unchanged world")
	return builder


func test_the_room_leaf_refuses_a_publication_after_the_pin() -> void:
	"""A Location or a route published after the pin refuses the operation's final leaf."""
	if _room == NULL_REF: return
	_pinned()
	_h._stand(Vector3i(Phase.X - 1536, Phase.FLOOR, Phase.Z + 3584))
	assert_equal(Delivery._room_source_leaf(_h.delivery), Delivery.REFUSE_SOURCE, "a Location was published")
	_h.delivery._pin_receipts()
	assert_equal(Delivery._room_source_leaf(_h.delivery), &"", "re-pinned")
	var token: int = _h._begin()
	_h._span(token, _h.parking, _h.staging_at, [_h.store_point(), HaulTests.SOURCE_POINT], Profiles.MODE_WALK)
	assert_equal(_h._binding.seal(token), &"", "sealed")
	assert_equal(_h._binding.publish(token), &"", "published")
	_h._end(token)
	assert_equal(Delivery._room_source_leaf(_h.delivery), Delivery.REFUSE_SOURCE, "a route was published")
	Delivery._clear(_h.delivery)


func test_the_room_leaf_re_proves_the_project_s_site_and_room() -> void:
	"""Each fact `_room_dig` read at the pin is read again: an entry Placement naming the room, the Site's Project,
	its room's generation and the Project's Site generation (each poked, then restored)."""
	if _room == NULL_REF: return
	var builder: Builder = _pinned()
	var site: int = builder._site.x
	var p: RefCounted = _h.placements
	p._live.present[0] = 1
	p._set_pair(p._live, 1, 0, _room)
	assert_equal(Delivery._room_source_leaf(_h.delivery), Delivery.REFUSE_SOURCE, "now an entry corridor")
	p._live.present[0] = 0
	_h.sites._project_generation[site] += 1
	assert_equal(Delivery._room_source_leaf(_h.delivery), Delivery.REFUSE_SOURCE, "the Site holds another Project")
	_h.sites._project_generation[site] -= 1
	_h.sites._room_generation[site] += 1
	assert_equal(Delivery._room_source_leaf(_h.delivery), Delivery.REFUSE_SOURCE, "the Site's room is not live")
	_h.sites._room_generation[site] -= 1
	var row: int = _h._construction._directory.get_typed_row(_h.sites.project_of(builder._site))
	_h._construction._subject_generation[row] += 1
	assert_equal(Delivery._room_source_leaf(_h.delivery), Delivery.REFUSE_SOURCE, "not a Site subject")
	_h._construction._subject_generation[row] -= 1
	assert_equal(Delivery._room_source_leaf(_h.delivery), &"", "restored")
	Delivery._clear(_h.delivery)


func test_the_room_leaf_spends_its_placement_scan() -> void:
	"""The leaf's budget covers the receipts and one read per Placement row, exactly."""
	if _room == NULL_REF: return
	_pinned()
	var needed: int = 512 + _h.placements._capacity
	_h.delivery._checks = needed
	assert_equal(Delivery._room_source_leaf(_h.delivery), &"", "exactly enough")
	_h.delivery._checks = needed - 1
	assert_equal(Delivery._room_source_leaf(_h.delivery), Delivery.REFUSE_SOURCE, "one check short")
	Delivery._clear(_h.delivery)


# --- The trip claim, box by box ------------------------------------------------------------------------------------

func _has_box(builder: Builder, point: Vector3i, row: int) -> bool:
	"""The claim holds exactly the row's extent box standing at the point."""
	var at: int = builder._foot._extent_at(row)
	var e: PackedInt32Array = builder._foot._extents
	var boxes: PackedInt32Array = builder.claim()
	for b: int in range(0, boxes.size(), 6):
		var same: bool = true
		for axis: int in 3:
			same = same and boxes[b + axis] == point[axis] + e[at + axis] and boxes[b + axis + 3] == point[axis] + e[at + axis + 3]
		if same: return true
	return false


func test_the_claim_holds_each_item_s_lift_and_set_down() -> void:
	"""ADR1206: the lift row (+2) at R's stand and the set-down row (+4) at M's stand, for wood and for stone."""
	if _room == NULL_REF: return
	var builder: Builder = _set_off(_foreman())
	var offset: Vector3i = Grip.stock_offset(Grip.QUARTER)
	for key: StringName in [&"wood", &"stone"]:
		var carry: int = Grip.carry_row_for(_h._items.compiled_id(key))
		assert_true(_has_box(builder, HaulTests.SOURCE_POINT - offset, carry + 2), "%s lift at R's stand" % key)
		assert_true(_has_box(builder, _h.store_point() - offset, carry + 4), "%s set-down at M's stand" % key)


func test_the_claim_holds_the_empty_walk_between_the_stands() -> void:
	"""Hand-built variant: a direct span M to R's stand, so the walk out no longer passes M's stand; the empty walk
	back between the stands (the next trip's) is still claimed on the haul WALK row."""
	if _room == NULL_REF: return
	var offset: Vector3i = Grip.stock_offset(Grip.QUARTER)
	var token: int = _h._begin()
	_h._span(token, _h.parking, _h.stand_source, [_h.store_point(), HaulTests.SOURCE_POINT - offset], Profiles.MODE_WALK)
	assert_equal(_h._binding.seal(token), &"", "sealed")
	assert_equal(_h._binding.publish(token), &"", "published")
	_h._end(token)
	var builder: Builder = _set_off(_foreman())
	var walk: int = builder._walk_row()
	var at: int = builder._foot._extent_at(walk)
	var stand_x: int = HaulTests.SOURCE_POINT.x - offset.x
	var boxes: PackedInt32Array = builder.claim()
	var found: bool = false
	for b: int in range(0, boxes.size(), 6):
		var middle2: int = boxes[b + 2] + boxes[b + 5] # Twice the middle, so no division.
		found = found or (boxes[b] == stand_x + builder._foot._extents[at] and boxes[b + 3] == stand_x + builder._foot._extents[at + 3]
			and middle2 > 2 * (Phase.Z + 1024) and middle2 < 2 * (Phase.Z + 2048))
	assert_true(found, "the WALK row's boxes along the stands' line")


# --- The stage machine, driven directly ----------------------------------------------------------------------------

func test_a_column_s_next_cube_hauls_from_its_station_on_the_retreat_family() -> void:
	"""Painted height with a haul: the next cube up the column lacks wood, so the builder plans its walk from the
	station back to M (on the retreat family), and its approach from M (first leg: the Corridor access). It walks there
	on real legs; R is empty by then, so the hauler names it (`ENTRY_HAUL_NO_STAGED_STOCK`) and the BRACE is cancelled."""
	if _room == NULL_REF: return
	var foreman: Foreman = _foreman()
	var builder: Builder = _set_off(foreman)
	_run_until(foreman, _hauled.bind(builder))
	_take_pick_back()
	var dummy: Jobs.OpResult = _h._jobs.create_job(Jobs.JOB_KIND_BUILD, 0, 0, 1000, 0)
	assert_equal(Installer.claim_stock(_h.haul_owners(), _h.material, dummy.ref, _h._items.compiled_id(&"wood"),
		Grip.QUANTITY_MILLI - Contract.BRACE_WOOD_MILLI, Reservations.PURPOSE_EXCAVATION_INPUT), &"", "M's spare wood taken")
	_run_until(foreman, func() -> bool: return builder.column_cubes() == 1)
	assert_equal(builder.stage(), Builder.STAGE_TO_STORE, "to M from the station")
	assert_false(builder._leg_profiles.is_empty(), "real legs to walk")
	assert_equal(Vector2i(builder._approach_legs[0], builder._approach_legs[1]), _h._first, "the approach starts at M")
	var code: StringName = &""
	for step: int in 3000:
		_h.tick += 1
		code = foreman.advance(_h.tick)
		if code != &"": break
	assert_equal(code, Hauler.REFUSE_STAGED, "R is empty")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_h._routes.read_actor_into(_h._worker, actor), &"", "actor")
	assert_equal(actor.location, _h.parking, "it walked back onto M")
	assert_equal(foreman.abandon_error(), &"", "released cleanly")


func test_a_finished_trip_restarts_the_stall_bound() -> void:
	"""The hauler's progress, not the builder's stage, is what the stall bound watches during a haul."""
	if _room == NULL_REF: return
	var foreman: Foreman = _foreman()
	var builder: Builder = _set_off(foreman)
	_run_until(foreman, func() -> bool: return builder.stage() == Builder.STAGE_HAUL)
	builder._stage_ticks = Builder.STAGE_TICK_LIMIT - 1
	builder._haul_marker = -1 # Negative-only: as if the hauler had just moved on.
	for step: int in 2:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "not stalled")


func test_a_rest_hour_at_a_stand_is_waited_out_not_a_stall() -> void:
	"""ADR1226: the hour turns to rest at R's stand; Work refuses the lift and the hauler waits there longer than the
	stall bound; when the hour allows work again the haul lands."""
	if _room == NULL_REF: return
	var foreman: Foreman = _foreman()
	var builder: Builder = _set_off(foreman)
	_run_until(foreman, func() -> bool: return builder._hauler != null and builder._hauler.stage() == Hauler.STAGE_LIFT)
	assert_true(_h._jobs.schedule().resolve(_worker_row(), REST_HOUR, false).ok, "the hour turns to rest")
	for step: int in Builder.STAGE_TICK_LIMIT + 60:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "resting")
	assert_equal(builder._hauler.stage(), Hauler.STAGE_LIFT, "still at the stand")
	assert_true(_h._jobs.schedule().resolve(_worker_row(), WORK_HOUR, false).ok, "a working hour again")
	_run_until(foreman, _hauled.bind(builder))


func test_after_the_haul_the_builder_stands_on_the_walk_row_and_travels_under_the_brace_job() -> void:
	"""The body is the haul WALK row's at M (the row it stands on), and the legs to the station carry the BRACE Job."""
	if _room == NULL_REF: return
	var foreman: Foreman = _foreman()
	var builder: Builder = _set_off(foreman)
	_run_until(foreman, _hauled.bind(builder))
	var at: int = builder._foot._extent_at(builder._walk_row())
	var e: PackedInt32Array = builder._foot._extents
	var m: Vector3i = _h.store_point()
	assert_equal(builder._foot.body(), PackedInt32Array([m.x + e[at], m.y + e[at + 1], m.z + e[at + 2],
		m.x + e[at + 3], m.y + e[at + 4], m.z + e[at + 5]]), "standing on the haul WALK row")
	_take_pick_back()
	var job: Vector2i = _h._jobs.ref_of(builder._job)
	_run_until(foreman, func() -> bool: return builder._leg_state == Builder.LEG_MOVING)
	assert_equal(_h._routes._resident_pair(Routes.R_JOB_SLOT, _worker_row()), job, "travelling under the BRACE Job")


func test_the_haul_ledgers_count_each_trip_once() -> void:
	"""Lost after one trip: one trip and its handling Work are counted, by the drop. Lost after the haul landed: the
	two trips stay two."""
	if _room == NULL_REF: return
	var foreman: Foreman = _foreman()
	var builder: Builder = _set_off(foreman)
	_run_until(foreman, func() -> bool: return builder._hauler != null and builder._hauler.trips() == 1)
	_kill()
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Builder.REFUSE_LOST, "named")
	assert_equal(builder.haul_trips(), 1, "one trip")
	assert_equal(builder.haul_mwu(), HaulPlanner.HAUL_LOAD_MILLI_WU + HaulPlanner.HAUL_UNLOAD_MILLI_WU, "its Work")


func test_trips_already_counted_are_not_counted_again_on_a_stop() -> void:
	"""A room stopped after its haul landed counts the two trips once."""
	if _room == NULL_REF: return
	var foreman: Foreman = _foreman()
	var builder: Builder = _set_off(foreman)
	_run_until(foreman, _hauled.bind(builder))
	_kill()
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Builder.REFUSE_LOST, "named")
	assert_equal(builder.haul_trips(), 2, "still two")


func test_only_a_brace_is_hauled_for() -> void:
	"""BACKFILL_CLOSE's earth has no certified carry: the haul plan is for BRACE inputs only, so it plans nothing."""
	if _room == NULL_REF: return
	var builder: Builder = _set_off(_foreman())
	var queue: PackedInt32Array = PackedInt32Array()
	builder._operation = Contract.OP_BACKFILL_CLOSE
	assert_equal(builder._haul_units(queue), &"", "nothing to plan")
	assert_true(queue.is_empty(), "no unit")
	builder._operation = Contract.OP_BRACE


func test_two_stands_at_one_point_are_no_stand() -> void:
	"""The stand is the one WORK endpoint at the certified offset; a second one there leaves the haul without a stand,
	before anything is walked."""
	if _room == NULL_REF: return
	_h._stand(HaulTests.SOURCE_POINT - Grip.stock_offset(Grip.QUARTER))
	var foreman: Foreman = _foreman()
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Hauler.REFUSE_STAND, "no single stand")
	assert_equal(foreman.abandon_error(), &"", "released cleanly")


func test_a_rest_hour_on_arrival_at_the_storage_delays_the_haul() -> void:
	"""Jobs refuses an assignment in a rest hour, so the haul (whose first trip takes a HAUL Job) starts only when the
	hour allows work; the wait is not a stall."""
	if _room == NULL_REF: return
	var foreman: Foreman = _foreman()
	var builder: Builder = _set_off(foreman)
	assert_true(_h._jobs.schedule().resolve(_worker_row(), REST_HOUR, false).ok, "the hour turns to rest")
	for step: int in Builder.STAGE_TICK_LIMIT + 60:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "waiting on M")
	assert_equal(builder.stage(), Builder.STAGE_TO_STORE, "the haul has not started")
	assert_true(_h._jobs.schedule().resolve(_worker_row(), WORK_HOUR, false).ok, "a working hour again")
	_run_until(foreman, func() -> bool: return builder.stage() == Builder.STAGE_HAUL)

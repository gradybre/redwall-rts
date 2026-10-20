extends "res://test/framework/test_case.gd"
## Decision 1991 (slice C3): the room-dig runtime's named crew (P-1990-4 (a)), its one player Stop (P-1990-5 (a)),
## the load's cross-record checks (decision 1937's review M3), record version 2, the reserved-resident filter (review
## M7) and the parking that never republishes a failed join (review M5). On the ADR1161 Kitchen fixture (the retired
## content-6 pick rows, tests only), as the runtime's own suite.

const ForemanTests := preload("res://test/test_underground_room_foreman.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Parking := preload("res://scripts/core/underground_room_parking.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Progress := preload("res://scripts/core/underground_room_progress.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TICK_BOUND: int = 20000
## Wire offsets of the first record row: header 12, contacts 12, kept count 4; then row, generation, state, three
## container pairs (24), the crew's four pairs (32) and the release flag.
const ROW_AT: int = 28
const STATE_AT: int = ROW_AT + 8
const CREW_AT: int = ROW_AT + 12 + 24
const FLAG_AT: int = CREW_AT + 32

var _h: ForemanTests.Kitchen = null
var _room: Vector2i = NULL_REF
var _runtime: Runtime = null


func before_each() -> void:
	"""One confirmed Kitchen and a runtime bound to its owners."""
	_h = ForemanTests.Kitchen.new()
	_room = _h.confirmed_room()
	_runtime = Runtime.new(_h._residents.directory())
	assert_true(_runtime.bind_owners(_h.owners()), "owners")


func after_each() -> void:
	"""Free every fixture owner."""
	_runtime = null
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "actual fixture: %s" % _h.failures)
	_h = null


func _crew() -> Array[Builder.Crew]:
	"""The fixture's one mole (it holds the pick: the content-6 rows need it)."""
	var crew: Array[Builder.Crew] = [_h.crew_member()]
	return crew


func _named() -> PackedInt32Array:
	"""The fixture's mole as a named crew."""
	return PackedInt32Array([_h._worker.x, _h._worker.y])


func _digging() -> void:
	"""The Kitchen queued with its crew named and started."""
	assert_equal(_runtime.order_room(_room, _h.material, _h.material, NULL_REF, _named()), &"", "queued")
	assert_equal(_runtime.start_room(_room, _h.owners(), _crew()), &"", "started")


func _captured() -> PackedByteArray:
	"""The runtime's record at a quiet tick."""
	var bytes: PackedByteArray = PackedByteArray()
	var code: StringName = _runtime.capture(bytes)
	for step: int in 400:
		if code == &"": break
		_h.tick += 1
		_runtime.advance(_h.tick)
		code = _runtime.capture(bytes)
	assert_equal(code, &"", "captured")
	return bytes


func _restored(bytes: PackedByteArray) -> StringName:
	"""Restore `bytes` into a fresh runtime over the same owners."""
	var fresh: Runtime = Runtime.new(_h._residents.directory())
	assert_true(fresh.bind_owners(_h.owners()), "owners")
	return fresh.restore(bytes)


func test_a_record_keeps_the_crew_it_names_and_frees_it_with_the_slot() -> void:
	"""Up to four (slot, generation) pairs, kept with the record and cleared when its slot is freed; an odd or
	oversize list is refused."""
	if _room == NULL_REF: return
	var five: PackedInt32Array = PackedInt32Array()
	for index: int in 10: five.append(index)
	assert_equal(_runtime.order_room(_room, _h.material, _h.material, NULL_REF, five), Runtime.REFUSE_CREW_BUSY, "five")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material, NULL_REF, PackedInt32Array([1])),
		Runtime.REFUSE_CREW_BUSY, "odd")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material, NULL_REF, _named()), &"", "queued")
	assert_equal(_runtime.crew_of(_room), _named(), "kept")
	assert_equal(_runtime.crew_of(Vector2i(_room.x, _room.y + 1)), PackedInt32Array(), "a stale room names none")
	assert_equal(_runtime.cancel_queued(_room), &"", "cancelled")
	assert_equal(_runtime._crew.count(-1), _runtime._crew.size(), "the freed slot names no crew")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued with none named")
	assert_equal(_runtime.crew_of(_room), PackedInt32Array(), "the first idle mole")


func test_queued_rooms_are_listed_in_room_row_order() -> void:
	"""`queued_into` lists QUEUED records only, by room row, whatever slots they hold."""
	if _room == NULL_REF: return
	var ids: Directory = _h._residents.directory()
	var later: Vector2i = ids.create(Directory.KIND_ROOM)
	var earlier: Vector2i = _room
	assert_true(ids.get_typed_row(later) > ids.get_typed_row(earlier), "row order")
	assert_equal(_runtime.order_room(later, _h.material, _h.material), &"", "the later row first")
	assert_equal(_runtime.order_room(earlier, _h.material, _h.material), &"", "then the earlier")
	var out: Array[Vector2i] = []
	_runtime.queued_into(out)
	assert_equal(out, [earlier, later] as Array[Vector2i], "by row")
	assert_equal(_runtime.start_room(earlier, _h.owners(), _crew()), &"", "one starts")
	_runtime.queued_into(out)
	assert_equal(out, [later] as Array[Vector2i], "only the waiting one")


func test_stop_forgets_a_queued_room_and_refuses_what_it_cannot_stop() -> void:
	"""A QUEUED room is simply forgotten; a stale reference, an unknown room and a finished one are refused."""
	if _room == NULL_REF: return
	assert_equal(_runtime.stop_room(_room), Runtime.REFUSE_STATE, "nothing kept")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued")
	assert_equal(_runtime.stop_room(Vector2i(_room.x, _room.y + 1)), Runtime.REFUSE_ROOM, "stale")
	assert_equal(_runtime.stop_room(_room), &"", "stopped")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_NONE, "forgotten at once")
	assert_equal(_runtime.kept(), 0, "nothing kept")


func test_stop_halts_a_dig_walks_the_crew_out_and_releases_the_record() -> void:
	"""P-1990-5 (a): the dig halts with the player's code (not an alert), the record is STOPPED with its crew still
	underground and kept reserved, then released once the crew is out; the resident is free again."""
	if _room == NULL_REF: return
	_digging()
	var foreman: Foreman = _runtime.foreman_of(_room)
	for step: int in TICK_BOUND:
		_h.tick += 1
		_runtime.advance(_h.tick)
		if foreman.done_cubes() >= 1: break
	assert_equal(_runtime.stop_room(_room), &"", "stopped")
	assert_equal(foreman.error(), Foreman.REFUSE_PLAYER_STOP, "the player's code")
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_STOPPED, "stopped")
	assert_true(_runtime.reserves_resident(row), "reserved while underground")
	assert_equal(_runtime.stop_room(_room), &"", "a second Stop is harmless")
	var seen: Array[StringName] = []
	for step: int in TICK_BOUND:
		_h.tick += 1
		seen.append_array(_runtime.advance(_h.tick))
		if _runtime.kept() == 0: break
	assert_equal(seen, [] as Array[StringName], "a player's stop raises no alert")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_NONE, "released once out")
	assert_false(_runtime.reserves_resident(row), "free again")
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "orderable again")


func test_stop_releases_a_refusal_stopped_record_once_its_crew_is_out() -> void:
	"""One Stop also clears a dig a refusal stopped: at once when its crew is out, else when the crew walks out."""
	if _room == NULL_REF: return
	var pile: Vector2i = _h._inventory.create_spatial_ground_staging(_h.parking).ref
	assert_true(_h._inventory.create_lot(pile, _h._items.compiled_id(&"excavated_earth"),
		_h._inventory.container_free_mass_g(pile) - 1000, 1, 0, -1, 0, 0).ok, "a nearly full pile")
	assert_equal(_runtime.order_room(_room, _h.material, pile), &"", "queued")
	assert_equal(_runtime.start_room(_room, _h.owners(), _crew()), &"", "started")
	for step: int in TICK_BOUND:
		_h.tick += 1
		_runtime.advance(_h.tick)
		if _runtime.state_of(_room) == Runtime.RECORD_STOPPED: break
	assert_true(_runtime.foreman_of(_room).crew_out(), "stopped by the full pile, crew still underground")
	assert_equal(_runtime.stop_room(_room), &"", "the player stops it too")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_STOPPED, "kept while the crew is out")
	for step: int in TICK_BOUND:
		_h.tick += 1
		_runtime.advance(_h.tick)
		if _runtime.kept() == 0: break
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_NONE, "released once out, no release_room call")


func test_a_finished_dig_has_nothing_to_stop() -> void:
	"""DONE while its crew walks out: Stop is refused; the record releases itself as before."""
	if _room == NULL_REF: return
	_digging()
	for step: int in TICK_BOUND:
		_h.tick += 1
		_runtime.advance(_h.tick)
		if _runtime.state_of(_room) == Runtime.RECORD_DONE: break
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_DONE, "done, crew walking out")
	assert_equal(_runtime.stop_room(_room), Runtime.REFUSE_STATE, "nothing to stop")
	assert_equal(_runtime.foreman_of(_room).stop(), Foreman.REFUSE_STATE, "nor at the foreman")


func test_the_reserved_filter_follows_every_foreman_added_and_answers_others_at_once() -> void:
	"""Review M7: a resident no kept builder names is not reserved (one byte); a builder is, through the full check;
	adding a foreman (a new dig) is seen at once; a dropped one only leaves a byte the full check answers."""
	if _room == NULL_REF: return
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	assert_false(_runtime.reserves_resident(row), "no foreman: nobody")
	_digging()
	assert_true(_runtime.reserves_resident(row), "the builder, at once")
	assert_eq_filter(row)
	assert_false(_runtime.reserves_resident(-1), "out of range")
	assert_false(_runtime.reserves_resident(Runtime.Residents.RESIDENT_CAPACITY), "out of range")
	assert_equal(_runtime.stop_room(_room), &"", "stopped")
	for step: int in TICK_BOUND:
		_h.tick += 1
		_runtime.advance(_h.tick)
		if _runtime.kept() == 0: break
	assert_false(_runtime.reserves_resident(row), "released: free")


func assert_eq_filter(builder_row: int) -> void:
	"""Every Resident row answers as the full scan of the foremen would."""
	for row: int in Runtime.Residents.RESIDENT_CAPACITY:
		var full: bool = false
		for foreman: Foreman in _runtime._foremen:
			full = full or foreman.reserves_resident(row)
		if _runtime.reserves_resident(row) != full:
			assert_true(false, "row %d disagrees with the full check (builder row %d)" % [row, builder_row])
			return


func test_a_named_crew_and_the_release_flag_round_trip_in_record_version_2() -> void:
	"""A stopped dig's release flag and a queued room's crew are saved and restored; the re-encode is identical."""
	if _room == NULL_REF: return
	_digging()
	var other: Vector2i = _h._residents.directory().create(Directory.KIND_ROOM)
	assert_equal(_runtime.order_room(other, _h.material, _h.material, NULL_REF, _named()), &"", "a second room waits")
	for step: int in 50:
		_h.tick += 1
		_runtime.advance(_h.tick)
	assert_equal(_runtime.stop_room(_room), &"", "stopped")
	var bytes: PackedByteArray = _captured()
	assert_equal(bytes.decode_s32(4), Progress.VERSION, "version 2")
	assert_equal(Progress.VERSION, 2, "decision 1991's version")
	var fresh: Runtime = Runtime.new(_h._residents.directory())
	assert_true(fresh.bind_owners(_h.owners()), "owners")
	assert_equal(fresh.restore(bytes), &"", "restored")
	assert_equal(fresh.crew_of(other), _named(), "the waiting crew")
	var slot: int = fresh._slot(fresh._row(_room))
	assert_true(slot >= 0, "the stopped record was captured while its crew was still underground")
	if slot >= 0:
		assert_equal(fresh._state[slot], Runtime.RECORD_STOPPED, "STOPPED")
		assert_equal(fresh._release_out[slot], 1, "the stopped record still releases once out")


func test_a_version_1_record_is_refused() -> void:
	"""DEC-055 item 1 (as P-1972-3 did): a record from before decision 1991 is refused, ROOM_SAVE_VERSION."""
	if _room == NULL_REF: return
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued")
	var bytes: PackedByteArray = _captured()
	bytes.encode_s32(4, 1)
	assert_equal(_restored(bytes), Progress.REFUSE_VERSION, "version 1 refused")


func test_a_load_re_proves_the_cross_record_invariants() -> void:
	"""Review M3: a record whose state disagrees with its foreman, a QUEUED record with a foreman, or a malformed
	named crew is refused, though every scalar is in range."""
	if _room == NULL_REF: return
	_digging()
	for step: int in 50:
		_h.tick += 1
		_runtime.advance(_h.tick)
	var bytes: PackedByteArray = _captured()
	assert_equal(_restored(bytes), &"", "the record itself restores")
	assert_equal(bytes.decode_s32(STATE_AT), Runtime.RECORD_DIGGING, "the state field located")
	for state: int in [Runtime.RECORD_QUEUED, Runtime.RECORD_DONE, Runtime.RECORD_STOPPED]:
		var wrong: PackedByteArray = bytes.duplicate()
		wrong.encode_s32(STATE_AT, state)
		assert_equal(_restored(wrong), Progress.REFUSE_SHAPE, "a running foreman under state %d" % state)
	var gap: PackedByteArray = bytes.duplicate()
	gap.encode_s32(CREW_AT, -1); gap.encode_s32(CREW_AT + 4, -1)
	gap.encode_s32(CREW_AT + 8, _h._worker.x); gap.encode_s32(CREW_AT + 12, _h._worker.y)
	assert_equal(_restored(gap), Progress.REFUSE_SHAPE, "a member after a gap")
	var twice: PackedByteArray = bytes.duplicate()
	twice.encode_s32(CREW_AT + 8, _h._worker.x); twice.encode_s32(CREW_AT + 12, _h._worker.y)
	assert_equal(_restored(twice), Progress.REFUSE_SHAPE, "a member named twice")
	var half: PackedByteArray = bytes.duplicate()
	half.encode_s32(CREW_AT + 12, 0)
	assert_equal(_restored(half), Progress.REFUSE_SHAPE, "half a null pair")


func test_a_queued_record_with_a_foreman_or_a_stopped_one_without_is_refused() -> void:
	"""Review M3: only a QUEUED record has no foreman."""
	if _room == NULL_REF: return
	assert_equal(_runtime.order_room(_room, _h.material, _h.material), &"", "queued")
	var bytes: PackedByteArray = _captured()
	var lone: PackedByteArray = bytes.duplicate()
	lone.encode_s32(STATE_AT, Runtime.RECORD_STOPPED)
	assert_equal(_restored(lone), Progress.REFUSE_SHAPE, "a STOPPED record with no foreman")
	lone.encode_s32(STATE_AT, Runtime.RECORD_DIGGING)
	assert_equal(_restored(lone), Progress.REFUSE_SHAPE, "a DIGGING record with no foreman")


func test_a_parking_whose_spans_never_join_is_not_published_again() -> void:
	"""Review M5: a candidate whose spans to the access already exist but do not join is passed over without adding
	two more spans on every later order."""
	if _room == NULL_REF: return
	var owners: Builder.Owners = _h.owners()
	var ctx: Builder.Context = Foreman._context(owners, _h.material, _h.material)
	var ask: Parking.Request = Parking.Request.new()
	ask.access = _h._first; ask.forward = ctx.forward; ask.backward = ctx.backward; ask.content = ctx.content
	ask.room_box = Composer._room_box(_h.sites, _room)
	var found: Array[Vector2i] = []
	assert_equal(Parking.find_into(owners, ask, found), &"", "a parking")
	assert_true(Parking._span_between(owners.routes, found[0], _h._first), "joined by its spans")
	assert_false(Parking._span_between(owners.routes, _h._first, _h._worker), "not between unrelated refs")
	var unjoined: Parking.Request = Parking.Request.new()
	unjoined.access = ask.access; unjoined.content = ask.content; unjoined.room_box = ask.room_box
	unjoined.forward = ask.backward; unjoined.backward = ask.backward # Rows that cannot join it both ways.
	var again: Array[Vector2i] = []
	Parking.find_into(owners, unjoined, again)
	var later: int = owners.routes._live.edge_count
	Parking.find_into(owners, unjoined, again)
	assert_equal(owners.routes._live.edge_count, later, "a second ask publishes nothing more")
	# The path itself (review M-5): an endpoint with spans to the access that do not join on the asked rows.
	var access: Locations.Record = Parking._record()
	assert_equal(owners.locations.read_location_into(_h._first, access), &"", "the access")
	var point: Vector3i = Parking._point(owners.locations, found[0].x)
	var rows: int = owners.profiles._live.header[1]
	var tried: int = 0
	for row: int in rows:
		var other: Parking.Request = Parking.Request.new()
		other.access = ask.access; other.content = ask.content; other.room_box = ask.room_box
		other.forward = row; other.backward = row
		if Parking._joined(owners, other, found[0]): continue
		var before: int = owners.routes._live.edge_count
		assert_equal(Parking._parking_at(owners, other, access, point), NULL_REF, "passed over on row %d" % row)
		assert_equal(owners.routes._live.edge_count, before, "no span published on row %d" % row)
		tried += 1
	print("P1ROWS ", tried, " of ", rows)
	assert_true(tried > 0, "some row does not join it")


func test_a_stopped_foreman_under_a_digging_or_done_record_is_refused() -> void:
	"""Review M3, the other way round: a failed foreman saved under a DIGGING (or DONE) record is refused."""
	if _room == NULL_REF: return
	_digging()
	for step: int in 50:
		_h.tick += 1
		_runtime.advance(_h.tick)
	assert_equal(_runtime.stop_room(_room), &"", "stopped, its crew still underground")
	var bytes: PackedByteArray = _captured()
	assert_equal(bytes.decode_s32(STATE_AT), Runtime.RECORD_STOPPED, "saved STOPPED")
	assert_equal(_restored(bytes), &"", "as it is, it restores")
	for state: int in [Runtime.RECORD_DIGGING, Runtime.RECORD_DONE]:
		var wrong: PackedByteArray = bytes.duplicate()
		wrong.encode_s32(STATE_AT, state)
		wrong[FLAG_AT] = 0 # Only the foreman's state may refuse it (the release flag is checked on its own).
		assert_equal(_restored(wrong), Progress.REFUSE_SHAPE, "a stopped foreman under state %d" % state)


func test_a_stop_before_the_crew_walked_in_releases_the_record_at_once() -> void:
	"""Review M-5 (M11): a dig stopped before any builder is underground has no crew to wait for; `stop_room` releases
	its record itself, since the host advances only while something runs."""
	if _room == NULL_REF: return
	_digging()
	var foreman: Foreman = _runtime.foreman_of(_room)
	assert_false(foreman.crew_out(), "nobody underground yet")
	assert_equal(_runtime.stop_room(_room), &"", "stopped")
	assert_equal(_runtime.state_of(_room), Runtime.RECORD_NONE, "released without a tick")
	assert_equal(_runtime.kept(), 0, "nothing kept")
	assert_false(_runtime.is_running(), "nothing runs")


func test_a_release_flag_on_a_record_nobody_stopped_is_refused() -> void:
	"""Review LOW: the release flag is set only by a Stop; a load finding it on a DIGGING record (or above 1) refuses."""
	if _room == NULL_REF: return
	_digging()
	var bytes: PackedByteArray = _captured()
	assert_equal(bytes.decode_s32(STATE_AT), Runtime.RECORD_DIGGING, "digging")
	assert_equal(bytes[FLAG_AT], 0, "the flag field located, clear")
	assert_equal(_restored(bytes), &"", "as captured")
	var flagged: PackedByteArray = bytes.duplicate()
	flagged[FLAG_AT] = 1
	assert_false(_restored(flagged) == &"", "a flag nobody set")

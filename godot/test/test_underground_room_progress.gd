extends "res://test/framework/test_case.gd"
## Decision 1936, P-1936-4 (a): the room-dig progress record (section 6 `underground_room_progress`). Next-tick parity
## (ARCH-SAVE-006) on the Kitchen fixtures: a dig whose runtime is saved and restored into a fresh runtime before
## every tick ends exactly as the same dig run uninterrupted, record for record; the record round-trips canonically;
## a malformed or foreign record is refused and leaves the runtime empty.

const ForemanTests := preload("res://test/test_underground_room_foreman.gd")
const HaulTests := preload("res://test/test_underground_room_haul.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Progress := preload("res://scripts/core/underground_room_progress.gd")
const EntryProgress := preload("res://scripts/core/underground_entry_progress.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Claim := preload("res://scripts/core/underground_room_claim.gd")
const CrewTests := preload("res://test/test_underground_room_foreman_crews.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TICK_BOUND: int = 20000

var _a: ForemanTests.Kitchen = null # Restored before every tick.
var _b: ForemanTests.Kitchen = null # Uninterrupted.
var _final: Runtime = null # The last restored runtime of a pair run.


func after_each() -> void:
	"""Free both fixtures, propagating their own assertions."""
	for fixture: ForemanTests.Kitchen in [_a, _b]:
		if fixture == null: continue
		fixture.after_each()
		assert_true(fixture.failures.is_empty(), "fixture: %s" % fixture.failures)
	_a = null
	_b = null
	_final = null


func _runtime(h: ForemanTests.Kitchen, room: Vector2i, staging: Vector2i, crew: Array[Builder.Crew],
		owners: Builder.Owners) -> Runtime:
	"""A runtime over the fixture's owners with the room ordered and started."""
	var runtime: Runtime = Runtime.new(h._residents.directory())
	assert_true(runtime.bind_owners(owners), "owners bound")
	assert_equal(runtime.order_room(room, h.material, h.material, staging), &"", "ordered")
	assert_equal(runtime.start_room(room, runtime.bound_owners(), crew), &"", "started")
	return runtime


func _swap(h: ForemanTests.Kitchen, runtime: Runtime, owners: Builder.Owners) -> Runtime:
	"""Save the runtime, restore the record into a fresh runtime over the same owners, and require the restored one
	to save the very same bytes."""
	var bytes: PackedByteArray = PackedByteArray()
	assert_equal(runtime.capture(bytes), &"", "captured")
	var fresh: Runtime = Runtime.new(h._residents.directory())
	assert_true(fresh.bind_owners(owners), "owners bound")
	assert_equal(fresh.restore(bytes), &"", "restored")
	var again: PackedByteArray = PackedByteArray()
	assert_equal(fresh.capture(again), &"", "captured again")
	assert_true(again == bytes, "the restored runtime saves the same record")
	return fresh


func test_a_dig_restored_before_every_tick_ends_as_the_uninterrupted_dig() -> void:
	"""ARCH-SAVE-006 on the Kitchen: the whole one-builder dig (walk in, 16 cubes, column hand-overs, walk out),
	saved and restored before every tick, saves the same record after every tick as the uninterrupted dig."""
	_a = ForemanTests.Kitchen.new()
	_b = ForemanTests.Kitchen.new()
	var room_a: Vector2i = _a.confirmed_room()
	var room_b: Vector2i = _b.confirmed_room()
	if room_a == NULL_REF or room_b == NULL_REF: return
	var owners_a: Builder.Owners = _a.owners()
	var a: Runtime = _runtime(_a, room_a, NULL_REF, [_a.crew_member()], owners_a)
	var b: Runtime = _runtime(_b, room_b, NULL_REF, [_b.crew_member()], _b.owners())
	var ticks: int = 0
	for step: int in TICK_BOUND:
		a = _swap(_a, a, owners_a)
		_a.tick += 1; _b.tick += 1
		var codes_a: Array[StringName] = a.advance(_a.tick).duplicate()
		var codes_b: Array[StringName] = b.advance(_b.tick).duplicate()
		assert_equal(codes_a, codes_b, "same refusals")
		if not _same_record(a, b): break
		ticks += 1
		if not a.is_running() and not b.is_running(): break
	assert_false(a.is_running() or b.is_running(), "both digs finished")
	assert_equal(_a.sites.virgin_sourced_milli(), _b.sites.virgin_sourced_milli(), "the same earth cut")
	assert_true(ticks > 2000, "restored before every one of %d ticks" % ticks)


func _same_record(a: Runtime, b: Runtime) -> bool:
	"""Both runtimes save the same bytes."""
	var bytes_a: PackedByteArray = PackedByteArray()
	var bytes_b: PackedByteArray = PackedByteArray()
	assert_equal(a.capture(bytes_a), &"", "a captured")
	assert_equal(b.capture(bytes_b), &"", "b captured")
	assert_true(bytes_a == bytes_b, "the same record")
	return bytes_a == bytes_b


func test_a_record_is_refused_unless_it_is_exactly_canonical() -> void:
	"""A truncated, extended, re-versioned or altered record is refused and leaves the runtime empty; an empty
	runtime saves the empty record, which restores to an empty runtime."""
	_a = ForemanTests.Kitchen.new()
	var room: Vector2i = _a.confirmed_room()
	if room == NULL_REF: return
	var owners: Builder.Owners = _a.owners()
	var runtime: Runtime = _runtime(_a, room, NULL_REF, [_a.crew_member()], owners)
	for step: int in 400:
		_a.tick += 1
		runtime.advance(_a.tick)
	for extra: int in 2: # Two more queued rows, so a row block can be out of order.
		var queued: Vector2i = _a._residents.directory().create(Directory.KIND_ROOM)
		assert_equal(runtime.order_room(queued, _a.material, _a.material), &"", "queued")
	var bytes: PackedByteArray = PackedByteArray()
	assert_equal(runtime.capture(bytes), &"", "captured mid-dig")
	var cases: Dictionary = {"truncated": bytes.slice(0, bytes.size() - 1), "extended": bytes + PackedByteArray([0]),
		"empty": PackedByteArray()}
	var versioned: PackedByteArray = bytes.duplicate(); versioned.encode_s32(4, Progress.VERSION + 1)
	cases["versioned"] = versioned
	var staged: PackedByteArray = bytes.duplicate(); staged.encode_s32(Progress.HEADER_BYTES + 16 + 8, 99) # The row's state.
	cases["a state out of range"] = staged
	var first: int = Progress.HEADER_BYTES + 16
	var swapped: PackedByteArray = bytes.slice(0, first) + bytes.slice(first + Progress.ROW_BYTES, first + 2 * Progress.ROW_BYTES) \
		+ bytes.slice(first, first + Progress.ROW_BYTES) + bytes.slice(first + 2 * Progress.ROW_BYTES)
	for name: String in cases:
		var fresh: Runtime = Runtime.new(_a._residents.directory())
		fresh.bind_owners(owners)
		assert_false(fresh.restore(cases[name]) == &"", "%s refused" % name)
		assert_true(fresh.is_empty(), "%s leaves it empty" % name)
	var reordered: Runtime = Runtime.new(_a._residents.directory())
	reordered.bind_owners(owners)
	assert_equal(reordered.restore(swapped), Progress.REFUSE_NONCANONICAL, "two row blocks swapped: in range, not canonical")
	assert_true(reordered.is_empty(), "and left empty")
	var empty: Runtime = Runtime.new(_a._residents.directory())
	var nothing: PackedByteArray = PackedByteArray()
	assert_equal(empty.capture(nothing), &"", "an empty runtime saves")
	var restored: Runtime = Runtime.new(_a._residents.directory())
	assert_true(restored.bind_owners(owners), "owners")
	assert_equal(restored.restore(nothing), &"", "and restores")
	assert_true(restored.is_empty(), "to an empty runtime")


func test_the_wire_bound_covers_the_largest_record() -> void:
	"""The codec's bound is its block constants at their limits (the census charges it): kept records, the Sites of
	running digs and the living builders."""
	assert_equal(Progress.LEG_LIST_BYTES, 4 + 12 * Claim.MAX_LEGS, "a leg list")
	assert_equal(Progress.MAX_WIRE_BYTES, Progress.HEADER_BYTES + Progress.RUNTIME_FIXED_BYTES
		+ Progress.MAX_KEPT * (Progress.ROW_BYTES + Progress.FOREMAN_FIXED_BYTES) + Progress.MAX_SITES * Progress.SITE_BYTES
		+ Progress.MAX_BUILDERS * Progress.BUILDER_BYTES, "the sum of the blocks")
	assert_equal(Progress.MAX_KEPT, Runtime.MAX_KEPT, "the runtime's own bound")


func _run_pair(owners_a: Builder.Owners, a: Runtime, b: Runtime, hook: Callable) -> int:
	"""Advance both digs to the end, A saved and restored before every tick, comparing their records after every
	tick; `hook` runs the same fixture step on both worlds when it is due. Returns the ticks run."""
	var ticks: int = 0
	for step: int in TICK_BOUND:
		a = _swap(_a, a, owners_a)
		_a.tick += 1; _b.tick += 1
		assert_equal(a.advance(_a.tick).duplicate(), b.advance(_b.tick).duplicate(), "same refusals")
		if hook.is_valid(): hook.call(a, b)
		if not _same_record(a, b): break
		ticks += 1
		if not a.is_running() and not b.is_running(): break
	assert_false(a.is_running() or b.is_running(), "both digs finished")
	_final = a
	return ticks


func test_a_haul_restored_before_every_tick_ends_as_the_uninterrupted_haul() -> void:
	"""ARCH-SAVE-006 through decision 1935's haul: the hauler's own block (ADR1218) inside the builder's, the trips'
	planned edges and the reserved inputs, restored before every tick."""
	var ha: HaulTests.HaulKitchen = HaulTests.HaulKitchen.new()
	var hb: HaulTests.HaulKitchen = HaulTests.HaulKitchen.new()
	_a = ha; _b = hb
	var room_a: Vector2i = ha.haul_room()
	var room_b: Vector2i = hb.haul_room()
	if room_a == NULL_REF or room_b == NULL_REF: return
	var owners_a: Builder.Owners = ha.haul_owners()
	var a: Runtime = _runtime(ha, room_a, ha.staging, [ha.store_member()], owners_a)
	var b: Runtime = _runtime(hb, room_b, hb.staging, [hb.store_member()], hb.haul_owners())
	_a.tick += 1; _b.tick += 1
	a.advance(_a.tick); b.advance(_b.tick)
	for h: HaulTests.HaulKitchen in [ha, hb]:
		assert_true(h._gear.unequip(h.tool, h.material, false).ok, "pick put into M")
	var armed: Array[bool] = [false]
	var ticks: int = _run_pair(owners_a, a, b, _after_haul.bind(armed))
	assert_true(armed[0], "the haul landed")
	assert_true(ticks > 2000, "restored before every one of %d ticks" % ticks)


func _after_haul(a: Runtime, _b_runtime: Runtime, armed: Array[bool]) -> void:
	"""The haul test's own fixture step on both worlds, once the haul has landed in both."""
	if armed[0]: return
	var builder_a: Builder = a._foremen[0].builders()[0]
	if builder_a.stage() != Builder.STAGE_TRAVEL or builder_a.haul_trips() != 2: return
	armed[0] = true
	for h: HaulTests.HaulKitchen in [_a as HaulTests.HaulKitchen, _b as HaulTests.HaulKitchen]:
		var job: Vector2i = h._jobs.job_of(h._residents.directory().get_typed_row(h._worker))
		assert_equal(HaulTests.Phase.WorldFixture.Binding.turn_actor(h._binding, h._worker, job,
			HaulTests.StationTests.YAW_PLUS_X, HaulTests.Space.MAX_CHECKS), &"", "turned")
		assert_true(h._gear.equip(h.tool, h._worker).ok, "pick back")
		assert_equal(h._routes.refresh_travel_actor(h._worker, job, 5, 1, HaulTests.StationTests.CONTENT, 0, -1, h.tool),
			&"", "pick row")
		var rest: int = (ForemanTests.KITCHEN_SITES - 4) * Contract.BRACE_WOOD_MILLI
		assert_true(h._inventory.create_lot(h.material, h._items.compiled_id(&"wood"), rest, 1, 0, -1, 0, 0).ok, "wood")
		assert_true(h._inventory.create_lot(h.material, h._items.compiled_id(&"stone"), rest, 1, 0, -1, 0, 0).ok, "stone")


func test_two_builders_restored_before_every_tick_end_as_the_uninterrupted_pair() -> void:
	"""ARCH-SAVE-006 with two builders: the second's walk in, both footprints swept again from their plans, the
	blocked epochs and the turns they take."""
	var ha: CrewTests.WideKitchen = CrewTests.WideKitchen.new()
	var hb: CrewTests.WideKitchen = CrewTests.WideKitchen.new()
	_a = ha; _b = hb
	var room_a: Vector2i = ha.confirmed_room()
	var room_b: Vector2i = hb.confirmed_room()
	if room_a == NULL_REF or room_b == NULL_REF: return
	var owners_a: Builder.Owners = ha.owners()
	var crew_a: Array[Builder.Crew] = [ha.crew_member(), ha.second_member(CrewTests.SECOND_PARKING)]
	var crew_b: Array[Builder.Crew] = [hb.crew_member(), hb.second_member(CrewTests.SECOND_PARKING)]
	var a: Runtime = _runtime(ha, room_a, NULL_REF, crew_a, owners_a)
	var b: Runtime = _runtime(hb, room_b, NULL_REF, crew_b, hb.owners())
	var ticks: int = _run_pair(owners_a, a, b, Callable())
	assert_true(ticks > 2000, "restored before every one of %d ticks" % ticks)


func test_a_stopped_dig_restored_before_every_tick_recovers_and_walks_out_as_uninterrupted() -> void:
	"""ARCH-SAVE-006 through a stop: the spoil pile's refusal at CUT's START, the work source's recovery with the
	phase release pending, and the walk out."""
	_a = ForemanTests.Kitchen.new()
	_b = ForemanTests.Kitchen.new()
	var rooms: Array[Vector2i] = [_a.confirmed_room(), _b.confirmed_room()]
	if rooms.has(NULL_REF): return
	var piles: Array[Vector2i] = []
	for h: ForemanTests.Kitchen in [_a, _b]:
		var pile: Vector2i = h._inventory.create_spatial_ground_staging(h.parking).ref
		assert_true(h._inventory.create_lot(pile, h._items.compiled_id(&"excavated_earth"),
			h._inventory.container_free_mass_g(pile) - 1000, 1, 0, -1, 0, 0).ok, "a nearly full pile")
		piles.append(pile)
	var owners_a: Builder.Owners = _a.owners()
	var a: Runtime = Runtime.new(_a._residents.directory())
	var b: Runtime = Runtime.new(_b._residents.directory())
	for pair: Array in [[a, _a, owners_a, rooms[0], piles[0]], [b, _b, _b.owners(), rooms[1], piles[1]]]:
		assert_true(pair[0].bind_owners(pair[2]), "owners")
		assert_equal(pair[0].order_room(pair[3], pair[1].material, pair[4]), &"", "ordered")
		assert_equal(pair[0].start_room(pair[3], pair[2], [pair[1].crew_member()] as Array[Builder.Crew]), &"", "started")
	var ticks: int = _run_pair(owners_a, a, b, Callable())
	assert_equal(_final.state_of(rooms[0]), Runtime.RECORD_STOPPED, "stopped, its crew out")
	assert_true(ticks > 100, "restored before every one of %d ticks" % ticks)


func test_a_stopped_pair_restored_before_every_tick_walks_out_one_by_one_as_uninterrupted() -> void:
	"""Decision 1937 (review H4): two builders stop together but leave apart; the one already out is forgotten
	(`shed_crew`), so every record saved while the other is still underground restores."""
	var ha: CrewTests.WideKitchen = CrewTests.WideKitchen.new()
	var hb: CrewTests.WideKitchen = CrewTests.WideKitchen.new()
	_a = ha; _b = hb
	var rooms: Array[Vector2i] = [ha.confirmed_room(), hb.confirmed_room()]
	if rooms.has(NULL_REF): return
	var piles: Array[Vector2i] = []
	for h: CrewTests.WideKitchen in [ha, hb]:
		var pile: Vector2i = h._inventory.create_spatial_ground_staging(h.parking).ref
		assert_true(h._inventory.create_lot(pile, h._items.compiled_id(&"excavated_earth"),
			h._inventory.container_free_mass_g(pile) - 1000, 1, 0, -1, 0, 0).ok, "a nearly full pile")
		piles.append(pile)
	var owners_a: Builder.Owners = ha.owners()
	var a: Runtime = Runtime.new(ha._residents.directory())
	var b: Runtime = Runtime.new(hb._residents.directory())
	for pair: Array in [[a, ha, owners_a, rooms[0], piles[0]], [b, hb, hb.owners(), rooms[1], piles[1]]]:
		var crew: Array[Builder.Crew] = [pair[1].crew_member(), pair[1].second_member(CrewTests.SECOND_PARKING)]
		assert_true(pair[0].bind_owners(pair[2]), "owners")
		assert_equal(pair[0].order_room(pair[3], pair[1].material, pair[4]), &"", "ordered")
		assert_equal(pair[0].start_room(pair[3], pair[2], crew), &"", "started")
	var sizes: PackedInt32Array = PackedInt32Array()
	var ticks: int = _run_pair(owners_a, a, b, func(x: Runtime, _y: Runtime) -> void:
		var kept: int = x._foremen[0].builders().size()
		if sizes.is_empty() or sizes[sizes.size() - 1] != kept: sizes.append(kept))
	assert_equal(_final.state_of(rooms[0]), Runtime.RECORD_STOPPED, "stopped, its crew out")
	assert_true(sizes.has(1), "one builder was out before the other: %s" % sizes)
	assert_equal(sizes[sizes.size() - 1], 0, "both forgotten once out")
	assert_true(ticks > 100, "restored before every one of %d ticks" % ticks)

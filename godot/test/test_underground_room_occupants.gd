extends "res://test/framework/test_case.gd"
## Decision 1991 (C3; a C2 defect): the room phases' occupancy proof under ADR1219's rule. A living resident who is not
## a route actor (every surface resident, and a crew member who has not arrived yet) occupies the reach cube around
## its Transform; before, `_ordinary_occupants_leaf` refused every phase ROOM_PHASE_WORKER while one existed, which the
## fixtures never showed because every resident in them was crew. The game always has a resident who is not crew.

const KitchenTests := preload("res://test/test_underground_room_claw_kitchen.gd")
const StationTests := preload("res://test/test_underground_room_station_planner.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Bindings := preload("res://scripts/core/underground_room_world_bindings.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TICK_BOUND: int = 40000
const NEAR: StringName = &"ROUTE_UNREGISTERED_RESIDENT_NEAR"

var _h: KitchenTests.ClawKitchen = null


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % _h.failures)
	_h = null


func _kitchen() -> Vector2i:
	"""The stocked claw Kitchen, confirmed; null when the fixture failed."""
	_h = KitchenTests.ClawKitchen.new()
	_h.stocked = true
	return _h.confirmed_room()


func _bystander() -> Vector2i:
	"""One more claw mole who is not crew, scheduled, standing far off on the surface (never registered)."""
	return _h._mole_at(Vector3i(Phase.X, Phase.FLOOR, Phase.Z), NULL_REF).worker


func _order(room: Vector2i, crew: PackedInt32Array) -> Runtime:
	"""The composer's order of the room with the named crew; the runtime, or null when refused."""
	var runtime: Runtime = Runtime.new(_h._residents.directory())
	assert_true(runtime.bind_owners(_h.owners()), "owners")
	var order: Composer.Order = Composer.Order.new()
	order.room = room; order.access = _h._first; order.travel = _h.provider._ordinary_travel
	order.storage = _h.material; order.output = _h.material; order.crew = crew
	var code: StringName = Composer.order(runtime, _h.placements, order)
	assert_equal(code, &"", "ordered")
	return runtime if code == &"" else null


func _run(runtime: Runtime) -> Array[StringName]:
	"""Every fixed tick to the end; the refusals seen."""
	var seen: Array[StringName] = []
	for step: int in TICK_BOUND:
		_h.tick += 1
		seen.append_array(runtime.advance(_h.tick))
		if not runtime.is_running(): break
	return seen


func _registered(worker: Vector2i) -> bool:
	"""The resident is a Routes actor."""
	var row: int = _h._residents.directory().get_typed_row(worker)
	return _h._routes._resident_ref(row) == worker


func _worker_crew() -> PackedInt32Array:
	"""The fixture's claw mole, named."""
	return PackedInt32Array([_h._worker.x, _h._worker.y])


func _work_point() -> Vector3i:
	"""The Kitchen's WORK endpoint, where the builder stands for its first cube."""
	return Composer.Parking._point(_h.owners().locations, _h._last.x)


func test_a_far_resident_who_is_not_crew_lets_the_dig_finish() -> void:
	"""Before decision 1991 every phase refused ROOM_PHASE_WORKER at 0 of 16; now the far bystander is clear."""
	var room: Vector2i = _kitchen()
	if room == NULL_REF: return
	var other: Vector2i = _bystander()
	var runtime: Runtime = _order(room, _worker_crew())
	if runtime == null: return
	var foreman: Foreman = runtime.foreman_of(room)
	assert_equal(_run(runtime), [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), StationTests.KITCHEN_SITES, "every cube dug")
	assert_false(_registered(other), "the bystander was never a route actor")


func test_a_resident_who_is_not_crew_within_reach_of_the_work_refuses_named() -> void:
	"""ADR1219's reach cube still refuses: a bystander who comes within reach of the builder while it works at its
	station stops the dig, named ROUTE_UNREGISTERED_RESIDENT_NEAR, and no cube is dug after it came."""
	var room: Vector2i = _kitchen()
	if room == NULL_REF: return
	var other: Vector2i = _bystander()
	var runtime: Runtime = _order(room, _worker_crew())
	if runtime == null: return
	var foreman: Foreman = runtime.foreman_of(room)
	var seen: Array[StringName] = []
	for step: int in TICK_BOUND:
		_h.tick += 1
		seen.append_array(runtime.advance(_h.tick))
		if foreman.done_cubes() >= 1 or not runtime.is_running(): break
	assert_equal(seen, [] as Array[StringName], "the first cube dug with the bystander far off")
	var at: Transforms.Pose = Transforms.Pose.new()
	assert_true(_h._transforms.read_into(_h._worker, at), "the builder's pose")
	assert_true(_h._transforms.place(other, at.x, at.y + 4096, at.z, StationTests.YAW_PLUS_X), "bystander overhead")
	var dug: int = foreman.done_cubes()
	seen = _run(runtime)
	assert_true(seen.has(NEAR), "named: %s" % [seen])
	assert_true(foreman.done_cubes() <= dug + 1, "at most the cube under way finished")


func _first_cube_dug(room: Vector2i) -> Runtime:
	"""The Kitchen ordered for the fixture's mole and dug until its first cube is done: the provider then holds the
	phase's query at the builder's WORK location. Null when that failed."""
	var runtime: Runtime = _order(room, _worker_crew())
	if runtime == null: return null
	var foreman: Foreman = runtime.foreman_of(room)
	for step: int in TICK_BOUND:
		_h.tick += 1
		assert_equal(runtime.advance(_h.tick), [] as Array[StringName], "no refusal")
		if foreman.done_cubes() >= 1 or not runtime.is_running(): break
	return runtime if foreman.done_cubes() >= 1 and _h.provider._ordinary_query != null else null


func _leaf(budget: int) -> StringName:
	"""The phases' occupancy leaf itself, for the fixture's builder, with a fresh budget."""
	_h.provider._entry_remaining = budget
	return _h.provider._ordinary_occupants_leaf(_h._worker)


func _query_point() -> Vector3i:
	"""The point of the phase query's WORK location."""
	return Composer.Parking._point(_h.owners().locations, _h.provider._ordinary_query.location.x)


func test_the_leaf_tests_an_unregistered_resident_at_the_work_location_and_charges_its_reach_test() -> void:
	"""The leaf itself (other proofs aside): a bystander above the query's WORK location is NEAR; the same bystander
	far off is clear, charging 8 checks a row plus ADR1219's 16 for its reach test."""
	var room: Vector2i = _kitchen()
	if room == NULL_REF: return
	var other: Vector2i = _bystander()
	if _first_cube_dug(room) == null: return
	var work: Vector3i = _query_point()
	assert_true(_h._transforms.place(other, work.x, work.y + 4096, work.z, StationTests.YAW_PLUS_X), "overhead")
	assert_equal(_leaf(1 << 30), NEAR, "within reach of the work location")
	assert_true(_h._transforms.place(other, work.x + 60000, work.y, work.z, StationTests.YAW_PLUS_X), "far off")
	assert_equal(_leaf(1 << 30), &"", "clear far off")
	assert_equal((1 << 30) - _h.provider._entry_remaining, 8 * Routes.RESIDENT_CAPACITY + 16,
		"8 checks a row and 16 for the one unregistered resident")
	assert_equal(_leaf(8 * Routes.RESIDENT_CAPACITY + 15), Bindings.ROOM_REFUSE_CAPACITY, "the reach test is charged")


func test_a_registered_resident_who_is_not_crew_keeps_the_exact_proof() -> void:
	"""A route actor who is not crew is proved by its exact body, as before (256 checks and its boxes), never by the
	reach cube: parked on the second parking, it is clear, and the leaf spent more than the reach test would."""
	var room: Vector2i = _kitchen()
	if room == NULL_REF: return
	var member: Builder.Crew = _h.second_member(KitchenTests.SECOND_PARKING)
	if _first_cube_dug(room) == null: return
	var point: Vector3i = KitchenTests.SECOND_PARKING
	assert_true(_h._transforms.place(member.worker, point.x, point.y, point.z, StationTests.YAW_PLUS_X), "parked")
	var forward: int = KitchenTests.CLAW_FORWARD
	assert_equal(_h._routes.admit_travel_actor(member.worker, NULL_REF, member.parking, forward,
		_h._profiles._live.quantities[forward], _h._profiles._live.header[0], 0, -1), &"", "registered")
	assert_true(_registered(member.worker), "a route actor")
	assert_equal(_leaf(1 << 30), &"", "its exact body is clear of the work")
	assert_true((1 << 30) - _h.provider._entry_remaining > 8 * Routes.RESIDENT_CAPACITY + 256,
		"the exact proof ran (%d checks)" % ((1 << 30) - _h.provider._entry_remaining))


func test_a_two_mole_crew_digs_while_its_second_member_is_still_on_the_surface() -> void:
	"""The composer's two-mole crew on the hauling Kitchen: the second member is not a route actor when the first
	starts work (it walks in from far off), and the first's phases are not refused for it; both dig to the end."""
	_h = KitchenTests.ClawKitchen.new()
	var room: Vector2i = _h.haul_room()
	if room == NULL_REF: return
	assert_true(_h._inventory.create_lot(_h.material, _h._items.compiled_id(&"wood"), Contract.BRACE_WOOD_MILLI, 1, 0, -1,
		0, 0).ok, "one BRACE of wood in M")
	assert_true(_h._inventory.create_lot(_h.material, _h._items.compiled_id(&"stone"), Contract.BRACE_STONE_MILLI, 1, 0, -1,
		0, 0).ok, "one BRACE of stone in M")
	for key: StringName in [&"wood", &"stone"]:
		assert_true(_h._inventory.create_lot(_h.staging, _h._items.compiled_id(key),
			(KitchenTests.UNITS_EACH - 1) * KitchenTests.HaulTests.Grip.QUANTITY_MILLI, 1, 0, -1, 0, 0).ok, "the rest of R")
	var second: Builder.Crew = _h.second_member(KitchenTests.SECOND_PARKING)
	var runtime: Runtime = Runtime.new(_h._residents.directory())
	assert_true(runtime.bind_owners(_h.haul_owners()), "owners")
	var order: Composer.Order = Composer.Order.new()
	order.room = room; order.access = _h._first; order.travel = _h.provider._ordinary_travel
	order.storage = _h.material; order.output = _h.material; order.staging = _h.staging
	order.crew = PackedInt32Array([_h._worker.x, _h._worker.y, second.worker.x, second.worker.y])
	assert_equal(Composer.order(runtime, _h.placements, order), &"", "ordered")
	var foreman: Foreman = runtime.foreman_of(room)
	assert_equal(foreman.builders().size(), 2, "both members crew it")
	var unregistered_while_working: bool = false
	var seen: Array[StringName] = []
	for step: int in TICK_BOUND:
		_h.tick += 1
		seen.append_array(runtime.advance(_h.tick))
		if foreman.done_cubes() == 0 and not _registered(second.worker) and _registered(_h._worker):
			unregistered_while_working = true
		if not runtime.is_running(): break
	assert_true(unregistered_while_working, "the first was in while the second was not yet")
	assert_equal(seen, [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), StationTests.KITCHEN_SITES, "every cube dug")


func test_a_named_crew_of_four_digs_with_as_many_as_can_park_and_leaves_the_rest_free() -> void:
	"""P-1990-4 (a) on the plain claw Kitchen: four named moles; the access has two parkings off the builders' way and
	off the storage's location (the composer's own and the fixture's second), so two dig, each parked apart, the
	other two stay free, and the Kitchen is dug to the end."""
	var room: Vector2i = _kitchen()
	if room == NULL_REF: return
	var second: Builder.Crew = _h.second_member(KitchenTests.SECOND_PARKING)
	var third: Vector2i = _bystander()
	var fourth: Vector2i = _bystander()
	var crew: PackedInt32Array = _worker_crew()
	for mole: Vector2i in [second.worker, third, fourth]: crew.append_array(PackedInt32Array([mole.x, mole.y]))
	var runtime: Runtime = _order(room, crew)
	if runtime == null: return
	var foreman: Foreman = runtime.foreman_of(room)
	assert_equal(foreman.builders().size(), 2, "two parked")
	assert_equal(foreman.builders()[1].crew().parking, second.parking, "the second on the fixture's parking")
	assert_false(foreman.builders()[0].crew().parking == foreman.builders()[1].crew().parking, "apart")
	for mole: Vector2i in [third, fourth]:
		assert_false(runtime.reserves_resident(_h._residents.directory().get_typed_row(mole)), "left free")
	var builders: Array[Builder] = []
	builders.assign(foreman.builders())
	assert_equal(_run(runtime), [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), StationTests.KITCHEN_SITES, "every cube dug")
	assert_true(builders[0].column_cubes() > 0 and builders[1].column_cubes() > 0, "both dug")

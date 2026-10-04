extends "res://test/framework/test_case.gd"
## Actual spatial stores. Source certificates in the reused geometry fixture are explicitly synthetic.

const WorldTests := preload("res://test/test_underground_world_routes.gd")
const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")

var _world: WorldTests = null


func before_each() -> void:
	"""Use actual loaded profiles, completed geometry, certificates and registered full actor identity."""
	_world = WorldTests.new()
	_world._turn_fixture()
	assert_true(_world.failures.is_empty(), "actual geometry setup: %s" % _world.failures)


func after_each() -> void:
	"""All actual owners and profile helper retains end with this test; no synchronous lease may escape."""
	_world.after_each()
	assert_true(_world.failures.is_empty(), "actual geometry cleanup: %s" % _world.failures)
	_world = null


func _box(offset_x: int) -> PackedInt32Array:
	"""A small positive obstacle at the real actor's height tests complete body and recovery enclosures."""
	return PackedInt32Array([WorldTests.X + 512 + offset_x, 600, WorldTests.Z + 512,
		WorldTests.X + 513 + offset_x, 700, WorldTests.Z + 513])


func _occupancy(bounds: PackedInt32Array, checks: int = -1) -> StringName:
	"""Call the concrete direct leaf with its separately admitted complete finite work allowance."""
	return WorldRoutes.workpiece_occupancy_refusal(_world._binding, bounds,
		WorldRoutes.workpiece_occupancy_checks(_world._binding) if checks < 0 else checks)


func test_current_body_and_complete_recovery_block_without_mutating_pose_or_routes() -> void:
	"""The geometry component does not grant handling motion or trim recovery to the narrower visible body."""
	var pose: PackedByteArray = _world._transforms.state_bytes()
	var route: PackedByteArray = _world._turn_route_image()
	assert_equal(_occupancy(_box(0)), &"ROUTE_OCCUPIED", "actual body overlaps")
	assert_equal(_occupancy(_box(160)), &"ROUTE_OCCUPIED", "128u body clears but181u recovery remains")
	assert_equal(_occupancy(_box(181)), &"", "half-open full recovery boundary clears")
	assert_equal(_world._transforms.state_bytes(), pose, "no pose or interpolation mutation")
	assert_equal(_world._turn_route_image(), route, "no actor/path/mask publication")


func test_unregistered_actual_living_resident_never_becomes_empty_set_down_space() -> void:
	"""A missing body source refuses independently of whether that resident has entered the sparse Space registry."""
	var other: Vector2i = _world._residents.ref_of(_world._residents.spawn(&"mouse").value)
	assert_true(_world._transforms.place(other, WorldTests.X + 1500, 512, WorldTests.Z + 512, 0), "real extra resident")
	var pose: PackedByteArray = _world._transforms.state_bytes()
	assert_equal(_occupancy(_box(181)), &"ROUTE_TURN_ACTOR_UNBOUND", "no registration cannot certify empty air")
	assert_equal(_world._transforms.state_bytes(), pose, "refused scan changes no pose")
	assert_true(_world._residents.despawn(other).ok, "actual removal")
	assert_equal(_occupancy(_box(181)), &"", "current removal permits fresh scan")


func test_finite_work_is_precharged_before_source_or_actor_scratch_reads() -> void:
	"""One missing check and malformed bounds refuse without borrowing another query's reusable packets."""
	var checks: int = WorldRoutes.workpiece_occupancy_checks(_world._binding)
	_world._routes._occupant_selection.x = 1234567
	assert_equal(_occupancy(_box(181), checks - 1), WorldRoutes.REFUSE_BUDGET, "complete admitted scan required")
	assert_equal(_world._routes._occupant_selection.x, 1234567, "no actor scratch before admission")
	assert_equal(_occupancy(PackedInt32Array([0, 0, 0, 0, 1, 1]), checks), WorldRoutes.REFUSE_BUDGET, "empty prism refuses")
	assert_equal(_occupancy(_box(181), checks), &"", "exact finite allowance succeeds")


func test_busy_shared_query_scratch_and_foreign_provider_binding_refuse() -> void:
	"""Static final reads cannot corrupt an active search or accept a same-number unrelated source provider."""
	_world._routes._occupant_selection.x = 7654321
	_world._routes._searching = true
	assert_equal(_occupancy(_box(181)), WorldRoutes.REFUSE_BUSY, "active graph search owns shared scratch")
	_world._routes._searching = false
	assert_equal(_world._routes._occupant_selection.x, 7654321, "busy refusal leaves scratch intact")
	var original: Routes.Bindings = _world._routes._bindings
	_world._routes._bindings = Routes.Bindings.new()
	assert_equal(_occupancy(_box(181)), WorldRoutes.REFUSE_BINDING, "actual provider identity is exact")
	_world._routes._bindings = original
	assert_equal(_occupancy(_box(181)), &"", "original binding retry")


func test_actual_source_replacement_and_late_transform_move_are_read_fresh() -> void:
	"""Source revisions and full current pose cannot be replaced by a preceding successful scan."""
	assert_equal(_occupancy(_box(181)), &"", "initial actual proof")
	assert_true(_world._transforms.place(_world._worker, WorldTests.X + 700, 512, WorldTests.Z + 512, 0), "real late pose")
	assert_equal(_occupancy(_box(181)), &"ROUTE_OCCUPIED", "new actual body reaches proposed obstacle")
	assert_equal(_world._load_catalog(2), &"", "actual monotonic immutable catalog replacement")
	assert_true(_occupancy(_box(1000)) != &"", "old certificates cannot certify replaced source")


func test_physical_payload_drift_refuses_before_selection_output_copy() -> void:
	"""No current source match can overwrite output when the full retained payload identity differs."""
	var graph: Routes = _world._routes
	var row: int = _world._residents.directory().get_typed_row(_world._worker)
	var at: int = Routes.R_QUANTITY * Routes.RESIDENT_CAPACITY + row
	var quantity: int = graph._motion.resident_long[at]
	graph._motion.resident_long[at] = quantity + 1
	graph._occupant_selection.x = 918273
	assert_equal(Routes.physical_selection_into(graph, row, graph._occupant_selection),
		&"ROUTE_TURN_PROFILE_STALE", "exact current full payload differs")
	assert_equal(graph._occupant_selection.x, 918273, "refused output remains untouched")
	graph._motion.resident_long[at] = quantity
	assert_equal(Routes.physical_selection_into(graph, row, graph._occupant_selection), &"", "exact payload retry")

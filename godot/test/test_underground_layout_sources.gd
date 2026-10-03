extends "res://test/framework/test_case.gd"
## Real typed Sources/RoomOrders composition with explicitly synthetic physical profile/contact fixtures.

const Sources := preload("res://scripts/core/underground_layout_sources.gd")
const Layout := preload("res://scripts/core/room_layout.gd")
const RoomOrders := preload("res://scripts/core/underground_room_orders.gd")
const Fixture := preload("res://test/test_underground_furniture_work.gd")
const BatchFixture := preload("res://test/test_underground_furniture_batches.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const GEOMETRY: int = 16
const PLACEMENTS: int = 8
const BENCH: int = 5
const HEARTH: int = 2

var _f: Fixture.Fixture = null
var _bindings: BatchFixture.SyntheticLayoutBindings = null
var _sources: Sources = null
var _layout: Layout = null
var _token: int = 0


func before_each() -> void:
	"""The test adapter borrows only the real configured coordinator and finite actual shared Budget."""
	_bindings = BatchFixture.SyntheticLayoutBindings.new()
	_f = Fixture.Fixture.new(self, true, _bindings)
	_f.make_room()
	_bindings.floor_ref = _f.floor_ref
	_sources = Sources.new(_f.orders)
	_layout = Layout.new(2, PLACEMENTS, GEOMETRY)
	assert_true(_layout.bind_sources(_sources).ok, "actual typed source binding")


func after_each() -> void:
	"""No hover/receipt or active coordinator survives the synchronous input boundary."""
	_layout.finish_input()
	if _token > 0:
		_sources.end_operation(_token, _f.room)
	assert_true(_bindings.budget.is_quiescent(), "actual shared budget released")
	_f.audit()
	_layout = null
	_sources = null
	_f = null
	_bindings = null
	_token = 0


func _begin() -> void:
	"""Use exact bounded planner requirements; callers cannot invent a cheaper peak."""
	_token = _sources.begin_operation(_f.room, Layout.cold_packed_bytes(GEOMETRY, PLACEMENTS), GEOMETRY, PLACEMENTS)
	assert_true(_token > 0, "actual scope acquired")


func _consume(result: Layout.Result) -> Layout.Result:
	"""A UI may copy data only into separately admitted storage; this test consumes and releases immediately."""
	if result.requires_release():
		assert_equal(_layout.release_result(result), &"", "same-input result release")
	assert_equal(_layout.quiescence_refusal(), &"", "input returned no cold lease")
	return result


func test_unbound_or_expired_coordinator_cannot_manufacture_a_scope_or_success() -> void:
	"""An absent actual owner cannot be replaced by a matching numeric Room or arbitrary callbacks."""
	var empty: Sources = Sources.new(null)
	assert_equal(empty.binding_refusal(), RoomOrders.REFUSE_BINDING, "no owner")
	assert_equal(empty.begin_operation(_f.room, 1, 1, 1), 0, "no synthetic lease")
	assert_true(empty.read(_f.room, 1) == null, "no synthetic snapshot")
	assert_false(empty.is_live(Layout.DOMAIN_ROOM, _f.room, 1), "no identity by number alone")
	assert_false(empty.can_submit(1), "no callback permission")
	assert_true(empty.submit(Layout.Batch.new(), 1) == null, "no fabricated receipt")
	assert_equal(empty.end_operation(1, _f.room), Layout.REFUSE_SCOPE, "nothing foreign is released")


func test_exact_source_scope_rejects_copied_tokens_foreign_rooms_and_wrong_peak() -> void:
	"""All reads and release are tied to the original full Room and actual shared Budget charge."""
	_begin()
	var bytes: int = Layout.cold_packed_bytes(GEOMETRY, PLACEMENTS)
	assert_equal(_sources.scope_refusal(_token, _f.room, bytes), &"", "exact attestation")
	assert_equal(_sources.scope_refusal(_token + 1, _f.room, bytes), Layout.REFUSE_SCOPE, "foreign token")
	assert_equal(_sources.scope_refusal(_token, Vector2i(_f.room.x, _f.room.y + 1), bytes), Layout.REFUSE_SCOPE, "stale Room")
	assert_equal(_sources.scope_refusal(_token, _f.room, bytes - 1), Layout.REFUSE_SCOPE, "different packed peak")
	assert_equal(_sources.end_operation(_token + 1, _f.room), Layout.REFUSE_SCOPE, "foreign release")
	assert_true(_bindings.budget.covers(_token, bytes), "actual owner kept its lease")
	assert_equal(_sources.begin_operation(_f.room, bytes, GEOMETRY, PLACEMENTS), 0, "no overlapping active owner")


func test_read_uses_actual_room_type_and_generation_in_the_current_finite_scope() -> void:
	"""The physical fixture supplies geometry, but real Buildings owns Room identity and permanent type."""
	_begin()
	var snapshot: Layout.Snapshot = _sources.read(_f.room, _token)
	assert_true(snapshot != null, "one bounded actual-coordinator snapshot")
	assert_true(_sources.read(_f.room, _token) == snapshot, "same scope reuses one bounded observation")
	assert_equal(_bindings.snapshot_calls, 1, "no additional simultaneous provider image")
	assert_equal(snapshot.room_ref, _f.room, "full actual Room")
	assert_equal(snapshot.room_type, Buildings.ROOM_TYPE_KITCHEN, "actual permanent type")
	assert_true(_sources.is_live(Layout.DOMAIN_ROOM, _f.room, _token), "actual live Room")
	assert_false(_sources.is_live(Layout.DOMAIN_ROOM, Vector2i(_f.room.x, _f.room.y + 1), _token), "generation refusal")
	assert_false(_sources.is_live(Layout.DOMAIN_PROJECT, _f.room, _token), "domain refusal")
	assert_true(_sources.read(Vector2i(_f.room.x, _f.room.y + 1), _token) == null, "no stale snapshot")


func test_source_keeps_actual_coordinator_alive_only_until_synchronous_release() -> void:
	"""No permanent reference cycle is required to safely finish the same input operation."""
	_begin()
	var owner: WeakRef = weakref(_f.orders)
	_f.orders = null
	assert_true(owner.get_ref() != null, "active operation retains actual coordinator")
	assert_true(_sources.read(_f.room, _token) != null, "scope remains valid while synchronously active")
	assert_equal(_sources.end_operation(_token, _f.room), &"", "original operation releases")
	_token = 0
	assert_true(owner.get_ref() == null, "no retained coordinator after input")
	assert_equal(_sources.binding_refusal(), RoomOrders.REFUSE_BINDING, "expired owner stays unavailable")


func test_hover_preview_does_not_hold_the_shared_arena_after_consumption() -> void:
	"""The guide lifetime is same-input only, allowing worker/other-room operations immediately afterward."""
	assert_true(_layout.open_room(_f.room).ok, "open real Room")
	var preview: Layout.Result = _layout.preview(_f.room, BENCH, Vector2i(1, 0), 0)
	assert_true(preview.ok and preview.requires_release(), "valid scoped guide")
	assert_false(_bindings.budget.is_quiescent(), "guide still borrows actual shared arena")
	assert_equal(_layout.release_result(preview), &"", "consume guide within input")
	assert_true(preview.occupied_xy.is_empty(), "guide buffer cleared before release")
	assert_true(_bindings.budget.is_quiescent(), "actual arena free for next simulation step")
	assert_equal(_layout.finish_input(), &"", "no deferred hover lease")
	assert_equal(_f.construction.live_project_count(), 0, "preview creates no work")


func test_abandoned_guide_is_diagnosed_and_released_at_the_input_boundary() -> void:
	"""A hover cannot silently monopolize the World arena across frames or mouse events."""
	assert_true(_layout.open_room(_f.room).ok, "open real Room")
	var preview: Layout.Result = _layout.preview(_f.room, BENCH, Vector2i(1, 0), 0)
	assert_true(preview.ok, "valid guide")
	assert_equal(_layout.finish_input(), Layout.REFUSE_ABANDONED, "missed explicit consumption is visible")
	assert_false(preview.requires_release(), "abandoned view no longer owns cold memory")
	assert_true(_bindings.budget.is_quiescent(), "mandatory input cleanup freed actual arena")
	assert_equal(_f.construction.live_project_count(), 0, "no implicit confirmation")


func test_layout_mode_accepts_all_real_pairs_and_individual_mode_uses_the_same_owner() -> void:
	"""Both approved per-Room interactions reach one actual whole-batch acceptance contract."""
	assert_true(_layout.open_room(_f.room).ok, "open real Room")
	assert_true(_consume(_layout.place(_f.room, BENCH, Vector2i(1, 0), 0)).ok, "first draft")
	assert_true(_consume(_layout.place(_f.room, HEARTH, Vector2i(1, 2), 0)).ok, "second draft")
	assert_equal(_f.construction.live_project_count(), 0, "drafts are not paid orders")
	var accepted: Layout.Result = _layout.confirm_layout(_f.room)
	assert_true(accepted.ok, "actual whole-layout submission: %s" % accepted.error)
	assert_equal(accepted.value, 2, "complete receipt")
	assert_true(_f.construction.is_live_project(_layout.project_of(accepted.ref)), "real retained receipt")
	assert_equal(_f.construction.live_project_count(), 2, "two actual Projects")
	assert_true(_layout.set_mode(_f.room, Layout.MODE_INDIVIDUAL).ok, "same Room changes interaction")
	var shelf: int = int(Catalog.FURNITURE_DEFINITION["shelf"])
	assert_true(_consume(_layout.place(_f.room, shelf, Vector2i(3, 2), 0)).ok, "individual uses actual same owner")
	assert_equal(_f.construction.live_project_count(), 3, "one more real Project")
	assert_equal(_f.buildings.furniture_mask_of(_f.room).value, 0, "all orders remain uninstalled")
	assert_true(_bindings.budget.is_quiescent(), "no cross-frame receipt lease")


func test_late_physical_refusal_retains_drafts_and_can_retry_without_partial_world_rows() -> void:
	"""A blocked batch can retry after current qualification recovers, without losing or duplicating orders."""
	assert_true(_layout.open_room(_f.room).ok, "open real Room")
	assert_true(_consume(_layout.place(_f.room, BENCH, Vector2i(1, 0), 0)).ok, "staged draft")
	_bindings.prepared_error = &"SYNTHETIC_FINAL_PROFILE_DRIFT"
	var before: PackedByteArray = _f.image()
	assert_false(_layout.confirm_layout(_f.room).ok, "final companion refuses")
	assert_true(_f.image() == before, "all real state unchanged")
	var drafts: Layout.Result = _layout.placements(_f.room)
	assert_equal(drafts.placement_rows.size(), 6, "same one draft retained")
	_consume(drafts)
	_bindings.prepared_error = &""
	assert_true(_layout.confirm_layout(_f.room).ok, "retry accepted once")
	assert_equal(_f.construction.live_project_count(), 1, "no partial or duplicate Project")
	assert_equal(_bindings.layout_publications, 1, "one atomic publication")

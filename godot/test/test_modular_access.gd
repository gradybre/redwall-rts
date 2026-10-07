extends "res://test/framework/test_case.gd"
## Real Location/Profiles/path/WorkFace/RoomOrders, with explicitly synthetic finite geometry and source rows.
## Source content, an installed first entrance and playable demo activation are not qualified by this fixture.

const Access := preload("res://demo/burrow/modular_access.gd")
const Fixture := preload("res://test/test_underground_room_approach.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Editor := preload("res://demo/burrow/modular_editor.gd")
const Draft := preload("res://demo/burrow/modular_draft.gd")
const Tool := preload("res://demo/burrow/modular_world_tool.gd")
const Runtime := preload("res://demo/burrow/modular_runtime.gd")

const WorldRoutes := preload("res://scripts/core/underground_world_routes.gd")
const AccessFaceFixture := preload("res://test/test_underground_work_face.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Space := preload("res://scripts/core/room_space.gd")

class LivenessLocations extends AccessFaceFixture.ObservedLocations:
	var liveness_probe: Callable = Callable()

	func is_live_location(location: Vector2i) -> bool:
		"""One late callback follows the genuine original liveness value; it never grants a fake positive."""
		var live: bool = super.is_live_location(location)
		if liveness_probe.is_valid():
			var action: Callable = liveness_probe
			liveness_probe = Callable()
			action.call()
		return live


class SparseFixture extends Fixture.ActualFixture:
	var endpoint_capacity: int = 128
	## A real larger Location capacity demonstrates resumable absent-slot enumeration, not a fabricated reader.
	func _finish_space(domain: Space.Domain) -> void:
		"""Only capacity changes; all stores, source identity, profile and route checks remain actual."""
		_locations = LivenessLocations.new()
		assert_equal(_locations.configure(_residents.directory(), _buildings, _transforms, _inventory,
			_owner, _sources, _budget, endpoint_capacity, 228 * endpoint_capacity + 256), &"", "actual sparse endpoints")
		assert_equal(_locations.bind_sites(physical.sites), &"", "actual physical ownership")
		_terrain = ReenteringTerrain.new()
		assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "actual terrain")
		_actual_catalog(domain)

	func _actual_binding() -> void:
		"""A real sparse graph uses the same finite Location capacity, never private bank size changes."""
		exact_terrain = Terrain.new()
		assert_equal(exact_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "exact terrain")
		_binding = WorldRoutes.new()
		assert_equal(_binding.configure(_configuration()), &"", "actual concrete provider")
		assert_equal(_routes.configure(_locations, _owner, _sources, _buildings, _budget, _binding,
			endpoint_capacity, Routes.MAX_EDGES, Routes.MAX_VERTICES, Routes.MAX_LINKS, Routes.ARENA_BYTES), &"", "matching actual graph")
		assert_equal(_routes.bind_profiles(_profiles, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual profiles")
		assert_equal(_binding.binding_refusal(), &"", "complete actual binding")


class FullGraphFixture extends SparseFixture:
	## Finite worst populated topology uses only real Location and WorldRoutes preparation/publication.
	var ring: Array[Vector2i] = []

	func build_network() -> void:
		"""Publish every1024 endpoint,1536 certified edge and4096 vertex without a positive provider override."""
		endpoint_capacity = 1024
		_actual_fixture(0)
		for x: int in 2:
			assert_true(physical.sites.claim_quantum(Vector3i(X + x * 1024, FLOOR, Z + 1024), room).ok, "actual second-row Site key")
		_add_ring_locations()
		if not failures.is_empty(): return
		var token: int = _begin()
		for index: int in 1024:
			var edge: Routes.Edge = _ring_edge(index, false)
			assert_equal(_routes.stage_add(token, edge).error, &"", "real ring edge")
		for index: int in 512:
			assert_equal(_routes.stage_add(token, _ring_edge(index * 2, true)).error, &"", "real longer alternate")
		assert_equal(_binding.seal(token), &"", "actual full certificate bank")
		assert_equal(_binding.publish(token), &"", "actual graph publication")
		_end(token)

	func _add_ring_locations() -> void:
		"""One exact cold candidate preserves both existing endpoints and appends the full supported perimeter."""
		var cold: int = _budget.acquire(Budget.COLD_BYTES)
		var token: int = _locations.begin_prepare(cold).token
		for index: int in 1024:
			if index == 0 or index == 768:
				ring.append(_first if index == 0 else _last)
				continue
			var point: Vector3i = ring_point(index)
			var row: Locations.Record = Locations.Record.new()
			row.point = point
			row.section = _floor
			row.room = room
			row.level = 1
			row.role = Locations.ROLE_WORK
			row.envelope = PackedInt32Array([point.x - 256, point.y, point.z - 256, point.x + 256, point.y + 1024, point.z + 256])
			row.support = PackedInt32Array([point.x - 256, point.y - 128, point.z - 256, point.x + 256, point.y, point.z + 256])
			var added: Locations.Result = _locations.stage_add(token, row)
			assert_equal(added.error, &"", "actual finite endpoint")
			if added.error != &"":
				_locations.abort(token)
				_budget.release(cold)
				return
			ring.append(added.location)
		assert_equal(_locations.seal(token), &"", "actual full endpoint census")
		assert_true(_locations.publish(token), "actual endpoint publication")
		assert_equal(_budget.release(cold), &"", "endpoint lease returned")

	func ring_point(index: int) -> Vector3i:
		"""The integer perimeter stays strictly inside the already source-consistent support and void fixture."""
		@warning_ignore("integer_division") var side: int = index / 256
		var offset: int = (index % 256) * 4
		match side:
			0: return Vector3i(X + 512, FLOOR, Z + 512 + offset)
			1: return Vector3i(X + 512 + offset, FLOOR, Z + 1536)
			2: return Vector3i(X + 1536, FLOOR, Z + 1536 - offset)
		return Vector3i(X + 1536 - offset, FLOOR, Z + 512)

	func _ring_edge(index: int, alternate: bool) -> Routes.Edge:
		"""Every alternate consumes four actual vertices and is longer than its corresponding4u perimeter edge."""
		var next: int = (index + 1) % 1024
		var first: Vector3i = ring_point(index)
		var last: Vector3i = ring_point(next)
		var edge: Routes.Edge = _edge()
		edge.from_location = ring[index]
		edge.to_location = ring[next]
		edge.length_u = 8 if alternate else 4
		edge.point_count = 4 if alternate else 2
		edge.points = PackedInt32Array([first.x, first.y, first.z])
		if alternate:
			var offset: Vector3i = Vector3i(2, 0, 0) if first.x == last.x else Vector3i(0, 0, 2)
			edge.points.append_array(PackedInt32Array([first.x + offset.x, first.y, first.z + offset.z,
				last.x + offset.x, last.y, last.z + offset.z]))
		edge.points.append_array(PackedInt32Array([last.x, last.y, last.z]))
		return edge

var _fixture: Fixture = null
var _access: Access = null
var _runtime: Runtime = null
var _editor: Editor = null
var _tool: Tool = null
var _camera: Camera3D = null
var _callback_code: StringName = &""
var _setup_action: int = -1
var _view_probe: Callable = Callable()


func _setup(connected: bool = true, admission: bool = false) -> void:
	"""Reuse accepted actual source owners, releasing setup's cold lease before any view search."""
	_fixture = Fixture.new()
	_fixture._setup(connected, 0, admission)
	assert_equal(_fixture.failures, PackedStringArray(), "actual fixture setup")
	assert_equal(_fixture._actual._budget.release(_fixture._lease), &"", "fixture setup lease released")
	_fixture._lease = 0
	_access = Access.new()
	assert_equal(_access.configure(_fixture._actual._binding, _fixture._actual._first), &"", "explicit actual anchor")


func after_each() -> void:
	"""Release command callbacks and all view/source handles without retaining a world or a lease."""
	if _runtime != null: assert_equal(_runtime.disconnect_view(), &"", "disconnect")
	_runtime = null
	if is_instance_valid(_tool): _tool.free()
	if is_instance_valid(_editor): _editor.free()
	if is_instance_valid(_camera): _camera.free()
	_tool = null
	_editor = null
	_camera = null
	_access = null
	if _fixture != null:
		_fixture.after_each()
		assert_equal(_fixture.failures, PackedStringArray(), "actual source teardown")
	_fixture = null
	_setup_action = -1
	_view_probe = Callable()


func _finish(access: Access) -> void:
	"""Bound the test's cursor replay; each real view step must relinquish the actual shared arena."""
	for ignored: int in 128:
		if not access.searching(): break
		var prior: int = access.proof_attempts
		access.step()
		assert_true(access.proof_attempts - prior <= 1, "at most one full proof per step")
		assert_true(_fixture._actual._budget.is_quiescent(), "no witness/lease carried into another frame")
	assert_false(access.searching(), "finite actual fixture search ended")


func test_real_suggestion_is_exact_and_never_mutates_authoritative_owners() -> void:
	"""A suggested contact comes from real public rows and passes the same complete Approach proof as admission."""
	_setup()
	var geometry: PackedByteArray = _fixture._actual._owner.state_bytes()
	var inventory: PackedByteArray = _fixture._actual._inventory.state_bytes()
	assert_equal(_access.begin(_fixture._plan, 7), &"", "search begins")
	_finish(_access)
	assert_equal(_access.refusal(), &"", "actual prospective suggestion succeeds")
	var selected: Approach.Request = _access.selected_request(_fixture._plan, 7, _access.revision)
	assert_true(selected != null, "typed selected request")
	if selected == null: return
	assert_equal(Approach.Witness.extra_values(selected), Approach.Witness.extra_values(_fixture._request), "exact real tuple")
	assert_equal(_fixture._actual._owner.state_bytes(), geometry, "preview did not publish geometry")
	assert_equal(_fixture._actual._inventory.state_bytes(), inventory, "preview did not move/pay materials")
	assert_equal(_fixture._actual._locations._live.count, 2, "no extra endpoint")
	assert_equal(_fixture._actual._routes._live.edge_count, 1, "no fabricated passage")
	var preview: Dictionary = _access.preview()
	assert_equal(preview.route.size(), 6, "actual two-vertex corridor is drawn")
	assert_equal(preview.patch[0], _fixture._request.target_origin.x, "full patch lies on actual face")
	print("ACCESS_STEP_USEC fixture=%d proofs=%d" % [_access.max_step_usec, _access.proof_attempts])


func test_disconnected_endpoint_cannot_be_its_own_invented_access_anchor() -> void:
	"""A valid work face still needs the exact completed route from the explicit host anchor."""
	_setup(false)
	assert_equal(_access.begin(_fixture._plan, 1), &"", "search begins")
	_finish(_access)
	assert_true(_access.refusal() != &"", "disconnected real graph refuses")
	assert_true(_access.selected_request(_fixture._plan, 1, _access.revision) == null, "no fake zero-edge selected request")
	assert_false(_access.preview().selected, "no invented marker")


func test_invalid_edit_keeps_original_marker_and_drawing_without_silent_replacement() -> void:
	"""A changed exposed boundary invalidates the chosen face while preserving what the player selected."""
	_setup()
	_access.begin(_fixture._plan, 1)
	_finish(_access)
	var before: Dictionary = _access.preview()
	var changed: Orders.RoomPlan = Orders.RoomPlan.new()
	changed.copy_from(_fixture._plan)
	changed.origin_u.x += 1024
	assert_equal(_access.begin(changed, 2), &"", "exact marker recheck begins")
	_finish(_access)
	assert_true(_access.refusal() != &"", "old face is no longer on new paint")
	assert_true(_access.preview().selected, "old marker remains visible")
	assert_equal(_access.preview().target, before.target, "no automatic new target")
	assert_equal(changed.origin_u.x, _fixture._plan.origin_u.x + 1024, "input drawing preserved")
	assert_true(_access.selected_request(changed, 2, _access.revision) == null, "invalid retained marker cannot submit")


func test_selected_request_and_render_arrays_do_not_alias_private_selection() -> void:
	"""Presentation consumers cannot move the command by changing their copied mesh or request arrays."""
	_setup()
	_access.begin(_fixture._plan, 4)
	_finish(_access)
	var first: Approach.Request = _access.selected_request(_fixture._plan, 4, _access.revision)
	assert_true(first != null, "first selected copy")
	if first == null: return
	first.cells[0] = 77
	first.work_location = Vector2i(-1, 0)
	var preview: Dictionary = _access.preview()
	preview.patch[0] = 77
	preview.roles[0] = 77
	preview.route[0] = 77
	var next: Approach.Request = _access.selected_request(_fixture._plan, 4, _access.revision)
	assert_equal(next.cells, _fixture._plan.cells, "input copy does not alias")
	assert_equal(next.work_location, _fixture._request.work_location, "private exact endpoint unchanged")
	assert_true(_access.preview().patch[0] != 77 and _access.preview().route[0] != 77, "render copies isolated")


func test_source_reload_expires_search_and_old_choice_without_guessing_a_new_version() -> void:
	"""A new actual catalog revision cannot inherit an old selection just because its numeric geometry matches."""
	_setup()
	_access.begin(_fixture._plan, 2)
	_finish(_access)
	var before: Dictionary = _access.preview()
	_fixture._actual.load_profiles(0, 2)
	assert_equal(_access.selection_refusal(_fixture._plan, 2, _access.revision), Access.REFUSE_CHANGED, "actual source expires")
	assert_equal(_access.preview().target, before.target, "source expiry keeps original marker")
	assert_equal(_access.begin(_fixture._plan, 3), &"", "recheck requested")
	_finish(_access)
	assert_equal(_access.refusal(), Access.REFUSE_CHANGED, "does not adopt new source under old choice")


func test_busy_actual_cold_arena_refuses_without_closing_foreign_operation() -> void:
	"""A view cannot steal a production owner's lease to finish a preview."""
	_setup()
	_access.begin(_fixture._plan, 1)
	var token: int = _fixture._actual._budget.acquire(Budget.COLD_BYTES)
	for ignored: int in 16:
		if not _access.searching(): break
		_access.step()
	assert_equal(_access.refusal(), Budget.REFUSE_BUSY, "real busy arena refusal")
	assert_true(_fixture._actual._budget.covers(token, Budget.COLD_BYTES), "foreign lease preserved")
	assert_equal(_fixture._actual._budget.release(token), &"", "foreign owner releases")


func test_expired_actual_provider_never_rebinds_to_equal_numeric_world() -> void:
	"""The view owns no strong authoritative composition across frames."""
	_setup()
	_access.begin(_fixture._plan, 1)
	var weak: WeakRef = weakref(_fixture._actual._binding)
	_fixture._actual._binding = null
	assert_true(weak.get_ref() == null, "no view-owned strong provider")
	assert_equal(_access.step(), Access.REFUSE_BINDING, "expired binding refuses")


func test_planar_target_derivation_uses_exact_signed_datum_and_full_patch() -> void:
	"""No cardinal rotation, float rounding or partial patch clipping can manufacture a paid face."""
	var patch: PackedInt32Array = PackedInt32Array([-1024, -12, -500, -1024, 12, -400])
	assert_equal(Access.target_for_patch(patch, Vector3i(-1408, 0, -450), Vector3i(0, 512, 0)),
		PackedInt32Array([-1024, -512, -1024, 0]), "negative exact datum-aligned face")
	patch[3] += 1
	assert_true(Access.target_for_patch(patch, Vector3i.ZERO, Vector3i(0, 512, 0)).is_empty(), "positive-volume patch refused")
	patch = PackedInt32Array([0, 100, -1, 0, 200, 1])
	assert_true(Access.target_for_patch(patch, Vector3i(-10, 0, 0), Vector3i.ZERO).is_empty(), "cross-cube patch refused intact")
	patch = PackedInt32Array([1, 100, 1, 1, 200, 2])
	assert_true(Access.target_for_patch(patch, Vector3i.ZERO, Vector3i.ZERO).is_empty(), "unaligned face refused")


func test_exact_concave_boundary_and_picked_cell_filter() -> void:
	"""An internal cell seam, missing corner or different clicked boundary cannot pass by bounding rectangle."""
	var plan: Orders.RoomPlan = Orders.RoomPlan.new()
	plan.cell_size_u = 512
	plan.height_u = 2048
	plan.cells = PackedInt32Array([0, 0, 1, 0, 0, 1])
	var patch: PackedInt32Array = PackedInt32Array([0, 10, 400, 0, 100, 600])
	assert_true(Access.boundary_contains(plan, patch, 0), "patch spans two adjacent exposed cells")
	assert_true(Access.boundary_contains(plan, patch, 0, Vector2i(0, 1), true), "picked exposed cell intersects full patch")
	assert_false(Access.boundary_contains(plan, patch, 0, Vector2i(1, 0), true), "other edge cannot silently replace selection")
	patch = PackedInt32Array([512, 10, 400, 512, 100, 600])
	assert_false(Access.boundary_contains(plan, patch, 1), "mixed interior/exposed span refused")
	patch = PackedInt32Array([400, 0, 400, 600, 0, 600])
	assert_false(Access.boundary_contains(plan, patch, 2), "horizontal concave hole is not filled")


func _ui(bind_access: bool = true) -> void:
	"""Compose the real released adapter around actual RoomOrders, with the explicit genuine source anchor."""
	_setup(true, true)
	var actual: Fixture.AdmissionFixture = _fixture._actual as Fixture.AdmissionFixture
	var draft: Draft = Draft.new()
	assert_equal(draft.configure(Buildings.ROOM_TYPE_KITCHEN, 1, 1024, 64, Rect2i(-4, -4, 16, 16), true), &"", "draft")
	_editor = Editor.new()
	_editor.configure(draft, 2)
	_tool = Tool.new()
	_camera = Camera3D.new()
	assert_equal(_tool.configure(_camera, _editor, _fixture._plan.origin_u, 1, _not_modal, _view), &"", "world drawing")
	_tool.set_active(true)
	_runtime = Runtime.new()
	assert_equal(_runtime.configure(_editor, _tool, actual.orders, actual.rooms, actual._levels, 0), &"", "actual Runtime")
	if bind_access: assert_equal(_runtime.configure_access(actual._binding, actual._first), &"", "explicit actual access")
	assert_true(_editor.world_press(Vector2i.ZERO), "draw on dirt")
	_editor.world_motion(Vector2i.ONE)
	_editor.world_release()
	if bind_access:
		_finish(_runtime._access)
		_editor._sync_access()


func _not_modal() -> bool:
	"""The fixture has no modal UI; actual view state is still queried by the real WorldTool."""
	return false


func _view() -> Vector3i:
	"""The visible slice is the same actual authored floor used by the drawing and source endpoint."""
	if _view_probe.is_valid():
		var action: Callable = _view_probe
		_view_probe = Callable()
		action.call()
	return Vector3i(1, Fixture.FLOOR, 1)


func _change_access_setup() -> void:
	"""Mutate only after a genuine successful Location/view read; no fixture permission is overridden."""
	match _setup_action:
		0: _editor.free()
		1: _tool.free()
		2: _editor.draft.discard()
		3: _fixture._actual._binding._levels = null
		4: _editor.bind_access(_access, _runtime.search_access)
		5: _tool._read_view = Callable()
		6: _editor.draft = Draft.new()
		7: _tool.set_active(false)
		8: _camera.free()


func _arm_access_setup() -> void:
	"""The actual endpoint observer runs during Access.configure, after both Runtime owner checks."""
	var locations: AccessFaceFixture.ObservedLocations = _fixture._actual._locations as AccessFaceFixture.ObservedLocations
	locations.countdown = 1
	locations.probe = _change_access_setup


func test_access_configuration_refuses_view_teardown_without_a_refresh_crash() -> void:
	"""A freed original inspector, world tool or camera cannot return successful access binding."""
	for action: int in [0, 1, 8]:
		_ui(false)
		_setup_action = action
		_arm_access_setup()
		assert_equal(_runtime.configure_access(_fixture._actual._binding, _fixture._actual._first), Runtime.REFUSE_BINDING,
			"actual endpoint callback teardown refuses")
		assert_true(_runtime._access == null, "no partially published selector")
		assert_false(_runtime._busy, "configuration guard restored")
		assert_true(_fixture._actual._budget.is_quiescent(), "configuration never retains a cold lease")
		after_each()


func test_access_configuration_preserves_original_drawing_owner_and_existing_binding() -> void:
	"""Late configuration changes refuse without undoing an externally selected binding or edited drawing."""
	for action: int in [2, 3, 4, 5, 6, 7]:
		_ui(false)
		_setup_action = action
		_arm_access_setup()
		var code: StringName = _runtime.configure_access(_fixture._actual._binding, _fixture._actual._first)
		assert_equal(code, Runtime.REFUSE_DRAFT if action == 2 else Runtime.REFUSE_BINDING, "exact changed tuple refused")
		assert_true(_runtime._access == null, "candidate binding remains unpublished")
		assert_equal(_editor._checker, _runtime.check_request, "prior checker retained")
		assert_equal(_editor._submitter, _runtime.submit_request, "prior submitter retained")
		if action == 4: assert_true(_editor._access == _access, "newer external Access preserved")
		elif action == 2: assert_true(_editor.draft._cells.is_empty(), "observer's edited drawing not rolled back")
		else: assert_true(_editor._access == null, "no candidate editor binding")
		after_each()


func test_final_configuration_view_callback_cannot_replace_the_original_tuple() -> void:
	"""Original owner observations do not excuse teardown or drawing mutation in the final view callback."""
	for action: int in [0, 1, 2, 3]:
		_ui(false)
		_setup_action = action
		_view_probe = _change_access_setup
		var code: StringName = _runtime.configure_access(_fixture._actual._binding, _fixture._actual._first)
		assert_equal(code, Runtime.REFUSE_DRAFT if action == 2 else Runtime.REFUSE_BINDING, "final view mutation refused")
		assert_true(_runtime._access == null, "no trailing refresh after refused configuration")
		after_each()


func test_existing_drawing_starts_access_search_on_next_frame_without_more_input() -> void:
	"""First binding keeps Confirm disabled until the regular editor frame has observed the existing drawing."""
	_ui(false)
	var before: Dictionary = _editor.command_snapshot()
	assert_equal(_runtime.configure_access(_fixture._actual._binding, _fixture._actual._first), &"", "real late access bind")
	assert_true(_editor._confirm.disabled, "unobserved selection cannot submit")
	assert_false(_runtime._access.searching(), "no synchronous search in configuration")
	_editor._process(0.0)
	assert_true(_runtime._access.searching() or _runtime._access.preview().selected, "next normal frame starts actual search")
	_finish(_runtime._access)
	_editor._sync_access()
	assert_equal(_runtime._access.refusal(), &"", "actual source observation succeeds")
	assert_equal(_editor.draft.snapshot(), before, "same already drawn cells and revision")
	assert_false(_editor._confirm.disabled, "complete proof enables Confirm")
	assert_equal(_editor._access_status.text, "First cut selected · worker clearance and access shown.", "player-facing scope")


func test_real_ui_suggestion_then_atomic_room_confirmation() -> void:
	"""The complete UI command reaches genuine Kitchen admission; preview never orders or pays the room."""
	_ui()
	var actual: Fixture.AdmissionFixture = _fixture._actual as Fixture.AdmissionFixture
	assert_equal(_runtime._access.refusal(), &"", "actual UI-selected approach ready")
	assert_equal(_runtime.check_request(_editor.command_snapshot()), "", "exact drawing and selection checked")
	var inventory: PackedByteArray = actual._inventory.state_bytes()
	var revision_before: int = actual._owner.revision()
	assert_true(_editor.request_confirmation(), "real RoomOrders confirms the selected approach")
	assert_equal(actual._owner.revision(), revision_before + 1, "one actual metadata/claim publication")
	assert_equal(actual._inventory.state_bytes(), inventory, "no implicit phase payment")
	assert_true(_editor.draft.visible_cells().is_empty(), "exact accepted drawing consumed")
	assert_true(actual._budget.is_quiescent(), "real cold scope released")
	assert_false(_editor.request_confirmation(), "duplicate confirmation cannot resubmit")


func test_ui_reposition_is_a_world_selection_not_a_paint_or_order_gesture() -> void:
	"""Picking a missing boundary preserves both previous marker and draft, with confirmation visibly blocked."""
	_ui()
	var before: Dictionary = _editor.draft.snapshot()
	var target: Vector3i = _runtime._access.preview().target
	_editor._pick_access()
	assert_true(_editor.selecting_access(), "world access mode")
	assert_true(_editor.place_access_at(Vector2i(1, 1)), "explicit requested boundary")
	_finish(_runtime._access)
	_editor._sync_access()
	assert_equal(_editor.draft.snapshot(), before, "reposition never paints")
	assert_equal(_runtime._access.preview().target, target, "invalid new boundary keeps selected marker")
	assert_true(_editor._confirm.disabled, "no valid selected access visibly disables confirmation")
	assert_false(_editor.request_confirmation(), "real checker refuses invalid selection")


func test_old_or_float_selection_stamp_cannot_replace_the_reviewed_access() -> void:
	"""The selected tuple is part of the original command, not an implicit read of whatever marker is newest."""
	_ui()
	var request: Dictionary = _editor.command_snapshot()
	request.access_revision = float(request.access_revision)
	assert_equal(_runtime.submit_request(request).error_code, Runtime.REFUSE_DRAFT, "float stamp refused")
	request = _editor.command_snapshot()
	_editor._suggest_access()
	_finish(_runtime._access)
	assert_equal(_runtime.submit_request(request).error_code, Runtime.REFUSE_DRAFT, "old stamp refused")
	assert_false(_editor.draft.visible_cells().is_empty(), "original paint retained")


func _arm_probe(action: Callable) -> void:
	"""Run once after a genuine endpoint observation; the production WorkFace still owns every proof."""
	var observed: AccessFaceFixture.ObservedLocations = _fixture._actual._locations as AccessFaceFixture.ObservedLocations
	observed.countdown = 1
	observed.probe = action


func _try_clear() -> void:
	"""An observer may attempt reentry but cannot discard the original selection or drawing."""
	_callback_code = _access.clear()


func _replace_profiles() -> void:
	"""Use the real loader to expire the exact source during a late endpoint observation."""
	_fixture._actual.load_profiles(0, 2)


func test_recursive_mutation_during_actual_proof_refuses_and_releases_original_lease() -> void:
	"""No result or lease survives a recursive clear attempt, even when the genuine physical proof would pass."""
	_setup()
	_access.begin(_fixture._plan, 1)
	_arm_probe(_try_clear)
	_finish(_access)
	assert_equal(_callback_code, Access.REFUSE_BUSY, "original search blocks recursive mutation")
	assert_equal(_access.refusal(), Access.REFUSE_BUSY, "attempt poisons search")
	assert_false(_access.preview().selected, "no partial successful preview")
	assert_true(_fixture._actual._budget.is_quiescent(), "original lease released after callback")


func test_late_actual_profile_reload_cannot_mix_candidate_with_new_content() -> void:
	"""Every source observation is revalidated after callbacks, without silently adopting the new wire."""
	_setup()
	_access.begin(_fixture._plan, 1)
	_arm_probe(_replace_profiles)
	_finish(_access)
	assert_true(_access.refusal() != &"", "real late source expiry refuses")
	assert_false(_access.preview().selected, "mixed source never becomes a marker")
	assert_true(_fixture._actual._budget.is_quiescent(), "no stale cold lease")


func test_malformed_and_oversize_drawing_refuses_before_copy_and_preserves_marker() -> void:
	"""Canonical shape, finite count and int32 world bounds protect both loops and copied presentation input."""
	_setup()
	_access.begin(_fixture._plan, 1)
	_finish(_access)
	var marker: Vector3i = _access.preview().target
	var bad: Orders.RoomPlan = Orders.RoomPlan.new()
	bad.copy_from(_fixture._plan)
	bad.cells = PackedInt32Array([0, 0, 0, 0])
	assert_equal(_access.begin(bad, 2), Access.REFUSE_BOUNDARY, "duplicate cells refused")
	bad.cells.resize(32770)
	assert_equal(_access.begin(bad, 3), Access.REFUSE_BOUNDARY, "capacity refused before copy")
	bad.copy_from(_fixture._plan)
	bad.origin_u.x = Space.I32_MAX
	assert_equal(_access.begin(bad, 4), Access.REFUSE_BOUNDARY, "wide addition refuses narrowing overflow")
	assert_equal(_access.preview().target, marker, "refusals preserve chosen marker")
	assert_false(Access.boundary_contains(_fixture._plan,
		PackedInt32Array([0, 0, -2147483648, 2147483647, 0, 2147483647]), 2), "oversize patch before area product")


func test_sparse_actual_capacity_search_yields_and_remains_view_only() -> void:
	"""The full Location capacity cannot become a synchronous proof cross product."""
	_fixture = Fixture.new()
	_fixture._actual = SparseFixture.new()
	_fixture._actual._actual_fixture(0)
	_fixture._actual.connect_path()
	assert_true(_fixture._actual.failures.is_empty(), "actual sparse setup")
	_fixture._plan = Orders.RoomPlan.new()
	_fixture._plan.world = _fixture._actual._world_ref
	_fixture._plan.space_revision = _fixture._actual._owner.revision()
	_fixture._plan.room_type = Buildings.ROOM_TYPE_KITCHEN
	_fixture._plan.level = 1
	_fixture._plan.origin_u = Vector3i(Fixture.X + 8192, Fixture.FLOOR, Fixture.Z)
	_fixture._plan.height_u = Approach.reachable_height_u(_fixture._actual._profiles, 1) # DEC-054
	_fixture._plan.cell_size_u = 1024
	_fixture._plan.cells = PackedInt32Array([0, 0])
	_access = Access.new()
	assert_equal(_access.configure(_fixture._actual._binding, _fixture._actual._first), &"", "real explicit anchor")
	assert_equal(_access.begin(_fixture._plan, 1), &"", "distant actual drawing")
	assert_equal(_access.step(), Access.REFUSE_SEARCHING, "large scan visibly yields")
	assert_equal(_access.proof_attempts, 0, "cheap boundary prefilters avoid all full proofs")
	assert_true(_fixture._actual._budget.is_quiescent(), "no lease across frame")
	_finish(_access)
	assert_equal(_access.refusal(), Access.REFUSE_MISSING, "full finite scan finds no invented endpoint")
	print("ACCESS_STEP_USEC sparse128=%d proofs=%d" % [_access.max_step_usec, _access.proof_attempts])


func test_final_liveness_observer_cannot_hide_a_real_profile_reload() -> void:
	"""The source epoch is checked after the last actual observer, including a successful copied liveness value."""
	test_sparse_actual_capacity_search_yields_and_remains_view_only()
	assert_equal(_access.begin(_fixture._plan, 2), &"", "new same-source search")
	var observed: LivenessLocations = _fixture._actual._locations as LivenessLocations
	observed.liveness_probe = _replace_profiles
	assert_equal(_access.step(), Access.REFUSE_CHANGED, "late real loader invalidates original epoch")
	assert_equal(_access.proof_attempts, 0, "no mixed-source expensive candidate")
	assert_false(_access.preview().selected, "no stale marker published")
	assert_true(_fixture._actual._budget.is_quiescent(), "no lease acquired by refused source observation")


func test_access_guard_and_teardown_preserve_exact_view_binding() -> void:
	"""An old UI cannot detach another access controller; command guards refuse preview mutation."""
	_ui()
	var access: Access = _runtime._access
	var request: Approach.Request = access.selected_request(_fixture._plan, _editor.draft.revision, access.revision)
	assert_true(request != null, "exact selected command")
	assert_equal(access.lock_selection(request, _editor.draft.revision, access.revision), &"", "view command lock")
	assert_equal(access.clear(), Access.REFUSE_BUSY, "guarded selection retained")
	access.unlock_selection()
	assert_false(_editor.unbind_access(Access.new(), _runtime.search_access), "foreign access cannot detach")
	assert_equal(_runtime.disconnect_view(), &"", "actual exact teardown")
	assert_true(_editor._access == null, "no retained selector after world retirement")
	assert_false(_editor.request_confirmation(), "unbound view cannot submit")


func test_maximum_paint_and_actual_space_capacity_candidate_is_measured() -> void:
	"""The complete finite paint is retained; native elapsed time is diagnostic, never a permission or clock."""
	_setup()
	_fixture._plan.cells.clear()
	for z: int in 128:
		for x: int in 128:
			_fixture._plan.cells.append(x)
			_fixture._plan.cells.append(z)
	assert_equal(_fixture._actual._owner._region_capacity, Budget.REGION_CAPACITY, "full region arena")
	assert_equal(_fixture._actual._owner._source_capacity, Budget.SOURCE_CAPACITY, "full source arena")
	assert_equal(_access.begin(_fixture._plan, 1), &"", "all16384 exact cells")
	_finish(_access)
	assert_equal(_access.refusal(), &"", "complete source contact survives maximum drawing")
	assert_equal(_access.selected_request(_fixture._plan, 1, _access.revision).cells.size(), 32768, "no paint reduction")
	print("ACCESS_STEP_USEC paint16384_region6144_source2048=%d proofs=%d" % [_access.max_step_usec, _access.proof_attempts])


func test_boundary_index_matches_full_paint_scan_for_signed_edges_holes_and_seams() -> void:
	"""The optimized bounded lookup is equivalent to complete area/span coverage, including absent fine cells."""
	for mask: int in range(1, 64):
		var plan: Orders.RoomPlan = Orders.RoomPlan.new()
		plan.cell_size_u = 128
		plan.height_u = 1024
		for bit: int in 6:
			if mask & (1 << bit):
				plan.cells.append(bit % 3 - 1)
				@warning_ignore("integer_division") var z: int = bit / 3 - 1
				plan.cells.append(z)
		for side: int in 4:
			var face: int = [0, 1, 4, 5][side]
			var patch: PackedInt32Array = PackedInt32Array([0, 5, -64, 0, 30, 64]) if side < 2 \
				else PackedInt32Array([-64, 5, 0, 64, 30, 0])
			var expected: bool = Access._scan_boundary(plan, patch, face, Vector2i.ZERO, false, 128)
			assert_equal(Access.boundary_contains(plan, patch, face), expected, "exact full vertical coverage")
		var top: PackedInt32Array = PackedInt32Array([-64, 0, -64, 64, 0, 64])
		assert_equal(Access.boundary_contains(plan, top, 2),
			Access._scan_boundary(plan, top, 2, Vector2i.ZERO, false, 16384), "full horizontal area with holes")


func test_full_populated_graph_and_maximum_paint_candidate_latency() -> void:
	"""This expensive cold setup is not UI timing; the measured one-step query includes the genuine768-edge path."""
	_fixture = Fixture.new()
	var actual: FullGraphFixture = FullGraphFixture.new()
	_fixture._actual = actual
	actual.build_network()
	assert_true(actual.failures.is_empty(), "full public composition: %s" % actual.failures)
	if not actual.failures.is_empty(): return
	_fixture._plan = Orders.RoomPlan.new()
	_fixture._plan.world = actual._world_ref
	_fixture._plan.space_revision = actual._owner.revision()
	_fixture._plan.room_type = Buildings.ROOM_TYPE_KITCHEN
	_fixture._plan.level = 1
	_fixture._plan.origin_u = Vector3i(Fixture.X + 2048, Fixture.FLOOR, Fixture.Z)
	_fixture._plan.height_u = Approach.reachable_height_u(_fixture._actual._profiles, 1) # DEC-054
	_fixture._plan.cell_size_u = 1024
	for z: int in 128:
		for x: int in 128: _fixture._plan.cells.append_array(PackedInt32Array([x, z]))
	_access = Access.new()
	assert_equal(_access.configure(actual._binding, actual._first), &"", "full actual anchor")
	assert_equal(_access.begin(_fixture._plan, 1), &"", "maximum paint search")
	_finish(_access)
	assert_equal(_access.refusal(), &"", "complete actual full-graph proof")
	assert_equal(_access.preview().route.size(), 768 * 6, "every actual selected span shown")
	print("ACCESS_STEP_USEC full1024_1536_4096_paint16384=%d proofs=%d" % [_access.max_step_usec, _access.proof_attempts])

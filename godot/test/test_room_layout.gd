extends "res://test/framework/test_case.gd"
## Owner-boundary fixtures, not an invented production furnishing/portability catalog.
## The synthetic profile height/contact offsets below test validation without granting services.

const Layout := preload("res://scripts/core/room_layout.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const ROOM: Vector2i = Vector2i(41, 3)
const OTHER_ROOM: Vector2i = Vector2i(42, 1)
const BED: int = Catalog.FURNITURE_DEFINITION["bed"]
const BENCH: int = Catalog.FURNITURE_DEFINITION["kitchen_bench"]
const SHELF: int = Catalog.FURNITURE_DEFINITION["shelf"]
const HEARTH: int = Catalog.FURNITURE_DEFINITION["hearth"]


class Owners extends Layout.Sources:

	var snapshots: Dictionary = {}
	var live: Dictionary = {}
	var calls: int = 0
	var last_entries: PackedInt32Array = PackedInt32Array()
	var refuse: StringName = &""
	var change_revision_at_commit: bool = false
	var bad_receipt: bool = false
	var next_project: int = 100
	var during_submit: Callable = Callable()
	var reentrant_result: Layout.Result = null
	var arena: Budget = Budget.new()
	var allow_submit: bool = true
	var token: int = 0
	var charged: int = 0
	var room: Vector2i = Layout.NULL_REF
	var begins: int = 0
	var ends: int = 0
	var reads: int = 0
	var live_reads: int = 0
	var during_binding: Callable = Callable()
	var during_begin: Callable = Callable()
	var during_read: Callable = Callable()
	var during_release: Callable = Callable()
	var scope_checks: int = 0
	var fail_scope_at: int = -1
	var scope_after_receipt: int = -1
	var end_error: StringName = &""


	func binding_refusal() -> StringName:
		"""Geometry is deliberately synthetic; the cold arena itself is the actual shared Budget owner."""
		if during_binding.is_valid():
			during_binding.call()
		return &""


	func begin_operation(ref: Vector2i, packed_bytes: int, _geometry: int, _placements: int) -> int:
		"""Charge the finite test planner peak before any fixture read; no production permission implied."""
		begins += 1
		charged = packed_bytes
		room = ref
		token = arena.acquire(charged)
		if during_begin.is_valid():
			during_begin.call()
		return token


	func cold_refusal() -> StringName:
		"""Preserve actual shared capacity/busy refusals."""
		return arena.admission_refusal(charged)


	func scope_refusal(value: int, ref: Vector2i, packed_bytes: int) -> StringName:
		"""A numerically similar or replaced token cannot cover this operation."""
		scope_checks += 1
		if scope_checks == fail_scope_at:
			return Layout.REFUSE_SCOPE
		return &"" if value == token and ref == room and packed_bytes == charged \
			and arena.covers(value, charged) else Layout.REFUSE_SCOPE


	func end_operation(value: int, ref: Vector2i) -> StringName:
		"""Observe cleared planner output before releasing the real actual arena token."""
		ends += 1
		if during_release.is_valid():
			during_release.call()
		if value != token or ref != room:
			return Layout.REFUSE_SCOPE
		var code: StringName = arena.release(value)
		token = 0
		room = Layout.NULL_REF
		return end_error if end_error != &"" else code


	func can_submit(value: int) -> bool:
		"""Fixture opt-in still requires the live actual cold token."""
		return allow_submit and arena.covers(value, charged)


	func read(room_ref: Vector2i, value: int) -> Layout.Snapshot:
		"""The owner hands over one consistent image, as the integration boundary requires."""
		reads += 1
		if during_read.is_valid():
			during_read.call()
		return snapshots.get(room_ref) as Layout.Snapshot if value == token else null


	func is_live(domain: int, ref: Vector2i, value: int) -> bool:
		"""Separate room/furniture/project namespaces, with exact generation equality."""
		live_reads += 1
		if domain == Layout.DOMAIN_PROJECT and scope_after_receipt > 0:
			fail_scope_at = scope_checks + scope_after_receipt
			scope_after_receipt = -1
		return arena.covers(value, charged) and bool(live.get(Vector3i(domain, ref.x, ref.y), false))


	func submit(batch: Layout.Batch, value: int) -> Layout.Submission:
		"""Fake only the atomic project owner; this test helper installs no furniture or services."""
		calls += 1
		last_entries = batch.entries.duplicate() # Independently owned fixture evidence, not a retained planner view.
		if during_submit.is_valid():
			reentrant_result = during_submit.call() as Layout.Result
		var answer: Layout.Submission = Layout.Submission.new()
		var snapshot: Layout.Snapshot = read(batch.room_ref, value)
		if change_revision_at_commit:
			snapshot.revision += 1
		if snapshot.revision != batch.expected_revision:
			answer.error = &"STALE_GEOMETRY_REVISION"
			return answer
		if refuse != &"":
			answer.error = refuse
			return answer
		answer.ok = true
		answer.error = &""
		if bad_receipt:
			return answer
		_accept(batch, snapshot, answer)
		return answer


	func _accept(batch: Layout.Batch, snapshot: Layout.Snapshot, answer: Layout.Submission) -> void:
		"""Publish one real fixture reference/occupancy claim per item, all in one call."""
		for base: int in range(0, batch.entries.size(), Layout.ENTRY_STRIDE):
			var project: Vector2i = Vector2i(next_project, 1)
			next_project += 1
			live[Vector3i(Layout.DOMAIN_PROJECT, project.x, project.y)] = true
			answer.project_refs.append_array(PackedInt32Array([project.x, project.y]))
			snapshot.object_refs.append_array(PackedInt32Array([project.x, project.y]))
			snapshot.object_kinds.append(Layout.DOMAIN_PROJECT)
			snapshot.object_entries.append_array(batch.entries.slice(base, base + Layout.ENTRY_STRIDE))
		snapshot.revision += 1


var _layout: Layout = null
var _owners: Owners = null
var _snapshot: Layout.Snapshot = null


func before_each() -> void:
	"""A small bounded store and a synthetic completed kitchen with one exterior-connected entry."""
	_layout = Layout.new(4, 16, 128)
	_owners = Owners.new()
	_snapshot = _make_room(ROOM)
	_owners.snapshots[ROOM] = _snapshot
	_owners.live[Vector3i(Layout.DOMAIN_ROOM, ROOM.x, ROOM.y)] = true
	_layout.bind_sources(_owners)
	assert_true(_layout.open_room(ROOM).ok, "fixture room opens")


func after_each() -> void:
	"""Release fixtures explicitly; bound method Callables retain no back-reference cycle."""
	assert_equal(_layout.quiescence_refusal(), &"", "test consumer releases before its input boundary")
	_layout.finish_input()
	_layout = null
	_snapshot = null
	_owners = null


func _consume(result: Layout.Result) -> Layout.Result:
	"""Legacy semantic assertions retain scalar results only, consuming views in this same call."""
	if result.requires_release():
		assert_equal(_layout.release_result(result), &"", "synchronous guide consumption")
	return result


func _placement_rows(room_ref: Vector2i, state: int = Layout.STATE_DRAFT) -> PackedInt32Array:
	"""An independently allocated fixture assertion copy is not production display storage."""
	var result: Layout.Result = _layout.placements(room_ref, state)
	var copy: PackedInt32Array = result.placement_rows.duplicate()
	_consume(result)
	return copy


func _make_room(ref: Vector2i, width: int = 6, depth: int = 6) -> Layout.Snapshot:
	"""Author a flat synthetic floor and its actual cardinal links, independent of Layout code."""
	var snapshot: Layout.Snapshot = Layout.Snapshot.new()
	snapshot.room_ref = ref
	snapshot.room_type = int(Catalog.ROOM_TYPE["KITCHEN"])
	snapshot.revision = 1
	snapshot.pitch_units = 2048
	snapshot.shell_complete = true
	snapshot.allowed_types_mask = (1 << BENCH) | (1 << HEARTH) | (1 << SHELF)
	for z: int in depth:
		for x: int in width:
			snapshot.room_cells.append(z * width + x)
			snapshot.floor_xy.append_array(PackedInt32Array([x, z]))
			snapshot.floor_height.append(0)
			snapshot.ceiling_height.append(4096)
			if x > 0:
				snapshot.walk_links.append_array(PackedInt32Array([z * width + x - 1, z * width + x]))
			if z > 0:
				snapshot.walk_links.append_array(PackedInt32Array([(z - 1) * width + x, z * width + x]))
	snapshot.entries = PackedInt32Array([0])
	snapshot.profiles.resize(9)
	for id: int in [BED, BENCH, HEARTH, SHELF]:
		var profile: Layout.Profile = Layout.Profile.new()
		profile.height_units = 1024
		profile.install_xy = PackedInt32Array([0, 1])
		profile.use_xy = PackedInt32Array([0, 1])
		snapshot.profiles[id] = profile
	return snapshot


func _expect_refusal(result: Layout.Result, code: StringName) -> void:
	"""A reason must be specific and no expected negative case may appear as an engine error."""
	assert_false(result.ok, "placement must refuse")
	assert_equal(result.error, code, "specific refusal code")


func _existing(type_id: int, origin: Vector2i, rotation: int = 0,
		domain: int = Layout.DOMAIN_FURNITURE, ref: Vector2i = Vector2i(91, 4)) -> void:
	"""Add an owner-backed installed object or unfinished construction claim."""
	_snapshot.object_refs.append_array(PackedInt32Array([ref.x, ref.y]))
	_snapshot.object_kinds.append(domain)
	_snapshot.object_entries.append_array(PackedInt32Array([type_id, origin.x, origin.y, rotation]))
	_owners.live[Vector3i(domain, ref.x, ref.y)] = true
	_snapshot.revision += 1


func test_unbound_sources_and_unbound_construction_fail_closed() -> void:
	"""A preview store cannot implicitly create a free furniture project."""
	var unbound: Layout = Layout.new(1, 2, 64)
	_expect_refusal(unbound.open_room(ROOM), &"ROOM_LAYOUT_SOURCES_UNBOUND")
	_owners.allow_submit = false
	_layout.bind_sources(_owners)
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	_expect_refusal(_layout.confirm_layout(ROOM), &"CONSTRUCTION_COORDINATOR_UNBOUND")
	assert_equal(_placement_rows(ROOM).size(), 6, "the retained draft was not discarded")
	assert_equal(_owners.calls, 0, "no mutation callback")


func test_layout_preview_and_staging_are_non_authoritative() -> void:
	"""Guides/drafts do not reserve world cells, call construction or change owner revision."""
	var revision: int = _snapshot.revision
	var preview: Layout.Result = _layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)
	assert_true(preview.ok, preview.error)
	assert_equal(preview.occupied_xy, PackedInt32Array([2, 2, 3, 2]), "preview.occupied_xy")
	assert_equal(preview.install_xy, PackedInt32Array([2, 3]), "preview.install_xy")
	assert_equal(preview.use_xy, PackedInt32Array([2, 3]), "preview.use_xy")
	assert_equal(_layout.release_result(preview), &"", "release guides before another input")
	assert_true(_consume(_layout.place(ROOM, BENCH, Vector2i(2, 2), 0)).ok, "layout place(ROOM, BENCH, Vector2i(2, 2), 0).ok")
	assert_equal(_snapshot.revision, revision, "snapshot revision")
	assert_equal(_snapshot.object_kinds.size(), 0, "no world occupancy")
	assert_equal(_owners.calls, 0, "no construction, materials, or work")


func test_unknown_or_forbidden_furniture_is_refused() -> void:
	"""Room compatibility is supplied explicitly; a kitchen cannot accept a bedroom's bed."""
	_expect_refusal(_consume(_layout.preview(ROOM, BED, Vector2i(2, 2), 0)), &"FURNITURE_NOT_PERMITTED_IN_ROOM")
	_expect_refusal(_consume(_layout.preview(ROOM, -1, Vector2i(2, 2), 0)), &"UNKNOWN_FURNITURE_TYPE")
	assert_equal(_owners.calls, 0, "owner calls")


func test_an_unfinished_shell_cannot_be_furnished() -> void:
	"""Eligibility waits for excavation AND selected finishing to complete."""
	_snapshot.shell_complete = false
	_expect_refusal(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)), &"ROOM_SHELL_UNFINISHED")
	assert_equal(_placement_rows(ROOM).size(), 0, "layout placements(ROOM).size()")
	assert_equal(_owners.calls, 0, "owner calls")


func test_all_four_rotations_use_the_full_catalog_footprint_and_contact() -> void:
	"""Two-tile benches rotate with their access guide, never as one origin-cell socket."""
	var floors: Array[PackedInt32Array] = [PackedInt32Array([2, 2, 3, 2]),
		PackedInt32Array([2, 2, 2, 3]), PackedInt32Array([3, 2, 2, 2]),
		PackedInt32Array([2, 3, 2, 2])]
	var contacts: Array[Vector2i] = [Vector2i(2, 3), Vector2i(1, 2), Vector2i(3, 1), Vector2i(3, 3)]
	for rotation: int in 4:
		var result: Layout.Result = _layout.preview(ROOM, BENCH, Vector2i(2, 2), rotation)
		assert_true(result.ok, result.error)
		assert_equal(result.occupied_xy, floors[rotation], "rotated occupied cells")
		assert_equal(result.use_xy, PackedInt32Array([contacts[rotation].x, contacts[rotation].y]), "result.use_xy")
		assert_equal(_layout.release_result(result), &"", "release guides before another input")
	_expect_refusal(_consume(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 4)), &"INVALID_ROTATION")


func test_concave_finished_boundary_beats_the_bounding_rectangle() -> void:
	"""An inward wall notch makes the bench illegal even though its origin lies inside."""
	_snapshot.floor_xy[15 * 2] = 20 # Replace (3,2) with a remote detached floor cell.
	_snapshot.floor_xy[15 * 2 + 1] = 20
	var result: Layout.Result = _layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)
	_expect_refusal(result, &"FURNITURE_OUTSIDE_FINISHED_FLOOR")
	assert_equal(result.affected_xy, PackedInt32Array([3, 2]), "highlight the missing second tile")
	assert_equal(_layout.release_result(result), &"", "release guides before another input")


func test_rotated_second_tile_detects_overlap() -> void:
	"""The unobstructed origin cannot hide a collision at the far end of a rotated item."""
	_existing(SHELF, Vector2i(2, 3))
	_expect_refusal(_consume(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 1)), &"FURNITURE_OVERLAP")


func test_protected_entrance_and_stair_landing_are_never_occupied() -> void:
	"""All active connection approaches remain protected against later furnishings."""
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i.ZERO, 0)),
		&"FURNITURE_BLOCKS_ENTRANCE_OR_LANDING")
	_snapshot.protected_cells = PackedInt32Array([15])
	_expect_refusal(_consume(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)),
		&"FURNITURE_BLOCKS_ENTRANCE_OR_LANDING")


func test_every_footprint_cell_needs_support_at_the_same_height() -> void:
	"""One floor step through a bench cannot be hidden by the room's shared identity."""
	_snapshot.floor_height[15] = 256
	_expect_refusal(_consume(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)), &"FURNITURE_CROSSES_FLOOR_HEIGHT")


func test_full_footprint_requires_headroom_including_other_level_obstructions() -> void:
	"""The provider's lowest overhead obstruction applies to the far occupied cell too."""
	_snapshot.ceiling_height[15] = 1023
	_expect_refusal(_consume(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)), &"FURNITURE_HEADROOM_BLOCKED")
	_snapshot.ceiling_height[15] = 1024
	assert_true(_consume(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)).ok, "exact known fit succeeds")


func test_install_contact_cannot_float_across_a_riser() -> void:
	"""A contact on a different level is not an invented standing/install pose."""
	_snapshot.floor_height[20] = 256
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)),
		&"FURNITURE_ACCESS_HEIGHT_MISMATCH")


func test_same_room_or_nearby_cells_do_not_invent_walk_connections() -> void:
	"""A physically nearby alcove is unreachable until its actual movement link exists."""
	_snapshot.walk_links = PackedInt32Array()
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"FURNITURE_ACCESS_UNREACHABLE")
	_snapshot.walk_links = PackedInt32Array([0, 20]) # Synthetic eligible stair/route supplied by owner.
	assert_true(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "layout preview(ROOM, SHELF, Vector2i(2, 2), 0).ok")


func test_later_furniture_must_preserve_existing_furniture_access() -> void:
	"""Both installed objects and the new item are stamped before route/contact validation."""
	_existing(SHELF, Vector2i(2, 2))
	var result: Layout.Result = _layout.preview(ROOM, SHELF, Vector2i(2, 3), 0)
	_expect_refusal(result, &"FURNITURE_ACCESS_UNREACHABLE")
	assert_equal(result.affected_xy, PackedInt32Array([2, 3]), "existing shelf's contact is blocked")
	assert_equal(_layout.release_result(result), &"", "release guides before another input")


func test_open_boundary_allows_real_access_from_a_neighboring_room() -> void:
	"""GDD starter pantry shelves may use common-room walk tiles without owning those tiles."""
	_snapshot.room_cells = PackedInt32Array([12, 13, 14, 15, 16, 17])
	var result: Layout.Result = _layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)
	assert_true(result.ok, "the actual contact is reachable across an open boundary")
	assert_equal(result.use_xy, PackedInt32Array([2, 3]), "contact is in neighboring walk space")
	assert_equal(_layout.release_result(result), &"", "release guides before another input")
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "stage only the owned footprint")


func test_neighboring_walk_context_does_not_authorize_neighboring_floor_occupation() -> void:
	"""Widening route context must not let a two-cell bench spill into another room."""
	_snapshot.room_cells = PackedInt32Array([14])
	var result: Layout.Result = _layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)
	_expect_refusal(result, &"FURNITURE_OUTSIDE_ROOM")
	assert_equal(result.affected_xy, PackedInt32Array([3, 2]), "second cell is another room's floor")
	assert_equal(_layout.release_result(result), &"", "release guides before another input")
	_snapshot.room_cells = PackedInt32Array([14, 14])
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"INVALID_ROOM_FLOOR_CELLS")


func test_required_circulation_must_reach_a_distant_landing() -> void:
	"""Avoiding the landing itself is insufficient when the placement cuts its only route."""
	_snapshot.protected_cells = PackedInt32Array([35])
	_snapshot.walk_links = PackedInt32Array([0, 7, 7, 8, 8, 9, 9, 15, 15, 21, 21, 35,
		0, 20])
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 1), 0)),
		&"FURNITURE_ACCESS_UNREACHABLE")
	_snapshot.profiles[SHELF].install_xy = PackedInt32Array([0, 2])
	_snapshot.profiles[SHELF].use_xy = PackedInt32Array([0, 2])
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 1), 0)),
		&"ENTRANCE_OR_LANDING_UNREACHABLE")


func test_confirmed_unfinished_projects_block_new_footprints() -> void:
	"""A construction claim is occupied before an installed object starts granting services."""
	_existing(SHELF, Vector2i(2, 2), 0, Layout.DOMAIN_PROJECT)
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"FURNITURE_OVERLAP")


func test_stale_object_generation_refuses_the_whole_image() -> void:
	"""A reused furniture slot cannot validate geometry captured from the old object."""
	_existing(SHELF, Vector2i(2, 2))
	_owners.live.erase(Vector3i(Layout.DOMAIN_FURNITURE, 91, 4))
	_owners.live[Vector3i(Layout.DOMAIN_FURNITURE, 91, 5)] = true
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(4, 2), 0)), &"STALE_OBJECT_REF")


func test_group_confirmation_revalidates_after_world_changes() -> void:
	"""A valid preview does not permit an overlapping transaction against a newer world."""
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(4, 2), 0)).ok, "layout place(ROOM, SHELF, Vector2i(4, 2), 0).ok")
	var before: PackedInt32Array = _placement_rows(ROOM)
	_existing(SHELF, Vector2i(4, 2))
	_expect_refusal(_layout.confirm_layout(ROOM), &"FURNITURE_OVERLAP")
	assert_equal(_placement_rows(ROOM), before, "every draft survives the atomic refusal")
	assert_equal(_owners.calls, 0, "no partial project publication")


func test_group_success_submits_one_transaction_and_retains_individual_projects() -> void:
	"""Grouping is a UI transaction; it still creates one construction project per furniture."""
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(4, 2), 0)).ok, "layout place(ROOM, SHELF, Vector2i(4, 2), 0).ok")
	var result: Layout.Result = _layout.confirm_layout(ROOM)
	assert_true(result.ok, result.error)
	assert_equal(result.value, 2, "result.value")
	assert_equal(_owners.calls, 1, "one atomic boundary call")
	assert_equal(_owners.last_entries, PackedInt32Array([SHELF, 2, 2, 0, SHELF, 4, 2, 0]), "owner last_batch.entries")
	assert_equal(_placement_rows(ROOM).size(), 0, "accepted previews cease being drafts")
	assert_equal(_placement_rows(ROOM, Layout.STATE_ACCEPTED).size(), 12, "layout placements(ROOM, Layout.STATE_ACCEPTED).size()")
	assert_equal(_layout.project_of(result.ref), Vector2i(100, 1), "layout project_of(result.ref)")


func test_coordinator_refusal_retains_all_drafts_and_creates_no_receipts() -> void:
	"""Capacity, command pause and delivery rules remain the actual project's responsibility."""
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	var before: PackedInt32Array = _placement_rows(ROOM)
	_owners.refuse = &"COMMAND_QUEUE_FULL"
	_expect_refusal(_layout.confirm_layout(ROOM), &"COMMAND_QUEUE_FULL")
	assert_equal(_placement_rows(ROOM), before, "layout placements(ROOM)")
	assert_equal(_placement_rows(ROOM, Layout.STATE_ACCEPTED).size(), 0, "layout placements(ROOM, Layout.STATE_ACCEPTED).size()")
	assert_equal(_snapshot.object_refs.size(), 0, "snapshot object_refs.size()")


func test_atomic_owner_refuses_revision_change_at_commit() -> void:
	"""The real owner must compare expected_revision at its own final acceptance boundary."""
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	_owners.change_revision_at_commit = true
	_expect_refusal(_layout.confirm_layout(ROOM), &"STALE_GEOMETRY_REVISION")
	assert_equal(_placement_rows(ROOM).size(), 6, "layout placements(ROOM).size()")
	assert_equal(_snapshot.object_refs.size(), 0, "snapshot object_refs.size()")


func test_malformed_success_is_a_coordinator_contract_breach() -> void:
	"""A callback without real live project receipts never becomes a successful placement."""
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	_owners.bad_receipt = true
	_expect_refusal(_layout.confirm_layout(ROOM), &"CONSTRUCTION_COORDINATOR_CONTRACT_BREACH")
	assert_equal(_placement_rows(ROOM).size(), 6, "layout placements(ROOM).size()")
	_expect_refusal(_layout.confirm_layout(ROOM), &"CONSTRUCTION_COORDINATOR_UNBOUND")
	assert_equal(_owners.calls, 1, "a faulty coordinator cannot repeat unknown external writes")


func test_mode_changes_preserve_drafts_and_accepted_projects() -> void:
	"""Changing modes only affects subsequent clicks; retained previews never become reservations."""
	var draft: Layout.Result = _consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0))
	assert_true(draft.ok, "draft.ok")
	assert_true(_layout.set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok, "layout set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok")
	var ordered: Layout.Result = _consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0))
	assert_true(ordered.ok, "an unconfirmed draft does not reserve a world cell")
	assert_equal(_owners.calls, 1, "owner calls")
	assert_equal(_placement_rows(ROOM).size(), 6, "draft retained separately")
	assert_true(_layout.set_mode(ROOM, Layout.MODE_LAYOUT).ok, "layout set_mode(ROOM, Layout.MODE_LAYOUT).ok")
	assert_equal(_layout.project_of(ordered.ref), Vector2i(100, 1), "accepted project unchanged")
	_expect_refusal(_layout.confirm_layout(ROOM), &"FURNITURE_OVERLAP")
	assert_true(_layout.discard_draft(draft.ref).ok, "discard requires its explicit action")


func test_each_room_has_an_independent_mode() -> void:
	"""Opening a second room does not inherit the previous room's click behavior."""
	_owners.snapshots[OTHER_ROOM] = _make_room(OTHER_ROOM)
	_owners.live[Vector3i(Layout.DOMAIN_ROOM, OTHER_ROOM.x, OTHER_ROOM.y)] = true
	assert_true(_layout.set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok, "layout set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok")
	assert_true(_layout.open_room(OTHER_ROOM).ok, "layout open_room(OTHER_ROOM).ok")
	assert_equal(_layout.mode_of(OTHER_ROOM).value, Layout.MODE_LAYOUT, "layout mode_of(OTHER_ROOM).value")
	assert_equal(_layout.mode_of(ROOM).value, Layout.MODE_INDIVIDUAL, "layout mode_of(ROOM).value")
	_expect_refusal(_layout.set_mode(OTHER_ROOM, 2), &"INVALID_FURNISHING_MODE")


func test_draft_edits_and_stale_draft_handles_are_atomic() -> void:
	"""An invalid move preserves a draft, and slot reuse cannot let an old UI edit a new draft."""
	var draft: Layout.Result = _consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0))
	var before: PackedInt32Array = _placement_rows(ROOM)
	_expect_refusal(_consume(_layout.edit_draft(draft.ref, SHELF, Vector2i.ZERO, 0)),
		&"FURNITURE_BLOCKS_ENTRANCE_OR_LANDING")
	assert_equal(_placement_rows(ROOM), before, "layout placements(ROOM)")
	assert_true(_consume(_layout.edit_draft(draft.ref, SHELF, Vector2i(4, 2), 0)).ok, "layout edit_draft(draft.ref, SHELF, Vector2i(4, 2), 0).ok")
	assert_true(_layout.discard_draft(draft.ref).ok, "layout discard_draft(draft.ref).ok")
	var replacement: Layout.Result = _consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0))
	assert_equal(replacement.ref.x, draft.ref.x, "replacement.ref.x")
	assert_true(replacement.ref.y > draft.ref.y, "replacement.ref.y > draft.ref.y")
	_expect_refusal(_layout.discard_draft(draft.ref), &"STALE_DRAFT_REF")
	_expect_refusal(_consume(_layout.edit_draft(draft.ref, SHELF, Vector2i(4, 2), 0)), &"STALE_DRAFT_REF")


func test_room_reuse_never_inherits_drafts_or_mode() -> void:
	"""Room identity is the whole ref; a new bedroom in a reused slot is not the old kitchen."""
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	assert_true(_layout.set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok, "layout set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok")
	_owners.live.erase(Vector3i(Layout.DOMAIN_ROOM, ROOM.x, ROOM.y))
	var next_room: Vector2i = Vector2i(ROOM.x, ROOM.y + 1)
	var next_snapshot: Layout.Snapshot = _make_room(next_room)
	next_snapshot.room_type = int(Catalog.ROOM_TYPE["PRIVATE_ROOM"])
	next_snapshot.allowed_types_mask = 1 << BED
	_owners.snapshots[next_room] = next_snapshot
	_owners.live[Vector3i(Layout.DOMAIN_ROOM, next_room.x, next_room.y)] = true
	_expect_refusal(_layout.confirm_layout(ROOM), &"STALE_ROOM_REF")
	assert_true(_layout.open_room(next_room).ok, "layout open_room(next_room).ok")
	assert_equal(_layout.mode_of(next_room).value, Layout.MODE_LAYOUT, "layout mode_of(next_room).value")
	assert_equal(_placement_rows(next_room).size(), 0, "layout placements(next_room).size()")
	assert_true(_consume(_layout.place(next_room, BED, Vector2i(2, 2), 0)).ok, "layout place(next_room, BED, Vector2i(2, 2), 0).ok")


func test_existing_room_type_cannot_change_by_emptying_or_reopening() -> void:
	"""A same-identity room type change requires real room replacement, not a UI relabel."""
	_snapshot.room_type = int(Catalog.ROOM_TYPE["PRIVATE_ROOM"])
	_snapshot.allowed_types_mask = 1 << BED
	_expect_refusal(_layout.open_room(ROOM), &"ROOM_TYPE_CHANGED")
	_expect_refusal(_consume(_layout.place(ROOM, BED, Vector2i(2, 2), 0)), &"ROOM_TYPE_CHANGED")
	_expect_refusal(_layout.forget_room(ROOM), &"ROOM_STILL_LIVE")


func test_room_cleanup_and_project_receipts_do_not_cancel_real_work() -> void:
	"""Only retired project tracking is releasable; an empty UI binding removes no room."""
	assert_true(_layout.set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok, "layout set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok")
	var ordered: Layout.Result = _consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0))
	_expect_refusal(_layout.forget_receipt(ordered.ref), &"CONSTRUCTION_PROJECT_STILL_LIVE")
	_owners.live.erase(Vector3i(Layout.DOMAIN_PROJECT, 100, 1))
	_owners.live[Vector3i(Layout.DOMAIN_PROJECT, 100, 2)] = true
	assert_equal(_layout.project_of(ordered.ref), Layout.NULL_REF, "new generation is not old work")
	_owners.live.erase(Vector3i(Layout.DOMAIN_ROOM, ROOM.x, ROOM.y))
	_expect_refusal(_layout.forget_room(ROOM), &"ROOM_HAS_LAYOUT_ENTRIES")
	assert_true(_layout.forget_receipt(ordered.ref).ok, "layout forget_receipt(ordered.ref).ok")
	assert_true(_layout.forget_room(ROOM).ok, "layout forget_room(ROOM).ok")
	_expect_refusal(_layout.forget_receipt(ordered.ref), &"STALE_PLACEMENT_REF")
	_expect_refusal(_layout.forget_room(ROOM), &"ROOM_NOT_OPEN")


func test_capacity_refuses_before_world_submission() -> void:
	"""No project is published when its local accepted receipt cannot be represented."""
	_layout = Layout.new(1, 1, 64)
	_layout.bind_sources(_owners)
	assert_true(_layout.open_room(ROOM).ok, "layout open_room(ROOM).ok")
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	_expect_refusal(_consume(_layout.place(ROOM, SHELF, Vector2i(4, 2), 0)), &"LAYOUT_ENTRY_CAPACITY")
	assert_true(_layout.set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok, "layout set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok")
	_expect_refusal(_consume(_layout.place(ROOM, SHELF, Vector2i(4, 2), 0)), &"LAYOUT_ENTRY_CAPACITY")
	assert_equal(_owners.calls, 0, "owner calls")
	_owners.snapshots[OTHER_ROOM] = _make_room(OTHER_ROOM)
	_owners.live[Vector3i(Layout.DOMAIN_ROOM, OTHER_ROOM.x, OTHER_ROOM.y)] = true
	_expect_refusal(_layout.open_room(OTHER_ROOM), &"ROOM_LAYOUT_CAPACITY")


func test_unknown_profile_opening_geometry_and_grid_pitch_fail_closed() -> void:
	"""Incomplete geometry is reported; no invented standard height, doorway or scaled footprint."""
	_snapshot.profiles[SHELF] = null
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"FURNITURE_PROFILE_MISSING")
	var door: int = int(Catalog.FURNITURE_DEFINITION["interior_door"])
	_snapshot.allowed_types_mask |= 1 << door
	_expect_refusal(_consume(_layout.preview(ROOM, door, Vector2i(2, 2), 0)),
		&"EDGE_FURNITURE_REQUIRES_OPENING_OWNER")
	_snapshot.pitch_units = 750
	_expect_refusal(_consume(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)), &"INVALID_ROOM_SNAPSHOT")


func test_finer_grid_subdivides_existing_catalog_dimensions_without_scaling_furniture() -> void:
	"""Half-size grid cells make a 2×1 catalog bench occupy 4×2 cells, not 2×1."""
	_snapshot.pitch_units = 1024
	_snapshot.profiles[BENCH].install_xy = PackedInt32Array([0, 2])
	_snapshot.profiles[BENCH].use_xy = PackedInt32Array([0, 2])
	var result: Layout.Result = _layout.preview(ROOM, BENCH, Vector2i(1, 2), 0)
	assert_true(result.ok, result.error)
	assert_equal(result.occupied_xy.size(), 16, "eight actual half-tile footprint cells")
	assert_equal(result.use_xy, PackedInt32Array([1, 4]), "result.use_xy")
	assert_equal(_layout.release_result(result), &"", "release guides before another input")


func test_invalid_floor_and_link_columns_are_refused_before_indexing() -> void:
	"""Malformed snapshots cannot cause out-of-range accesses hidden by a release runtime."""
	_snapshot.floor_height.remove_at(0)
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"INVALID_FLOOR_COLUMNS")
	_snapshot.floor_height.append(0)
	_snapshot.walk_links.append(0)
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"INVALID_WALK_LINK")
	_snapshot.walk_links = PackedInt32Array([0, 999])
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"INVALID_WALK_LINK")
	_snapshot.walk_links = PackedInt32Array([0, 1, 1, 0])
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"DUPLICATE_WALK_LINK")


func test_floor_link_object_and_contact_operation_budgets_are_enforced() -> void:
	"""Corrupt owner images cannot turn one cold UI operation into an unbounded allocation."""
	_layout = Layout.new(1, 2, 35)
	_layout.bind_sources(_owners)
	assert_true(_layout.open_room(ROOM).ok, "layout open_room(ROOM).ok")
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"INVALID_FLOOR_COLUMNS")
	_layout = Layout.new(1, 2, 36)
	_layout.bind_sources(_owners)
	assert_true(_layout.open_room(ROOM).ok, "layout open_room(ROOM).ok")
	_snapshot.walk_links.resize(36 * 8 + 2)
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"INVALID_WALK_LINK")
	_snapshot.walk_links = PackedInt32Array()
	_snapshot.object_kinds.resize(3)
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"INVALID_OBJECT_COLUMNS")
	_snapshot.object_kinds.clear()
	_snapshot.profiles[SHELF].use_xy.resize(74)
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"FURNITURE_PROFILE_INCOMPLETE")


func test_tiny_grid_cannot_expand_a_single_piece_beyond_the_operation_budget() -> void:
	"""A valid integer pitch alone cannot request millions of catalog footprint cell probes."""
	_snapshot.pitch_units = 1
	_expect_refusal(_consume(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)),
		&"FURNITURE_FOOTPRINT_EXCEEDS_OPERATION_BUDGET")


func test_combined_contact_budget_covers_many_individually_bounded_profiles() -> void:
	"""Many legal-sized profile lists cannot multiply into an unbounded combined validation."""
	_layout = Layout.new(1, 16, 36)
	_layout.bind_sources(_owners)
	assert_true(_layout.open_room(ROOM).ok, "open bounded room")
	var contacts: PackedInt32Array = PackedInt32Array()
	for index: int in 36:
		contacts.append_array(PackedInt32Array([0, 1]))
	_snapshot.profiles[SHELF].install_xy = contacts
	_snapshot.profiles[SHELF].use_xy = contacts
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(1, 1), 0)).ok, "first contact set fits")
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(3, 1), 0)).ok, "exact combined contact limit fits")
	_expect_refusal(_consume(_layout.place(ROOM, SHELF, Vector2i(5, 1), 0)), &"LAYOUT_CONTACT_BUDGET")
	assert_equal(_placement_rows(ROOM).size(), 12, "over-budget item was not staged")


func test_reentrant_draft_edits_and_rebinding_are_refused_during_acceptance() -> void:
	"""A coordinator cannot rewrite or discard the draft whose batch is currently being accepted."""
	var draft: Layout.Result = _consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0))
	_owners.during_submit = _layout.discard_draft.bind(draft.ref)
	assert_true(_layout.confirm_layout(ROOM).ok, "original batch accepted intact")
	_expect_refusal(_owners.reentrant_result, &"SUBMISSION_IN_PROGRESS")
	assert_equal(_placement_rows(ROOM, Layout.STATE_ACCEPTED).size(), 6, "receipt still tracked")
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(4, 2), 0)).ok, "another valid draft")
	_owners.during_submit = _layout.bind_sources.bind(null)
	assert_true(_layout.confirm_layout(ROOM).ok, "trusted adapters survive reentrant rebind")
	_expect_refusal(_owners.reentrant_result, &"SUBMISSION_IN_PROGRESS")


func test_rotation_and_translation_check_int64_before_int32_narrowing() -> void:
	"""INT32_MIN contact offsets must not wrap around to a legal opposite-side contact."""
	_snapshot.profiles[SHELF].use_xy = PackedInt32Array([-2147483648, 0])
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 2)), &"CELL_COORDINATE_OVERFLOW")
	_snapshot.profiles[SHELF].use_xy = PackedInt32Array([2147483647, 0])
	_expect_refusal(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)), &"CELL_COORDINATE_OVERFLOW")


func test_empty_confirmation_and_unopened_room_have_explicit_refusals() -> void:
	"""An empty group never becomes vacuous construction success."""
	_expect_refusal(_layout.confirm_layout(ROOM), &"EMPTY_LAYOUT")
	_owners.snapshots[OTHER_ROOM] = _make_room(OTHER_ROOM)
	_owners.live[Vector3i(Layout.DOMAIN_ROOM, OTHER_ROOM.x, OTHER_ROOM.y)] = true
	_expect_refusal(_consume(_layout.place(OTHER_ROOM, SHELF, Vector2i(2, 2), 0)), &"ROOM_NOT_OPEN")
	assert_equal(_placement_rows(OTHER_ROOM).size(), 0, "layout placements(OTHER_ROOM).size()")
	assert_equal(_layout.project_of(Vector2i(-1, 0)), Layout.NULL_REF, "layout project_of(Vector2i(-1, 0))")


func _attempt_reentry() -> void:
	"""Every external callback sees the already-exclusive planner operation."""
	_owners.reentrant_result = _layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)


func test_typed_base_and_foreign_sources_cannot_replace_world_ownership() -> void:
	"""No Callable fallback or coincident fixture room identity can switch an existing planner's world."""
	var closed: Layout = Layout.new(1, 1, 36)
	_expect_refusal(closed.bind_sources(Layout.Sources.new()), &"ROOM_LAYOUT_SOURCES_UNBOUND")
	var foreign: Owners = Owners.new()
	foreign.snapshots[ROOM] = _snapshot
	foreign.live[Vector3i(Layout.DOMAIN_ROOM, ROOM.x, ROOM.y)] = true
	_expect_refusal(_layout.bind_sources(foreign), &"ROOM_LAYOUT_SOURCES_UNBOUND")
	assert_equal(foreign.begins + foreign.reads + foreign.live_reads, 0, "foreign provider never queried")
	assert_true(_layout.open_room(ROOM).ok, "original world remains bound")


func test_actual_busy_arena_refuses_before_any_snapshot_or_liveness_callback() -> void:
	"""An unrelated worker/space cold operation retains the whole exact Budget lease."""
	var foreign: int = _owners.arena.acquire(4096)
	var reads: int = _owners.reads + _owners.live_reads
	var ends: int = _owners.ends
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), Budget.REFUSE_BUSY)
	assert_equal(_owners.reads + _owners.live_reads, reads, "no copying/liveness provider entered")
	assert_equal(_owners.ends, ends, "failed acquire has no lease to release")
	assert_true(_owners.arena.covers(foreign, 4096), "foreign exact lease preserved")
	assert_equal(_owners.arena.release(foreign), &"", "actual owner releases its own operation")
	assert_true(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "fresh retry works")


func test_packed_peak_admission_refuses_before_copies_at_unqualified_default_maximum() -> void:
	"""Inherited maximum columns do not pretend all simultaneous cold images fit the joint arena."""
	assert_equal(Layout.cold_packed_bytes(128, 16), 44544, "finite snapshot/validation/receipt peak")
	assert_equal(Layout.cold_dictionary_entries(128, 16), 768, "native map entries counted separately")
	assert_equal(Layout.cold_dictionary_entries(1, 20), 40, "receipt maps include retained and new refs")
	assert_equal(Layout.cold_packed_bytes(0, 1), 0, "invalid range is not silently clamped")
	assert_equal(Layout.cold_packed_bytes(1, Layout.PLACEMENT_CAPACITY + 1), 0, "invalid receipt bound")
	var large: Layout = Layout.new()
	assert_true(large.bind_sources(_owners).ok, "typed provider binds without reading geometry")
	var reads: int = _owners.reads + _owners.live_reads
	_expect_refusal(large.open_room(ROOM), Budget.REFUSE_BYTES)
	assert_equal(_owners.reads + _owners.live_reads, reads, "no owner image allocated")
	assert_true(_owners.arena.is_quiescent(), "refused technical maximum owns no arena")


func test_entry_guard_precedes_binding_begin_snapshot_and_release_callbacks() -> void:
	"""Early callbacks and final release cannot recursively start a second operation."""
	for boundary: int in 4:
		match boundary:
			0: _owners.during_binding = _attempt_reentry
			1: _owners.during_begin = _attempt_reentry
			2: _owners.during_read = _attempt_reentry
			3: _owners.during_release = _attempt_reentry
		assert_true(_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "outer scope remains intact")
		_expect_refusal(_owners.reentrant_result, &"SUBMISSION_IN_PROGRESS")
		_owners.during_binding = Callable()
		_owners.during_begin = Callable()
		_owners.during_read = Callable()
		_owners.during_release = Callable()
	assert_equal(_owners.begins, _owners.ends, "every admitted operation released exactly once")


func test_snapshot_is_read_once_and_guides_hold_only_their_exact_synchronous_scope() -> void:
	"""Opening validation plus preview share one actual image, then release before next input."""
	var reads: int = _owners.reads
	var result: Layout.Result = _layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)
	assert_true(result.ok, "valid preview")
	assert_true(result.requires_release(), "display receives explicit lifetime hint")
	assert_equal(_owners.reads - reads, 1, "no duplicate snapshot allocated")
	assert_equal(_layout.quiescence_refusal(), Layout.REFUSE_PENDING, "frame cannot cross held result")
	assert_true(_owners.arena.covers(result._lease_token, 44544), "result remains inside exact admitted peak")
	_expect_refusal(_layout.open_room(ROOM), Layout.REFUSE_PENDING)
	assert_equal(_owners.reads - reads, 1, "blocked next input does not read another image")
	assert_equal(_layout.release_result(result), &"", "explicit same-input release")
	assert_false(result.requires_release(), "consumed view no longer needs release")
	assert_equal(result.occupied_xy.size() + result.install_xy.size() + result.use_xy.size(), 0, "views cleared")
	assert_true(_owners.arena.is_quiescent(), "workers may use the shared arena now")


func _observe_cleared_result(result: Layout.Result) -> void:
	"""Inspect exact cleanup order before Budget.release is entered."""
	assert_null(_layout._operation_snapshot, "borrowed snapshot dropped before provider release")
	assert_equal(result.occupied_xy.size() + result.install_xy.size() + result.use_xy.size()
		+ result.affected_xy.size() + result.placement_rows.size(), 0, "every packed view cleared first")
	assert_equal(result._lease_token, 0, "result cannot recursively release the token")
	assert_equal(_layout.release_result(result), &"SUBMISSION_IN_PROGRESS", "release itself is exclusive")


func test_release_clears_all_views_before_provider_companion_and_arena_cleanup() -> void:
	"""No result-owned geometry remains charged after the provider releases its shared memory."""
	var result: Layout.Result = _layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)
	result.affected_xy = PackedInt32Array([1, 1]) # Independently bounded fixture corruption.
	_owners.during_release = _observe_cleared_result.bind(result)
	assert_equal(_layout.release_result(result), &"", "clear then release")
	_owners.during_release = Callable()
	assert_true(_owners.arena.is_quiescent(), "actual shared owner is free")


func test_forged_duplicate_and_foreign_result_release_cannot_release_another_lease() -> void:
	"""Exact result identity, planner identity and actual token all matter."""
	var result: Layout.Result = _layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)
	var forged: Layout.Result = Layout.Result.new()
	forged._lease_token = result._lease_token
	forged._lease_owner = result._lease_owner
	assert_equal(_layout.release_result(forged), &"ROOM_LAYOUT_RESULT_REF", "copied token is not the result")
	var foreign: Layout = Layout.new(1, 1, 36)
	assert_equal(foreign.release_result(result), &"ROOM_LAYOUT_RESULT_REF", "another planner cannot release")
	assert_true(_owners.arena.covers(result._lease_token, 44544), "original lease retained")
	assert_equal(_layout.release_result(result), &"", "actual consumer releases")
	var next: int = _owners.arena.acquire(4096)
	assert_equal(_layout.release_result(result), &"ROOM_LAYOUT_RESULT_REF", "duplicate cannot affect next operation")
	assert_true(_owners.arena.covers(next, 4096), "next owner remains covered")
	assert_equal(_owners.arena.release(next), &"", "actual next owner cleanup")


func test_input_boundary_diagnoses_and_clears_an_unreleased_live_result() -> void:
	"""A missed display release cannot silently monopolize the worker arena across frames."""
	var result: Layout.Result = _layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)
	assert_equal(_layout.finish_input(), Layout.REFUSE_ABANDONED, "caller omission diagnosed")
	assert_equal(result.occupied_xy.size() + result.install_xy.size() + result.use_xy.size(), 0, "escaped views invalidated")
	assert_true(_owners.arena.is_quiescent(), "arena released before simulation resumes")
	assert_equal(_layout.finish_input(), &"", "subsequent boundary is clean")
	assert_true(_layout.open_room(ROOM).ok, "normal operations may resume")


func test_dropped_result_is_diagnosed_without_starting_another_copying_operation() -> void:
	"""Weak result tracking detects abandoned temporary expressions without retaining their arrays."""
	var result: Layout.Result = _layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)
	assert_true(result.ok, "fixture escaped result")
	result = null
	var reads: int = _owners.reads + _owners.live_reads
	_expect_refusal(_layout.open_room(ROOM), Layout.REFUSE_ABANDONED)
	assert_equal(_owners.reads + _owners.live_reads, reads, "diagnosis did not begin another read")
	assert_true(_owners.arena.is_quiescent(), "abandoned lease safely dropped")
	assert_true(_layout.open_room(ROOM).ok, "explicit next retry succeeds")


func _expire_snapshot_lease() -> void:
	"""Replace the arena token after the actual fixture read, without authorizing the old scope."""
	assert_equal(_owners.arena.release(_owners.token), &"", "adversary expires original token")
	_foreign_lease = _owners.arena.acquire(4096)


var _foreign_lease: int = 0


func test_expired_snapshot_token_cannot_authorize_draft_mutation_or_release_replacement() -> void:
	"""No dictionary/guide/draft may be built from an image whose cold lease expired in its callback."""
	var before: PackedByteArray = _layout._state.duplicate()
	_owners.during_read = _expire_snapshot_lease
	_expect_refusal(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0), Layout.REFUSE_SCOPE)
	assert_equal(_layout._state, before, "all local states unchanged before staging")
	assert_true(_owners.arena.covers(_foreign_lease, 4096), "failed old cleanup cannot release replacement")
	assert_equal(_owners.arena.release(_foreign_lease), &"", "actual replacement cleanup")
	_owners.during_read = Callable()
	assert_equal(_layout.quiescence_refusal(), Layout.REFUSE_PROVIDER, "provider violation is quarantined")
	assert_true(_layout.bind_sources(_owners).ok, "explicit same-world reconciliation after clearing rogue lease")
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "fresh retry is funded")


func test_placement_list_copies_are_scoped_and_confirm_receipts_escape_without_geometry() -> void:
	"""Raw packed row copies cannot bypass the same accounting used for preview geometry."""
	var placed: Layout.Result = _consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0))
	var rows: Layout.Result = _layout.placements(ROOM)
	assert_equal(rows.placement_rows, PackedInt32Array([placed.ref.x, placed.ref.y, SHELF, 2, 2, 0]), "complete rows")
	assert_equal(_layout.quiescence_refusal(), Layout.REFUSE_PENDING, "row result retains exact scope")
	assert_equal(_layout.release_result(rows), &"", "consume rows within same input")
	assert_equal(rows.placement_rows.size(), 0, "row storage released")
	var confirmed: Layout.Result = _layout.confirm_layout(ROOM)
	assert_true(confirmed.ok, "paid acceptance fixture succeeds")
	assert_equal(confirmed.occupied_xy.size() + confirmed.install_xy.size() + confirmed.use_xy.size(), 0, "receipt is scalar only")
	assert_equal(confirmed._lease_token, 0, "confirmation keeps no arena alive")
	assert_true(_owners.arena.is_quiescent(), "accepted tracking does not stall worker processing")


func test_input_boundary_releases_pinned_scope_even_if_result_metadata_was_mutated() -> void:
	"""Mutable returned fields may refuse explicit release, but cannot strand the true planner token."""
	var result: Layout.Result = _layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)
	var actual: int = result._lease_token
	result._lease_token += 1
	result._lease_owner = null
	assert_equal(_layout.release_result(result), &"ROOM_LAYOUT_RESULT_REF", "corrupted result is not accepted")
	assert_true(_owners.arena.covers(actual, 44544), "real scope still tracked separately")
	assert_equal(_layout.finish_input(), Layout.REFUSE_ABANDONED, "input boundary reports caller violation")
	assert_true(_owners.arena.is_quiescent(), "pinned actual token released regardless of corrupt metadata")
	assert_equal(result.occupied_xy.size() + result.install_xy.size() + result.use_xy.size(), 0, "all views dropped")


func test_failed_guided_preview_keeps_scope_until_highlight_is_consumed() -> void:
	"""An illegal placement's red affected-cell guide has the same lifetime as a valid preview."""
	_snapshot.protected_cells = PackedInt32Array([15])
	var result: Layout.Result = _layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)
	_expect_refusal(result, &"FURNITURE_BLOCKS_ENTRANCE_OR_LANDING")
	assert_equal(result.affected_xy, PackedInt32Array([3, 2]), "exact failed cell can be rendered synchronously")
	assert_equal(_layout.quiescence_refusal(), Layout.REFUSE_PENDING, "failed result still owns packed guides")
	assert_equal(_layout.release_result(result), &"", "display consumed rejection highlight")
	assert_true(_owners.arena.is_quiescent(), "failure cannot retain the worker arena")


func test_expired_weak_provider_refuses_before_liveness_or_snapshot_fallback() -> void:
	"""A stale planner cannot extend an old world merely by retaining a provider pointer."""
	_owners = null
	_expect_refusal(_layout.open_room(ROOM), &"ROOM_LAYOUT_SOURCES_UNBOUND")
	var replacement: Owners = Owners.new()
	_expect_refusal(_layout.bind_sources(replacement), &"ROOM_LAYOUT_SOURCES_UNBOUND")
	assert_equal(replacement.begins + replacement.reads + replacement.live_reads, 0, "new world needs a new planner")


func test_binding_itself_is_exclusive_before_the_initial_provider_attestation() -> void:
	"""Reentry protection applies to configuration as well as every cold operation."""
	_owners.during_binding = _attempt_reentry
	assert_true(_layout.bind_sources(_owners).ok, "same-world explicit reconciliation allowed")
	_expect_refusal(_owners.reentrant_result, &"SUBMISSION_IN_PROGRESS")
	_owners.during_binding = Callable()
	assert_true(_owners.arena.is_quiescent(), "configuration allocated no cold image")


func _assert_committed_cleanup_fault(result: Layout.Result) -> void:
	"""The command happened; cleanup diagnostics cannot advertise rollback or permit another submit."""
	assert_true(result.ok, "accepted mutation remains truthfully successful")
	assert_true(result.mutation_committed, "caller can distinguish committed outcome")
	assert_equal(result.error, &"", "no ordinary placement refusal after commitment")
	assert_true(result.cleanup_error != &"", "provider cleanup fault surfaced separately")
	assert_equal(_layout.quiescence_refusal(), Layout.REFUSE_PROVIDER, "provider requires reconciliation")
	assert_equal(result.occupied_xy.size() + result.install_xy.size() + result.use_xy.size(), 0, "failure retains no geometry")


func test_scope_failure_after_successful_project_acceptance_preserves_outcome_and_quarantines() -> void:
	"""An owner's last receipt check succeeds, then the final scope callback fails after actual acceptance."""
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "draft staged")
	_owners.scope_after_receipt = 2 # The receipt's post-liveness check, then final finish check.
	var result: Layout.Result = _layout.confirm_layout(ROOM)
	_assert_committed_cleanup_fault(result)
	assert_equal(_layout._state[result.ref.x], Layout.STATE_ACCEPTED, "accepted receipt exists")
	assert_true(bool(_owners.live.get(Vector3i(Layout.DOMAIN_PROJECT, 100, 1))), "actual fixture project committed")
	assert_equal(_owners.calls, 1, "exactly one atomic acceptance")
	_expect_refusal(_layout.confirm_layout(ROOM), Layout.REFUSE_PROVIDER)
	assert_equal(_owners.calls, 1, "no automatic resubmission after a contract breach")
	assert_true(_owners.arena.is_quiescent(), "scope still cleaned before frame returns")
	assert_true(_layout.bind_sources(_owners).ok, "explicit owner reconciliation")
	assert_equal(_layout.project_of(result.ref), Vector2i(100, 1), "original accepted project remains the receipt")


func test_end_operation_failure_after_acceptance_cannot_report_an_atomic_refusal() -> void:
	"""Cleanup is fallible evidence, never a rollback of published projects or receipts."""
	assert_true(_consume(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0)).ok, "draft staged")
	_owners.end_error = &"SYNTHETIC_RELEASE_CONTRACT_BREACH"
	var result: Layout.Result = _layout.confirm_layout(ROOM)
	_assert_committed_cleanup_fault(result)
	assert_equal(result.cleanup_error, _owners.end_error, "exact cleanup diagnostic retained")
	assert_equal(_layout._state[result.ref.x], Layout.STATE_ACCEPTED, "no false local rollback")
	_expect_refusal(_layout.place(ROOM, SHELF, Vector2i(4, 2), 0), Layout.REFUSE_PROVIDER)
	assert_equal(_owners.calls, 1, "no second accepted project")
	_owners.end_error = &""
	assert_true(_layout.bind_sources(_owners).ok, "explicit same-provider recovery")
	assert_equal(_layout.project_of(result.ref), Vector2i(100, 1), "accepted project survives cleanup failure")


func test_late_scope_failure_after_local_draft_write_preserves_the_committed_draft() -> void:
	"""Even a non-authoritative draft cannot be reported as unchanged when the local write succeeded."""
	# Establish this fixture's exact callback sequence without changing geometry or local rows.
	var before: int = _owners.scope_checks
	_consume(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0))
	var checks: int = _owners.scope_checks - before
	_owners.fail_scope_at = _owners.scope_checks + checks
	var result: Layout.Result = _layout.place(ROOM, SHELF, Vector2i(2, 2), 0)
	_assert_committed_cleanup_fault(result)
	assert_equal(_layout._state[result.ref.x], Layout.STATE_DRAFT, "draft is present and its actual ref is returned")
	assert_equal(_owners.calls, 0, "no world project implied")
	_expect_refusal(_layout.place(ROOM, SHELF, Vector2i(4, 2), 0), Layout.REFUSE_PROVIDER)
	assert_true(_layout.bind_sources(_owners).ok, "same-world reconciliation retains draft")
	assert_equal(_placement_rows(ROOM).size(), 6, "only the committed draft remains")

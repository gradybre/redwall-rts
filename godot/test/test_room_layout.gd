extends "res://test/framework/test_case.gd"
## Owner-boundary fixtures, not an invented production furnishing/portability catalog.
## The synthetic profile height/contact offsets below test validation without granting services.

const Layout := preload("res://scripts/core/room_layout.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const ROOM: Vector2i = Vector2i(41, 3)
const OTHER_ROOM: Vector2i = Vector2i(42, 1)
const BED: int = Catalog.FURNITURE_DEFINITION["bed"]
const BENCH: int = Catalog.FURNITURE_DEFINITION["kitchen_bench"]
const SHELF: int = Catalog.FURNITURE_DEFINITION["shelf"]
const HEARTH: int = Catalog.FURNITURE_DEFINITION["hearth"]


class Owners extends RefCounted:

	var snapshots: Dictionary = {}
	var live: Dictionary = {}
	var calls: int = 0
	var last_batch: Layout.Batch = null
	var refuse: StringName = &""
	var change_revision_at_commit: bool = false
	var bad_receipt: bool = false
	var next_project: int = 100
	var during_submit: Callable = Callable()
	var reentrant_result: Layout.Result = null


	func read(room_ref: Vector2i) -> Layout.Snapshot:
		"""The owner hands over one consistent image, as the integration boundary requires."""
		return snapshots.get(room_ref) as Layout.Snapshot


	func is_live(domain: int, ref: Vector2i) -> bool:
		"""Separate room/furniture/project namespaces, with exact generation equality."""
		return bool(live.get(Vector3i(domain, ref.x, ref.y), false))


	func submit(batch: Layout.Batch) -> Layout.Submission:
		"""Fake only the atomic project owner; this test helper installs no furniture or services."""
		calls += 1
		last_batch = batch
		if during_submit.is_valid():
			reentrant_result = during_submit.call() as Layout.Result
		var answer: Layout.Submission = Layout.Submission.new()
		var snapshot: Layout.Snapshot = read(batch.room_ref)
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
	_layout.bind_sources(_owners.read, _owners.is_live, _owners.submit)
	assert_true(_layout.open_room(ROOM).ok, "fixture room opens")


func after_each() -> void:
	"""Release fixtures explicitly; bound method Callables retain no back-reference cycle."""
	_layout = null
	_snapshot = null
	_owners = null


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
	_layout.bind_sources(_owners.read, _owners.is_live)
	assert_true(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	_expect_refusal(_layout.confirm_layout(ROOM), &"CONSTRUCTION_COORDINATOR_UNBOUND")
	assert_equal(_layout.placements(ROOM).size(), 6, "the retained draft was not discarded")
	assert_equal(_owners.calls, 0, "no mutation callback")


func test_layout_preview_and_staging_are_non_authoritative() -> void:
	"""Guides/drafts do not reserve world cells, call construction or change owner revision."""
	var revision: int = _snapshot.revision
	var preview: Layout.Result = _layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)
	assert_true(preview.ok, preview.error)
	assert_equal(preview.occupied_xy, PackedInt32Array([2, 2, 3, 2]), "preview.occupied_xy")
	assert_equal(preview.install_xy, PackedInt32Array([2, 3]), "preview.install_xy")
	assert_equal(preview.use_xy, PackedInt32Array([2, 3]), "preview.use_xy")
	assert_true(_layout.place(ROOM, BENCH, Vector2i(2, 2), 0).ok, "layout place(ROOM, BENCH, Vector2i(2, 2), 0).ok")
	assert_equal(_snapshot.revision, revision, "snapshot revision")
	assert_equal(_snapshot.object_kinds.size(), 0, "no world occupancy")
	assert_equal(_owners.calls, 0, "no construction, materials, or work")


func test_unknown_or_forbidden_furniture_is_refused() -> void:
	"""Room compatibility is supplied explicitly; a kitchen cannot accept a bedroom's bed."""
	_expect_refusal(_layout.preview(ROOM, BED, Vector2i(2, 2), 0), &"FURNITURE_NOT_PERMITTED_IN_ROOM")
	_expect_refusal(_layout.preview(ROOM, -1, Vector2i(2, 2), 0), &"UNKNOWN_FURNITURE_TYPE")
	assert_equal(_owners.calls, 0, "owner calls")


func test_an_unfinished_shell_cannot_be_furnished() -> void:
	"""Eligibility waits for excavation AND selected finishing to complete."""
	_snapshot.shell_complete = false
	_expect_refusal(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0), &"ROOM_SHELL_UNFINISHED")
	assert_equal(_layout.placements(ROOM).size(), 0, "layout placements(ROOM).size()")
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
	_expect_refusal(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 4), &"INVALID_ROTATION")


func test_concave_finished_boundary_beats_the_bounding_rectangle() -> void:
	"""An inward wall notch makes the bench illegal even though its origin lies inside."""
	_snapshot.floor_xy[15 * 2] = 20 # Replace (3,2) with a remote detached floor cell.
	_snapshot.floor_xy[15 * 2 + 1] = 20
	var result: Layout.Result = _layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)
	_expect_refusal(result, &"FURNITURE_OUTSIDE_FINISHED_FLOOR")
	assert_equal(result.affected_xy, PackedInt32Array([3, 2]), "highlight the missing second tile")


func test_rotated_second_tile_detects_overlap() -> void:
	"""The unobstructed origin cannot hide a collision at the far end of a rotated item."""
	_existing(SHELF, Vector2i(2, 3))
	_expect_refusal(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 1), &"FURNITURE_OVERLAP")


func test_protected_entrance_and_stair_landing_are_never_occupied() -> void:
	"""All active connection approaches remain protected against later furnishings."""
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i.ZERO, 0),
		&"FURNITURE_BLOCKS_ENTRANCE_OR_LANDING")
	_snapshot.protected_cells = PackedInt32Array([15])
	_expect_refusal(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 0),
		&"FURNITURE_BLOCKS_ENTRANCE_OR_LANDING")


func test_every_footprint_cell_needs_support_at_the_same_height() -> void:
	"""One floor step through a bench cannot be hidden by the room's shared identity."""
	_snapshot.floor_height[15] = 256
	_expect_refusal(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 0), &"FURNITURE_CROSSES_FLOOR_HEIGHT")


func test_full_footprint_requires_headroom_including_other_level_obstructions() -> void:
	"""The provider's lowest overhead obstruction applies to the far occupied cell too."""
	_snapshot.ceiling_height[15] = 1023
	_expect_refusal(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 0), &"FURNITURE_HEADROOM_BLOCKED")
	_snapshot.ceiling_height[15] = 1024
	assert_true(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 0).ok, "exact known fit succeeds")


func test_install_contact_cannot_float_across_a_riser() -> void:
	"""A contact on a different level is not an invented standing/install pose."""
	_snapshot.floor_height[20] = 256
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0),
		&"FURNITURE_ACCESS_HEIGHT_MISMATCH")


func test_same_room_or_nearby_cells_do_not_invent_walk_connections() -> void:
	"""A physically nearby alcove is unreachable until its actual movement link exists."""
	_snapshot.walk_links = PackedInt32Array()
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"FURNITURE_ACCESS_UNREACHABLE")
	_snapshot.walk_links = PackedInt32Array([0, 20]) # Synthetic eligible stair/route supplied by owner.
	assert_true(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0).ok, "layout preview(ROOM, SHELF, Vector2i(2, 2), 0).ok")


func test_later_furniture_must_preserve_existing_furniture_access() -> void:
	"""Both installed objects and the new item are stamped before route/contact validation."""
	_existing(SHELF, Vector2i(2, 2))
	var result: Layout.Result = _layout.preview(ROOM, SHELF, Vector2i(2, 3), 0)
	_expect_refusal(result, &"FURNITURE_ACCESS_UNREACHABLE")
	assert_equal(result.affected_xy, PackedInt32Array([2, 3]), "existing shelf's contact is blocked")


func test_open_boundary_allows_real_access_from_a_neighboring_room() -> void:
	"""GDD starter pantry shelves may use common-room walk tiles without owning those tiles."""
	_snapshot.room_cells = PackedInt32Array([12, 13, 14, 15, 16, 17])
	var result: Layout.Result = _layout.preview(ROOM, SHELF, Vector2i(2, 2), 0)
	assert_true(result.ok, "the actual contact is reachable across an open boundary")
	assert_equal(result.use_xy, PackedInt32Array([2, 3]), "contact is in neighboring walk space")
	assert_true(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0).ok, "stage only the owned footprint")


func test_neighboring_walk_context_does_not_authorize_neighboring_floor_occupation() -> void:
	"""Widening route context must not let a two-cell bench spill into another room."""
	_snapshot.room_cells = PackedInt32Array([14])
	var result: Layout.Result = _layout.preview(ROOM, BENCH, Vector2i(2, 2), 0)
	_expect_refusal(result, &"FURNITURE_OUTSIDE_ROOM")
	assert_equal(result.affected_xy, PackedInt32Array([3, 2]), "second cell is another room's floor")
	_snapshot.room_cells = PackedInt32Array([14, 14])
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"INVALID_ROOM_FLOOR_CELLS")


func test_required_circulation_must_reach_a_distant_landing() -> void:
	"""Avoiding the landing itself is insufficient when the placement cuts its only route."""
	_snapshot.protected_cells = PackedInt32Array([35])
	_snapshot.walk_links = PackedInt32Array([0, 7, 7, 8, 8, 9, 9, 15, 15, 21, 21, 35,
		0, 20])
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 1), 0),
		&"FURNITURE_ACCESS_UNREACHABLE")
	_snapshot.profiles[SHELF].install_xy = PackedInt32Array([0, 2])
	_snapshot.profiles[SHELF].use_xy = PackedInt32Array([0, 2])
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 1), 0),
		&"ENTRANCE_OR_LANDING_UNREACHABLE")


func test_confirmed_unfinished_projects_block_new_footprints() -> void:
	"""A construction claim is occupied before an installed object starts granting services."""
	_existing(SHELF, Vector2i(2, 2), 0, Layout.DOMAIN_PROJECT)
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"FURNITURE_OVERLAP")


func test_stale_object_generation_refuses_the_whole_image() -> void:
	"""A reused furniture slot cannot validate geometry captured from the old object."""
	_existing(SHELF, Vector2i(2, 2))
	_owners.live.erase(Vector3i(Layout.DOMAIN_FURNITURE, 91, 4))
	_owners.live[Vector3i(Layout.DOMAIN_FURNITURE, 91, 5)] = true
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(4, 2), 0), &"STALE_OBJECT_REF")


func test_group_confirmation_revalidates_after_world_changes() -> void:
	"""A valid preview does not permit an overlapping transaction against a newer world."""
	assert_true(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	assert_true(_layout.place(ROOM, SHELF, Vector2i(4, 2), 0).ok, "layout place(ROOM, SHELF, Vector2i(4, 2), 0).ok")
	var before: PackedInt32Array = _layout.placements(ROOM)
	_existing(SHELF, Vector2i(4, 2))
	_expect_refusal(_layout.confirm_layout(ROOM), &"FURNITURE_OVERLAP")
	assert_equal(_layout.placements(ROOM), before, "every draft survives the atomic refusal")
	assert_equal(_owners.calls, 0, "no partial project publication")


func test_group_success_submits_one_transaction_and_retains_individual_projects() -> void:
	"""Grouping is a UI transaction; it still creates one construction project per furniture."""
	assert_true(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	assert_true(_layout.place(ROOM, SHELF, Vector2i(4, 2), 0).ok, "layout place(ROOM, SHELF, Vector2i(4, 2), 0).ok")
	var result: Layout.Result = _layout.confirm_layout(ROOM)
	assert_true(result.ok, result.error)
	assert_equal(result.value, 2, "result.value")
	assert_equal(_owners.calls, 1, "one atomic boundary call")
	assert_equal(_owners.last_batch.entries, PackedInt32Array([SHELF, 2, 2, 0, SHELF, 4, 2, 0]), "owner last_batch.entries")
	assert_equal(_layout.placements(ROOM).size(), 0, "accepted previews cease being drafts")
	assert_equal(_layout.placements(ROOM, Layout.STATE_ACCEPTED).size(), 12, "layout placements(ROOM, Layout.STATE_ACCEPTED).size()")
	assert_equal(_layout.project_of(result.ref), Vector2i(100, 1), "layout project_of(result.ref)")


func test_coordinator_refusal_retains_all_drafts_and_creates_no_receipts() -> void:
	"""Capacity, command pause and delivery rules remain the actual project's responsibility."""
	assert_true(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	var before: PackedInt32Array = _layout.placements(ROOM)
	_owners.refuse = &"COMMAND_QUEUE_FULL"
	_expect_refusal(_layout.confirm_layout(ROOM), &"COMMAND_QUEUE_FULL")
	assert_equal(_layout.placements(ROOM), before, "layout placements(ROOM)")
	assert_equal(_layout.placements(ROOM, Layout.STATE_ACCEPTED).size(), 0, "layout placements(ROOM, Layout.STATE_ACCEPTED).size()")
	assert_equal(_snapshot.object_refs.size(), 0, "snapshot object_refs.size()")


func test_atomic_owner_refuses_revision_change_at_commit() -> void:
	"""The real owner must compare expected_revision at its own final acceptance boundary."""
	assert_true(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	_owners.change_revision_at_commit = true
	_expect_refusal(_layout.confirm_layout(ROOM), &"STALE_GEOMETRY_REVISION")
	assert_equal(_layout.placements(ROOM).size(), 6, "layout placements(ROOM).size()")
	assert_equal(_snapshot.object_refs.size(), 0, "snapshot object_refs.size()")


func test_malformed_success_is_a_coordinator_contract_breach() -> void:
	"""A callback without real live project receipts never becomes a successful placement."""
	assert_true(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	_owners.bad_receipt = true
	_expect_refusal(_layout.confirm_layout(ROOM), &"CONSTRUCTION_COORDINATOR_CONTRACT_BREACH")
	assert_equal(_layout.placements(ROOM).size(), 6, "layout placements(ROOM).size()")
	_expect_refusal(_layout.confirm_layout(ROOM), &"CONSTRUCTION_COORDINATOR_UNBOUND")
	assert_equal(_owners.calls, 1, "a faulty coordinator cannot repeat unknown external writes")


func test_mode_changes_preserve_drafts_and_accepted_projects() -> void:
	"""Changing modes only affects subsequent clicks; retained previews never become reservations."""
	var draft: Layout.Result = _layout.place(ROOM, SHELF, Vector2i(2, 2), 0)
	assert_true(draft.ok, "draft.ok")
	assert_true(_layout.set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok, "layout set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok")
	var ordered: Layout.Result = _layout.place(ROOM, SHELF, Vector2i(2, 2), 0)
	assert_true(ordered.ok, "an unconfirmed draft does not reserve a world cell")
	assert_equal(_owners.calls, 1, "owner calls")
	assert_equal(_layout.placements(ROOM).size(), 6, "draft retained separately")
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
	var draft: Layout.Result = _layout.place(ROOM, SHELF, Vector2i(2, 2), 0)
	var before: PackedInt32Array = _layout.placements(ROOM)
	_expect_refusal(_layout.edit_draft(draft.ref, SHELF, Vector2i.ZERO, 0),
		&"FURNITURE_BLOCKS_ENTRANCE_OR_LANDING")
	assert_equal(_layout.placements(ROOM), before, "layout placements(ROOM)")
	assert_true(_layout.edit_draft(draft.ref, SHELF, Vector2i(4, 2), 0).ok, "layout edit_draft(draft.ref, SHELF, Vector2i(4, 2), 0).ok")
	assert_true(_layout.discard_draft(draft.ref).ok, "layout discard_draft(draft.ref).ok")
	var replacement: Layout.Result = _layout.place(ROOM, SHELF, Vector2i(2, 2), 0)
	assert_equal(replacement.ref.x, draft.ref.x, "replacement.ref.x")
	assert_true(replacement.ref.y > draft.ref.y, "replacement.ref.y > draft.ref.y")
	_expect_refusal(_layout.discard_draft(draft.ref), &"STALE_DRAFT_REF")
	_expect_refusal(_layout.edit_draft(draft.ref, SHELF, Vector2i(4, 2), 0), &"STALE_DRAFT_REF")


func test_room_reuse_never_inherits_drafts_or_mode() -> void:
	"""Room identity is the whole ref; a new bedroom in a reused slot is not the old kitchen."""
	assert_true(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
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
	assert_equal(_layout.placements(next_room).size(), 0, "layout placements(next_room).size()")
	assert_true(_layout.place(next_room, BED, Vector2i(2, 2), 0).ok, "layout place(next_room, BED, Vector2i(2, 2), 0).ok")


func test_existing_room_type_cannot_change_by_emptying_or_reopening() -> void:
	"""A same-identity room type change requires real room replacement, not a UI relabel."""
	_snapshot.room_type = int(Catalog.ROOM_TYPE["PRIVATE_ROOM"])
	_snapshot.allowed_types_mask = 1 << BED
	_expect_refusal(_layout.open_room(ROOM), &"ROOM_TYPE_CHANGED")
	_expect_refusal(_layout.place(ROOM, BED, Vector2i(2, 2), 0), &"ROOM_TYPE_CHANGED")
	_expect_refusal(_layout.forget_room(ROOM), &"ROOM_STILL_LIVE")


func test_room_cleanup_and_project_receipts_do_not_cancel_real_work() -> void:
	"""Only retired project tracking is releasable; an empty UI binding removes no room."""
	assert_true(_layout.set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok, "layout set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok")
	var ordered: Layout.Result = _layout.place(ROOM, SHELF, Vector2i(2, 2), 0)
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
	_layout.bind_sources(_owners.read, _owners.is_live, _owners.submit)
	assert_true(_layout.open_room(ROOM).ok, "layout open_room(ROOM).ok")
	assert_true(_layout.place(ROOM, SHELF, Vector2i(2, 2), 0).ok, "layout place(ROOM, SHELF, Vector2i(2, 2), 0).ok")
	_expect_refusal(_layout.place(ROOM, SHELF, Vector2i(4, 2), 0), &"LAYOUT_ENTRY_CAPACITY")
	assert_true(_layout.set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok, "layout set_mode(ROOM, Layout.MODE_INDIVIDUAL).ok")
	_expect_refusal(_layout.place(ROOM, SHELF, Vector2i(4, 2), 0), &"LAYOUT_ENTRY_CAPACITY")
	assert_equal(_owners.calls, 0, "owner calls")
	_owners.snapshots[OTHER_ROOM] = _make_room(OTHER_ROOM)
	_owners.live[Vector3i(Layout.DOMAIN_ROOM, OTHER_ROOM.x, OTHER_ROOM.y)] = true
	_expect_refusal(_layout.open_room(OTHER_ROOM), &"ROOM_LAYOUT_CAPACITY")


func test_unknown_profile_opening_geometry_and_grid_pitch_fail_closed() -> void:
	"""Incomplete geometry is reported; no invented standard height, doorway or scaled footprint."""
	_snapshot.profiles[SHELF] = null
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"FURNITURE_PROFILE_MISSING")
	var door: int = int(Catalog.FURNITURE_DEFINITION["interior_door"])
	_snapshot.allowed_types_mask |= 1 << door
	_expect_refusal(_layout.preview(ROOM, door, Vector2i(2, 2), 0),
		&"EDGE_FURNITURE_REQUIRES_OPENING_OWNER")
	_snapshot.pitch_units = 750
	_expect_refusal(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 0), &"INVALID_ROOM_SNAPSHOT")


func test_finer_grid_subdivides_existing_catalog_dimensions_without_scaling_furniture() -> void:
	"""Half-size grid cells make a 2×1 catalog bench occupy 4×2 cells, not 2×1."""
	_snapshot.pitch_units = 1024
	_snapshot.profiles[BENCH].install_xy = PackedInt32Array([0, 2])
	_snapshot.profiles[BENCH].use_xy = PackedInt32Array([0, 2])
	var result: Layout.Result = _layout.preview(ROOM, BENCH, Vector2i(1, 2), 0)
	assert_true(result.ok, result.error)
	assert_equal(result.occupied_xy.size(), 16, "eight actual half-tile footprint cells")
	assert_equal(result.use_xy, PackedInt32Array([1, 4]), "result.use_xy")


func test_invalid_floor_and_link_columns_are_refused_before_indexing() -> void:
	"""Malformed snapshots cannot cause out-of-range accesses hidden by a release runtime."""
	_snapshot.floor_height.remove_at(0)
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"INVALID_FLOOR_COLUMNS")
	_snapshot.floor_height.append(0)
	_snapshot.walk_links.append(0)
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"INVALID_WALK_LINK")
	_snapshot.walk_links = PackedInt32Array([0, 999])
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"INVALID_WALK_LINK")
	_snapshot.walk_links = PackedInt32Array([0, 1, 1, 0])
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"DUPLICATE_WALK_LINK")


func test_floor_link_object_and_contact_operation_budgets_are_enforced() -> void:
	"""Corrupt owner images cannot turn one cold UI operation into an unbounded allocation."""
	_layout = Layout.new(1, 2, 35)
	_layout.bind_sources(_owners.read, _owners.is_live, _owners.submit)
	assert_true(_layout.open_room(ROOM).ok, "layout open_room(ROOM).ok")
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"INVALID_FLOOR_COLUMNS")
	_layout = Layout.new(1, 2, 36)
	_layout.bind_sources(_owners.read, _owners.is_live, _owners.submit)
	assert_true(_layout.open_room(ROOM).ok, "layout open_room(ROOM).ok")
	_snapshot.walk_links.resize(36 * 8 + 2)
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"INVALID_WALK_LINK")
	_snapshot.walk_links = PackedInt32Array()
	_snapshot.object_kinds.resize(3)
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"INVALID_OBJECT_COLUMNS")
	_snapshot.object_kinds.clear()
	_snapshot.profiles[SHELF].use_xy.resize(74)
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"FURNITURE_PROFILE_INCOMPLETE")


func test_tiny_grid_cannot_expand_a_single_piece_beyond_the_operation_budget() -> void:
	"""A valid integer pitch alone cannot request millions of catalog footprint cell probes."""
	_snapshot.pitch_units = 1
	_expect_refusal(_layout.preview(ROOM, BENCH, Vector2i(2, 2), 0),
		&"FURNITURE_FOOTPRINT_EXCEEDS_OPERATION_BUDGET")


func test_combined_contact_budget_covers_many_individually_bounded_profiles() -> void:
	"""Many legal-sized profile lists cannot multiply into an unbounded combined validation."""
	_layout = Layout.new(1, 16, 36)
	_layout.bind_sources(_owners.read, _owners.is_live, _owners.submit)
	assert_true(_layout.open_room(ROOM).ok, "open bounded room")
	var contacts: PackedInt32Array = PackedInt32Array()
	for index: int in 36:
		contacts.append_array(PackedInt32Array([0, 1]))
	_snapshot.profiles[SHELF].install_xy = contacts
	_snapshot.profiles[SHELF].use_xy = contacts
	assert_true(_layout.place(ROOM, SHELF, Vector2i(1, 1), 0).ok, "first contact set fits")
	assert_true(_layout.place(ROOM, SHELF, Vector2i(3, 1), 0).ok, "exact combined contact limit fits")
	_expect_refusal(_layout.place(ROOM, SHELF, Vector2i(5, 1), 0), &"LAYOUT_CONTACT_BUDGET")
	assert_equal(_layout.placements(ROOM).size(), 12, "over-budget item was not staged")


func test_reentrant_draft_edits_and_rebinding_are_refused_during_acceptance() -> void:
	"""A coordinator cannot rewrite or discard the draft whose batch is currently being accepted."""
	var draft: Layout.Result = _layout.place(ROOM, SHELF, Vector2i(2, 2), 0)
	_owners.during_submit = _layout.discard_draft.bind(draft.ref)
	assert_true(_layout.confirm_layout(ROOM).ok, "original batch accepted intact")
	_expect_refusal(_owners.reentrant_result, &"SUBMISSION_IN_PROGRESS")
	assert_equal(_layout.placements(ROOM, Layout.STATE_ACCEPTED).size(), 6, "receipt still tracked")
	assert_true(_layout.place(ROOM, SHELF, Vector2i(4, 2), 0).ok, "another valid draft")
	_owners.during_submit = _layout.bind_sources.bind(Callable(), Callable())
	assert_true(_layout.confirm_layout(ROOM).ok, "trusted adapters survive reentrant rebind")
	_expect_refusal(_owners.reentrant_result, &"SUBMISSION_IN_PROGRESS")


func test_rotation_and_translation_check_int64_before_int32_narrowing() -> void:
	"""INT32_MIN contact offsets must not wrap around to a legal opposite-side contact."""
	_snapshot.profiles[SHELF].use_xy = PackedInt32Array([-2147483648, 0])
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 2), &"CELL_COORDINATE_OVERFLOW")
	_snapshot.profiles[SHELF].use_xy = PackedInt32Array([2147483647, 0])
	_expect_refusal(_layout.preview(ROOM, SHELF, Vector2i(2, 2), 0), &"CELL_COORDINATE_OVERFLOW")


func test_empty_confirmation_and_unopened_room_have_explicit_refusals() -> void:
	"""An empty group never becomes vacuous construction success."""
	_expect_refusal(_layout.confirm_layout(ROOM), &"EMPTY_LAYOUT")
	_owners.snapshots[OTHER_ROOM] = _make_room(OTHER_ROOM)
	_owners.live[Vector3i(Layout.DOMAIN_ROOM, OTHER_ROOM.x, OTHER_ROOM.y)] = true
	_expect_refusal(_layout.place(OTHER_ROOM, SHELF, Vector2i(2, 2), 0), &"ROOM_NOT_OPEN")
	assert_equal(_layout.placements(OTHER_ROOM).size(), 0, "layout placements(OTHER_ROOM).size()")
	assert_equal(_layout.project_of(Vector2i(-1, 0)), Layout.NULL_REF, "layout project_of(Vector2i(-1, 0))")

extends "res://test/framework/test_case.gd"
## All dimensions, profiles and support facts in this suite are SYNTHETIC, never a live catalog.

const Space := preload("res://scripts/core/room_space.gd")
const WORLD: Vector2i = Vector2i(0, 1)
const ROOM: Vector2i = Vector2i(1, 2)
const OBJECT: Vector2i = Vector2i(2, 3)


class SyntheticAuthority extends Space.Authority:

	func qualification_error(_domain: Space.Domain, _snapshot: Space.Snapshot, plan: Space.Plan) -> StringName:
		"""Accept only the explicit synthetic fixture profile, not a production measurement claim."""
		for row: int in plan.contacts.profile_id.size():
			if plan.contacts.profile_id[row] != 3 or plan.contacts.profile_revision[row] != 5:
				return &"SYNTHETIC_PROFILE_NOT_QUALIFIED"
		return &""


class MutatingAuthority extends Space.Authority:

	func qualification_error(_domain: Space.Domain, snapshot: Space.Snapshot, plan: Space.Plan) -> StringName:
		"""Try to corrupt the supplied scratch; the validated candidate must remain unchanged."""
		snapshot.volumes.lo_x[0] = -7000
		plan.cuts_xyz.clear()
		plan.volumes.lo_x[0] = -7000
		return &""


var _domain: Space.Domain = null
var _snapshot: Space.Snapshot = null
var _plan: Space.Plan = null


func before_each() -> void:
	"""A dry unit cube reached from a real finished neighboring volume, with support below."""
	_domain = _new_domain()
	_snapshot = Space.Snapshot.new()
	_snapshot.world_ref = WORLD
	_snapshot.revision = 7
	_snapshot.live_refs = PackedInt32Array([0, 1, 1, 2, 2, 3])
	_snapshot.live_revisions = PackedInt64Array([1, 4, 6])
	_world([0, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID)
	_world([-1024, 0, 0, 0, 1024, 1024], Space.SUPPORTED_VOID)
	_world([0, -1024, 0, 1024, 0, 1024], Space.SUPPORT)
	_plan = Space.Plan.new()
	_plan.owner_ref = ROOM
	_plan.owner_revision = 4
	_plan.expected_revision = 7
	_plan.volumes.append(PackedInt32Array([0, 0, 0, 1024, 1024, 1024]), Space.ENVELOPE, 1, ROOM, 4)
	_plan.volumes.append(PackedInt32Array([0, -1024, 0, 1024, 0, 1024]), Space.SUPPORT_REQUIRED, 1, ROOM, 4)
	_plan.cuts_xyz = PackedInt32Array([0, 0, 0])
	_plan.cut_contacts = PackedInt32Array([0])
	_add_contact()


func _new_domain(cells: int = 64, regions: int = 128, checks: int = 10000) -> Space.Domain:
	"""Finite synthetic space includes negative levels and positive support without adopting them."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(WORLD, Vector3i.ZERO, Vector3i(-8, -8, -8), Vector3i(16, 16, 16),
		cells, regions, checks), &"", "domain configured")
	return domain


func _world(box: Array[int], role: int, level: int = 1) -> void:
	"""Append one world-owned synthetic survey fact."""
	assert_true(_snapshot.volumes.append(PackedInt32Array(box), role, level, WORLD, 1), "survey row")


func _add_contact() -> void:
	"""The body envelope stays in finished space; the exact work point touches the cut's near face."""
	var box: PackedInt32Array = PackedInt32Array([-512, 0, 128, 0, 768, 896])
	_plan.contacts.approach.append(box, Space.ENVELOPE, 1, ROOM, 4)
	_plan.contacts.reach.append(box, Space.ENVELOPE, 1, ROOM, 4)
	_plan.contacts.work_xyz = PackedInt32Array([0, 512, 512])
	_plan.contacts.profile_id = PackedInt32Array([3])
	_plan.contacts.profile_revision = PackedInt64Array([5])


func _validate() -> Space.Result:
	"""Run the actual validator with a deliberately synthetic owner qualification."""
	return Space.validate(_domain, _snapshot, _plan, SyntheticAuthority.new())


func _refuses(code: StringName) -> void:
	"""Refusal never carries a partial plan that a caller might accidentally publish."""
	var result: Space.Result = _validate()
	assert_false(result.ok, "refused")
	assert_equal(result.error, code, "specific reason")
	assert_equal(result.candidate, null, "no partial candidate")


func test_exact_paid_cube_yields_only_a_copied_candidate() -> void:
	"""One exact dry cube is not yet a paid cut, a reservation or a finished public route."""
	var result: Space.Result = _validate()
	assert_true(result.ok, "synthetic geometry valid")
	assert_equal(result.candidate.cuts_xyz, PackedInt32Array([0, 0, 0]), "absolute physical origin")
	result.candidate.cuts_xyz[0] = 1024
	assert_equal(_plan.cuts_xyz[0], 0, "result cannot mutate request")
	assert_true(result.checks > 0, "actual geometry checks ran")


func test_unbound_authority_and_missing_profile_never_authorize() -> void:
	"""Complete boxes alone do not prove real support, worker reach, profile or travel qualification."""
	assert_equal(Space.validate(_domain, _snapshot, _plan).error, &"SPACE_AUTHORITY_UNBOUND", "no adapter")
	assert_equal(Space.validate(_domain, _snapshot, _plan, Space.Authority.new()).error,
		&"SPACE_AUTHORITY_UNBOUND", "base adapter refuses")
	_plan.contacts.profile_id[0] = -1
	_refuses(&"SPACE_PROFILE_MISSING")
	_plan.contacts.profile_id[0] = 3
	_plan.contacts.profile_revision[0] = 6
	_refuses(&"SYNTHETIC_PROFILE_NOT_QUALIFIED")


func test_adapter_cannot_mutate_checked_geometry_or_callers() -> void:
	"""The qualification adapter sees isolated bounded copies, never the eventual accepted image."""
	var result: Space.Result = Space.validate(_domain, _snapshot, _plan, MutatingAuthority.new())
	assert_true(result.ok, "fixture returned explicit qualification")
	assert_equal(result.candidate.cuts_xyz.size(), 3, "candidate cubes intact")
	assert_equal(result.candidate.volumes.lo_x[0], 0, "checked candidate intact")
	assert_equal(_snapshot.volumes.lo_x[0], 0, "world snapshot intact")
	assert_equal(_plan.volumes.lo_x[0], 0, "original request intact")


func test_domain_is_immutable_and_signed_datum_is_exact() -> void:
	"""Neither a new project nor a caller editing a descriptor can reset physical conservation keys."""
	assert_equal(_domain.configure(WORLD, Vector3i.ONE, Vector3i.ZERO, Vector3i.ONE, 1, 1, 1),
		&"SPACE_DOMAIN_ALREADY_REGISTERED", "cannot rebase existing map")
	var copy: Dictionary = _domain.descriptor()
	copy.bounds_u[0] = 99
	assert_equal(_domain.descriptor().bounds_u[0], -8192, "descriptor isolated")
	var shifted: Space.Domain = Space.Domain.new()
	assert_equal(shifted.configure(WORLD, Vector3i(128, -256, 64), Vector3i(-2, -2, -2),
		Vector3i(4, 4, 4), 16, 32, 1000), &"", "nonzero signed datum")
	assert_equal(Space.quantum_box(shifted, Vector3i(-896, -1280, -960)),
		PackedInt32Array([-896, -1280, -960, 128, -256, 64]), "negative absolute cube")
	assert_true(Space.quantum_box(shifted, Vector3i(-897, -1280, -960)).is_empty(), "no rounding")


func test_domain_capacity_and_int32_far_corner_refuse() -> void:
	"""Extents are checked with int64 intermediates before any Vector3i or packed narrowing."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(WORLD, Vector3i(2147483647, 0, 0), Vector3i.ZERO, Vector3i.ONE,
		1, 1, 1), &"SPACE_DOMAIN_INVALID", "far corner overflow")
	assert_equal(domain.configure(WORLD, Vector3i.ZERO, Vector3i.ZERO, Vector3i.ONE,
		16385, 1, 1), &"SPACE_DOMAIN_INVALID", "cold capacity bounded")
	assert_true(Space.quantum_box(_domain, Vector3i(2147483647, 0, 0)).is_empty(), "cube overflow refused")
	assert_true(Space.quantum_box(_domain, Vector3i(-9216, 0, 0)).is_empty(), "outside map")


func test_fine_plan_cannot_charge_a_larger_rounded_cube() -> void:
	"""A quarter-metre boundary does not silently excavate the rest of its economic cube."""
	_plan.volumes.hi_x[0] = 768
	_refuses(&"SPACE_PARTIAL_QUANTUM")


func test_plan_cannot_gain_unpriced_void_past_its_cubes() -> void:
	"""A perfect paid cube does not cover an extra unpriced strip of room."""
	_plan.volumes.hi_x[0] = 1280
	_refuses(&"SPACE_UNPRICED_VOLUME")


func test_offset_and_duplicate_cube_keys_are_rejected() -> void:
	"""Non-lattice keys and duplicate charges cannot enter the physical history."""
	_plan.cuts_xyz[0] = 1
	_refuses(&"SPACE_CUT_DATUM")
	_plan.cuts_xyz = PackedInt32Array([0, 0, 0, 0, 0, 0])
	_plan.cut_contacts = PackedInt32Array([0, 0])
	_refuses(&"SPACE_CUT_NONCANONICAL")


func test_completed_void_can_be_reused_but_never_dug_for_new_output() -> void:
	"""Geometry distinguishes existing empty space from actual changed-solid work."""
	_snapshot.volumes.role[0] = Space.SUPPORTED_VOID
	_refuses(&"SPACE_CUT_NOT_DRY_SOLID")
	_plan.cuts_xyz.clear()
	_plan.cut_contacts.clear()
	assert_true(_validate().ok, "existing void needs zero new cut cubes")


func test_survey_coverage_is_union_not_bounding_box_or_sample_points() -> void:
	"""Two adjoining slabs can cover a cube; a one-unit hidden gap cannot."""
	_snapshot.volumes.hi_x[0] = 512
	_world([512, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID)
	assert_true(_validate().ok, "exact union covers cube")
	_snapshot.volumes.lo_x[3] = 513
	_refuses(&"SPACE_CUT_NOT_DRY_SOLID")


func test_hidden_interior_hole_is_not_paid_solid_coverage() -> void:
	"""Coverage checks every volume, not just corners or a centre sample."""
	_snapshot.volumes.hi_x[0] = 400
	_world([401, 0, 0, 1024, 1024, 1024], Space.DRY_SOLID)
	_world([400, 0, 0, 401, 300, 1024], Space.DRY_SOLID)
	_world([400, 301, 0, 401, 1024, 1024], Space.DRY_SOLID)
	_world([400, 300, 0, 401, 301, 200], Space.DRY_SOLID)
	_world([400, 300, 201, 401, 301, 1024], Space.DRY_SOLID)
	_refuses(&"SPACE_CUT_NOT_DRY_SOLID")


func test_contradictory_solid_and_void_survey_fails_closed() -> void:
	"""A source owner must resolve contradictory physical state, not rely on input ordering."""
	_world([256, 256, 256, 512, 512, 512], Space.SUPPORTED_VOID)
	_refuses(&"SPACE_SURVEY_CONTRADICTION")


func test_stacked_horizontal_overlap_is_allowed_when_heights_clear() -> void:
	"""A room above the planned cube must not be blocked merely by shared X/Z."""
	_world([0, 2048, 0, 1024, 3072, 1024], Space.OBSTACLE, 2)
	assert_true(_validate().ok, "vertical separation respected")


func test_intermediate_level_obstruction_reports_actual_owner_and_level() -> void:
	"""All 3D intersections matter, even if an obstruction's nominal level differs."""
	_snapshot.volumes.append(PackedInt32Array([512, 400, 512, 600, 500, 600]), Space.OBSTACLE, 7, OBJECT, 6)
	var result: Space.Result = _validate()
	assert_equal(result.error, &"SPACE_OBSTRUCTED", "intervening item blocks")
	assert_equal(result.conflict_ref, OBJECT, "full obstructing reference")
	assert_equal(result.conflict_revision, 6, "object revision")
	assert_equal(result.level, 7, "actual affected level for UI")


func test_water_resources_occupants_pending_work_and_protected_landings_block() -> void:
	"""No collision category is silently ignored because its owner is not a completed furniture item."""
	for role: int in [Space.OBSTACLE, Space.PROTECTED_ACCESS, Space.SUPPORT, Space.WATER,
			Space.RESOURCE, Space.OCCUPANT, Space.UNFINISHED]:
		var snapshot: Space.Snapshot = _snapshot.copy()
		snapshot.volumes.append(PackedInt32Array([1, 1, 1, 2, 2, 2]), role, 5, OBJECT, 6)
		var result: Space.Result = Space.validate(_domain, snapshot, _plan, SyntheticAuthority.new())
		assert_equal(result.error, &"SPACE_OBSTRUCTED", "protected category %d" % role)


func test_opening_requires_exact_target_and_does_not_excuse_overlapping_furniture() -> void:
	"""Permission to open one wall does not delete another owner's item in the same place."""
	var opening: PackedInt32Array = PackedInt32Array([0, 0, 0, 64, 1024, 1024])
	_snapshot.volumes.append(opening, Space.OPENABLE_SHELL, 1, OBJECT, 6)
	_refuses(&"SPACE_OBSTRUCTED")
	_plan.volumes.append(opening, Space.OPENING, 1, OBJECT, 6)
	assert_true(_validate().ok, "exact named opening accepted")
	_world([0, 0, 0, 32, 32, 32], Space.OBSTACLE)
	_refuses(&"SPACE_OBSTRUCTED")


func test_opening_cannot_claim_extra_wall_outside_actual_project() -> void:
	"""No broad opening authorization can conceal collateral demolition."""
	var shell: PackedInt32Array = PackedInt32Array([0, 0, 0, 2048, 1024, 1024])
	_snapshot.volumes.append(shell, Space.OPENABLE_SHELL, 1, OBJECT, 6)
	_plan.volumes.append(shell, Space.OPENING, 1, OBJECT, 6)
	_refuses(&"SPACE_OPENING_OUTSIDE_PLAN")


func test_support_must_cover_required_actual_extent() -> void:
	"""One valid support point cannot certify the entire room or spiral central support region."""
	_snapshot.volumes.hi_x[2] = 1023
	_refuses(&"SPACE_SUPPORT_MISSING")


func test_stale_snapshot_room_generation_and_obstruction_revision_refuse() -> void:
	"""A reused slot or changed room/site cannot inherit a previously drawn plan."""
	_plan.expected_revision = 6
	_refuses(&"SPACE_SNAPSHOT_STALE")
	_plan.expected_revision = 7
	_plan.owner_ref = Vector2i(1, 1)
	_refuses(&"SPACE_OWNER_STALE")
	_plan.owner_ref = ROOM
	_snapshot.volumes.owner_revision[0] = 2
	_refuses(&"SPACE_OWNER_STALE")


func test_unknown_or_unfinished_worker_approach_is_not_a_construction_route() -> void:
	"""Workers cannot start inside the room they are about to excavate."""
	_snapshot.volumes.role[1] = Space.UNFINISHED
	_refuses(&"SPACE_WORK_APPROACH_UNFINISHED")


func test_work_point_belongs_to_actual_cut_face_and_authored_reach() -> void:
	"""A geometrically nearby contact in another cube is not a valid work face."""
	_plan.contacts.work_xyz[0] = 512
	_refuses(&"SPACE_WORK_FACE")
	_plan.contacts.work_xyz[0] = 0
	_plan.contacts.reach.hi_x[0] = -1
	_refuses(&"SPACE_WORK_REACH")


func test_later_obstacle_at_worker_approach_blocks_the_whole_plan() -> void:
	"""A valid empty room shape does not override a blocked installer/digger body envelope."""
	_world([-128, 128, 256, -64, 256, 512], Space.OBSTACLE)
	_refuses(&"SPACE_OBSTRUCTED")


func test_future_opening_does_not_make_current_worker_approach_empty() -> void:
	"""A worker cannot stand inside a wall merely because the same plan intends to open it later."""
	var shell: PackedInt32Array = PackedInt32Array([-128, 128, 256, -64, 256, 512])
	_snapshot.volumes.append(shell, Space.OPENABLE_SHELL, 1, OBJECT, 6)
	_plan.volumes.append(shell, Space.OPENING, 1, OBJECT, 6)
	_plan.volumes.append(shell, Space.ENVELOPE, 1, ROOM, 4)
	_refuses(&"SPACE_OBSTRUCTED")


func test_malformed_columns_and_missing_contact_are_refused_before_indexing() -> void:
	"""Finite malformed snapshots produce a result rather than engine diagnostics or a partial plan."""
	_snapshot.volumes.hi_y.clear()
	_refuses(&"SPACE_FORMAT")
	before_each()
	_plan.contacts.work_xyz.clear()
	_refuses(&"SPACE_CONTACT_FORMAT")


func test_operation_and_region_budgets_leave_request_unchanged() -> void:
	"""Even adversarial fragmented input has a deterministic refusal and bounded cold work."""
	var before: PackedInt32Array = _plan.cuts_xyz.duplicate()
	_domain = _new_domain(64, 128, 1)
	_refuses(&"SPACE_OPERATION_BUDGET")
	assert_equal(_plan.cuts_xyz, before, "request preserved")
	_domain = _new_domain(64, 7, 10000)
	_refuses(&"SPACE_REGION_CAPACITY")


func test_face_tangency_is_not_intersection_and_integer_extremes_are_ordered() -> void:
	"""No hidden epsilon or float key changes a boundary decision."""
	assert_false(Space.overlaps(PackedInt32Array([0, 0, 0, 1, 1, 1]),
		PackedInt32Array([1, 0, 0, 2, 1, 1])), "touching boxes")
	assert_true(Space.point_less(Vector3i(-2147483648, 0, 0), Vector3i(2147483647, 0, 0)), "signed ordering")
	assert_false(Space.valid_box(PackedInt32Array([0, 0, 0, 0, 1, 1])), "zero width")
	assert_false(Space.valid_ref(Space.NULL_REF), "null owner")
	assert_false(Space.int32(2147483648), "int32 overflow")


func test_public_box_helpers_refuse_malformed_and_narrowing_inputs() -> void:
	"""Malformed previews cannot index absent coordinates or wrap oversized role/level values."""
	var box: PackedInt32Array = PackedInt32Array([0, 0, 0, 1, 1, 1])
	assert_false(Space.overlaps(PackedInt32Array(), box), "malformed overlap")
	assert_true(Space.intersection(PackedInt32Array(), box).is_empty(), "malformed intersection")
	assert_true(Space.intersection(box, PackedInt32Array([1, 0, 0, 2, 1, 1])).is_empty(), "tangent intersection")
	var rows: Space.Volumes = Space.Volumes.new()
	assert_false(rows.append(box, 4294967296, 0, WORLD, 1), "role narrowing refused")
	assert_false(rows.append(box, Space.ENVELOPE, 4294967296, WORLD, 1), "level narrowing refused")
	assert_equal(rows.role.size(), 0, "no partially appended row")

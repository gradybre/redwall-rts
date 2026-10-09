extends "res://test/framework/test_case.gd"
## SYNTHETIC two-height fixtures exercise transformations, never production stair or body dimensions.

const Connectors := preload("res://scripts/core/room_connectors.gd")
const Space := preload("res://scripts/core/room_space.gd")
const WORLD: Vector2i = Vector2i(0, 1)
const ROOM: Vector2i = Vector2i(1, 2)
const SHELL: Vector2i = Vector2i(2, 3)


class SyntheticAuthority extends Space.Authority:

	func qualification_error(_domain: Space.Domain, _snapshot: Space.Snapshot, _plan: Space.Plan) -> StringName:
		"""Deliberate synthetic evidence; this class is absent from runtime and grants no production profile."""
		return &""


var _domain: Space.Domain = null
var _definition: Connectors.Definition = null
var _placement: Connectors.Placement = null


func before_each() -> void:
	"""A fixed two-height chamber with distinct landings and a neighboring safe work approach."""
	_domain = Space.Domain.new()
	assert_equal(_domain.configure(WORLD, Vector3i.ZERO, Vector3i(-8, -8, -8), Vector3i(16, 16, 16),
		64, 128, 20000), &"", "domain")
	_definition = Connectors.Definition.new()
	_definition.key = &"synthetic.connector"
	_definition.revision = 4
	_definition.family = Connectors.EARTH_TIMBER
	_definition.allowed_rotations = 15
	_definition.start = Vector3i(512, 0, 512)
	_definition.end = Vector3i(512, 1024, 1536)
	_definition.start_level_offset = 0
	_definition.end_level_offset = 1
	_local([0, 0, 0, 1024, 2048, 2048], Space.ENVELOPE, 0)
	_local([0, 0, 0, 1024, 1024, 1024], Space.LANDING, 0)
	_local([0, 1024, 1024, 1024, 2048, 2048], Space.LANDING, 1)
	_local([0, -1024, 0, 1024, 0, 2048], Space.SUPPORT_REQUIRED, 0)
	_geometry_contacts()
	_placement = Connectors.Placement.new()
	_placement.owner_ref = ROOM
	_placement.owner_revision = 4
	_placement.expected_revision = 7
	_placement.level_base = 1
	_placement.start_floor_u = 0
	_placement.end_floor_u = 1024
	_placement.endpoint_refs = PackedInt32Array([1, 2, 1, 2])
	_placement.endpoint_revisions = PackedInt64Array([4, 4])


func _local(box: Array[int], role: int, level: int) -> void:
	"""Local catalog geometry carries no borrowed live room identity."""
	assert_true(_definition.geometry.volumes.append(PackedInt32Array(box), role, level, Space.NULL_REF, 0), "local row")


func _geometry_contacts() -> void:
	"""Each exact cube has its own reachable synthetic face; contact indices survive sorting."""
	var p: Space.Plan = _definition.geometry
	for y: int in [0, 1024]:
		for z: int in [0, 1024]:
			var row: int = p.cut_contacts.size()
			p.cuts_xyz.append_array(PackedInt32Array([0, y, z]))
			p.cut_contacts.append(row)
			var box: PackedInt32Array = PackedInt32Array([-512, y, z + 128, 0, y + 768, z + 896])
			p.contacts.approach.append(box, Space.ENVELOPE, 0, Space.NULL_REF, 0)
			p.contacts.reach.append(box, Space.ENVELOPE, 0, Space.NULL_REF, 0)
			p.contacts.work_xyz.append_array(PackedInt32Array([0, y + 512, z + 512]))
			p.contacts.profile_id.append(3)
			p.contacts.profile_revision.append(5)


func _place() -> Connectors.Result:
	"""Run the actual fixed-piece transform without any construction or profile authority."""
	return Connectors.place(_domain, _definition, _placement)


func _refuses(code: StringName) -> void:
	"""A failed transform cannot leak a partially placed stair or its cut list."""
	var result: Connectors.Result = _place()
	assert_false(result.ok, "refused")
	assert_equal(result.error, code, "specific refusal")
	assert_equal(result.plan, null, "no partial candidate")


func _snapshot() -> Space.Snapshot:
	"""Actual finite fixture survey includes the full wall volume and both owner-authored floor heights."""
	var snapshot: Space.Snapshot = Space.Snapshot.new()
	snapshot.world_ref = WORLD
	snapshot.revision = 7
	snapshot.live_refs = PackedInt32Array([0, 1, 1, 2, 2, 3])
	snapshot.live_revisions = PackedInt64Array([1, 4, 8])
	snapshot.volumes.append(PackedInt32Array([0, 0, 0, 1024, 2048, 2048]), Space.DRY_SOLID, 1, WORLD, 1)
	snapshot.volumes.append(PackedInt32Array([-1024, 0, 0, 0, 2048, 2048]), Space.SUPPORTED_VOID, 1, WORLD, 1)
	snapshot.volumes.append(PackedInt32Array([0, -1024, 0, 1024, 0, 2048]), Space.SUPPORT, 1, WORLD, 1)
	snapshot.volumes.append(PackedInt32Array([0, 0, 0, 1024, 2048, 1024]), Space.FLOOR_DATUM, 1, ROOM, 4)
	snapshot.volumes.append(PackedInt32Array([0, 1024, 1024, 1024, 2048, 2048]), Space.FLOOR_DATUM, 2, ROOM, 4)
	return snapshot


func test_all_five_families_use_fixed_geometry_without_invented_defaults() -> void:
	"""Every approved family is expressible; these shared synthetic boxes are not a finished catalog."""
	assert_equal(Connectors.FAMILY_KEYS.size(), 5, "five families")
	for family: int in Connectors.FAMILY_COUNT:
		_definition.family = family
		var result: Connectors.Result = _place()
		assert_true(result.ok, "family %d transforms" % family)
		assert_equal(result.plan.catalog_key, &"synthetic.connector", "content identity retained")
		assert_equal(result.plan.catalog_revision, 4, "content revision retained")
		assert_equal(result.plan.volumes.box_at(0), _definition.geometry.volumes.box_at(0), "fixed dimensions")
	_definition.family = Connectors.FAMILY_COUNT
	_refuses(&"CONNECTOR_CATALOG_MISSING")


func test_transformed_plan_passes_full_space_geometry_but_requires_owner_qualification() -> void:
	"""A placed preview is not a route, paid work, or an installed connector."""
	var plan: Space.Plan = _place().plan
	assert_true(Space.validate(_domain, _snapshot(), plan, SyntheticAuthority.new()).ok, "synthetic geometry passes")
	assert_equal(Space.validate(_domain, _snapshot(), plan).error, &"SPACE_AUTHORITY_UNBOUND", "runtime qualification mandatory")


func test_quarter_turn_rotates_full_boxes_work_contacts_landings_and_cube_minima() -> void:
	"""A rotated cube's minimum is not simply its rotated original minimum."""
	_placement.rotation = 1
	var result: Connectors.Result = _place()
	assert_true(result.ok, "quarter turn")
	assert_equal(result.plan.volumes.box_at(0), PackedInt32Array([-2048, 0, 0, 0, 2048, 1024]), "full envelope rotated")
	assert_equal(result.plan.endpoints_xyz, PackedInt32Array([-512, 0, 512, -1536, 1024, 512]), "both floor contacts rotate")
	assert_equal(result.plan.cuts_xyz, PackedInt32Array([-2048, 0, 0, -2048, 1024, 0, -1024, 0, 0, -1024, 1024, 0]),
		"canonical absolute cube origins")
	assert_equal(result.plan.cut_contacts, PackedInt32Array([1, 3, 0, 2]), "cube face bindings kept while sorting")
	assert_equal(result.plan.contacts.work_xyz.slice(3, 6), PackedInt32Array([-1536, 512, 0]), "work point rotated")
	assert_equal(_definition.geometry.cuts_xyz[0], 0, "catalog not changed")


func test_all_rotations_preserve_volume_and_actual_rise() -> void:
	"""Quarter turns alter neither room volume nor stair rise."""
	for rotation: int in 4:
		_placement.rotation = rotation
		var result: Connectors.Result = _place()
		assert_true(result.ok, "rotation")
		var box: PackedInt32Array = result.plan.volumes.box_at(0)
		assert_equal((box[3] - box[0]) * (box[4] - box[1]) * (box[5] - box[2]), 4294967296, "same exact volume")
		assert_equal(result.plan.endpoints_xyz[4] - result.plan.endpoints_xyz[1], 1024, "unchanged rise")


func test_height_mismatch_is_refusal_never_resizing_or_moving_a_floor() -> void:
	"""The caller must choose a matching variant; no scaling repairs an incompatible room pair."""
	_placement.end_floor_u = 1025
	_refuses(&"CONNECTOR_HEIGHT_MISMATCH")
	assert_equal(_definition.end.y, 1024, "authored rise untouched")


func test_rotation_mask_and_missing_catalog_identity_fail_closed() -> void:
	"""No unadvertised rotation or unnamed catalog entry is silently accepted."""
	_definition.allowed_rotations = 1
	_placement.rotation = 1
	_refuses(&"CONNECTOR_ROTATION")
	_placement.rotation = 0
	_definition.key = &""
	_refuses(&"CONNECTOR_CATALOG_MISSING")


func test_exact_translation_preserves_datum_and_floor_bindings() -> void:
	"""An aligned translated piece names different absolute cubes without changing its recipe geometry."""
	_placement.origin = Vector3i(2048, -1024, 3072)
	_placement.start_floor_u = -1024
	_placement.end_floor_u = 0
	var result: Connectors.Result = _place()
	assert_true(result.ok, "aligned placement")
	assert_equal(result.plan.cuts_xyz.slice(0, 3), PackedInt32Array([2048, -1024, 3072]), "absolute origin")
	_placement.origin.x += 1
	_refuses(&"CONNECTOR_CUT_DATUM")


func test_int32_minimum_negation_and_translation_overflow_refuse() -> void:
	"""The transform cannot wrap and place an invalid stair across the other side of the world."""
	_placement.rotation = 2
	assert_true(Connectors.transform_box(PackedInt32Array([-2147483648, 0, 0, -2147483000, 1, 1]),
		_placement).is_empty(), "negated minimum is checked in int64")
	_placement.rotation = 0
	_placement.origin.x = 2147483647
	_refuses(&"CONNECTOR_OVERFLOW")


func test_level_base_cannot_wrap_before_transform() -> void:
	"""Scalar level inputs are checked before summing or storing into packed int32 columns."""
	_placement.level_base = 4294967296
	_refuses(&"CONNECTOR_OVERFLOW")
	_placement.level_base = 2147483647
	_refuses(&"CONNECTOR_OVERFLOW")


func test_landing_and_profile_are_required_catalog_fields() -> void:
	"""A generic family name never supplies missing actual landing or body geometry."""
	_definition.geometry.volumes.role[2] = Space.ENVELOPE
	_refuses(&"CONNECTOR_LANDING_MISSING")
	_definition.geometry.volumes.role[2] = Space.LANDING
	_definition.geometry.contacts.profile_id[0] = -1
	_refuses(&"CONNECTOR_PROFILE_MISSING")


func test_opening_target_is_bound_per_actual_shell_not_catalog_placeholder() -> void:
	"""Only placement can name the specific wall/floor generation a blueprint intends to open."""
	_local([0, 0, 0, 64, 1024, 1024], Space.OPENING, 0)
	_refuses(&"CONNECTOR_OPENING_UNBOUND")
	_placement.opening_refs = PackedInt32Array([2, 3])
	_placement.opening_revisions = PackedInt64Array([8])
	var result: Connectors.Result = _place()
	assert_true(result.ok, "target supplied")
	assert_equal(result.plan.volumes.ref_at(4), SHELL, "whole target reference")
	assert_equal(result.plan.volumes.owner_revision[4], 8, "target revision")
	assert_equal(result.plan.volumes.ref_at(0), ROOM, "other regions retain project owner")


func test_endpoint_floor_change_or_generation_reuse_is_rejected_after_preview() -> void:
	"""Placement input heights are rechecked against actual owner floor data at validation."""
	var plan: Space.Plan = _place().plan
	var snapshot: Space.Snapshot = _snapshot()
	snapshot.volumes.lo_y[4] = 1025
	assert_equal(Space.validate(_domain, snapshot, plan, SyntheticAuthority.new()).error,
		&"SPACE_ENDPOINT_HEIGHT", "actual floor mismatch")
	snapshot = _snapshot()
	plan.endpoint_refs[3] = 1
	assert_equal(Space.validate(_domain, snapshot, plan, SyntheticAuthority.new()).error,
		&"SPACE_ENDPOINT_STALE", "reused floor owner")


func test_split_level_same_level_id_does_not_collapse_two_actual_heights() -> void:
	"""Short stairs can join distinct elevations inside one main level, with actual floor evidence."""
	_definition.end_level_offset = 0
	_definition.geometry.volumes.level[2] = 0
	var result: Connectors.Result = _place()
	assert_true(result.ok, "same nominal level")
	assert_equal(result.plan.endpoint_levels, PackedInt32Array([1, 1]), "same level recorded")
	var snapshot: Space.Snapshot = _snapshot()
	snapshot.volumes.level[4] = 1
	assert_true(Space.validate(_domain, snapshot, result.plan, SyntheticAuthority.new()).ok, "different real heights retained")


func test_internal_post_cannot_be_hidden_inside_a_spiral_landing() -> void:
	"""Central supports and tight turns use real solids, not a spiral-family shortcut."""
	_definition.family = Connectors.SPIRAL
	_local([400, 0, 400, 600, 1024, 600], Space.SOLID, 0)
	var plan: Space.Plan = _place().plan
	assert_equal(Space.validate(_domain, _snapshot(), plan, SyntheticAuthority.new()).error,
		&"SPACE_INTERNAL_CLEARANCE", "post obstructs its own landing")


func test_obstacle_on_intervening_level_blocks_entire_connection() -> void:
	"""Two clear endpoints do not prove the shaft between them is clear."""
	var snapshot: Space.Snapshot = _snapshot()
	snapshot.volumes.append(PackedInt32Array([128, 1100, 500, 384, 1200, 700]), Space.OBSTACLE, 9, SHELL, 8)
	var result: Space.Result = Space.validate(_domain, snapshot, _place().plan, SyntheticAuthority.new())
	assert_equal(result.error, &"SPACE_OBSTRUCTED", "intermediate obstruction")
	assert_equal(result.level, 9, "reports real conflicting level")


func test_duplicate_cubes_and_malformed_tables_have_no_partial_result() -> void:
	"""Adversarial catalog records are refused before producing plausible paid work."""
	_definition.geometry.cuts_xyz[5] = 0
	_refuses(&"CONNECTOR_CUT_DATUM")
	_definition.geometry.cuts_xyz[5] = 1024
	_definition.geometry.volumes.hi_y.clear()
	_refuses(&"CONNECTOR_FORMAT")

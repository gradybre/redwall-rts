extends "res://test/framework/test_case.gd"
## SYNTHETIC authored content. Values below are test fixtures, never production connector dimensions.

const Geometry := preload("res://scripts/core/connector_geometry.gd")
const Connectors := preload("res://scripts/core/room_connectors.gd")
const Space := preload("res://scripts/core/room_space.gd")


static func limits() -> Geometry.Limits:
	"""Explicit small cold-operation budget for a synthetic fixed-content fixture."""
	var result: Geometry.Limits = Geometry.Limits.new()
	result.parts = 32
	result.points = 256
	result.triangles = 512
	result.regions = 128
	return result


static func fixture(family: int) -> Geometry.Row:
	"""All five approved shapes have real mesh parts; no fixture has movement or economy permission."""
	var row: Geometry.Row = Geometry.Row.new()
	row.definition = Connectors.Definition.new()
	row.definition.key = &"synthetic.fixed.connector"
	row.definition.revision = 7
	row.definition.family = family
	row.definition.allowed_rotations = 15
	row.definition.start = Vector3i(0, 0, -1024)
	row.definition.end = Vector3i(0, 1024, 2048)
	row.definition.end_level_offset = 1
	row.material_period_u = PackedInt32Array([1024, 512])
	_contract(row.definition.geometry)
	match family:
		Connectors.EARTH_TIMBER, Connectors.STONE:
			_box(row.parts, Geometry.TREAD, Vector3i(-512, 256, 0), Vector3i(512, 256, 512), 128)
			_box(row.parts, Geometry.RISER, Vector3i(-512, 256, -64), Vector3i(512, 256, 0), 256)
			_box(row.parts, Geometry.RAIL, Vector3i(-640, 1280, 0), Vector3i(-576, 1280, 2048), 64)
		Connectors.RAMP:
			_box(row.parts, Geometry.RAMP_DECK, Vector3i(-512, 0, 0), Vector3i(512, 1024, 2048), 128)
			_box(row.parts, Geometry.RAIL, Vector3i(-640, 1024, 0), Vector3i(-576, 2048, 2048), 64)
		Connectors.SPIRAL:
			_spiral(row.parts)
		Connectors.LADDER_HATCH:
			_ladder(row.parts)
	return row


static func _contract(plan: Space.Plan) -> void:
	"""Complete local volume/contact metadata, labeled synthetic rather than a measured profile."""
	plan.volumes.append(PackedInt32Array([-8192, -4096, -8192, 8192, 8192, 8192]), Space.ENVELOPE, 0, Space.NULL_REF, 0)
	plan.volumes.append(PackedInt32Array([-1024, 0, -2048, 1024, 2048, 0]), Space.LANDING, 0, Space.NULL_REF, 0)
	plan.volumes.append(PackedInt32Array([-1024, 1024, 1024, 1024, 3072, 3072]), Space.LANDING, 1, Space.NULL_REF, 0)
	plan.volumes.append(PackedInt32Array([-2048, -2048, -2048, 2048, -1024, 4096]), Space.SUPPORT_REQUIRED, 0, Space.NULL_REF, 0)
	plan.volumes.append(PackedInt32Array([-1024, 0, -1024, 1024, 2048, -512]), Space.OPENING, 0, Space.NULL_REF, 0)
	var contact: PackedInt32Array = PackedInt32Array([-2048, 0, -2048, -1024, 1024, -1024])
	plan.contacts.approach.append(contact, Space.ENVELOPE, 0, Space.NULL_REF, 0)
	plan.contacts.reach.append(contact, Space.ENVELOPE, 0, Space.NULL_REF, 0)
	plan.contacts.work_xyz = PackedInt32Array([-1024, 512, -1024])
	plan.contacts.profile_id = PackedInt32Array([777])
	plan.contacts.profile_revision = PackedInt64Array([9])
	plan.cuts_xyz = PackedInt32Array([0, 0, 0])
	plan.cut_contacts = PackedInt32Array([0])


static func _box(parts: Geometry.Parts, kind: int, low: Vector3i, high: Vector3i, depth: int, hinge: int = -1) -> void:
	"""A quadrilateral's Y can slope along Z; its integer corners are the complete authored profile."""
	part(parts, kind, PackedInt32Array([low.x, low.y, low.z, low.x, high.y, high.z,
		high.x, high.y, high.z, high.x, low.y, low.z]), depth, hinge)


static func part(parts: Geometry.Parts, kind: int, top: PackedInt32Array, depth: int, hinge: int = -1) -> void:
	"""Append one complete synthetic packed row without a dynamic per-part entity."""
	parts.top_xyz.append_array(top)
	@warning_ignore("integer_division") var count: int = parts.top_xyz.size() / 3
	parts.offsets.append(count)
	parts.depth_u.append(depth)
	parts.kind.append(kind)
	parts.level.append(0)
	parts.materials.append_array(PackedInt32Array([0, 1, 1]))
	parts.hinge_edge.append(hinge)


static func _spiral(parts: Geometry.Parts) -> void:
	"""Three authored ring-sector treads turn around a physically present central post."""
	var polygon: PackedInt32Array = PackedInt32Array([512, 0, 1536, 0, 1024, 1024, 384, 384])
	for step: int in 3:
		var top: PackedInt32Array = PackedInt32Array()
		for corner: int in 4:
			var x: int = polygon[corner * 2]
			var z: int = polygon[corner * 2 + 1]
			if step == 1:
				var saved: int = x
				x = -z
				z = saved
			elif step == 2:
				x = -x
				z = -z
			top.append_array(PackedInt32Array([x, (step + 1) * 256, z]))
		part(parts, Geometry.TREAD, top, 64)
	_box(parts, Geometry.POST, Vector3i(-256, 1280, -256), Vector3i(256, 1280, 256), 1536)
	_box(parts, Geometry.RAIL, Vector3i(1792, 1536, -1792), Vector3i(1856, 1536, 1792), 64)


static func _ladder(parts: Geometry.Parts) -> void:
	"""Two actual rails, authored rungs and a fixed upward-opening hatch; no grip permission."""
	_box(parts, Geometry.LADDER_RAIL, Vector3i(-512, 1280, -64), Vector3i(-448, 1280, 64), 1536)
	_box(parts, Geometry.LADDER_RAIL, Vector3i(448, 1280, -64), Vector3i(512, 1280, 64), 1536)
	for height: int in [0, 256, 512, 768, 1024]:
		_box(parts, Geometry.RUNG, Vector3i(-448, height, -32), Vector3i(448, height, 32), 64)
	_box(parts, Geometry.HATCH, Vector3i(-512, 1024, -512), Vector3i(512, 1024, 512), 64, 0)


func test_every_approved_family_compiles_actual_parts_and_full_solid_boxes() -> void:
	"""All five families are represented; a family label cannot stand in for actual complete geometry."""
	for family: int in Connectors.FAMILY_COUNT:
		var row: Geometry.Row = fixture(family)
		var before: int = row.definition.geometry.volumes.role.size()
		var result: Geometry.Result = Geometry.compile(row, limits())
		assert_true(result.ok, "family %d: %s" % [family, result.error])
		assert_equal(result.compiled.definition.geometry.volumes.role.count(Space.SOLID), row.parts.kind.size(), "one complete physical enclosure per part")
		assert_equal(row.definition.geometry.volumes.role.size(), before, "input contract unchanged")
		assert_equal(result.compiled.triangle_xyz.size(), result.compiled.triangle_material.size() * 9, "complete triangles")
		assert_equal(result.compiled.definition.geometry.cuts_xyz, row.definition.geometry.cuts_xyz, "no extra paid cubes")


func test_ramp_top_is_sloped_and_texture_surface_geometry_is_exact() -> void:
	"""A ramp is not replaced by a flat bounding box or automatically resized to its landings."""
	var result: Geometry.Result = Geometry.compile(fixture(Connectors.RAMP), limits())
	var vertices: PackedInt32Array = result.compiled.triangle_xyz
	assert_equal(vertices.slice(0, 9), PackedInt32Array([-512, 0, 0, -512, 1024, 2048, 512, 1024, 2048]), "authored sloping triangle")
	assert_equal(result.compiled.definition.end, Vector3i(0, 1024, 2048), "exact authored rise")


func test_reversed_loop_winding_still_produces_outward_top_normals() -> void:
	"""Input loop orientation does not flip closed material surfaces inward."""
	var row: Geometry.Row = fixture(Connectors.STONE)
	for corner: int in 2:
		for axis: int in 3:
			var at: int = corner * 3 + axis
			var other: int = (3 - corner) * 3 + axis
			var saved: int = row.parts.top_xyz[at]
			row.parts.top_xyz[at] = row.parts.top_xyz[other]
			row.parts.top_xyz[other] = saved
	var result: Geometry.Result = Geometry.compile(row, limits())
	assert_true(result.ok, "reversed input")
	var p: PackedInt32Array = result.compiled.triangle_xyz
	var a: Vector3i = Vector3i(p[0], p[1], p[2])
	var b: Vector3i = Vector3i(p[3], p[4], p[5])
	var c: Vector3i = Vector3i(p[6], p[7], p[8])
	assert_true(Geometry._cross(b - a, c - a)[1] > 0, "top points upward")


func test_nonplanar_ramp_and_concave_tread_refuse_without_partial_candidate() -> void:
	"""Malformed clipping polygons never produce a visually filled but physically different room surface."""
	var row: Geometry.Row = fixture(Connectors.RAMP)
	row.parts.top_xyz[7] += 1
	_refuses(row, &"CONNECTOR_PART_NONPLANAR")
	row = fixture(Connectors.STONE)
	row.parts.top_xyz[6] = -256
	row.parts.top_xyz[8] = 128
	_refuses(row, &"CONNECTOR_PART_NONCONVEX")


func test_coordinate_and_top_depth_overflow_refuse_before_narrowing() -> void:
	"""Extreme packed coordinates and vertical extrusion cannot wrap into valid local geometry."""
	var row: Geometry.Row = fixture(Connectors.STONE)
	row.parts.top_xyz[0] = -2147483648
	_refuses(row, &"CONNECTOR_GEOMETRY_OVERFLOW")
	row = fixture(Connectors.STONE)
	row.parts.depth_u[0] = 2147483647
	_refuses(row, &"CONNECTOR_PART_THICKNESS")
	row = fixture(Connectors.STONE)
	row.definition.end_level_offset = 9223372036854775807
	_refuses(row, &"CONNECTOR_GEOMETRY_ENDPOINT")


func test_finite_triangle_and_region_budgets_refuse_whole_operation() -> void:
	"""A later part hitting capacity cannot publish the already-built earlier tread."""
	var row: Geometry.Row = fixture(Connectors.STONE)
	var cap: Geometry.Limits = limits()
	cap.triangles = 12
	var result: Geometry.Result = Geometry.compile(row, cap)
	assert_equal(result.error, &"CONNECTOR_GEOMETRY_CAPACITY", "triangle budget")
	assert_equal(result.compiled, null, "no partial geometry")
	cap = limits()
	cap.regions = 9
	result = Geometry.compile(row, cap)
	assert_equal(result.error, &"CONNECTOR_GEOMETRY_CAPACITY", "region budget")
	assert_equal(result.compiled, null, "no partial footprint")


func test_profile_contact_and_opening_contract_cannot_be_omitted() -> void:
	"""Drawing a mesh does not invent measured workers, openings, supports or usable landings."""
	var row: Geometry.Row = fixture(Connectors.STONE)
	row.definition.geometry.contacts.profile_revision[0] = 0
	_refuses(row, &"CONNECTOR_CONTACT_MISSING")
	row = fixture(Connectors.STONE)
	row.definition.geometry.volumes.role[4] = Space.ENVELOPE
	_refuses(row, &"CONNECTOR_FOOTPRINT_MISSING")
	row = fixture(Connectors.STONE)
	row.definition.end.y = 1025
	_refuses(row, &"CONNECTOR_LANDING_MISSING")


func test_missing_parts_do_not_masquerade_as_an_approved_family() -> void:
	"""Spiral and ladder remain distinct real construction, not renamed straight stairs."""
	var row: Geometry.Row = fixture(Connectors.STONE)
	row.definition.family = Connectors.LADDER_HATCH
	_refuses(row, &"CONNECTOR_FAMILY_INCOMPLETE")
	row = fixture(Connectors.SPIRAL)
	row.spiral_centre_xz = Vector2i(7000, 7000)
	assert_false(Geometry.compile(row, limits()).ok, "spiral cannot borrow an unrelated support centre")


func test_material_scale_and_slot_are_explicit() -> void:
	"""There is no one-texture-stretched-over-any-size fallback."""
	var row: Geometry.Row = fixture(Connectors.STONE)
	row.material_period_u[0] = 0
	_refuses(row, &"CONNECTOR_MATERIAL_SCALE")
	row = fixture(Connectors.STONE)
	row.parts.materials[0] = 2
	_refuses(row, &"CONNECTOR_MATERIAL_MISSING")


func test_hatch_sweep_includes_thickness_and_all_four_hinge_edges() -> void:
	"""The opening's complete protected swing exists for every authored orientation."""
	for edge: int in 4:
		var row: Geometry.Row = fixture(Connectors.LADDER_HATCH)
		row.parts.hinge_edge[row.parts.kind.size() - 1] = edge
		var result: Geometry.Result = Geometry.compile(row, limits())
		assert_true(result.ok, "hinge edge %d" % edge)
		assert_true(result.compiled.hinge_open_sign != 0, "upward opening sign")
		assert_equal(result.compiled.hatch_sweep[4], 2050, "ceil sqrt(1024 squared + 64 squared), above 1024 floor")
		assert_equal(result.compiled.hatch_sweep[1], 960, "actual thickness below hinge")
	assert_equal(Geometry._ceil_sqrt(5), 3, "non-square radius rounds outward")
	assert_equal(Geometry._ceil_sqrt(343597383680), 586172, "wide plus thick radius exceeds two-coordinate ceiling")


func test_hatch_cannot_swing_outside_the_reserved_multilevel_envelope() -> void:
	"""A closed leaf that fits is insufficient when its raised motion hits the ceiling above."""
	var row: Geometry.Row = fixture(Connectors.LADDER_HATCH)
	row.definition.geometry.volumes.hi_y[0] = 1900
	_refuses(row, &"CONNECTOR_HATCH_SWEEP_OUTSIDE_ENVELOPE")


func test_exact_paid_cut_coordinates_and_contact_index_survive_compilation() -> void:
	"""The compiler preserves a nonaligned caller cut for the datum owner to reject; it never rounds it."""
	var row: Geometry.Row = fixture(Connectors.STONE)
	row.definition.geometry.cuts_xyz[0] = 1
	var result: Geometry.Result = Geometry.compile(row, limits())
	assert_true(result.ok, "cold content compilation")
	assert_equal(result.compiled.definition.geometry.cuts_xyz, PackedInt32Array([1, 0, 0]), "no hidden cube rounding")
	assert_equal(result.compiled.definition.geometry.cut_contacts, PackedInt32Array([0]), "full contact pairing")
	row.definition.geometry.cuts_xyz[0] = 2048
	assert_equal(result.compiled.definition.geometry.cuts_xyz[0], 1, "isolated accepted candidate")


func test_malformed_offsets_and_short_columns_are_named_atomic_refusals() -> void:
	"""Malformed array lengths cannot turn into engine bounds errors or partial geometry."""
	var row: Geometry.Row = fixture(Connectors.STONE)
	row.parts.offsets[1] = -1
	_refuses(row, &"CONNECTOR_PART_FORMAT")
	row = fixture(Connectors.STONE)
	row.parts.level.resize(0)
	_refuses(row, &"CONNECTOR_GEOMETRY_FORMAT")
	row = fixture(Connectors.STONE)
	row.definition.geometry.contacts.approach.hi_y.clear()
	_refuses(row, &"CONNECTOR_GEOMETRY_FORMAT")


func _refuses(row: Geometry.Row, code: StringName) -> void:
	"""Assert both the useful authoring diagnostic and absence of any partial candidate."""
	var result: Geometry.Result = Geometry.compile(row, limits())
	assert_false(result.ok, "refused")
	assert_equal(result.error, code, "specific refusal")
	assert_equal(result.compiled, null, "no partial geometry")

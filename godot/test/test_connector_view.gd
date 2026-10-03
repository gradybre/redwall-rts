extends "res://test/framework/test_case.gd"
## Synthetic rendered connector surfaces, deliberately disconnected from production movement authority.

const Geometry := preload("res://scripts/core/connector_geometry.gd")
const Connectors := preload("res://scripts/core/room_connectors.gd")
const View := preload("res://demo/burrow/connector_view.gd")
const Fixtures := preload("res://test/test_connector_geometry.gd")


static func _materials() -> Array[Material]:
	"""Synthetic materials exercise repeat normalization without authoring a production palette."""
	var first: StandardMaterial3D = StandardMaterial3D.new()
	first.uv1_scale = Vector3(4, 5, 6)
	first.uv1_offset = Vector3(7, 8, 9)
	first.uv1_triplanar = true
	first.grow = true
	first.fixed_size = true
	first.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	first.next_pass = ShaderMaterial.new()
	return [first, StandardMaterial3D.new()]


func test_all_five_families_render_one_fixed_mesh_and_at_most_one_leaf() -> void:
	"""Cold batching uses material surfaces, not a Node3D allocation per tread or rung."""
	for family: int in Connectors.FAMILY_COUNT:
		var result: Geometry.Result = Geometry.compile(Fixtures.fixture(family), Fixtures.limits())
		var view: View = View.new()
		assert_equal(view.configure(result.compiled, _materials()), &"", "family view")
		assert_not_null(view.fixed_mesh(), "fixed parts")
		assert_true(view.fixed_mesh().get_surface_count() <= 2, "one surface per explicit material")
		assert_equal(view.hatch_mesh() != null, family == Connectors.LADDER_HATCH, "only real leaf moves")
		view.free()


func test_sloping_ramp_uv_edges_preserve_actual_metre_length() -> void:
	"""Texture distance follows the face plane, including its slope, without stretching to its bounds."""
	var result: Geometry.Result = Geometry.compile(Fixtures.fixture(Connectors.RAMP), Fixtures.limits())
	var view: View = View.new()
	assert_equal(view.configure(result.compiled, _materials()), &"", "ramp view")
	var mesh: ArrayMesh = view.fixed_mesh()
	for surface: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var period: float = 1.0 if surface == 0 else 0.5
		for index: int in range(0, points.size(), 3):
			for corner: int in 3:
				var a: int = index + corner
				var b: int = index + (corner + 1) % 3
				_assert_close(uvs[a].distance_to(uvs[b]) * period, points[a].distance_to(points[b]), 0.00001, "physical texel scale")
	view.free()


func test_material_copy_clears_hidden_uv_stretch_without_editing_source() -> void:
	"""The caller retains its material while compiled periods exclusively control the view's repeat scale."""
	var source: Array[Material] = _materials()
	var view: View = View.new()
	var compiled: Geometry.Compiled = Geometry.compile(Fixtures.fixture(Connectors.STONE), Fixtures.limits()).compiled
	assert_equal(view.configure(compiled, source), &"", "material binding")
	var actual: BaseMaterial3D = view.fixed_mesh().surface_get_material(0) as BaseMaterial3D
	assert_equal(actual.uv1_scale, Vector3.ONE, "no double scaling")
	assert_equal(actual.uv1_offset, Vector3.ZERO, "no hidden translation")
	assert_false(actual.uv1_triplanar, "use exact clipped-face UVs")
	assert_false(actual.grow, "material cannot inflate physical bounds")
	assert_false(actual.fixed_size, "distance cannot resize geometry")
	assert_equal(actual.billboard_mode, BaseMaterial3D.BILLBOARD_DISABLED, "camera cannot rotate fixed surfaces")
	assert_null(actual.next_pass, "an additional shader cannot displace vertices")
	assert_not_null(source[0].next_pass, "source pass chain unchanged")
	assert_equal((source[0] as BaseMaterial3D).uv1_scale, Vector3(4, 5, 6), "source unchanged")
	view.free()


func test_all_family_fixed_and_hatch_triangles_use_clockwise_godot_front_faces() -> void:
	"""With back-face culling, emitted render winding must oppose the independently retained outward normal."""
	for family: int in Connectors.FAMILY_COUNT:
		var compiled: Geometry.Compiled = Geometry.compile(Fixtures.fixture(family), Fixtures.limits()).compiled
		var view: View = View.new()
		assert_equal(view.configure(compiled, _materials()), &"", "family view")
		for mesh: ArrayMesh in [view.fixed_mesh(), view.hatch_mesh()]:
			if mesh == null:
				continue
			for surface: int in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				assert_equal((mesh.surface_get_material(surface) as BaseMaterial3D).cull_mode, BaseMaterial3D.CULL_BACK, "back faces culled")
				for at: int in range(0, vertices.size(), 3):
					var cross: Vector3 = (vertices[at + 1] - vertices[at]).cross(vertices[at + 2] - vertices[at])
					assert_true(cross.dot(normals[at]) < 0.0, "clockwise front face")
		view.free()


func test_hatch_every_sampled_angle_fits_complete_integer_sweep() -> void:
	"""Visual hatch poses agree with the complete analytic footprint, including the opposite hinge orientations."""
	for edge: int in 4:
		var row: Geometry.Row = Fixtures.fixture(Connectors.LADDER_HATCH)
		row.parts.hinge_edge[row.parts.kind.size() - 1] = edge
		var compiled: Geometry.Compiled = Geometry.compile(row, Fixtures.limits()).compiled
		var view: View = View.new()
		assert_equal(view.configure(compiled, _materials()), &"", "hatch view")
		_hatch_sweep(view, compiled.hatch_sweep)
		view.free()


func _hatch_sweep(view: View, box: PackedInt32Array) -> void:
	"""Dense samples validate rendering against the separately derived integer whole-motion enclosure."""
	for step: int in 37:
		assert_true(view.set_hatch_fraction(float(step) / 36.0), "fraction")
		var mesh: ArrayMesh = view.hatch_mesh()
		for surface: int in mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var actual: Vector3 = view.hatch_transform() * vertex * 1024.0
				for axis: int in 3:
					assert_true(actual[axis] >= float(box[axis]) - 0.001 and actual[axis] <= float(box[axis + 3]) + 0.001, "entire leaf inside reserved swing")


func test_fixed_rotation_and_translation_match_integer_placement_convention() -> void:
	"""The ghost cannot turn clockwise while authoritative quarter-turn placement turns counterclockwise."""
	var compiled: Geometry.Compiled = Geometry.compile(Fixtures.fixture(Connectors.STONE), Fixtures.limits()).compiled
	var view: View = View.new()
	assert_equal(view.configure(compiled, _materials()), &"", "view")
	var placement: Connectors.Placement = Connectors.Placement.new()
	placement.origin = Vector3i(2048, -4096, 1024)
	var point: Vector3i = Vector3i(-512, 256, 512)
	for turn: int in 4:
		placement.rotation = turn
		assert_true(view.set_fixed_placement(placement.origin, turn), "quarter turn")
		var expected: PackedInt64Array = Connectors._point64(point, placement)
		var actual: Vector3 = view.transform * (Vector3(point) / 1024.0)
		for axis: int in 3:
			_assert_close(actual[axis], float(expected[axis]) / 1024.0, 0.00001, "same exact shape orientation")
	view.free()


func _assert_close(actual: float, expected: float, tolerance: float, label: String) -> void:
	"""Compare presentation float evidence with an explicit test tolerance, never a gameplay margin."""
	assert_true(absf(actual - expected) <= tolerance, "%s: %f versus %f" % [label, actual, expected])


func test_bad_material_and_partial_geometry_leave_existing_preview_intact() -> void:
	"""UI validation failures preserve the last complete preview instead of clearing or partially replacing it."""
	var compiled: Geometry.Compiled = Geometry.compile(Fixtures.fixture(Connectors.STONE), Fixtures.limits()).compiled
	var view: View = View.new()
	assert_equal(view.configure(compiled, _materials()), &"", "initial view")
	var before: ArrayMesh = view.fixed_mesh()
	var invalid: Array[Material] = [ShaderMaterial.new(), StandardMaterial3D.new()]
	assert_equal(view.configure(compiled, invalid), &"CONNECTOR_VIEW_MATERIAL", "unknown UV shader refused")
	assert_equal(view.fixed_mesh(), before, "material refusal atomic")
	compiled.triangle_xyz.remove_at(0)
	assert_equal(view.configure(compiled, _materials()), &"CONNECTOR_VIEW_FORMAT", "partial triangle")
	assert_equal(view.fixed_mesh(), before, "geometry refusal atomic")
	view.free()


func test_hatch_fraction_and_rotation_do_not_silently_clamp_or_resize() -> void:
	"""Presentation edits respect fixed authored options and preserve the last valid transform on refusal."""
	var compiled: Geometry.Compiled = Geometry.compile(Fixtures.fixture(Connectors.LADDER_HATCH), Fixtures.limits()).compiled
	compiled.definition.allowed_rotations = 1
	var view: View = View.new()
	assert_equal(view.configure(compiled, _materials()), &"", "hatch")
	assert_true(view.set_hatch_fraction(0.5), "half open")
	var before: Transform3D = view.hatch_transform()
	assert_false(view.set_hatch_fraction(NAN), "nonfinite fraction")
	assert_false(view.set_hatch_fraction(1.01), "no silent clamping")
	assert_equal(view.hatch_transform(), before, "fraction refusal preserves pose")
	assert_false(view.set_fixed_placement(Vector3i.ZERO, 1), "authored rotation mask")
	view.free()

extends "res://test/framework/test_case.gd"
## Synthetic rendering geometry, not production room dimensions, clearance or material recipes.

const Shell := preload("res://demo/burrow/modular_shell.gd")
const Materials := preload("res://demo/burrow/modular_materials.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")


func test_single_cell_has_exact_floor_ceiling_and_four_inward_walls() -> void:
	"""The six finish planes meet at the supplied boundary, with clockwise front faces."""
	var result: Dictionary = Shell.new().rebuild(0, _spec(PackedInt32Array([0, 0])))
	assert_true(result.ok, "complete typed geometry builds")
	assert_equal(result.stats, PackedInt32Array([1, 4, 1, 0]), "six planes and no dig frontier")
	assert_almost_equal(_area(result.floor_mesh), 1.0, "one square metre floor")
	assert_almost_equal(_area(result.ceiling_mesh), 1.0, "one square metre ceiling")
	assert_almost_equal(_area(result.wall_mesh), 8.0, "four walls exactly two metres tall")
	for key: String in Shell.MESH_KEYS:
		_assert_clockwise(result[key])


func test_shared_equal_height_edges_have_no_interior_walls() -> void:
	"""Two adjacent cells produce six exterior bands rather than eight overlapping walls."""
	var result: Dictionary = Shell.new().rebuild(0, _spec(PackedInt32Array([0, 0, 1, 0])))
	assert_equal(result.stats, PackedInt32Array([2, 6, 2, 0]), "one joined shell")
	var vertices: PackedVector3Array = result.wall_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = result.wall_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	for at: int in range(vertices.size()):
		assert_false(is_equal_approx(vertices[at].x, 1.0) and absf(normals[at].x) > 0.5,
			"no X-facing wall on the shared internal plane")


func test_concave_and_rounded_shapes_keep_exact_cell_area() -> void:
	"""Every floor quad belongs to a real cell, including bends and missing concave corners."""
	var shapes: Array[PackedInt32Array] = [PackedInt32Array([0, 0, 1, 0, 2, 0, 0, 1, 0, 2]),
		Footprint.ellipse(-3, -2, 6, 4, 128).cells,
		Footprint.tunnel_path(PackedInt32Array([0, 0, 4, 0, 4, 3]), 1, 128).cells]
	for cells: PackedInt32Array in shapes:
		var result: Dictionary = Shell.new().rebuild(0, _spec(cells))
		assert_true(result.ok, "valid synthetic shape builds")
		assert_almost_equal(_area(result.floor_mesh), float(cells.size()) / 2.0, "floor area is cell union")
		assert_equal(result.stats[1] * 3, Footprint.boundary_edges(cells).size(), "only actual boundary walls")
		_assert_floor_cells(result.floor_mesh, cells)


func test_inner_island_keeps_hole_in_floor_ceiling_and_wall_ring() -> void:
	"""A retained solid island never becomes a triangle fan across the hole."""
	var cells: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 2, 0, 0, 1, 2, 1, 0, 2, 1, 2, 2, 2])
	var result: Dictionary = Shell.new().rebuild(0, _spec(cells))
	assert_true(result.ok, "explicit connected ring builds")
	assert_equal(result.stats, PackedInt32Array([8, 16, 8, 0]), "island retains four inward-ring faces")
	_assert_floor_cells(result.floor_mesh, cells)
	_assert_floor_cells(result.ceiling_mesh, cells)


func test_split_height_exposes_only_riser_and_soffit_bands() -> void:
	"""A raised short room section meets the lower taller part with two nonoverlapping bands."""
	var spec: Dictionary = _spec(PackedInt32Array([0, 0, 1, 0]))
	spec.floor_u = PackedInt32Array([0, 512])
	spec.ceiling_u = PackedInt32Array([2048, 1536])
	var result: Dictionary = Shell.new().rebuild(0, spec)
	assert_true(result.ok, "each section retains supplied one metre minimum headroom")
	assert_equal(result.stats, PackedInt32Array([2, 8, 2, 0]), "six outer walls plus riser and soffit")
	assert_almost_equal(_area(result.wall_mesh), 10.0, "only exposed interval differences have walls")
	var arrays: Array = result.wall_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for at: int in range(vertices.size()):
		if is_equal_approx(vertices[at].x, 1.0) and absf(normals[at].x) > 0.5:
			assert_true(vertices[at].y <= 0.5 or vertices[at].y >= 1.5, "shared opening has no middle wall")
	_assert_clockwise(result.wall_mesh)


func test_disjoint_height_intervals_do_not_emit_overlapping_tall_risers() -> void:
	"""Geometric disconnection stays visible; presentation does not invent a passage between levels."""
	var spec: Dictionary = _spec(PackedInt32Array([0, 0, 1, 0]))
	spec.floor_u = PackedInt32Array([0, 2048])
	spec.ceiling_u = PackedInt32Array([1024, 3072])
	var result: Dictionary = Shell.new().rebuild(0, spec)
	assert_true(result.ok, "individually valid void intervals render without claiming traversal")
	assert_equal(result.stats[1], 8, "each separate void has its own complete boundary")
	assert_almost_equal(_area(result.wall_mesh), 8.0, "no band crosses the solid vertical gap")


func test_opening_leaves_exact_sill_and_lintel_geometry() -> void:
	"""Partial-height opening has no wall triangles in its interior, even without a cutaway shader."""
	var spec: Dictionary = _spec(PackedInt32Array([0, 0]))
	spec.openings = PackedInt32Array([0, 0, Footprint.NORTH, 256, 1536])
	var result: Dictionary = Shell.new().rebuild(0, spec)
	assert_true(result.ok, "reviewed opening builds")
	assert_equal(result.stats[1], 5, "three complete walls, sill and lintel")
	assert_almost_equal(_area(result.wall_mesh), 6.75, "exact one-by-1.25m aperture")
	var arrays: Array = result.wall_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for at: int in range(vertices.size()):
		if normals[at].z > 0.5:
			assert_true(vertices[at].y <= 0.25 or vertices[at].y >= 1.5, "north aperture is empty")


func test_full_height_opening_removes_its_wall_and_apertures_remove_only_selected_patches() -> void:
	"""Stair floor/ceiling holes are intentional complete cell apertures, separate from wall holes."""
	var spec: Dictionary = _spec(PackedInt32Array([0, 0, 1, 0]))
	spec.openings = PackedInt32Array([0, 0, Footprint.WEST, 0, 2048])
	spec.floor_open = PackedByteArray([1, 0])
	spec.ceiling_open = PackedByteArray([0, 1])
	var result: Dictionary = Shell.new().rebuild(0, spec)
	assert_equal(result.stats, PackedInt32Array([1, 5, 1, 0]), "only selected openings remove surfaces")
	_assert_floor_cells(result.floor_mesh, PackedInt32Array([1, 0]))
	_assert_floor_cells(result.ceiling_mesh, PackedInt32Array([0, 0]))


func test_invalid_openings_refuse_before_replacing_cached_mesh() -> void:
	"""Outside, duplicate, internal, reversed and over-height openings never silently become valid."""
	var shell: Shell = Shell.new()
	var good: Dictionary = _spec(PackedInt32Array([0, 0, 1, 0]))
	assert_true(shell.rebuild(1, good).ok, "initial shell builds")
	var bad: Array[PackedInt32Array] = [PackedInt32Array([2, 0, 0, 0, 1024]),
		PackedInt32Array([0, 0, 1, 0, 1024]), PackedInt32Array([0, 0, 0, -1, 1024]),
		PackedInt32Array([0, 0, 0, 0, 2049]), PackedInt32Array([0, 0, 0, 1024, 0]),
		PackedInt32Array([0, 0, 0, 0, 1024, 0, 0, 0, 0, 1024]), PackedInt32Array([0, 0, 0])]
	for opening: PackedInt32Array in bad:
		var spec: Dictionary = good.duplicate(true)
		spec.openings = opening
		assert_equal(shell.rebuild(2, spec).error, Shell.REFUSE_OPENING, "invalid opening refuses")
	assert_equal(shell.build_count, 1, "refusals allocate no replacement mesh")
	assert_true(shell.rebuild(1, good).ok, "reviewed old snapshot survives failed replacement")


func test_actual_stages_control_shell_extent_finish_color_and_frontier() -> void:
	"""No elapsed time or dig percentage can reveal an unexcavated cell."""
	var spec: Dictionary = _spec(PackedInt32Array([0, 0, 1, 0, 2, 0]))
	spec.state = PackedByteArray([Shell.FINISHED, Shell.CUT, Shell.SOLID])
	var result: Dictionary = Shell.new().rebuild(0, spec)
	assert_equal(result.stats, PackedInt32Array([2, 5, 2, 1]), "void and solid meet at one actual work face")
	var colors: PackedColorArray = result.floor_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	for at: int in range(4):
		assert_almost_equal(colors[at].r, 1.0, "completed cell uses selected finish")
		assert_almost_equal(colors[at + 4].r, 0.0, "cut cell remains earth")
	var face_colors: PackedColorArray = result.frontier_mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_almost_equal(face_colors[0].g, 1.0, "actual frontier is marked explicitly")
	_assert_floor_cells(result.floor_mesh, PackedInt32Array([0, 0, 1, 0]))


func test_unexcavated_cells_cannot_have_any_opening() -> void:
	"""A renderer input cannot erase a floor or wall before that cell becomes void."""
	for key: String in ["floor_open", "ceiling_open", "openings"]:
		var spec: Dictionary = _spec(PackedInt32Array([0, 0]))
		spec.state = PackedByteArray([Shell.SOLID])
		if key == "openings":
			spec[key] = PackedInt32Array([0, 0, 0, 0, 1024])
		else:
			spec[key] = PackedByteArray([1])
		assert_equal(Shell.validation_error(spec), Shell.REFUSE_OPENING, "opening requires actual void: " + key)
	var untouched: Dictionary = _spec(PackedInt32Array([0, 0]))
	untouched.state = PackedByteArray([Shell.SOLID])
	assert_equal(Shell.new().rebuild(0, untouched).stats, PackedInt32Array([0, 0, 0, 0]), "solid means no shell")


func test_missing_limits_bad_streams_and_short_headroom_refuse() -> void:
	"""The renderer cannot choose a default level height, clearance or cell pitch."""
	var spec: Dictionary = _spec(PackedInt32Array([0, 0]))
	spec.erase("minimum_headroom_u")
	assert_equal(Shell.validation_error(spec), Shell.REFUSE_SPEC, "unbound clearance is explicit refusal")
	spec = _spec(PackedInt32Array([0, 0]))
	spec.floor_u = PackedInt32Array([1100])
	assert_equal(Shell.validation_error(spec), Shell.REFUSE_HEIGHT, "short headroom is visible failure")
	spec = _spec(PackedInt32Array([0, 0]))
	spec.state = PackedByteArray([3])
	assert_equal(Shell.validation_error(spec), Shell.REFUSE_SPEC, "unknown construction stage refuses")
	spec = _spec(PackedInt32Array([0, 0]))
	spec.ceiling_u = PackedInt32Array()
	assert_equal(Shell.validation_error(spec), Shell.REFUSE_SPEC, "misaligned columns refuse")
	spec = _spec(PackedInt32Array([2147483646, 0]))
	assert_equal(Shell.validation_error(spec), Footprint.REFUSE_WORLD, "world corner overflow refuses")


func test_revision_cache_reuses_meshes_and_rejects_changed_data() -> void:
	"""Cache identity cannot conceal changed geometry under a reused revision."""
	var shell: Shell = Shell.new()
	var spec: Dictionary = _spec(PackedInt32Array([0, 0]))
	var first: Dictionary = shell.rebuild(4, spec)
	assert_equal(shell.rebuild(4, spec).floor_mesh, first.floor_mesh, "unchanged revision reuses resource")
	assert_equal(shell.build_count, 1, "idle refresh rebuilds nothing")
	first.stats[0] = 999
	assert_equal(shell.rebuild(4, spec).stats[0], 1, "caller metadata edits cannot corrupt cached counters")
	spec.floor_u[0] = 256
	assert_equal(shell.rebuild(4, spec).error, Shell.REFUSE_REVISION, "same revision changed height refuses")
	assert_equal(shell.rebuild(3, spec).error, Shell.REFUSE_REVISION, "stale revision refuses")
	assert_true(shell.rebuild(5, spec).ok, "new revision installs actual changed geometry")
	assert_equal(shell.build_count, 2, "one rebuild for the new revision")
	shell.clear()
	assert_true(shell.rebuild(0, spec).ok, "cleared cache accepts a fresh owner")


func test_float_presentation_cannot_collapse_fine_cells_at_extreme_coordinates() -> void:
	"""Int32 fixed bounds alone do not prove a float32 mesh can retain every requested corner."""
	var spec: Dictionary = _spec(PackedInt32Array([0, 0]))
	spec.cell_size_u = 1
	spec.origin_u = Vector2i(2147483645, 0)
	assert_equal(Shell.validation_error(spec), Shell.REFUSE_PRECISION, "float32 rounding must be visible")
	spec.origin_u = Vector2i.ZERO
	assert_true(Shell.new().rebuild(0, spec).ok, "the same fine synthetic pitch works near the origin")


func test_opening_heights_cannot_silently_round_at_extreme_levels() -> void:
	"""Representable room corners do not make every interior sill and lintel representable."""
	var spec: Dictionary = _spec(PackedInt32Array([0, 0]))
	spec.floor_u = PackedInt32Array([1073741824])
	spec.ceiling_u = PackedInt32Array([1073743872])
	assert_true(Shell.new().rebuild(0, spec).ok, "coarse exact extreme level renders")
	spec.openings = PackedInt32Array([0, 0, Footprint.NORTH, 1073741825, 1073742848])
	assert_equal(Shell.validation_error(spec), Shell.REFUSE_PRECISION, "inexact sill refuses")
	spec.openings = PackedInt32Array([0, 0, Footprint.NORTH, 1073741824, 1073742849])
	assert_equal(Shell.validation_error(spec), Shell.REFUSE_PRECISION, "inexact lintel refuses")
	spec.openings = PackedInt32Array([0, 0, Footprint.NORTH, 1073741824, 1073742848])
	assert_true(Shell.new().rebuild(0, spec).ok, "exact aperture boundaries render")


func test_world_anchored_uvs_survive_expansion_and_negative_origin() -> void:
	"""The same world corner keeps its material phase; a wider floor cannot stretch its planks."""
	var original: Dictionary = _spec(PackedInt32Array([-1, 0]))
	original.origin_u = Vector2i(256, -512)
	var expanded: Dictionary = _spec(PackedInt32Array([-1, 0, 0, 0]))
	expanded.origin_u = original.origin_u
	var a: Dictionary = Shell.new().rebuild(0, original)
	var b: Dictionary = Shell.new().rebuild(0, expanded)
	var a_uv: PackedVector2Array = a.floor_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var b_uv: PackedVector2Array = b.floor_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	assert_equal(a_uv, PackedVector2Array([Vector2(-0.75, -0.5), Vector2(0.25, -0.5),
		Vector2(0.25, 0.5), Vector2(-0.75, 0.5)]), "UVs are world metres")
	for at: int in range(4):
		assert_equal(a_uv[at], b_uv[at], "existing floor texels do not move during expansion")


func test_material_selection_and_cutaway_leave_geometry_and_stages_unchanged() -> void:
	"""Whole-category rendering choices neither mutate construction input nor rebuild the shell."""
	var shell: Shell = Shell.new()
	var spec: Dictionary = _spec(PackedInt32Array([0, 0, 1, 0]))
	spec.state = PackedByteArray([Shell.FINISHED, Shell.CUT])
	var saved: Dictionary = spec.duplicate(true)
	var result: Dictionary = shell.rebuild(0, spec)
	var before: Array = result.floor_mesh.surface_get_arrays(0)
	var materials: Materials = Materials.new()
	assert_true(materials.set_finishes(Materials.TIMBER, Materials.STONE, Materials.EARTH), "select complete surfaces")
	assert_true(materials.apply(result), "apply rendering only")
	materials.set_cutaway_y(0.75)
	assert_equal(result.floor_mesh.surface_get_arrays(0), before, "material/cutaway preserves all mesh arrays")
	assert_equal(spec, saved, "caller state is untouched")
	assert_equal(shell.build_count, 1, "view changes rebuild no geometry")
	assert_equal(materials.selections(), PackedInt32Array([1, 2, 0]), "whole-surface choices retained")
	assert_false(materials.set_finishes(3, 0, 0), "unknown finish refuses atomically")
	assert_equal(materials.selections(), PackedInt32Array([1, 2, 0]), "invalid selection preserves choices")
	assert_equal(materials.material(1, 0), materials.material(1, 0), "material resource is cached")
	assert_null(materials.material(-1, 0), "invalid material has no silent fallback")


func test_vertical_uvs_anchor_to_world_height_and_each_wall_axis() -> void:
	"""Lower levels retain physical courses and grain scale; height is not normalized per wall."""
	var spec: Dictionary = _spec(PackedInt32Array([-1, -1]))
	spec.origin_u = Vector2i(256, -512)
	spec.floor_u = PackedInt32Array([-4096])
	spec.ceiling_u = PackedInt32Array([-2048])
	var result: Dictionary = Shell.new().rebuild(0, spec)
	var uv: PackedVector2Array = result.wall_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	assert_equal(uv.slice(0, 4), PackedVector2Array([Vector2(-0.75, -4), Vector2(0.25, -4),
		Vector2(0.25, -2), Vector2(-0.75, -2)]), "north wall uses world X/Y metres")
	assert_equal(uv.slice(4, 8), PackedVector2Array([Vector2(-1.5, -4), Vector2(-0.5, -4),
		Vector2(-0.5, -2), Vector2(-1.5, -2)]), "east wall uses world Z/Y metres")


func test_explicit_finer_pitch_preserves_area_and_material_scale() -> void:
	"""A render study may use another explicit pitch without silently changing its physical extent."""
	var spec: Dictionary = _spec(Footprint.rectangle(0, 0, 4, 4, 32).cells)
	spec.cell_size_u = 256
	var result: Dictionary = Shell.new().rebuild(0, spec)
	assert_true(result.ok, "explicit synthetic quarter-metre pitch renders")
	assert_almost_equal(_area(result.floor_mesh), 1.0, "sixteen quarter-metre cells cover one square metre")
	var uv: PackedVector2Array = result.floor_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	assert_equal(uv[1] - uv[0], Vector2(0.25, 0), "texture pitch stays in metres rather than cells")


func _spec(cells: PackedInt32Array) -> Dictionary:
	"""Explicit synthetic one-metre grid, two-metre height and one-metre minimum clearance."""
	@warning_ignore("integer_division") var count: int = cells.size() / 2
	var floor_u: PackedInt32Array = PackedInt32Array()
	var ceiling_u: PackedInt32Array = PackedInt32Array()
	var state: PackedByteArray = PackedByteArray()
	floor_u.resize(count)
	ceiling_u.resize(count)
	ceiling_u.fill(2048)
	state.resize(count)
	state.fill(Shell.FINISHED)
	return {"cells": cells, "floor_u": floor_u, "ceiling_u": ceiling_u, "state": state,
		"origin_u": Vector2i.ZERO, "cell_size_u": 1024, "minimum_headroom_u": 1024,
		"openings": PackedInt32Array()}


func _area(mesh: ArrayMesh) -> float:
	"""Independent triangle-area oracle for presentation geometry."""
	if mesh.get_surface_count() == 0:
		return 0.0
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var area: float = 0.0
	for at: int in range(0, indices.size(), 3):
		area += (points[indices[at + 1]] - points[indices[at]]).cross(points[indices[at + 2]] - points[indices[at]]).length() * 0.5
	return area


func _assert_clockwise(mesh: ArrayMesh) -> void:
	"""Godot's front-face winding must agree with each deliberately inward/upward/downward normal."""
	if mesh.get_surface_count() == 0:
		return
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for at: int in range(0, indices.size(), 3):
		var a: int = indices[at]
		var b: int = indices[at + 1]
		var c: int = indices[at + 2]
		assert_true((points[b] - points[a]).cross(points[c] - points[a]).dot(normals[a]) < 0.0, "nondegenerate clockwise face")


func _assert_floor_cells(mesh: ArrayMesh, cells: PackedInt32Array) -> void:
	"""Every floor/ceiling quad center belongs to exactly one allowed cell, with no duplicates."""
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var seen: Dictionary = {}
	for at: int in range(0, vertices.size(), 4):
		var center: Vector3 = (vertices[at] + vertices[at + 1] + vertices[at + 2] + vertices[at + 3]) * 0.25
		var cell: Vector2i = Vector2i(floori(center.x), floori(center.z))
		assert_true(Footprint.contains_cell(cells, cell.x, cell.y), "floor patch belongs to confirmed cell")
		assert_false(seen.has(cell), "each horizontal patch occurs once")
		seen[cell] = true

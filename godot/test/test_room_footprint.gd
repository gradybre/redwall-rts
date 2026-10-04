extends "res://test/framework/test_case.gd"
## Cold integer geometry fixtures. These dimensions are synthetic, not a gameplay grid catalog.

const Footprint := preload("res://scripts/core/room_footprint.gd")
const CAPACITY: int = 512


func test_canonicalization_sorts_signed_coordinates_and_deduplicates() -> void:
	"""Negative coordinates sort numerically; duplicate paint produces one physical cell."""
	var source: PackedInt32Array = PackedInt32Array([0, 0, -2, -1, -1, 0, 0, 0, 2, -1])
	var result: Dictionary = Footprint.canonicalize(source, CAPACITY)
	assert_true(result.ok, "canonicalization sorts signed coordinates and deduplicates")
	assert_equal(result.cells, PackedInt32Array([-2, -1, 2, -1, -1, 0, 0, 0]), "canonicalization sorts signed coordinates and deduplicates")
	assert_equal(source, PackedInt32Array([0, 0, -2, -1, -1, 0, 0, 0, 2, -1]), "input remains untouched")


func test_canonicalization_handles_int32_extremes_without_key_collision() -> void:
	"""Both words retain their full signed range; no string or float keys lose precision."""
	var source: PackedInt32Array = PackedInt32Array([2147483646, 2147483646, -2147483648, -2147483648,
		-2147483648, 2147483646, 2147483646, -2147483648])
	var result: Dictionary = Footprint.canonicalize(source, CAPACITY)
	assert_true(result.ok, "canonicalization sorts signed coordinates and deduplicates")
	assert_equal(result.cells, PackedInt32Array([-2147483648, -2147483648, 2147483646, -2147483648,
		-2147483648, 2147483646, 2147483646, 2147483646]), "canonicalization sorts signed coordinates and deduplicates")


func test_malformed_over_capacity_and_unrepresentable_corners_are_refused() -> void:
	"""Refusals carry no partial footprint and do not reinterpret an odd trailing coordinate."""
	_expect_failure(Footprint.canonicalize(PackedInt32Array([1, 2, 3]), CAPACITY), Footprint.REFUSE_FORMAT)
	_expect_failure(Footprint.canonicalize(PackedInt32Array([0, 0, 1, 0]), 1), Footprint.REFUSE_CAPACITY)
	_expect_failure(Footprint.canonicalize(PackedInt32Array([2147483647, 0]), CAPACITY),
		Footprint.REFUSE_COORDINATE)
	_expect_failure(Footprint.canonicalize(PackedInt32Array(), 0), Footprint.REFUSE_CAPACITY)
	_expect_failure(Footprint.canonicalize(PackedInt32Array(), 16385), Footprint.REFUSE_CAPACITY)


func test_empty_draft_is_editable_but_cannot_be_confirmed() -> void:
	"""Erasing a draft completely is different from confirming a zero-area room."""
	var result: Dictionary = Footprint.canonicalize(PackedInt32Array(), CAPACITY)
	assert_true(result.ok, "empty draft is editable but cannot be confirmed")
	assert_equal(Footprint.validation_error(result.cells, CAPACITY, true), Footprint.REFUSE_EMPTY, "empty draft is editable but cannot be confirmed")


func test_validation_does_not_repair_saved_noncanonical_data() -> void:
	"""A saved or confirmed cell stream must already be sorted and unique."""
	assert_equal(Footprint.validation_error(PackedInt32Array([1, 0, 0, 0]), CAPACITY, false),
		Footprint.REFUSE_CANONICAL, "validation does not repair saved noncanonical data")
	assert_equal(Footprint.validation_error(PackedInt32Array([0, 0, 0, 0]), CAPACITY, false),
		Footprint.REFUSE_CANONICAL, "validation does not repair saved noncanonical data")
	assert_equal(Footprint.validation_error(PackedInt32Array([0]), CAPACITY, false), Footprint.REFUSE_FORMAT, "validation does not repair saved noncanonical data")


func test_disconnected_cells_and_diagonal_only_contact_are_not_rooms() -> void:
	"""Touching only at one corner is not a usable cardinal connection."""
	assert_equal(Footprint.validation_error(PackedInt32Array([0, 0, 1, 1]), CAPACITY, true),
		Footprint.REFUSE_DISCONNECTED, "disconnected cells and diagonal only contact are not rooms")
	assert_equal(Footprint.validation_error(PackedInt32Array([-2000000000, 0, 2000000000, 0]), CAPACITY, true),
		Footprint.REFUSE_DISCONNECTED, "huge sparse bounds require no dense allocation")


func test_connected_concave_plan_is_accepted_without_bounding_box_fill() -> void:
	"""An L-shaped room remains L-shaped and can contain a full one-cell-wide leg."""
	var cells: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 2, 0, 0, 1, 0, 2])
	assert_equal(Footprint.validation_error(cells, CAPACITY, false), Footprint.REFUSE_NONE, "connected concave plan is accepted without bounding box fill")
	assert_true(Footprint.contains_cell(cells, 0, 2), "connected concave plan is accepted without bounding box fill")
	assert_false(Footprint.contains_cell(cells, 1, 1), "connected concave plan is accepted without bounding box fill")


func test_holes_are_explicit_policy_and_never_filled_silently() -> void:
	"""A closed island keeps both wall loops if the caller allows retained solid islands."""
	var cells: PackedInt32Array = _ring()
	assert_equal(Footprint.validation_error(cells, CAPACITY, false), Footprint.REFUSE_HOLES, "holes are explicit policy and never filled silently")
	assert_equal(Footprint.validation_error(cells, CAPACITY, true), Footprint.REFUSE_NONE, "holes are explicit policy and never filled silently")
	assert_false(Footprint.contains_cell(cells, 1, 1), "holes are explicit policy and never filled silently")
	var loops: Array[PackedInt32Array] = Footprint.boundary_loops(cells)
	assert_equal(loops.size(), 2, "holes are explicit policy and never filled silently")
	assert_equal(_twice_area(loops[0]), 18, "outer 3x3 clockwise boundary")
	assert_equal(_twice_area(loops[1]), -2, "inner 1x1 counterclockwise boundary")
	assert_equal(_twice_area(loops[0]) + _twice_area(loops[1]), cells.size(), "holes are explicit policy and never filled silently")


func test_connected_diagonal_pinch_refuses_ambiguous_wall_ownership() -> void:
	"""The opening of an almost-ring cannot meet the cavity at a zero-width corner."""
	var result: Dictionary = Footprint.combine(_ring(), PackedInt32Array([0, 0]), true, CAPACITY)
	assert_true(result.ok, "connected diagonal pinch refuses ambiguous wall ownership")
	assert_equal(Footprint.validation_error(result.cells, CAPACITY, true), Footprint.REFUSE_PINCH, "connected diagonal pinch refuses ambiguous wall ownership")
	assert_true(Footprint.boundary_loops(result.cells).is_empty(), "connected diagonal pinch refuses ambiguous wall ownership")


func test_rectangle_uses_exact_extent_and_negative_origin() -> void:
	"""A positive width/depth includes precisely each cell of the requested extent."""
	var result: Dictionary = Footprint.rectangle(-2, -1, 3, 2, CAPACITY)
	assert_true(result.ok, "rectangle uses exact extent and negative origin")
	assert_equal(result.cells, PackedInt32Array([-2, -1, -1, -1, 0, -1, -2, 0, -1, 0, 0, 0]), "rectangle uses exact extent and negative origin")
	assert_equal(Footprint.validation_error(result.cells, CAPACITY, false), Footprint.REFUSE_NONE, "rectangle uses exact extent and negative origin")


func test_shape_arguments_and_capacity_fail_without_clipping() -> void:
	"""Invalid extents, arithmetic bounds and capacity cannot yield a smaller plausible room."""
	_expect_failure(Footprint.rectangle(0, 0, 0, 2, CAPACITY), Footprint.REFUSE_SHAPE)
	_expect_failure(Footprint.rectangle(0, 0, 32768, 1, CAPACITY), Footprint.REFUSE_SHAPE)
	_expect_failure(Footprint.rectangle(0, 0, 10, 10, 99), Footprint.REFUSE_CAPACITY)
	_expect_failure(Footprint.rectangle(2147483646, 0, 2, 1, CAPACITY), Footprint.REFUSE_COORDINATE)
	_expect_failure(Footprint.rectangle(-2147483649, 0, 1, 1, CAPACITY), Footprint.REFUSE_COORDINATE)


func test_ellipse_has_independent_axes_and_keeps_grid_boundary() -> void:
	"""A 6x4 oval has straight middle spans and missing corner cells rather than a filled box."""
	var result: Dictionary = Footprint.ellipse(0, 0, 6, 4, CAPACITY)
	assert_true(result.ok, "ellipse has independent axes and keeps grid boundary")
	assert_equal(result.cells, PackedInt32Array([1, 0, 2, 0, 3, 0, 4, 0,
		0, 1, 1, 1, 2, 1, 3, 1, 4, 1, 5, 1,
		0, 2, 1, 2, 2, 2, 3, 2, 4, 2, 5, 2, 1, 3, 2, 3, 3, 3, 4, 3]), "ellipse has independent axes and keeps grid boundary")
	assert_equal(Footprint.validation_error(result.cells, CAPACITY, false), Footprint.REFUSE_NONE, "ellipse has independent axes and keeps grid boundary")
	assert_equal(_twice_area(Footprint.boundary_loops(result.cells)[0]), result.cells.size(), "ellipse has independent axes and keeps grid boundary")


func test_narrow_ellipse_and_single_cell_are_supported() -> void:
	"""Small dimensions cannot divide by zero or drop the central usable route."""
	assert_equal(Footprint.ellipse(0, 0, 1, 4, CAPACITY).cells, PackedInt32Array([0, 0, 0, 1, 0, 2, 0, 3]), "narrow ellipse and single cell are supported")
	assert_equal(Footprint.ellipse(-1, -1, 1, 1, CAPACITY).cells, PackedInt32Array([-1, -1]), "narrow ellipse and single cell are supported")
	_expect_failure(Footprint.ellipse(0, 0, 6, 4, 19), Footprint.REFUSE_CAPACITY)


func test_rounded_rectangle_retains_straight_usable_walls() -> void:
	"""A long room can soften corners without becoming an oval or changing its overall span."""
	var result: Dictionary = Footprint.rounded_rectangle(0, 0, 8, 4, 2, CAPACITY)
	assert_true(result.ok, "rounded rectangle retains straight usable walls")
	assert_equal(result.cells.size(), 56, "rounded rectangle retains straight usable walls")
	assert_false(Footprint.contains_cell(result.cells, 0, 0), "rounded rectangle retains straight usable walls")
	assert_true(Footprint.contains_cell(result.cells, 1, 0), "rounded rectangle retains straight usable walls")
	assert_true(Footprint.contains_cell(result.cells, 0, 1), "rounded rectangle retains straight usable walls")
	assert_true(Footprint.contains_cell(result.cells, 7, 2), "rounded rectangle retains straight usable walls")
	assert_equal(Footprint.validation_error(result.cells, CAPACITY, false), Footprint.REFUSE_NONE, "rounded rectangle retains straight usable walls")
	assert_equal(Footprint.rounded_rectangle(0, 0, 4, 3, 0, CAPACITY).cells,
		Footprint.rectangle(0, 0, 4, 3, CAPACITY).cells, "rounded rectangle retains straight usable walls")


func test_rounded_rectangle_rejects_impossible_radius() -> void:
	"""Radius mismatch is a refusal, never a silently clamped change to the requested shape."""
	_expect_failure(Footprint.rounded_rectangle(0, 0, 4, 3, 2, CAPACITY), Footprint.REFUSE_SHAPE)
	_expect_failure(Footprint.rounded_rectangle(0, 0, 4, 3, -1, CAPACITY), Footprint.REFUSE_SHAPE)
	_expect_failure(Footprint.rounded_rectangle(0, 0, 4, 3, 9223372036854775807, CAPACITY),
		Footprint.REFUSE_SHAPE)


func test_brush_rim_zero_radius_and_negative_center() -> void:
	"""Disk inclusion uses integer squared distance, including exactly-on-radius cells."""
	var result: Dictionary = Footprint.brush(-1, -2, 1, CAPACITY)
	assert_true(result.ok, "brush rim zero radius and negative center")
	assert_equal(result.cells, PackedInt32Array([-1, -3, -2, -2, -1, -2, 0, -2, -1, -1]), "brush rim zero radius and negative center")
	assert_equal(Footprint.brush(4, 6, 0, CAPACITY).cells, PackedInt32Array([4, 6]), "brush rim zero radius and negative center")
	_expect_failure(Footprint.brush(0, 0, -1, CAPACITY), Footprint.REFUSE_SHAPE)
	_expect_failure(Footprint.brush(0, 0, 16384, CAPACITY), Footprint.REFUSE_SHAPE)
	_expect_failure(Footprint.brush(-9223372036854775807 - 1, 0, 1, CAPACITY), Footprint.REFUSE_COORDINATE)
	_expect_failure(Footprint.brush(0, 9223372036854775807, 1, CAPACITY), Footprint.REFUSE_COORDINATE)


func test_tunnel_straight_turns_and_single_point_route() -> void:
	"""The dedicated route tool preserves all legs and keeps a corner connected without a gap."""
	var points: PackedInt32Array = PackedInt32Array([0, 0, 3, 0, 3, 2])
	var result: Dictionary = Footprint.tunnel_path(points, 0, CAPACITY)
	assert_true(result.ok, "tunnel straight turns and single point route")
	assert_equal(result.cells, PackedInt32Array([0, 0, 1, 0, 2, 0, 3, 0, 3, 1, 3, 2]), "tunnel straight turns and single point route")
	assert_equal(Footprint.validation_error(result.cells, CAPACITY, false), Footprint.REFUSE_NONE, "tunnel straight turns and single point route")
	assert_equal(Footprint.tunnel_path(PackedInt32Array([2, 3]), 1, CAPACITY).cells,
		Footprint.brush(2, 3, 1, CAPACITY).cells, "tunnel straight turns and single point route")


func test_diagonal_tunnel_supercover_includes_both_corner_neighbors() -> void:
	"""A diagonal through exact corners does not leave diagonal-only connections or pinches."""
	var result: Dictionary = Footprint.tunnel_path(PackedInt32Array([0, 0, 2, 2]), 0, CAPACITY)
	assert_true(result.ok, "diagonal tunnel supercover includes both corner neighbors")
	assert_equal(result.cells, PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1, 2, 1, 1, 2, 2, 2]), "diagonal tunnel supercover includes both corner neighbors")
	assert_equal(Footprint.validation_error(result.cells, CAPACITY, false), Footprint.REFUSE_NONE, "diagonal tunnel supercover includes both corner neighbors")


func test_tunnel_reversal_and_nonuniform_slopes_preserve_identical_cells() -> void:
	"""Route direction cannot change width or choose a different dig ledger footprint."""
	for end_x: int in range(-5, 6):
		for end_z: int in range(-5, 6):
			var forward: Dictionary = Footprint.tunnel_path(PackedInt32Array([0, 0, end_x, end_z]), 1, CAPACITY)
			var backward: Dictionary = Footprint.tunnel_path(PackedInt32Array([end_x, end_z, 0, 0]), 1, CAPACITY)
			assert_true(forward.ok, "tunnel reversal and nonuniform slopes preserve identical cells")
			assert_equal(forward.cells, backward.cells, "reverse route at %d,%d" % [end_x, end_z])
			assert_equal(Footprint.validation_error(forward.cells, CAPACITY, false), Footprint.REFUSE_NONE, "tunnel reversal and nonuniform slopes preserve identical cells")


func test_tunnel_width_join_and_overlapping_route_do_not_duplicate_cells() -> void:
	"""Widening stamps all bends and junctions, with one canonical row per occupied cell."""
	var result: Dictionary = Footprint.tunnel_path(PackedInt32Array([0, 0, 2, 0, 2, 2, 2, 0]), 1, CAPACITY)
	assert_true(result.ok, "tunnel width join and overlapping route do not duplicate cells")
	assert_true(Footprint.contains_cell(result.cells, 2, -1), "tunnel width join and overlapping route do not duplicate cells")
	assert_true(Footprint.contains_cell(result.cells, 3, 0), "tunnel width join and overlapping route do not duplicate cells")
	assert_true(Footprint.contains_cell(result.cells, 3, 1), "tunnel width join and overlapping route do not duplicate cells")
	assert_true(Footprint.contains_cell(result.cells, 2, 3), "tunnel width join and overlapping route do not duplicate cells")
	assert_equal(Footprint.validation_error(result.cells, CAPACITY, false), Footprint.REFUSE_NONE, "tunnel width join and overlapping route do not duplicate cells")
	assert_equal(result.cells, Footprint.canonicalize(result.cells, CAPACITY).cells, "tunnel width join and overlapping route do not duplicate cells")


func test_tunnel_refuses_empty_malformed_huge_and_overflowing_routes() -> void:
	"""No route can trigger an unbounded scan or wrap around the signed coordinate range."""
	_expect_failure(Footprint.tunnel_path(PackedInt32Array(), 0, CAPACITY), Footprint.REFUSE_EMPTY)
	_expect_failure(Footprint.tunnel_path(PackedInt32Array([1]), 0, CAPACITY), Footprint.REFUSE_FORMAT)
	_expect_failure(Footprint.tunnel_path(PackedInt32Array([-2000000000, 0, 2000000000, 0]), 0, CAPACITY),
		Footprint.REFUSE_CAPACITY)
	_expect_failure(Footprint.tunnel_path(PackedInt32Array([2147483646, 0]), 1, CAPACITY),
		Footprint.REFUSE_COORDINATE)
	_expect_failure(Footprint.tunnel_path(PackedInt32Array([0, 0, 2, 0]), 0, 2), Footprint.REFUSE_CAPACITY)


func test_add_and_erase_are_deterministic_and_leave_inputs_unchanged() -> void:
	"""Brush order and overlapping additions cannot change the canonical footprint."""
	var base: PackedInt32Array = PackedInt32Array([1, 0, 0, 0])
	var paint: PackedInt32Array = PackedInt32Array([1, 1, 1, 0])
	var added: Dictionary = Footprint.combine(base, paint, false, CAPACITY)
	assert_true(added.ok, "add and erase are deterministic and leave inputs unchanged")
	assert_equal(added.cells, PackedInt32Array([0, 0, 1, 0, 1, 1]), "add and erase are deterministic and leave inputs unchanged")
	assert_equal(added.cells, Footprint.combine(paint, base, false, CAPACITY).cells, "add and erase are deterministic and leave inputs unchanged")
	assert_equal(Footprint.combine(added.cells, PackedInt32Array([0, 0]), true, CAPACITY).cells,
		PackedInt32Array([1, 0, 1, 1]), "add and erase are deterministic and leave inputs unchanged")
	assert_true(Footprint.combine(added.cells, added.cells, true, CAPACITY).cells.is_empty(), "add and erase are deterministic and leave inputs unchanged")
	assert_equal(base, PackedInt32Array([1, 0, 0, 0]), "add and erase are deterministic and leave inputs unchanged")
	assert_equal(paint, PackedInt32Array([1, 1, 1, 0]), "add and erase are deterministic and leave inputs unchanged")


func test_add_capacity_failure_and_erase_can_create_invalid_draft() -> void:
	"""Painting never clips excess cells; topology may be temporarily invalid while editing."""
	_expect_failure(Footprint.combine(PackedInt32Array([0, 0]), PackedInt32Array([1, 0]), false, 1),
		Footprint.REFUSE_CAPACITY)
	var result: Dictionary = Footprint.combine(Footprint.rectangle(0, 0, 3, 1, CAPACITY).cells,
		PackedInt32Array([1, 0]), true, CAPACITY)
	assert_true(result.ok, "add capacity failure and erase can create invalid draft")
	assert_equal(Footprint.validation_error(result.cells, CAPACITY, false), Footprint.REFUSE_DISCONNECTED, "add capacity failure and erase can create invalid draft")


func test_rotation_uses_grid_vertex_pivot_and_preserves_cell_area() -> void:
	"""Rotating the whole cell around (0,0) needs the minus-one offset, unlike rotating a point."""
	var cells: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 0, 1])
	assert_equal(Footprint.transform_cells(cells, 1, 0, 0, CAPACITY).cells,
		PackedInt32Array([-2, 0, -1, 0, -1, 1]), "rotation uses grid vertex pivot and preserves cell area")
	assert_equal(Footprint.transform_cells(cells, -1, 0, 0, CAPACITY).cells,
		PackedInt32Array([0, -2, 0, -1, 1, -1]), "rotation uses grid vertex pivot and preserves cell area")
	var result: Dictionary = Footprint.transform_cells(cells, 4, -3, 2, CAPACITY)
	assert_true(result.ok, "rotation uses grid vertex pivot and preserves cell area")
	assert_equal(result.cells, PackedInt32Array([-3, 2, -2, 2, -3, 3]), "rotation uses grid vertex pivot and preserves cell area")


func test_four_rotations_restore_original_without_drift() -> void:
	"""Concave geometry and negative cell coordinates survive a complete rotation cycle exactly."""
	var original: PackedInt32Array = PackedInt32Array([-2, -3, -1, -3, -2, -2])
	var cells: PackedInt32Array = original.duplicate()
	for turn: int in range(4):
		var result: Dictionary = Footprint.transform_cells(cells, 1, 0, 0, CAPACITY)
		assert_true(result.ok, "four rotations restore original without drift")
		cells = result.cells
	assert_equal(cells, original, "four rotations restore original without drift")
	_expect_failure(Footprint.transform_cells(original, 0, -2147483648, 0, CAPACITY),
		Footprint.REFUSE_COORDINATE)


func test_full_containment_rejects_concave_corner_hole_and_partial_item() -> void:
	"""Bounding-box or anchor-only placement would incorrectly accept all three refused items."""
	var room: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 0, 1])
	assert_true(Footprint.contains_all(room, PackedInt32Array([0, 0, 1, 0])), "full containment rejects concave corner hole and partial item")
	assert_false(Footprint.contains_all(room, PackedInt32Array([0, 1, 1, 1])), "full containment rejects concave corner hole and partial item")
	assert_false(Footprint.contains_all(_ring(), PackedInt32Array([1, 0, 1, 1])), "full containment rejects concave corner hole and partial item")
	assert_false(Footprint.contains_all(room, PackedInt32Array([1, 0, 2, 0])), "full containment rejects concave corner hole and partial item")
	assert_false(Footprint.contains_all(room, PackedInt32Array()), "full containment rejects concave corner hole and partial item")
	assert_false(Footprint.contains_all(room, PackedInt32Array([0])), "full containment rejects concave corner hole and partial item")
	assert_false(Footprint.contains_cell(room, -1, 0), "full containment rejects concave corner hole and partial item")


func test_boundary_edges_cancel_interior_walls_and_have_stable_order() -> void:
	"""A pair of cells has six outer edges and no duplicate shared wall."""
	var cells: PackedInt32Array = PackedInt32Array([0, 0, 1, 0])
	assert_equal(Footprint.boundary_edges(cells), PackedInt32Array([0, 0, 0, 0, 0, 2, 0, 0, 3,
		1, 0, 0, 1, 0, 1, 1, 0, 2]), "boundary edges cancel interior walls and have stable order")
	var loops: Array[PackedInt32Array] = Footprint.boundary_loops(cells)
	assert_equal(loops.size(), 1, "boundary edges cancel interior walls and have stable order")
	assert_equal(loops[0], PackedInt32Array([0, 0, 1, 0, 2, 0, 2, 1, 1, 1, 0, 1, 0, 0]), "boundary edges cancel interior walls and have stable order")
	assert_true(Footprint.boundary_edges(PackedInt32Array([1, 0, 0, 0])).is_empty(), "boundary edges cancel interior walls and have stable order")


func test_concave_boundary_exactly_matches_floor_area() -> void:
	"""Walls and the filled floor agree, including an inward corner rather than its bounding box."""
	var cells: PackedInt32Array = PackedInt32Array([-1, -1, 0, -1, -1, 0])
	var loops: Array[PackedInt32Array] = Footprint.boundary_loops(cells)
	assert_equal(loops.size(), 1, "concave boundary exactly matches floor area")
	assert_equal(loops[0], PackedInt32Array([-1, -1, 0, -1, 1, -1, 1, 0, 0, 0, 0, 1, -1, 1, -1, 0, -1, -1]), "concave boundary exactly matches floor area")
	assert_equal(_twice_area(loops[0]), 6, "concave boundary exactly matches floor area")


func test_boundary_corners_retain_int32_extremes_without_wrapping_neighbors() -> void:
	"""The far corner is legal INT32_MAX even though no cell can start there."""
	for coordinate: int in [-2147483648, 2147483646]:
		var cells: PackedInt32Array = PackedInt32Array([coordinate, coordinate])
		assert_equal(Footprint.validation_error(cells, CAPACITY, false), Footprint.REFUSE_NONE, "concave boundary exactly matches floor area")
		var loops: Array[PackedInt32Array] = Footprint.boundary_loops(cells)
		assert_equal(loops[0], PackedInt32Array([coordinate, coordinate, coordinate + 1, coordinate,
			coordinate + 1, coordinate + 1, coordinate, coordinate + 1, coordinate, coordinate]), "concave boundary exactly matches floor area")


func test_opening_descriptor_names_whole_boundary_edges() -> void:
	"""A reviewed width may span several cells but each must own the same exposed wall side."""
	var cells: PackedInt32Array = Footprint.rectangle(0, 0, 3, 2, CAPACITY).cells
	var north: Dictionary = Footprint.opening_edges(cells, 1, 0, Footprint.NORTH, 2)
	assert_true(north.ok, "opening descriptor names whole boundary edges")
	assert_equal(north.edges, PackedInt32Array([1, 0, 0, 2, 0, 0]), "opening descriptor names whole boundary edges")
	var east: Dictionary = Footprint.opening_edges(cells, 2, 0, Footprint.EAST, 2)
	assert_true(east.ok, "opening descriptor names whole boundary edges")
	assert_equal(east.edges, PackedInt32Array([2, 0, 1, 2, 1, 1]), "opening descriptor names whole boundary edges")
	assert_true(Footprint.opening_edges(cells, 0, 1, Footprint.SOUTH, 3).ok, "opening descriptor names whole boundary edges")
	assert_true(Footprint.opening_edges(cells, 0, 0, Footprint.WEST, 2).ok, "opening descriptor names whole boundary edges")


func test_opening_refuses_internal_edges_missing_cells_and_turning_runs() -> void:
	"""The full opening cannot run past a corner or accept a valid anchor with invalid width."""
	var cells: PackedInt32Array = Footprint.rectangle(0, 0, 3, 2, CAPACITY).cells
	for request: PackedInt32Array in [PackedInt32Array([0, 1, 0, 1]), PackedInt32Array([2, 0, 0, 2]),
		PackedInt32Array([3, 0, 0, 1]), PackedInt32Array([0, 0, 4, 1]), PackedInt32Array([0, 0, 0, 0])]:
		var result: Dictionary = Footprint.opening_edges(cells, request[0], request[1], request[2], request[3])
		assert_false(result.ok, "opening refuses internal edges missing cells and turning runs")
		assert_equal(result.error, Footprint.REFUSE_OPENING, "opening refuses internal edges missing cells and turning runs")
		assert_true(result.edges.is_empty(), "opening refuses internal edges missing cells and turning runs")
	var concave: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 0, 1])
	assert_false(Footprint.opening_edges(concave, 0, 0, Footprint.EAST, 2).ok, "opening refuses internal edges missing cells and turning runs")


func test_opening_runs_at_signed_coordinate_extremes() -> void:
	"""Boundary descriptors preserve extreme coordinates and refuse a run beyond their last cell."""
	var left: PackedInt32Array = PackedInt32Array([-2147483648, 0, -2147483647, 0])
	var right: PackedInt32Array = PackedInt32Array([2147483645, 0, 2147483646, 0])
	assert_true(Footprint.opening_edges(left, -2147483648, 0, Footprint.NORTH, 2).ok, "minimum coordinate fits")
	assert_true(Footprint.opening_edges(right, 2147483645, 0, Footprint.NORTH, 2).ok, "last legal cell fits")
	assert_false(Footprint.opening_edges(right, 2147483646, 0, Footprint.NORTH, 2).ok, "cannot overflow corner")
	assert_false(Footprint.opening_edges(right, 9223372036854775807, 0, Footprint.NORTH, 2).ok, "int64 overflow refused")


func test_world_mapping_takes_explicit_scale_and_origin() -> void:
	"""Fixed corners stay exact; changing a visual camera or material never changes these positions."""
	var result: Dictionary = Footprint.to_world_corners(PackedInt32Array([-1, -2, 0, 0, 2, 1]), 256, 1024, -512)
	assert_true(result.ok, "world mapping takes explicit scale and origin")
	assert_equal(result.points, PackedInt32Array([768, -1024, 1024, -512, 1536, -256]), "world mapping takes explicit scale and origin")
	assert_equal(Footprint.to_world_corners(PackedInt32Array([1, 1]), 1024, 0, 0).points,
		PackedInt32Array([1024, 1024]), "world mapping takes explicit scale and origin")


func test_world_mapping_refuses_overflow_and_invalid_scale_atomically() -> void:
	"""A far point cannot wrap, and no valid prefix escapes when a later point overflows."""
	for scale: int in [0, -1, 2147483648]:
		assert_false(Footprint.to_world_corners(PackedInt32Array([0, 0]), scale, 0, 0).ok, "world mapping refuses overflow and invalid scale atomically")
	var result: Dictionary = Footprint.to_world_corners(PackedInt32Array([0, 0, 2147483647, 0]), 2, 0, 0)
	assert_false(result.ok, "world mapping refuses overflow and invalid scale atomically")
	assert_equal(result.error, Footprint.REFUSE_WORLD, "world mapping refuses overflow and invalid scale atomically")
	assert_true(result.points.is_empty(), "world mapping refuses overflow and invalid scale atomically")
	assert_false(Footprint.to_world_corners(PackedInt32Array([0]), 1, 0, 0).ok, "world mapping refuses overflow and invalid scale atomically")
	assert_false(Footprint.to_world_corners(PackedInt32Array([0, 0]), 1, 2147483648, 0).ok, "world mapping refuses overflow and invalid scale atomically")


func test_all_three_by_three_shapes_have_conserved_boundary_area() -> void:
	"""Exhaustive small topology catches inner seams, missing edges and inconsistent hole winding."""
	for mask: int in range(1, 512):
		var cells: PackedInt32Array = _mask_cells(mask)
		var error: StringName = Footprint.validation_error(cells, CAPACITY, true)
		if error != Footprint.REFUSE_NONE:
			assert_true(error == Footprint.REFUSE_DISCONNECTED or error == Footprint.REFUSE_PINCH, "all three by three shapes have conserved boundary area")
			continue
		var area: int = 0
		var edge_count: int = 0
		for loop: PackedInt32Array in Footprint.boundary_loops(cells):
			area += _twice_area(loop)
			@warning_ignore("integer_division") var count: int = loop.size() / 2 - 1
			edge_count += count
			_assert_closed_cardinal(loop)
		assert_equal(area, cells.size(), "area matches every floor cell, mask %d" % mask)
		assert_equal(edge_count * 3, Footprint.boundary_edges(cells).size(), "all three by three shapes have conserved boundary area")


func test_large_room_does_not_inherit_twelve_cell_template_limit() -> void:
	"""Exercise the helper's full engineering limit with one large connected room."""
	var result: Dictionary = Footprint.rectangle(-64, -64, 128, 128, Footprint.MAX_OPERATION_CELLS)
	assert_true(result.ok, "large room does not inherit twelve cell template limit")
	assert_equal(result.cells.size(), 32768, "large room does not inherit twelve cell template limit")
	assert_equal(Footprint.validation_error(result.cells, Footprint.MAX_OPERATION_CELLS, false), Footprint.REFUSE_NONE, "large room does not inherit twelve cell template limit")
	assert_equal(Footprint.boundary_edges(result.cells).size(), 512 * 3, "large room does not inherit twelve cell template limit")
	assert_equal(_twice_area(Footprint.boundary_loops(result.cells)[0]), 32768, "large room does not inherit twelve cell template limit")


func _ring() -> PackedInt32Array:
	"""A 3x3 ring around one retained cell, in explicit canonical order."""
	return PackedInt32Array([0, 0, 1, 0, 2, 0, 0, 1, 2, 1, 0, 2, 1, 2, 2, 2])


func _expect_failure(result: Dictionary, error: StringName) -> void:
	"""Assert refusal includes an exact cause and no partial mutated result."""
	assert_false(result.ok, " expect failure")
	assert_equal(result.error, error, " expect failure")
	assert_true(result.cells.is_empty(), " expect failure")


func _twice_area(loop: PackedInt32Array) -> int:
	"""Independent integer shoelace oracle for small synthetic fixtures."""
	var area: int = 0
	for pair: int in range(0, loop.size() - 2, 2):
		area += loop[pair] * loop[pair + 3] - loop[pair + 2] * loop[pair + 1]
	return area


func _mask_cells(mask: int) -> PackedInt32Array:
	"""Read nine explicit bits as a row-major 3x3 test floor."""
	var cells: PackedInt32Array = PackedInt32Array()
	for index: int in range(9):
		if mask & (1 << index):
			@warning_ignore("integer_division") var z: int = index / 3
			cells.append_array(PackedInt32Array([index % 3, z]))
	return cells


func _assert_closed_cardinal(loop: PackedInt32Array) -> void:
	"""Boundary unit edges are closed, nonzero and never diagonal shortcuts through occupied cells."""
	assert_equal(loop[0], loop[loop.size() - 2], " assert closed cardinal")
	assert_equal(loop[1], loop[loop.size() - 1], " assert closed cardinal")
	for pair: int in range(0, loop.size() - 2, 2):
		assert_equal(absi(loop[pair + 2] - loop[pair]) + absi(loop[pair + 3] - loop[pair + 1]), 1, " assert closed cardinal")

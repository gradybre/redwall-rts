extends "res://test/framework/test_case.gd"
## Integer input boundary and actual village event qualification for direct-on-dirt room planning.

const Tool := preload("res://demo/burrow/modular_world_tool.gd")
const Overlay := preload("res://demo/burrow/modular_world_overlay.gd")
const Draft := preload("res://demo/burrow/modular_draft.gd")
const Editor := preload("res://demo/burrow/modular_editor.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")


func test_ray_pick_uses_exact_floor_and_nonzero_datum() -> void:
	"""Positive/negative cells have a common world origin, and two floors remain distinct."""
	var datum: Vector3i = Vector3i(1024, -2048, -1024)
	var hit: Tool.Pick = Tool.ray_pick(Vector3(1.125, 8, -0.875), Vector3.DOWN, datum, 256)
	assert_true(hit.ok, "finite downward ray")
	assert_equal(hit.cell, Vector2i.ZERO, "first cell centre")
	hit = Tool.ray_pick(Vector3(0.999, 8, -1.001), Vector3.DOWN, datum, 256)
	assert_equal(hit.cell, Vector2i(-1, -1), "negative positions floor rather than truncate")
	var upper: Tool.Pick = Tool.ray_pick(Vector3(0, 8, 0), Vector3(0, -1, 1), Vector3i.ZERO, 1024)
	var lower: Tool.Pick = Tool.ray_pick(Vector3(0, 8, 0), Vector3(0, -1, 1), Vector3i(0, -4096, 0), 1024)
	assert_equal(upper.cell, Vector2i(0, 8), "upper intersection")
	assert_equal(lower.cell, Vector2i(0, 12), "lower floor, same screen ray")


func test_invalid_rays_and_overflow_never_supply_an_accepted_cell() -> void:
	"""No horizon fallback, behind-camera hit or narrowed integer wrap is accepted."""
	for direction: Vector3 in [Vector3.UP, Vector3.RIGHT, Vector3(NAN, -1, 0), Vector3.INF]:
		assert_false(Tool.ray_pick(Vector3(0, 5, 0), direction, Vector3i.ZERO, 256).ok, "invalid ray")
	assert_false(Tool.ray_pick(Vector3(0, -5, 0), Vector3.DOWN, Vector3i.ZERO, 256).ok, "floor behind ray")
	assert_false(Tool.ray_pick(Vector3(1e20, 5, 0), Vector3.DOWN, Vector3i.ZERO, 1).ok, "coordinate overflow")
	assert_false(Tool.ray_pick(Vector3.ZERO, Vector3.DOWN, Vector3i.ZERO, 0).ok, "unbound pitch")


func test_overlay_preserves_exact_cells_and_caches_camera_independent_geometry() -> void:
	"""An L-shaped plan never fills the missing corner or drifts off its cell boundaries."""
	var overlay: Overlay = Overlay.new()
	assert_equal(overlay.configure(Vector3i(1024, -1280, -2048), 256, Rect2i(-8, -8, 16, 16), 8), &"", "bound")
	var cells: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 0, 1])
	assert_equal(overlay.refresh(cells, false), &"", "L-shaped cells")
	assert_equal(overlay._fill.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), 18, "two triangles per actual cell")
	assert_equal(overlay.world_corner(Vector2i(1, 1)), Vector3(1.25, -1.25, -1.75), "exact transformed corner")
	var mesh: Mesh = overlay._fill.mesh
	var draws: int = overlay.rebuilds
	overlay.refresh(cells, false)
	assert_equal(overlay._fill.mesh, mesh, "same geometry resource reused")
	assert_equal(overlay.rebuilds, draws, "no frame-driven mesh rebuild")
	overlay.refresh(cells, true)
	assert_equal(overlay._fill.mesh, mesh, "style-only refusal reuses the same clipped mesh")
	assert_equal(overlay.rebuilds, draws, "style-only refusal does not rebuild geometry")
	cells[0] = 7
	assert_equal(overlay._cells[0], 0, "caller cannot mutate retained preview")
	assert_equal(overlay.refresh(PackedInt32Array([999, 999]), false), &"WORLD_OVERLAY_BOUNDS", "explicit out-of-domain refusal")
	assert_equal(overlay._fill.mesh, mesh, "refusal does not install partial geometry")
	overlay.free()


func test_display_precision_and_grid_domain_are_explicit() -> void:
	"""A diagram cannot conceal a finer grid than the float32 world can actually draw."""
	var overlay: Overlay = Overlay.new()
	assert_equal(overlay.configure(Vector3i(2147483000, 0, 0), 1, Rect2i(0, 0, 16, 16), 8), &"WORLD_OVERLAY_PRECISION", "refuse lost low bits")
	assert_equal(overlay.configure(Vector3i(1073741824, 0, 0), 128, Rect2i(0, 0, 4, 4), 8), &"WORLD_OVERLAY_PRECISION", "exact corners but unpickable cell interiors are refused")
	overlay.free()
	var draft: Draft = Draft.new()
	assert_false(draft.grid_domain().configured, "unbound draft is explicit")
	draft.configure(2, 1, 256, 64, Rect2i(-4, -4, 8, 8), false)
	var domain: Dictionary = draft.grid_domain()
	domain.bounds = Rect2i()
	assert_equal(draft.grid_domain().bounds, Rect2i(-4, -4, 8, 8), "copied domain cannot mutate picking rules")


func test_direct_terrain_painting_uses_real_village_input_at_1280x720() -> void:
	"""Full event routing, camera/level alignment, GUI/modal interception and lost-capture recovery."""
	var output: Array = []
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://test/live/modular_world_live.gd", "--", "--size", "1280x720"]
	var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)
	var lines: PackedStringArray = "".join(PackedStringArray(output)).split("\n")
	var checks: int = 0
	var summary: bool = false
	for line: String in lines:
		if line.begins_with("LIVE "):
			checks += 1
			assert_true(line.contains(": PASS"), line)
		elif line.begins_with("LIVE-SUMMARY "):
			summary = line.get_slice(" ", 2) == "0"
		else:
			_assert_child_diagnostic(line)
	assert_true(summary and checks >= 30, "complete native event sequence ran")
	assert_equal(code, 0, "child completed cleanly")


func _assert_child_diagnostic(line: String) -> void:
	"""Only existing unstaged-asset notices are tolerated; script aborts and engine leaks fail."""
	if line.contains("SCRIPT ERROR") or line.begins_with("ERROR:") or line.begins_with("USER ERROR:") \
			or line.contains("ObjectDB instance") or line.contains("resources still in use at exit"):
		fail(line)
	elif line.begins_with("WARNING:") or line.begins_with("USER WARNING:"):
		assert_true(line == "WARNING: demo assets are not staged (tools/stage_demo_assets.py); running on placeholders" \
			or (line.begins_with("WARNING: sound cue ") and line.ends_with("; it plays silent until they are staged")), line)


func test_outline_contains_each_exposed_edge_once_and_no_interior_or_stray_segments() -> void:
	"""Check actual rendered endpoints independently of the boundary-triple representation."""
	var rounded: Dictionary = Footprint.rounded_rectangle(-7, -6, 8, 6, 2, 128)
	var shapes: Array[PackedInt32Array] = [PackedInt32Array([0, 0]),
		PackedInt32Array([0, 0, 1, 0, 0, 1]), rounded.cells]
	for cells: PackedInt32Array in shapes:
		var overlay: Overlay = Overlay.new()
		overlay.configure(Vector3i(1024, -1280, -2048), 256, Rect2i(-8, -8, 16, 16), 8)
		overlay.refresh(cells, false)
		var expected: Dictionary = _exposed_segments(overlay, cells)
		var vertices: PackedVector3Array = overlay._edge.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		assert_equal(vertices.size(), expected.size() * 2, "one segment per exposed edge")
		for at: int in range(0, vertices.size(), 2):
			var key: Array[Vector3] = _segment_key(vertices[at], vertices[at + 1])
			assert_true(expected.erase(key), "actual endpoints form a unique exposed unit edge")
		assert_true(expected.is_empty(), "all outer and concave edges are covered")
		overlay.free()


func _exposed_segments(overlay: Overlay, cells: PackedInt32Array) -> Dictionary:
	"""Count each full cell square's undirected edges; shared edges cancel in pairs."""
	var edges: Dictionary = {}
	for at: int in range(0, cells.size(), 2):
		var cell: Vector2i = Vector2i(cells[at], cells[at + 1])
		var corners: Array[Vector2i] = [cell, cell + Vector2i.RIGHT, cell + Vector2i.ONE, cell + Vector2i.DOWN]
		for side: int in range(4):
			var key: Array[Vector3] = _segment_key(overlay.world_corner(corners[side]),
				overlay.world_corner(corners[(side + 1) % 4]))
			if not edges.erase(key):
				edges[key] = true
	return edges


static func _segment_key(first: Vector3, second: Vector3) -> Array[Vector3]:
	"""Ignore line direction while retaining all exact world-coordinate endpoints."""
	var key: Array[Vector3] = [first, second]
	if second < first:
		key.reverse()
	return key


func test_replacing_draft_hides_old_geometry_and_cancels_only_its_own_gesture() -> void:
	"""A reused inspector must never cancel another room's draft or leave the old drag live."""
	var tool: Tool = _binding_fixture()
	var old: Draft = tool._draft
	tool._editor.world_press(Vector2i.ZERO)
	tool._captured = true
	var replacement: Draft = Draft.new()
	replacement.configure(1, 1, 256, 64, Rect2i(-4, -4, 8, 8), false)
	replacement.begin_stroke(Draft.RECTANGLE, Vector2i.ONE, 0, false)
	tool._editor.draft = replacement
	tool._process(0)
	assert_false(tool.overlay.visible, "replaced site cannot show old marks")
	assert_false(tool._can_draw(), "old adapter cannot draw into replacement")
	assert_false(old.drawing(), "only actually captured draft is cancelled")
	assert_true(replacement.drawing(), "replacement's own gesture is untouched")
	tool.free()


func test_reconfigured_grid_hides_stale_marks_without_rebinding_world_origin() -> void:
	"""Even an empty session cannot silently change pitch under an existing world adapter."""
	var tool: Tool = _binding_fixture()
	assert_true(tool.overlay.visible, "original binding visible")
	assert_equal(tool._draft.configure(2, 1, 512, 64, Rect2i(-4, -4, 8, 8), false), &"", "empty grid reconfigured")
	tool._process(0)
	assert_false(tool.overlay.visible, "stale grid hidden")
	assert_false(tool._can_draw(), "fresh world binding is required")
	tool.free()


func test_invalidated_view_provider_cancels_capture_instead_of_reusing_last_floor() -> void:
	"""The last valid visible floor is not permission after the live view owner goes away."""
	var tool: Tool = _binding_fixture()
	tool._editor.world_press(Vector2i.ZERO)
	tool._captured = true
	tool._read_view = Callable()
	tool._process(0)
	assert_false(tool._draft.drawing(), "view loss cancels the captured gesture")
	assert_false(tool.overlay.visible, "no stale last-floor preview")
	assert_false(tool._can_draw(), "no stale last-floor permission")
	tool.free()


func _binding_fixture() -> Tool:
	"""All nodes belong to the returned tool for explicit, leak-free teardown."""
	var tool: Tool = Tool.new()
	var camera: Camera3D = Camera3D.new()
	var editor: Editor = Editor.new()
	tool.add_child(camera)
	tool.add_child(editor)
	var draft: Draft = Draft.new()
	draft.configure(2, 1, 256, 64, Rect2i(-4, -4, 8, 8), false)
	editor.configure(draft, 4)
	assert_equal(tool.configure(camera, editor, Vector3i.ZERO, 8, _test_unblocked, _test_view), &"", "binding")
	tool.set_active(true)
	tool._process(0)
	return tool


static func _test_unblocked() -> bool:
	"""This isolated unit fixture has no modal owner; the real-village test does."""
	return false


static func _test_view() -> Vector3i:
	"""Explicit visible floor for binding-lifetime tests only."""
	return Vector3i(1, 0, 1)

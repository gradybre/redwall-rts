extends "res://test/framework/test_case.gd"
## Coverage for the container frame placement contract: `ui_frame_geometry.gd` + `ui_frame_builder.gd`.
##
## Two earlier attempts to apply these frames put the corners OUTSIDE their panels and left the
## edge strips invisible, and nothing in the suite noticed, because the suite only measured the
## art files. These tests measure PLACEMENT, in two independent layers:
##
##   * the arithmetic, through `Geometry.rects_into()`, at seven panel sizes per frame;
##   * the built Control tree, through `Builder.apply()`, read back rectangle by rectangle.
##
## The four properties that both failures violated each have their own test, and each is
## asserted for all five silhouettes at every size:
##
##   INSIDE      every piece lies within (0,0,W,H). The old code anchored a zero-sized piece on
##               the panel's right or bottom edge and let Control's minimum-size enforcement
##               inflate it outward, so three corners and two strips ended up beyond the panel.
##   AT CORNERS  the four corners touch the four corners exactly, at their declared extents.
##   BETWEEN     each strip starts where its corner ends and stops where the next begins, so no
##               strip is drawn underneath a corner motif. `PRESET_TOP_WIDE` spans the whole
##               panel and fails this.
##   NON-ZERO    no piece has a zero width or height. This is the one that catches an edge that
##               loads, is placed, and draws nothing.
##
## A fifth, THICKNESS, ties the arithmetic back to the art: an edge's cross-axis extent must
## equal its texture's cross-axis extent at every panel size, which is what proves the strip is
## scaled along its run only and never squashed across it.

const Geometry := preload("res://ui/ui_frame_geometry.gd")
const Builder := preload("res://ui/ui_frame_builder.gd")
const ART := preload("res://ui/ui_art.gd")

## Panel sizes every frame is placed at. Small enough to catch a frame that only works when
## there is room to spare, wide and tall enough to make stretching along one axis obvious.
const PANEL_SIZES: Array[Vector2] = [
	Vector2(120.0, 72.0), Vector2(200.0, 96.0), Vector2(300.0, 120.0),
	Vector2(640.0, 88.0), Vector2(1024.0, 96.0), Vector2(240.0, 600.0),
	Vector2(300.5, 120.5),
]

const MANIFEST_PATH: String = "res://ui/ui_art_manifest.json"

## The three sizes the review contact sheet uses, so the sheet and the suite agree.
const SHEET_SIZES: Array[Vector2] = [
	Vector2(132.0, 76.0), Vector2(300.0, 120.0), Vector2(760.0, 96.0),
]

var _panels: Array[Control] = []


func after_each() -> void:
	"""Free every panel built by a test, so no Control leaks into the next one."""
	for panel: Control in _panels:
		panel.free()
	_panels.clear()


func _panel(width: float, height: float) -> Control:
	"""A bare panel of a given size, tracked for teardown."""
	var panel: Panel = Panel.new()
	panel.size = Vector2(width, height)
	_panels.append(panel)
	return panel


func _rects_of(frame: int, panel_size: Vector2) -> Array[Rect2]:
	"""The eight computed rectangles, asserting that the frame was not refused."""
	var rects: Array[Rect2] = []
	assert_true(Geometry.rects_into(frame, panel_size, rects),
		"%s accepts %v" % [ART.FRAME_KEYS[frame], panel_size])
	return rects


# --- the declared numbers mean what the contract says they mean -------------------------

func test_the_edge_inset_is_a_cross_axis_thickness_not_a_square_extent() -> void:
	"""The misreading that started this: `FRAME_EDGE_INSET` used for both axes of a strip.

	The top strip's HEIGHT is the inset and its WIDTH is the run between the corners; a square
	of (inset, inset) is wrong on the long axis for every frame at every real panel size.
	"""
	for frame: int in Geometry.frame_count():
		var rects: Array[Rect2] = _rects_of(frame, Vector2(300.0, 120.0))
		var top: float = float(ART.frame_edge_inset(frame, Geometry.SIDE_TOP))
		var left: float = float(ART.frame_edge_inset(frame, Geometry.SIDE_LEFT))
		assert_almost_equal(rects[Geometry.PIECE_EDGE_TOP].size.y, top,
			"%s top strip is inset-thick" % ART.FRAME_KEYS[frame])
		assert_true(rects[Geometry.PIECE_EDGE_TOP].size.x > top * 2.0,
			"%s top strip is run-long, not inset-long" % ART.FRAME_KEYS[frame])
		assert_almost_equal(rects[Geometry.PIECE_EDGE_LEFT].size.x, left,
			"%s left strip is inset-thick" % ART.FRAME_KEYS[frame])
		assert_true(rects[Geometry.PIECE_EDGE_LEFT].size.y > left * 2.0,
			"%s left strip is run-long, not inset-long" % ART.FRAME_KEYS[frame])


func test_the_corner_extent_is_the_draw_size_of_its_own_source() -> void:
	"""Corners are blitted at their document size; a bound with bleed would misplace the edges."""
	for frame: int in Geometry.frame_count():
		var rects: Array[Rect2] = _rects_of(frame, Vector2(300.0, 120.0))
		for corner: int in 4:
			var piece: int = Geometry.PIECE_CORNER_TL + corner
			var declared: Vector2i = ART.frame_corner_size(frame, corner)
			var image: Image = ART.rasterise(Geometry.source_path_of(frame, piece),
				ART.optical_sizes_of(Geometry.registry_index_of(frame, piece))[0])
			assert_equal(image.get_size(), declared,
				"%s %s art is its declared extent"
				% [ART.FRAME_KEYS[frame], Geometry.PIECE_NAMES[piece]])
			assert_equal(rects[piece].size, Vector2(declared),
				"%s %s is placed at that extent"
				% [ART.FRAME_KEYS[frame], Geometry.PIECE_NAMES[piece]])


func test_each_piece_slot_maps_to_the_registry_asset_it_claims() -> void:
	"""Piece order must equal registry run order, or the builder loads the wrong art."""
	var suffix: Array[String] = ["EDGE_TOP", "EDGE_BOTTOM", "EDGE_LEFT", "EDGE_RIGHT",
		"CORNER_TL", "CORNER_TR", "CORNER_BL", "CORNER_BR"]
	for frame: int in Geometry.frame_count():
		for piece: int in Geometry.PIECE_COUNT:
			var id: String = String(ART.asset_id_of(Geometry.registry_index_of(frame, piece)))
			assert_true(id.ends_with(suffix[piece]),
				"%s piece %d is %s" % [ART.FRAME_KEYS[frame], piece, suffix[piece]])


# --- INSIDE ------------------------------------------------------------------------------

func test_every_piece_lies_inside_the_panel_rectangle() -> void:
	"""ART-UI-07. The first failure put three corners and two strips beyond the panel edge."""
	for frame: int in Geometry.frame_count():
		for panel_size: Vector2 in PANEL_SIZES:
			var rects: Array[Rect2] = _rects_of(frame, panel_size)
			for piece: int in Geometry.PIECE_COUNT:
				var rect: Rect2 = rects[piece]
				var inside: bool = rect.position.x >= 0.0 and rect.position.y >= 0.0 \
					and rect.end.x <= panel_size.x and rect.end.y <= panel_size.y
				assert_true(inside, "%s %s stays inside %v (got %s)"
					% [ART.FRAME_KEYS[frame], Geometry.PIECE_NAMES[piece], panel_size, rect])


# --- AT CORNERS --------------------------------------------------------------------------

func test_the_four_corners_sit_at_the_four_corners() -> void:
	"""Each corner touches the two panel edges it belongs to, at both extremes of the range."""
	for frame: int in Geometry.frame_count():
		for panel_size: Vector2 in PANEL_SIZES:
			var rects: Array[Rect2] = _rects_of(frame, panel_size)
			var key: StringName = ART.FRAME_KEYS[frame]
			assert_equal(rects[Geometry.PIECE_CORNER_TL].position, Vector2.ZERO,
				"%s top-left is at the origin" % key)
			assert_almost_equal(rects[Geometry.PIECE_CORNER_TR].end.x, panel_size.x,
				"%s top-right touches the right edge" % key)
			assert_almost_equal(rects[Geometry.PIECE_CORNER_TR].position.y, 0.0,
				"%s top-right touches the top edge" % key)
			assert_almost_equal(rects[Geometry.PIECE_CORNER_BL].position.x, 0.0,
				"%s bottom-left touches the left edge" % key)
			assert_almost_equal(rects[Geometry.PIECE_CORNER_BL].end.y, panel_size.y,
				"%s bottom-left touches the bottom edge" % key)
			assert_equal(rects[Geometry.PIECE_CORNER_BR].end, panel_size,
				"%s bottom-right touches both far edges" % key)


# --- BETWEEN -----------------------------------------------------------------------------

func test_each_strip_runs_exactly_between_the_two_corners_that_bracket_it() -> void:
	"""A strip spanning the full side draws under the corner motif at both ends."""
	for frame: int in Geometry.frame_count():
		for panel_size: Vector2 in PANEL_SIZES:
			var rects: Array[Rect2] = _rects_of(frame, panel_size)
			var key: StringName = ART.FRAME_KEYS[frame]
			_assert_span(rects[Geometry.PIECE_EDGE_TOP].position.x,
				rects[Geometry.PIECE_CORNER_TL].end.x, "%s top strip starts at TL" % key)
			_assert_span(rects[Geometry.PIECE_EDGE_TOP].end.x,
				rects[Geometry.PIECE_CORNER_TR].position.x, "%s top strip stops at TR" % key)
			_assert_span(rects[Geometry.PIECE_EDGE_BOTTOM].position.x,
				rects[Geometry.PIECE_CORNER_BL].end.x, "%s bottom strip starts at BL" % key)
			_assert_span(rects[Geometry.PIECE_EDGE_BOTTOM].end.x,
				rects[Geometry.PIECE_CORNER_BR].position.x, "%s bottom strip stops at BR" % key)
			_assert_span(rects[Geometry.PIECE_EDGE_LEFT].position.y,
				rects[Geometry.PIECE_CORNER_TL].end.y, "%s left strip starts at TL" % key)
			_assert_span(rects[Geometry.PIECE_EDGE_LEFT].end.y,
				rects[Geometry.PIECE_CORNER_BL].position.y, "%s left strip stops at BL" % key)
			_assert_span(rects[Geometry.PIECE_EDGE_RIGHT].position.y,
				rects[Geometry.PIECE_CORNER_TR].end.y, "%s right strip starts at TR" % key)
			_assert_span(rects[Geometry.PIECE_EDGE_RIGHT].end.y,
				rects[Geometry.PIECE_CORNER_BR].position.y, "%s right strip stops at BR" % key)


func _assert_span(actual: float, expected: float, message: String) -> void:
	"""One end of one strip meets one corner exactly."""
	assert_almost_equal(actual, expected, message)


func test_no_two_pieces_of_a_frame_overlap() -> void:
	"""Overlap would double-draw a relief band and darken it where it crosses."""
	for frame: int in Geometry.frame_count():
		for panel_size: Vector2 in PANEL_SIZES:
			var rects: Array[Rect2] = _rects_of(frame, panel_size)
			for a: int in Geometry.PIECE_COUNT:
				for b: int in range(a + 1, Geometry.PIECE_COUNT):
					assert_false(rects[a].intersection(rects[b]).get_area() > 0.0,
						"%s %s and %s do not overlap at %v" % [ART.FRAME_KEYS[frame],
							Geometry.PIECE_NAMES[a], Geometry.PIECE_NAMES[b], panel_size])


# --- NON-ZERO ----------------------------------------------------------------------------

func test_no_piece_is_zero_sized_at_any_accepted_panel_size() -> void:
	"""A placed but zero-sized strip is the exact shape of the second failure: it draws nothing."""
	for frame: int in Geometry.frame_count():
		for panel_size: Vector2 in PANEL_SIZES:
			var rects: Array[Rect2] = _rects_of(frame, panel_size)
			for piece: int in Geometry.PIECE_COUNT:
				assert_true(rects[piece].size.x > 0.0 and rects[piece].size.y > 0.0,
					"%s %s has a drawable size at %v (got %v)" % [ART.FRAME_KEYS[frame],
						Geometry.PIECE_NAMES[piece], panel_size, rects[piece].size])


# --- THICKNESS ---------------------------------------------------------------------------

func test_a_strip_is_scaled_along_its_run_only_and_never_across_it() -> void:
	"""Squashing a relief band across its thickness changes its apparent depth."""
	for frame: int in Geometry.frame_count():
		for piece: int in 4:
			var index: int = Geometry.registry_index_of(frame, piece)
			var image: Image = ART.rasterise(ART.source_path_of(index),
				ART.optical_sizes_of(index)[0])
			var horizontal: bool = piece < Geometry.PIECE_EDGE_LEFT
			for panel_size: Vector2 in PANEL_SIZES:
				var rect: Rect2 = _rects_of(frame, panel_size)[piece]
				var drawn: float = rect.size.y if horizontal else rect.size.x
				var authored: float = float(image.get_height() if horizontal
					else image.get_width())
				assert_almost_equal(drawn, authored, "%s %s keeps its authored thickness at %v"
					% [ART.FRAME_KEYS[frame], Geometry.PIECE_NAMES[piece], panel_size])


# --- refusal ------------------------------------------------------------------------------

func test_a_panel_too_small_for_its_own_corners_is_refused_by_name() -> void:
	"""Clamping would stack the two corners of a side on top of each other and report success."""
	for frame: int in Geometry.frame_count():
		var minimum: Vector2 = Geometry.minimum_size_of(frame)
		var narrow: Vector2 = Vector2(minimum.x - 1.0, minimum.y)
		var short: Vector2 = Vector2(minimum.x, minimum.y - 1.0)
		assert_equal(Geometry.refusal_for(frame, narrow), Geometry.REFUSE_PANEL_TOO_SMALL,
			"%s refuses a panel one pixel too narrow" % ART.FRAME_KEYS[frame])
		assert_equal(Geometry.refusal_for(frame, short), Geometry.REFUSE_PANEL_TOO_SMALL,
			"%s refuses a panel one pixel too short" % ART.FRAME_KEYS[frame])
		assert_equal(Geometry.refusal_for(frame, minimum), Geometry.REFUSE_NONE,
			"%s accepts its own minimum" % ART.FRAME_KEYS[frame])


func test_a_refused_call_leaves_the_output_array_untouched() -> void:
	"""No sentinel rectangle: a caller cannot mistake a refusal for a placement."""
	var rects: Array[Rect2] = []
	assert_false(Geometry.rects_into(0, Vector2(4.0, 4.0), rects),
		"a tiny panel is refused")
	assert_equal(rects.size(), 0, "the output array was not written")
	assert_false(Geometry.rects_into(Geometry.frame_count(), Vector2(300.0, 120.0), rects),
		"an unknown frame is refused")
	assert_equal(Geometry.refusal_for(-1, Vector2(300.0, 120.0)), Geometry.REFUSE_UNKNOWN_FRAME,
		"a negative frame index is named unknown")
	assert_false(Geometry.is_frame(Geometry.frame_count()), "the count itself is not a frame")
	assert_true(Geometry.is_piece(Geometry.PIECE_CORNER_BR), "the last corner is a piece")
	assert_false(Geometry.is_piece(Geometry.PIECE_COUNT), "the count itself is not a piece")


func test_the_minimum_size_is_both_corner_pairs_plus_one_run_pixel() -> void:
	"""Stated independently of the implementation, for all five silhouettes."""
	var expected: Array[Vector2] = [Vector2(37.0, 37.0), Vector2(33.0, 33.0),
		Vector2(37.0, 37.0), Vector2(27.0, 33.0), Vector2(45.0, 45.0)]
	for frame: int in Geometry.frame_count():
		assert_equal(Geometry.minimum_size_of(frame), expected[frame],
			"%s minimum size" % ART.FRAME_KEYS[frame])


# --- the built Control tree ----------------------------------------------------------------

func test_apply_builds_eight_named_decorative_pieces_inside_the_panel() -> void:
	"""The whole point: one call, eight pieces, every one of them inside and drawable."""
	for frame: int in Geometry.frame_count():
		var panel: Control = _panel(300.0, 120.0)
		assert_true(Builder.apply(panel, frame), "%s applies" % ART.FRAME_KEYS[frame])
		var holder: Control = panel.get_node(NodePath(Builder.HOLDER_NAME)) as Control
		assert_equal(holder.get_child_count(), Geometry.PIECE_COUNT, "eight pieces")
		for piece: int in Geometry.PIECE_COUNT:
			var built: Control = holder.get_child(piece) as Control
			assert_equal(built.name, StringName(Geometry.PIECE_NAMES[piece]), "piece name")
			assert_true(built.size.x > 0.0 and built.size.y > 0.0,
				"%s %s is drawable" % [ART.FRAME_KEYS[frame], built.name])
			assert_true(built.position.x >= 0.0 and built.position.y >= 0.0
				and built.position.x + built.size.x <= panel.size.x
				and built.position.y + built.size.y <= panel.size.y,
				"%s %s is inside the panel" % [ART.FRAME_KEYS[frame], built.name])


func test_the_built_rectangles_equal_the_computed_rectangles_at_every_sheet_size() -> void:
	"""The node tree and the arithmetic are the same contract, or the sheet proves nothing."""
	for frame: int in Geometry.frame_count():
		for panel_size: Vector2 in SHEET_SIZES:
			var panel: Control = _panel(panel_size.x, panel_size.y)
			assert_true(Builder.apply(panel, frame), "%s applies at %v"
				% [ART.FRAME_KEYS[frame], panel_size])
			var holder: Control = panel.get_node(NodePath(Builder.HOLDER_NAME)) as Control
			var rects: Array[Rect2] = _rects_of(frame, panel_size)
			for piece: int in Geometry.PIECE_COUNT:
				var built: Control = holder.get_child(piece) as Control
				assert_equal(built.get_rect(), rects[piece],
					"%s %s built rect" % [ART.FRAME_KEYS[frame], built.name])


func test_every_built_piece_is_decorative_and_unreachable() -> void:
	"""ART-UI-08: ornament never takes a click, a tab stop or an accessibility announcement."""
	var panel: Control = _panel(300.0, 120.0)
	assert_true(Builder.apply(panel, Builder.FRAME_RESOURCE_TRAY), "the tray applies")
	var holder: Control = panel.get_node(NodePath(Builder.HOLDER_NAME)) as Control
	var controls: Array[Control] = [holder]
	for piece: int in Geometry.PIECE_COUNT:
		controls.append(holder.get_child(piece) as Control)
	for control: Control in controls:
		assert_equal(control.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s ignores the mouse" % control.name)
		assert_equal(control.focus_mode, Control.FOCUS_NONE,
			"%s cannot take focus" % control.name)
		assert_equal(control.accessibility_name, "",
			"%s is not announced" % control.name)


func test_the_built_pieces_carry_the_texture_of_their_declared_source() -> void:
	"""A piece drawn from the wrong source would pass every rectangle test in this file."""
	for frame: int in Geometry.frame_count():
		var panel: Control = _panel(300.0, 120.0)
		assert_true(Builder.apply(panel, frame), "%s applies" % ART.FRAME_KEYS[frame])
		var holder: Control = panel.get_node(NodePath(Builder.HOLDER_NAME)) as Control
		for piece: int in Geometry.PIECE_COUNT:
			var built: TextureRect = holder.get_child(piece) as TextureRect
			assert_equal(built.texture.resource_path, Geometry.source_path_of(frame, piece),
				"%s %s draws its own source" % [ART.FRAME_KEYS[frame], built.name])
			assert_equal(built.expand_mode, TextureRect.EXPAND_IGNORE_SIZE,
				"%s %s takes no minimum size from its texture"
				% [ART.FRAME_KEYS[frame], built.name])


func test_the_frame_follows_the_panel_through_a_relayout() -> void:
	"""A responsive profile change resizes the panel; the frame must not stay at the old size.

	Driven through `NOTIFICATION_RESIZED`, which is exactly what the engine issues in a live
	tree. `Control.set_size()` only runs `_size_changed()` while inside a tree, so `resized`
	is never emitted under `--script` and the signal alone cannot be observed here.
	"""
	var panel: Control = _panel(300.0, 120.0)
	assert_true(Builder.apply(panel, Builder.FRAME_COMMAND_DOCK), "the dock applies")
	var holder: Control = panel.get_node(NodePath(Builder.HOLDER_NAME)) as Control
	panel.size = Vector2(900.0, 140.0)
	panel.notification(Control.NOTIFICATION_RESIZED)
	var rects: Array[Rect2] = _rects_of(Builder.FRAME_COMMAND_DOCK, Vector2(900.0, 140.0))
	assert_equal(holder.size, Vector2(900.0, 140.0), "the holder tracked the panel")
	for piece: int in Geometry.PIECE_COUNT:
		assert_equal((holder.get_child(piece) as Control).get_rect(), rects[piece],
			"%s moved with the panel" % Geometry.PIECE_NAMES[piece])


func test_refresh_brings_an_off_tree_frame_up_to_date_without_rebuilding_it() -> void:
	"""The explicit door for a caller that resizes a panel where `resized` cannot fire."""
	var panel: Control = _panel(300.0, 120.0)
	assert_false(Builder.refresh(panel), "an undressed panel has nothing to refresh")
	assert_true(Builder.apply(panel, Builder.FRAME_MAP_FOLIO), "the folio applies")
	var holder: Control = panel.get_node(NodePath(Builder.HOLDER_NAME)) as Control
	var before: Control = holder.get_child(Geometry.PIECE_CORNER_BR) as Control
	panel.size = Vector2(640.0, 200.0)
	assert_true(Builder.refresh(panel), "the applied frame refreshes")
	assert_equal(holder.get_child_count(), Geometry.PIECE_COUNT, "no piece was rebuilt")
	assert_true(holder.get_child(Geometry.PIECE_CORNER_BR) == before, "the same node moved")
	var rects: Array[Rect2] = _rects_of(Builder.FRAME_MAP_FOLIO, Vector2(640.0, 200.0))
	assert_equal(before.get_rect(), rects[Geometry.PIECE_CORNER_BR],
		"the bottom-right corner is at the new far corner")


func test_a_panel_shrunk_below_the_minimum_hides_the_frame_rather_than_clamping_it() -> void:
	"""A clamped frame stacks two corners and still reports itself as applied."""
	var panel: Control = _panel(300.0, 120.0)
	assert_true(Builder.apply(panel, Builder.FRAME_COMMAND_DOCK), "the dock applies")
	var holder: Control = panel.get_node(NodePath(Builder.HOLDER_NAME)) as Control
	assert_true(holder.visible, "the frame is shown at a size that fits")
	panel.size = Vector2(20.0, 20.0)
	assert_true(Builder.refresh(panel), "the frame is refreshed at the smaller size")
	assert_false(holder.visible, "the frame hides when the panel cannot hold its corners")
	panel.size = Vector2(300.0, 120.0)
	assert_true(Builder.refresh(panel), "the frame is refreshed at the larger size")
	assert_true(holder.visible, "the frame returns when there is room again")


func test_apply_refuses_instead_of_building_something_wrong() -> void:
	"""No half-built holder is ever left on a panel that was refused."""
	var panel: Control = _panel(20.0, 20.0)
	assert_false(Builder.apply(panel, Builder.FRAME_RESOURCE_TRAY),
		"a panel too small is refused")
	assert_false(Builder.has_frame(panel), "nothing was added to the refused panel")
	var wide: Control = _panel(300.0, 120.0)
	assert_false(Builder.apply(wide, Geometry.frame_count()), "an unknown frame is refused")
	assert_false(Builder.has_frame(wide), "nothing was added for the unknown frame")
	assert_false(Builder.apply(null, Builder.FRAME_JOURNAL), "a null panel is refused")


func test_applying_twice_replaces_the_frame_rather_than_stacking_it() -> void:
	"""A relayout that re-applies must not leave two frames drawing over each other."""
	var panel: Control = _panel(300.0, 120.0)
	assert_true(Builder.apply(panel, Builder.FRAME_JOURNAL), "the journal applies")
	assert_true(Builder.apply(panel, Builder.FRAME_MAP_FOLIO), "the folio replaces it")
	assert_equal(panel.get_child_count(), 1, "exactly one holder")
	var holder: Control = panel.get_node(NodePath(Builder.HOLDER_NAME)) as Control
	assert_equal(holder.get_child_count(), Geometry.PIECE_COUNT, "eight pieces, not sixteen")
	var built: TextureRect = holder.get_child(Geometry.PIECE_CORNER_TL) as TextureRect
	assert_equal(built.texture.resource_path,
		Geometry.source_path_of(Builder.FRAME_MAP_FOLIO, Geometry.PIECE_CORNER_TL),
		"the surviving frame is the folio")


func test_the_manifest_records_the_placement_contract_and_agrees_with_the_code() -> void:
	"""A bare pair of integers cannot say which axis it means; the manifest now says so.

	If the manifest's minimum panel sizes drift from `minimum_size_of()`, the recorded
	contract has stopped describing the code that implements it, which is the drift ART-UI-11
	exists to prevent.
	"""
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(document is Dictionary, "the manifest parses")
	var placement: Dictionary = (document as Dictionary).get("frame_placement", {}) as Dictionary
	assert_true(FileAccess.file_exists(placement.get("owner", "") as String),
		"the manifest names a placement owner that exists")
	assert_true(FileAccess.file_exists(placement.get("builder", "") as String),
		"the manifest names a builder that exists")
	var frames: Array = (document as Dictionary).get("frames", []) as Array
	assert_equal(frames.size(), Geometry.frame_count(), "one manifest row per silhouette")
	for frame: int in Geometry.frame_count():
		var row: Dictionary = frames[frame] as Dictionary
		var recorded: Array = row["minimum_panel_size"] as Array
		assert_equal(Vector2(float(recorded[0]), float(recorded[1])),
			Geometry.minimum_size_of(frame),
			"%s minimum panel size matches the code" % row["id"])
		assert_equal(row["stretch_margins_trbl"][Geometry.SIDE_LEFT],
			ART.frame_edge_inset(frame, Geometry.SIDE_LEFT),
			"%s left margin matches the registry" % row["id"])


func test_the_journal_places_its_asymmetric_pieces_on_the_correct_sides() -> void:
	"""The one silhouette where a symmetric placement would still look almost right."""
	var frame: int = Builder.FRAME_JOURNAL
	var rects: Array[Rect2] = _rects_of(frame, Vector2(300.0, 120.0))
	assert_almost_equal(rects[Geometry.PIECE_EDGE_LEFT].size.x, 12.0, "the spine side is 12 wide")
	assert_almost_equal(rects[Geometry.PIECE_EDGE_RIGHT].size.x, 5.0, "the fore-edge is 5 wide")
	assert_equal(rects[Geometry.PIECE_CORNER_TL].size, Vector2(12.0, 16.0), "the spine cap")
	assert_equal(rects[Geometry.PIECE_CORNER_TR].size, Vector2(14.0, 14.0), "the page corner")
	assert_almost_equal(rects[Geometry.PIECE_EDGE_LEFT].position.y, 16.0,
		"the spine strip starts below the spine cap, not below the page corner")
	assert_almost_equal(rects[Geometry.PIECE_EDGE_RIGHT].position.y, 14.0,
		"the fore-edge strip starts below the page corner")

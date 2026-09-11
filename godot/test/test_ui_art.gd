extends "res://test/framework/test_case.gd"
## Coverage for the ART-UI woodland art family: `godot/ui/ui_art.gd` and its SVG sources.
##
## These tests rasterise the real SVG through the same ThorVG path the Godot importer uses,
## so what is measured here is what the game will draw -- not what the file claims. That
## matters for three checks in particular, which are the ones a "looks fine to me" review
## cannot make:
##
##   * the SEPARATION KEYLINE check walks the outermost solid pixel of every painted icon
##     and requires it to clear 3:1 against the surface the icon sits on. ART-LOCK-001 4
##     makes that keyline the declared mechanism -- I04 cream on FOREST, the I01 ink
##     contour alone on JOURNAL -- so this is the check that a soft watercolour edge has
##     not quietly replaced it;
##   * the PAINTED check counts distinct quantised colours, so a painted object icon that
##     quietly regressed into an enlarged monochrome line icon fails;
##   * the STRETCHABLE EDGE check requires every column of a horizontal edge strip to be
##     identical to its first column (and every row of a vertical one). That is what makes
##     the strip stretchable without a seam, and it is invisible to the eye until a panel
##     is resized in front of a player.

const ART: GDScript = preload("res://ui/ui_art.gd")
const THEME: GDScript = preload("res://scripts/ui/ui_theme.gd")

const PANEL: Color = Color("#1E3028")
const PAPER: Color = Color("#EAE1C8")
const MANIFEST_PATH: String = "res://ui/ui_art_manifest.json"

## §2.1: "functional icons/boundaries >= 3:1".
const FUNCTIONAL_CONTRAST: float = 3.0
## The share of boundary pixels that must clear the contract. It is not 1.0 because a
## diagonal edge antialiases the keyline against the surface at the extreme corners of a
## 24 px grid; it is high enough that dropping the keyline from one icon fails the suite.
const BOUNDARY_SHARE: float = 0.92
## ART-LOCK-001 4: at 24 px every visible pixel fits a 22x22 box centred in the canvas.
const SAFE_INSET: int = 1
## Alpha at which a pixel is counted as drawn rather than as surround.
const VISIBLE_ALPHA: float = 0.60
## Distinct tones required strictly INSIDE an icon's body, away from its contour and its
## antialiased edge. Counting every opaque pixel instead would pass a flat-filled shape,
## because an ink contour and a cast shadow supply tones of their own -- that exact
## mutation survived an earlier version of this check. The delivered family measures 26 to
## 77 interior tones; the same family flat-filled measures 15, so the bar sits at 22.
const PAINTED_COLOUR_MINIMUM: int = 22
## Quantisation step for that count: 16 levels per channel, so antialiasing alone cannot
## inflate the tally into a pass.
const COLOUR_LEVELS: int = 16

var _alpha_threshold: float = 0.5


# --- the registry itself ----------------------------------------------------------------

func test_every_declared_asset_has_a_source_that_exists() -> void:
	"""A path that no longer resolves would leave a control blank with no error."""
	assert_true(ART.asset_count() > 0, "the registry declares assets")
	for index: int in ART.asset_count():
		var path: String = ART.source_path_of(index)
		assert_true(FileAccess.file_exists(path),
			"%s source %s exists" % [ART.asset_id_of(index), path])


func test_every_asset_id_is_unique_and_namespaced() -> void:
	"""Stable IDs are what a manifest and a screenshot record refer to; duplicates break both."""
	var seen: Dictionary = {}
	for index: int in ART.asset_count():
		var id: String = String(ART.asset_id_of(index))
		assert_false(seen.has(id), "%s appears once" % id)
		assert_true(id.begins_with("ART."), "%s is namespaced" % id)
		seen[id] = true
	assert_equal(seen.size(), ART.asset_count(), "every asset has its own ID")


func test_the_registry_columns_are_the_same_length() -> void:
	"""A short column would silently shift every asset after the gap onto the wrong path."""
	assert_equal(ART.ASSET_PATH.size(), ART.ASSET_ID.size(), "one path per ID")
	assert_equal(ART.ASSET_CATEGORY.size(), ART.ASSET_ID.size(), "one category per ID")
	var declared: int = 0
	for index: int in ART.asset_count():
		declared += ART.optical_sizes_of(index).size()
	assert_equal(ART.OPTICAL_SIZE.size(), declared,
		"the flat optical-size column holds exactly the declared runs")


func test_an_undeclared_id_is_refused_rather_than_resolved() -> void:
	"""There is no index-or-minus-one lookup; an unknown name gets a plain false."""
	assert_true(ART.has_asset_id(&"ART.RES.FOOD_READY"), "a declared ID is known")
	assert_false(ART.has_asset_id(&"ART.RES.CHEESE"), "an undeclared ID is refused")


func test_every_category_is_declared_and_named() -> void:
	"""An asset in an unnamed category would drop out of the manifest and the sheets."""
	assert_equal(ART.CATEGORY_KEYS.size(), ART.CATEGORY_COUNT, "every category is named")
	for index: int in ART.asset_count():
		var category: int = ART.category_of(index)
		assert_true(category >= 0 and category < ART.CATEGORY_COUNT,
			"%s has a declared category" % ART.asset_id_of(index))


# --- what the art actually rasterises to -------------------------------------------------

func test_every_asset_rasterises_at_every_declared_optical_size() -> void:
	"""The declared size is the delivered size: a 24 px entry must produce 24 real pixels."""
	for index: int in ART.asset_count():
		for size: int in ART.optical_sizes_of(index):
			var image: Image = ART.rasterise(ART.source_path_of(index), size)
			assert_not_null(image, "%s renders at %d" % [ART.asset_id_of(index), size])
			if image != null:
				assert_equal(image.get_width(), size,
					"%s is %d wide at its %d entry" % [ART.asset_id_of(index), size, size])


func test_a_missing_or_unparseable_source_returns_null_not_a_blank_image() -> void:
	"""A blank Image would look like a legitimately empty asset. Refuse instead."""
	assert_null(ART.rasterise("res://ui/painted/no_such_icon.svg", 24),
		"a missing source is refused")
	assert_null(ART.rasterise("res://ui/ui_art.gd", 24),
		"a file that is not an SVG document is refused")


func test_painted_icons_carry_a_separation_keyline_on_forest() -> void:
	"""The outer edge of every FOREST object icon must clear 3:1 over PANEL. See the header."""
	for index: int in ART.asset_count():
		var category: int = ART.category_of(index)
		if category != ART.CATEGORY_PAINTED_RESOURCE \
				and category != ART.CATEGORY_PAINTED_COMMAND:
			continue
		var image: Image = ART.rasterise(ART.source_path_of(index), 24)
		var share: float = _boundary_share(image, PANEL)
		assert_true(share >= BOUNDARY_SHARE,
			"%s keeps its I04 keyline over PANEL on %.0f%% of its outline (needs %.0f%%)"
			% [ART.asset_id_of(index), share * 100.0, BOUNDARY_SHARE * 100.0])


func test_painted_icons_stay_inside_the_lock_safe_box() -> void:
	"""ART-LOCK-001 4: keyline, art and cast shadow all fit a 22x22 box inside the 24 px grid."""
	for index: int in ART.asset_count():
		var category: int = ART.category_of(index)
		if category != ART.CATEGORY_PAINTED_RESOURCE \
				and category != ART.CATEGORY_PAINTED_COMMAND:
			continue
		var used: Rect2i = ART.rasterise(ART.source_path_of(index), 24).get_used_rect()
		assert_true(used.position.x >= SAFE_INSET and used.position.y >= SAFE_INSET
				and used.end.x <= 24 - SAFE_INSET and used.end.y <= 24 - SAFE_INSET,
			"%s occupies %s, inside the 22x22 safe box" % [ART.asset_id_of(index), used])


func test_painted_icons_actually_occupy_their_grid() -> void:
	"""A near-empty file would pass a colour count and a contrast share on a handful of pixels."""
	for index: int in ART.asset_count():
		var category: int = ART.category_of(index)
		if category != ART.CATEGORY_PAINTED_RESOURCE \
				and category != ART.CATEGORY_PAINTED_COMMAND:
			continue
		var image: Image = ART.rasterise(ART.source_path_of(index), 24)
		assert_true(_opaque_pixels(image) >= 150,
			"%s covers a real part of its 24x24 grid (%d px)"
			% [ART.asset_id_of(index), _opaque_pixels(image)])


func test_painted_icons_are_painted_and_not_enlarged_line_glyphs() -> void:
	"""ART-UI-03's whole point: object form with modelled light, not a bigger monochrome stroke."""
	for index: int in ART.asset_count():
		var category: int = ART.category_of(index)
		if category != ART.CATEGORY_PAINTED_RESOURCE \
				and category != ART.CATEGORY_PAINTED_COMMAND:
			continue
		var count: int = _interior_colours(ART.rasterise(ART.source_path_of(index), 32))
		assert_true(count >= PAINTED_COLOUR_MINIMUM,
			"%s carries %d distinct tones inside its body (needs %d)"
			% [ART.asset_id_of(index), count, PAINTED_COLOUR_MINIMUM])


func test_species_medallions_read_on_paper_and_differ_from_one_another() -> void:
	"""Four emblems that rasterise identically would be one emblem reused four times."""
	var digests: Dictionary = {}
	for index: int in ART.asset_count():
		if ART.category_of(index) != ART.CATEGORY_EMBLEM:
			continue
		var image: Image = ART.rasterise(ART.source_path_of(index),
			ART.optical_sizes_of(index)[0])
		assert_true(_boundary_share(image, PAPER) >= BOUNDARY_SHARE,
			"%s's roundel contour reads against PAPER" % ART.asset_id_of(index))
		var digest: String = String(Marshalls.raw_to_base64(image.get_data().compress()))
		assert_false(digests.has(digest),
			"%s is its own drawing, not a copy of %s"
			% [ART.asset_id_of(index), digests.get(digest, "")])
		digests[digest] = String(ART.asset_id_of(index))
	assert_equal(digests.size(), 8, "four founding species at two optical sizes each")


func test_functional_glyphs_stay_simple_and_monochrome() -> void:
	"""ART-UI-05: a painted mark would be unreadable at the 12 px a state mark is drawn at."""
	for index: int in ART.asset_count():
		if ART.category_of(index) != ART.CATEGORY_SYMBOLIC_CONTROL:
			continue
		var count: int = _distinct_colours(ART.rasterise(ART.source_path_of(index), 24))
		assert_true(count <= 3,
			"%s is a simple optical glyph, not artwork (%d tones)"
			% [ART.asset_id_of(index), count])


func test_painted_icons_have_a_transparent_surround() -> void:
	"""An opaque tile would paint a square over whatever token background it sits on."""
	for index: int in ART.asset_count():
		var category: int = ART.category_of(index)
		if category != ART.CATEGORY_PAINTED_RESOURCE \
				and category != ART.CATEGORY_PAINTED_COMMAND \
				and category != ART.CATEGORY_SYMBOLIC_NARROW:
			continue
		var image: Image = ART.rasterise(ART.source_path_of(index), 24)
		var last: int = image.get_width() - 1
		assert_true(image.get_pixel(0, 0).a < 0.05 and image.get_pixel(last, 0).a < 0.05,
			"%s leaves its top corners clear" % ART.asset_id_of(index))
		assert_true(image.get_pixel(0, last).a < 0.05,
			"%s leaves its bottom-left corner clear" % ART.asset_id_of(index))


# --- panel silhouettes -------------------------------------------------------------------

func test_every_frame_edge_is_stretchable_without_a_seam() -> void:
	"""A constant profile is the whole reason edge art may be scaled. See the header."""
	for index: int in ART.asset_count():
		if ART.category_of(index) != ART.CATEGORY_FRAME_EDGE:
			continue
		var image: Image = ART.rasterise(ART.source_path_of(index),
			ART.optical_sizes_of(index)[0])
		assert_true(_is_constant_along_run(image),
			"%s is constant along the axis it stretches on" % ART.asset_id_of(index))


func test_frame_edge_thickness_matches_the_declared_stretch_margin() -> void:
	"""A margin that does not match the art puts ornament through text or leaves a gap."""
	var side_of_piece: PackedInt32Array = PackedInt32Array([0, 2, 3, 1])
	for frame: int in ART.frame_count():
		for piece: int in 4:
			var index: int = ART.frame_first_asset(frame) + piece
			var image: Image = ART.rasterise(ART.source_path_of(index),
				ART.optical_sizes_of(index)[0])
			var thickness: int = image.get_height() if piece < 2 else image.get_width()
			assert_equal(thickness, ART.frame_edge_inset(frame, side_of_piece[piece]),
				"%s is as thick as its declared margin" % ART.asset_id_of(index))


func test_frame_corners_render_at_their_declared_extent() -> void:
	"""Corners never stretch, so a corner whose art is the wrong size shifts the whole edge."""
	for frame: int in ART.frame_count():
		for corner: int in 4:
			var index: int = ART.frame_first_asset(frame) + 4 + corner
			var image: Image = ART.rasterise(ART.source_path_of(index),
				ART.optical_sizes_of(index)[0])
			var declared: Vector2i = ART.frame_corner_size(frame, corner)
			assert_equal(image.get_size(), declared,
				"%s renders at its declared extent" % ART.asset_id_of(index))


func test_the_five_silhouettes_are_actually_different_outlines() -> void:
	"""ART-UI-02 forbids giving every container the same rounded rectangle."""
	var outlines: Dictionary = {}
	for frame: int in ART.frame_count():
		var index: int = ART.frame_first_asset(frame) + 4
		var image: Image = ART.rasterise(ART.source_path_of(index),
			ART.optical_sizes_of(index)[0])
		var signature: String = _alpha_signature(image)
		assert_false(outlines.has(signature),
			"%s has its own top-left outline, unlike %s"
			% [ART.FRAME_KEYS[frame], outlines.get(signature, "")])
		outlines[signature] = String(ART.FRAME_KEYS[frame])
	assert_equal(outlines.size(), ART.frame_count(), "five distinct silhouettes")


func test_each_frame_run_starts_where_the_registry_says_it_does() -> void:
	"""The run table is hand-written; a wrong entry would test the wrong silhouette."""
	var expected: PackedStringArray = PackedStringArray([
		"ART.FRAME.TRAY.EDGE_TOP", "ART.FRAME.TIME.EDGE_TOP", "ART.FRAME.FOLIO.EDGE_TOP",
		"ART.FRAME.JOURNAL.EDGE_TOP", "ART.FRAME.DOCK.EDGE_TOP"])
	for frame: int in ART.frame_count():
		assert_equal(String(ART.asset_id_of(ART.frame_first_asset(frame))), expected[frame],
			"%s's run starts at its top edge" % ART.FRAME_KEYS[frame])


func test_the_journal_declares_a_bound_side_wider_than_its_fore_edge() -> void:
	"""The journal is the one silhouette whose margins are deliberately asymmetric."""
	var journal: int = 3
	assert_true(ART.frame_edge_inset(journal, 3) > ART.frame_edge_inset(journal, 1),
		"the spine side is wider than the paper fore-edge")
	assert_equal(ART.frame_corner_size(journal, 0), Vector2i(12, 16),
		"the spine cap keeps its own extent")


# --- provenance and the token contract ---------------------------------------------------

func test_the_manifest_matches_the_sources_on_disk() -> void:
	"""ART-UI-11 asks for provenance that cannot drift from the art it describes."""
	var text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	assert_true(text.length() > 0, "the manifest exists")
	var document: Variant = JSON.parse_string(text)
	assert_true(document is Dictionary, "the manifest parses")
	var assets: Array = (document as Dictionary).get("assets", []) as Array
	assert_equal(assets.size(), ART.asset_count(), "one manifest row per declared asset")
	for row: Dictionary in assets:
		var path: String = row["source"] as String
		assert_equal(row["sha256"], FileAccess.get_sha256(path),
			"%s's recorded digest still matches its source" % row["id"])


func test_decorative_pigments_are_not_offered_as_semantic_tokens() -> void:
	"""§2.4: decorative pigments are not new UI tokens. The twelve §2.1 tokens stay the palette."""
	assert_equal(THEME.TOKEN_KEYS.size(), THEME.TOKEN_COUNT,
		"the semantic palette is unchanged in size")
	for pigment: StringName in ART.DECORATIVE_PIGMENTS:
		var name: String = String(pigment).get_slice(" ", 0)
		assert_false(THEME.TOKEN_KEYS.has(StringName(name)),
			"decorative pigment %s does not shadow a semantic token" % name)


# --- helpers ------------------------------------------------------------------------------

func _opaque_pixels(image: Image) -> int:
	"""How many pixels of an image are solid enough to carry the silhouette."""
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a >= _alpha_threshold:
				count += 1
	return count


func _boundary_share(image: Image, background: Color) -> float:
	"""The fraction of an icon's outline pixels that clear 3:1 once composited on a surface.

	"Outline" is the outermost *visible* pixel, not the outermost fully opaque one. The
	lock's keyline is one final pixel wide, so its outer half is antialiased; measuring
	only fully solid pixels would skip most of the keyline and grade the ink contour
	underneath it instead.
	`Color.blend` accounts for the partial alpha, so what is graded is what a player sees.
	"""
	var total: int = 0
	var passing: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a < VISIBLE_ALPHA or not _on_edge(image, x, y):
				continue
			total += 1
			if THEME.contrast_ratio(background.blend(pixel), background) \
					>= FUNCTIONAL_CONTRAST:
				passing += 1
	return 0.0 if total == 0 else float(passing) / float(total)


func _on_edge(image: Image, x: int, y: int) -> bool:
	"""True when a visible pixel touches the surround, so it is part of the outline."""
	for step: int in 4:
		var nx: int = x + (1 if step == 0 else (-1 if step == 1 else 0))
		var ny: int = y + (1 if step == 2 else (-1 if step == 3 else 0))
		if nx < 0 or ny < 0 or nx >= image.get_width() or ny >= image.get_height():
			return true
		if image.get_pixel(nx, ny).a < VISIBLE_ALPHA:
			return true
	return false


func _distinct_colours(image: Image) -> int:
	"""Distinct quantised opaque tones, so antialiasing cannot inflate the tally."""
	var seen: Dictionary = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a < 0.9:
				continue
			seen[_quantise(pixel)] = true
	return seen.size()


func _interior_colours(image: Image) -> int:
	"""Distinct quantised tones among pixels every one of whose neighbours is also solid.

	Excluding the edge excludes the ink contour, the keyline and every antialiased pixel,
	so what is counted is modelled light inside the form and nothing else.
	"""
	var seen: Dictionary = {}
	for y: int in range(1, image.get_height() - 1):
		for x: int in range(1, image.get_width() - 1):
			if not _deep_interior(image, x, y):
				continue
			seen[_quantise(image.get_pixel(x, y))] = true
	return seen.size()


func _deep_interior(image: Image, x: int, y: int) -> bool:
	"""True when a pixel and all eight of its neighbours are fully opaque."""
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if image.get_pixel(x + dx, y + dy).a < 0.95:
				return false
	return true


func _quantise(pixel: Color) -> int:
	"""One integer key per colour bucket, 16 levels per channel."""
	var r: int = int(pixel.r * float(COLOUR_LEVELS - 1))
	var g: int = int(pixel.g * float(COLOUR_LEVELS - 1))
	var b: int = int(pixel.b * float(COLOUR_LEVELS - 1))
	return r * COLOUR_LEVELS * COLOUR_LEVELS + g * COLOUR_LEVELS + b


func _is_constant_along_run(image: Image) -> bool:
	"""True when every line along the stretch axis repeats the first one exactly."""
	var horizontal: bool = image.get_width() >= image.get_height()
	if horizontal:
		for x: int in image.get_width():
			for y: int in image.get_height():
				if image.get_pixel(x, y) != image.get_pixel(0, y):
					return false
		return true
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y) != image.get_pixel(x, 0):
				return false
	return true


func _alpha_signature(image: Image) -> String:
	"""A digest of where a corner piece is opaque: its outline, ignoring colour."""
	var mask: PackedByteArray = PackedByteArray()
	for y: int in image.get_height():
		for x: int in image.get_width():
			mask.append(1 if image.get_pixel(x, y).a >= _alpha_threshold else 0)
	return "%dx%d:%s" % [image.get_width(), image.get_height(), Marshalls.raw_to_base64(mask.compress())]



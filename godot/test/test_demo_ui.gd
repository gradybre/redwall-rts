extends "res://test/framework/test_case.gd"
## Coverage for the live demo's woodland HUD skin (`godot/demo/ui/`).
##
## Three promises are checked here, each against something this file states for itself:
##   1. CONTRAST. The WCAG helper reproduces the standard's own literals (21:1, the 4.54/4.48
##      grey pair), and every text colour the skin paints clears 4.5:1 against BOTH ends of the
##      tone range its textured surface is allowed to span -- and the generated texels really do
##      stay inside that range.
##   2. A SKIN, NOT A RELAYOUT. Applied to a synthetic tree and to the real `hud.tscn`, the skin
##      changes styleboxes and colours and leaves every existing control's position, size,
##      minimum size and mouse filter exactly as they were. The cached Theme resource on disk is
##      never edited in place.
##   3. GRACEFUL. A null root, a bare Control and a tree missing every named target are dressed
##      without an error, and a second call is a no-op.
##
## The headless runner executes suites before the scene tree is live, so everything here works
## off-tree; `hud.tscn` is built the way `test_hud.gd` builds it, by calling `_ready()` by hand.

const Contrast := preload("res://demo/ui/woodland_contrast.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Textures := preload("res://demo/ui/woodland_textures.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const ThemePatch := preload("res://demo/ui/woodland_theme_patch.gd")
const WoodlandSkin := preload("res://demo/ui/woodland_skin.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const HudScript := preload("res://scripts/ui/hud.gd")

const HUD_SCENE_PATH: String = "res://scenes/ui/hud.tscn"
## ART-LOCK-001 §3's hex column, restated here so a mistyped pigment cannot also rewrite this.
const LOCK_HEX: PackedStringArray = [
	"25372d", "14211b", "eae1c8", "f5f0df", "708171", "466647",
	"b49a58", "91613e", "594332", "b76545", "d99743", "8a8d84",
]
## The game's cream TEXT and grey MUTED, which the shell writes as per-label overrides.
const SHELL_TEXT: Color = Color("#F5F0DF")
const SHELL_MUTED: Color = Color("#BECABF")
## Texels sampled from a piece's middle to check it stays inside its tone range.
const SAMPLE_STEP: int = 3
const LUMINANCE_SLACK: float = 0.002

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


# --- 1. the contrast helper -----------------------------------------------------------------------

func test_contrast_black_on_white_is_twenty_one() -> void:
	"""WCAG's maximum: black on white is exactly 21:1, in either order."""
	assert_almost_equal(Contrast.ratio(Color.BLACK, Color.WHITE), 21.0, "black on white")
	assert_almost_equal(Contrast.ratio(Color.WHITE, Color.BLACK), 21.0, "white on black")


func test_contrast_of_a_colour_with_itself_is_one() -> void:
	"""Identical colours have no contrast at all: 1:1."""
	assert_almost_equal(Contrast.ratio(Palette.OAT, Palette.OAT), 1.0, "oat on oat")


func test_contrast_reproduces_the_threshold_grey_pair() -> void:
	"""#767676 on white is the lightest grey that passes 4.5:1; #777777 is the first that fails."""
	var pass_ratio: float = Contrast.ratio(Color("#767676"), Color.WHITE)
	var fail_ratio: float = Contrast.ratio(Color("#777777"), Color.WHITE)
	assert_true(absf(pass_ratio - 4.54) < 0.01, "#767676 on white is 4.54:1, got %f" % pass_ratio)
	assert_true(absf(fail_ratio - 4.48) < 0.01, "#777777 on white is 4.48:1, got %f" % fail_ratio)
	assert_true(Contrast.passes(Color("#767676"), Color.WHITE, 16.0, false), "4.54 passes body")
	assert_false(Contrast.passes(Color("#777777"), Color.WHITE, 16.0, false), "4.48 fails body")


func test_large_text_thresholds() -> void:
	"""3:1 from 24 px regular or 18.66 px bold; 4.5:1 below either."""
	assert_equal(Contrast.minimum_for(24.0, false), Contrast.LARGE_MINIMUM, "24 px regular is large")
	assert_equal(Contrast.minimum_for(23.0, false), Contrast.BODY_MINIMUM, "23 px regular is body")
	assert_equal(Contrast.minimum_for(18.66, true), Contrast.LARGE_MINIMUM, "18.66 px bold is large")
	assert_equal(Contrast.minimum_for(18.0, true), Contrast.BODY_MINIMUM, "18 px bold is body")
	assert_true(Contrast.passes(Color("#777777"), Color.WHITE, 24.0, false), "4.48 passes large")


func test_worst_ratio_is_the_lowest_and_empty_is_zero() -> void:
	"""The worst case over several grounds is the lowest ratio; no grounds is 0.0."""
	var grounds: PackedColorArray = PackedColorArray([Color.WHITE, Color("#767676")])
	assert_almost_equal(Contrast.worst_ratio(Color.BLACK, grounds),
		Contrast.ratio(Color.BLACK, Color("#767676")), "worst is against the grey")
	assert_almost_equal(Contrast.worst_ratio(Color.BLACK, PackedColorArray()), 0.0, "empty set")


func test_composite_blends_source_over() -> void:
	"""Half-alpha black over white is mid grey, fully opaque."""
	var blended: Color = Contrast.composite(Color(0.0, 0.0, 0.0, 0.5), Color.WHITE)
	assert_true(blended.is_equal_approx(Color(0.5, 0.5, 0.5, 1.0)), "got %s" % blended)


# --- 1b. the palette and what it promises ---------------------------------------------------------

func test_palette_is_the_locks_twelve_pigments() -> void:
	"""The twelve constants are ART-LOCK-001 §3's hex values, in the lock's order."""
	assert_equal(Palette.PIGMENTS.size(), LOCK_HEX.size(), "twelve pigments")
	for index: int in LOCK_HEX.size():
		assert_equal(Palette.PIGMENTS[index].to_html(false), LOCK_HEX[index],
			"pigment I%02d" % (index + 1))


func test_every_surface_text_clears_body_contrast_across_its_range() -> void:
	"""Primary text on every surface is >= 4.5:1 against its darkest AND its lightest tone."""
	for surface: int in Palette.SURFACE_COUNT:
		var range_tones: PackedColorArray = PackedColorArray(
			[Palette.face_dark(surface), Palette.face_light(surface)])
		var worst: float = Contrast.worst_ratio(Palette.text_on(surface), range_tones)
		assert_true(worst >= Contrast.BODY_MINIMUM,
			"surface %d text reaches only %.2f:1" % [surface, worst])


func test_secondary_text_clears_body_contrast_on_every_surface() -> void:
	"""Captions, rates and notes are 14 px, so they owe the full 4.5:1 too."""
	for surface: int in Palette.SURFACE_COUNT:
		var range_tones: PackedColorArray = PackedColorArray(
			[Palette.face_dark(surface), Palette.face_light(surface)])
		var worst: float = Contrast.worst_ratio(Palette.secondary_on(surface), range_tones)
		assert_true(worst >= Contrast.BODY_MINIMUM,
			"surface %d secondary reaches only %.2f:1" % [surface, worst])


func test_readout_wash_keeps_ink_readable() -> void:
	"""A pressed readout's umber wash over the darkest parchment still leaves ink at 4.5:1."""
	var washed: Color = Contrast.composite(Color(Palette.UMBER, Styles.READOUT_PRESSED_ALPHA),
		Palette.face_dark(Palette.SURFACE_PARCHMENT))
	var ratio: float = Contrast.ratio(Palette.text_on(Palette.SURFACE_PARCHMENT), washed)
	assert_true(ratio >= Contrast.BODY_MINIMUM, "ink on a pressed readout is %.2f:1" % ratio)


func test_need_track_and_focus_ring_clear_non_text_contrast() -> void:
	"""SC 1.4.11: the track's edge and fill, and the focus ring, hold 3:1 where they are drawn."""
	var paper: Color = Palette.face_dark(Palette.SURFACE_PARCHMENT)
	assert_true(Contrast.ratio(Palette.TRACK_EDGE, paper) >= Contrast.NON_TEXT_MINIMUM,
		"track edge against parchment")
	assert_true(Contrast.ratio(Palette.TRACK_FILL, Palette.track_well()) >= Contrast.NON_TEXT_MINIMUM,
		"track fill against its well")
	for ground: Color in [Palette.CREAM, paper, Palette.face_dark(Palette.SURFACE_WOOD),
			Palette.face_light(Palette.SURFACE_WOOD)]:
		var best: float = maxf(Contrast.ratio(Palette.FOCUS_DARK, ground),
			Contrast.ratio(Palette.focus_bright(), ground))
		assert_true(best >= Contrast.NON_TEXT_MINIMUM, "focus ring on %s is %.2f:1" % [ground, best])


func test_generated_faces_stay_inside_their_tone_range() -> void:
	"""Every sampled middle texel of every textured face lies between its range's luminances.

	This is what lets the contrast claims above stand for the real textures, grain and all."""
	for piece: StringName in [Styles.PIECE_PANEL, Styles.PIECE_WOOD, Styles.PIECE_BRASS,
			Styles.PIECE_TILE, Styles.PIECE_NOTICE, Styles.PIECE_MAP]:
		var spec: Textures.Spec = Styles.spec_for(piece)
		var noise: Image = Textures.noise_image(spec.period(), spec.noise_seed)
		var low: float = UiTheme.relative_luminance(spec.face_dark) - LUMINANCE_SLACK
		var high: float = UiTheme.relative_luminance(spec.face_light) + LUMINANCE_SLACK
		var inside: bool = true
		for y: int in range(spec.margin, spec.size - spec.margin, SAMPLE_STEP):
			for x: int in range(spec.margin, spec.size - spec.margin, SAMPLE_STEP):
				var lum: float = UiTheme.relative_luminance(Textures.texel(spec, noise, x, y))
				inside = inside and lum >= low and lum <= high
		assert_true(inside, "piece %s strays outside its tone range" % piece)


func test_pieces_are_shaped_and_sized() -> void:
	"""A panel piece is its recipe's size, clear outside its rounded corner and opaque inside."""
	var texture: Texture2D = Styles.piece(Styles.PIECE_PANEL)
	assert_not_null(texture, "panel piece renders")
	var image: Image = texture.get_image()
	assert_equal(image.get_width(), int(Styles.RECIPES[Styles.PIECE_PANEL]["size"]), "width")
	assert_almost_equal(image.get_pixel(0, 0).a, 0.0, "corner outside the rounding is clear")
	assert_almost_equal(image.get_pixel(64, 64).a, 1.0, "middle is opaque")
	assert_null(Styles.piece(&"no_such_piece"), "an unknown piece is null, not an error")


func test_box_carries_the_callers_margins_and_draws_outside() -> void:
	"""A StyleBox keeps the content margins it is given; a frame's expand margin is its own."""
	var margins: PackedFloat32Array = PackedFloat32Array([2.0, 3.0, 4.0, 5.0])
	var style: StyleBoxTexture = Styles.box(Styles.PIECE_PANEL, margins)
	assert_equal(Styles.margins_of(style), margins, "content margins copied")
	assert_almost_equal(style.expand_margin_left,
		float(Styles.RECIPES[Styles.PIECE_PANEL]["expand"]), "frame draws outside its rect")
	assert_almost_equal(Styles.ring_box(margins).expand_margin_top, Styles.RING_EXPAND,
		"focus ring sits outside the control")


# --- 2. the theme copy ----------------------------------------------------------------------------

func test_skinned_theme_is_a_copy_and_the_original_is_untouched() -> void:
	"""The duplicate carries woodland styleboxes; the original keeps its own objects and values."""
	var original: Theme = _synthetic_theme()
	var original_panel: StyleBox = original.get_stylebox(&"panel", &"WoodlandPanel")
	var skinned: Theme = ThemePatch.skinned(original)
	assert_true(skinned != original, "a new Theme")
	assert_true(original.get_stylebox(&"panel", &"WoodlandPanel") == original_panel,
		"original panel stylebox is the same object")
	assert_true(original.get_stylebox(&"panel", &"WoodlandPanel") is StyleBoxFlat,
		"original is still flat")
	assert_true(skinned.get_stylebox(&"panel", &"WoodlandPanel") is StyleBoxTexture,
		"copy is textured")
	assert_true(ThemePatch.skinned(skinned) == skinned, "a skinned theme is not skinned twice")


func test_skinned_theme_keeps_every_button_margin() -> void:
	"""Each replaced button slot has the content margins of the slot it replaced."""
	var original: Theme = _synthetic_theme()
	var skinned: Theme = ThemePatch.skinned(original)
	for slot: StringName in ThemePatch.BUTTON_SLOTS:
		assert_equal(Styles.margins_of(skinned.get_stylebox(slot, &"WoodlandButton")),
			Styles.margins_of(original.get_stylebox(slot, &"WoodlandButton")), "slot %s" % slot)


func test_skinned_theme_inks_parchment_text_and_brasses_pressed_text() -> void:
	"""Labels read ink on parchment; a toggle's pressed text is deep shade on brass."""
	var skinned: Theme = ThemePatch.skinned(_synthetic_theme())
	assert_equal(skinned.get_color(&"font_color", &"WoodlandBody"), Palette.INK, "body ink")
	assert_equal(skinned.get_color(&"font_color", &"WoodlandSecondary"), Palette.UMBER,
		"secondary umber")
	assert_equal(skinned.get_color(&"font_pressed_color", &"WoodlandToggle"),
		Palette.DEEP_SHADE, "pressed toggle text on brass")
	assert_equal(skinned.get_color(&"font_color", &"WoodlandButton"), Palette.CREAM,
		"wood button text is cream")


func test_heading_font_is_the_vendored_serif() -> void:
	"""Noto Serif SemiBold is imported, and the heading variations wear it."""
	var serif: Font = Styles.heading_font()
	assert_not_null(serif, "the serif font loads")
	var skinned: Theme = ThemePatch.skinned(_synthetic_theme())
	assert_true(skinned.get_font(&"font", &"WoodlandCounter") == serif, "counter values are serif")


# --- 2b. the skin on a synthetic tree -------------------------------------------------------------

func test_skin_restyles_a_synthetic_tree() -> void:
	"""Panels, labels, tracks, the dock, the banner and the frame holders all change."""
	var tree: Dictionary = _synthetic_tree()
	var root: Control = tree["root"]
	var original: Theme = root.theme
	WoodlandSkin.apply(root)
	assert_true(root.theme != original and root.theme.has_meta(ThemePatch.META_SKINNED),
		"root wears a skinned copy")
	assert_equal((tree["caption"] as Label).get_theme_color(&"font_color"), Palette.INK,
		"cream caption on parchment turns ink")
	assert_equal((tree["rate"] as Label).get_theme_color(&"font_color"), Palette.UMBER,
		"muted rate on parchment turns umber")
	assert_equal((tree["notice_text"] as Label).get_theme_color(&"font_color"), SHELL_TEXT,
		"cream text on lacquer stays cream")
	assert_equal((tree["fill"] as ColorRect).color, Palette.TRACK_FILL, "track fill is leaf")
	assert_almost_equal((tree["frame_art"] as Control).modulate.a, 0.0, "SVG frame faded out")
	assert_true((tree["dock"] as Panel).get_theme_stylebox(&"panel") is StyleBoxTexture,
		"dock is carved")
	var tile: Button = tree["tile"]
	assert_equal(tile.get_theme_color(&"font_color"), Palette.INK, "dock tile text is ink")
	assert_true(tile.get_theme_stylebox(&"normal") is StyleBoxTexture, "dock tile is textured")
	assert_equal((tree["pause"] as Label).get_theme_color(&"font_color"), Palette.CREAM,
		"pause line is cream on its banner")
	assert_not_null((tree["pause"] as Label).get_node_or_null(^"WoodlandBanner"), "banner added")


func test_skin_moves_and_resizes_nothing() -> void:
	"""Every existing control keeps its position, size, minimum size and mouse filter."""
	var tree: Dictionary = _synthetic_tree()
	var root: Control = tree["root"]
	var before: Array[Control] = WoodlandSkin.collect(root)
	var snapshot: Array = _geometry_of(before)
	WoodlandSkin.apply(root)
	assert_equal(_geometry_of(before), snapshot, "geometry unchanged")


func test_skin_adds_only_decoration() -> void:
	"""The nodes the skin adds ignore the mouse, take no focus and have no accessible name."""
	var tree: Dictionary = _synthetic_tree()
	var root: Control = tree["root"]
	var before: Array[Control] = WoodlandSkin.collect(root)
	WoodlandSkin.apply(root)
	var added: int = 0
	for control: Control in WoodlandSkin.collect(root):
		if before.has(control):
			continue
		added += 1
		assert_equal(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores" % control.name)
		assert_equal(control.focus_mode, Control.FOCUS_NONE, "%s takes no focus" % control.name)
		assert_equal(control.accessibility_name, "", "%s is silent" % control.name)
	assert_equal(added, 2, "one banner and one oak spray")


func test_skin_is_applied_once() -> void:
	"""A second call adds nothing and swaps nothing."""
	var tree: Dictionary = _synthetic_tree()
	var root: Control = tree["root"]
	WoodlandSkin.apply(root)
	var theme_after_first: Theme = root.theme
	var count_after_first: int = WoodlandSkin.collect(root).size()
	WoodlandSkin.apply(root)
	assert_true(WoodlandSkin.is_applied(root), "marked applied")
	assert_true(root.theme == theme_after_first, "theme not re-skinned")
	assert_equal(WoodlandSkin.collect(root).size(), count_after_first, "no second banner or spray")


# --- 3. graceful degradation ----------------------------------------------------------------------

func test_skin_tolerates_a_null_root() -> void:
	"""apply(null) returns quietly."""
	WoodlandSkin.apply(null)
	assert_false(WoodlandSkin.is_applied(null), "a null root is never marked applied")


func test_skin_tolerates_a_bare_control() -> void:
	"""A Control with no theme and no children is dressed without error and gains nothing."""
	var bare: Control = _own(Control.new()) as Control
	WoodlandSkin.apply(bare)
	assert_true(WoodlandSkin.is_applied(bare), "marked applied")
	assert_null(bare.theme, "no theme invented")
	assert_equal(bare.get_child_count(), 0, "nothing added")


func test_skin_tolerates_a_tree_missing_every_named_target() -> void:
	"""No dock, no pause line, no frame holders, no tracks: the rest is still dressed."""
	var root: Control = _own(Control.new()) as Control
	root.theme = _synthetic_theme()
	var panel: Panel = Panel.new()
	panel.theme_type_variation = &"WoodlandPanel"
	root.add_child(panel)
	var text: Label = _text(panel, SHELL_TEXT)
	WoodlandSkin.apply(root)
	assert_equal(text.get_theme_color(&"font_color"), Palette.INK, "label still inked")
	assert_equal(panel.get_child_count(), 1, "no decoration for an unnamed panel")


# --- 2c. the skin on the real HUD -----------------------------------------------------------------

func test_skin_on_the_real_hud_changes_style_and_not_geometry() -> void:
	"""hud.tscn's built shell: skinned theme, inked counters, and not one control moved."""
	var hud: HudScript = (load(HUD_SCENE_PATH) as PackedScene).instantiate() as HudScript
	_own(hud)
	hud._ready()
	var root: Control = hud.get_node(^"Root") as Control
	var shell: Control = hud.get_node(^"Root/Shell") as Control
	var original: Theme = shell.theme
	var controls: Array[Control] = WoodlandSkin.collect(root)
	var snapshot: Array = _geometry_of(controls)
	WoodlandSkin.apply(root)
	assert_true(shell.theme != original and shell.theme.has_meta(ThemePatch.META_SKINNED),
		"the shell wears a skinned copy")
	assert_false(original.has_meta(ThemePatch.META_SKINNED), "the cached theme is untouched")
	assert_equal(_geometry_of(controls), snapshot, "no existing control moved or resized")
	var caption: Label = shell.get_node_or_null(^"UI-SET-001/UI-SET-004/Caption") as Label
	assert_not_null(caption, "the Wood counter's caption exists")
	if caption == null:
		return
	assert_equal(caption.get_theme_color(&"font_color"), Palette.INK, "counter caption is ink")


# --- helpers --------------------------------------------------------------------------------------

func _own(node: Node) -> Node:
	"""Track a node for freeing after the test."""
	_nodes.append(node)
	return node


func _synthetic_theme() -> Theme:
	"""A small Theme shaped like the shell's: flat styles under the §2.2 variation names."""
	var theme: Theme = Theme.new()
	theme.set_type_variation(&"WoodlandPanel", &"Panel")
	theme.set_stylebox(&"panel", &"WoodlandPanel", _flat(1.0))
	theme.set_type_variation(&"WoodlandNotice", &"Panel")
	theme.set_stylebox(&"panel", &"WoodlandNotice", _flat(1.0))
	theme.set_type_variation(&"WoodlandButton", &"Button")
	for slot: StringName in ThemePatch.BUTTON_SLOTS:
		theme.set_stylebox(slot, &"WoodlandButton", _flat(2.0))
	theme.set_type_variation(&"WoodlandReadout", &"Button")
	theme.set_stylebox(&"normal", &"WoodlandReadout", _flat(2.0))
	theme.set_color(&"font_color", &"WoodlandBody", SHELL_TEXT)
	return theme


func _flat(margin: float) -> StyleBoxFlat:
	"""A flat StyleBox with even content margins, like the shell's."""
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.set_content_margin_all(margin)
	return style


func _synthetic_tree() -> Dictionary:
	"""A root holding a parchment panel with a readout cell and a track, a notice, the dock and
	the pause line -- named the way `ui_shell.gd` names them."""
	var root: Control = _own(Control.new()) as Control
	root.size = Vector2(1280.0, 720.0)
	root.theme = _synthetic_theme()
	var out: Dictionary = {"root": root}
	_add_resources(root, out)
	var notice: Panel = _panel(root, &"UI-SET-011", &"WoodlandNotice", Vector2(600.0, 16.0))
	out["notice_text"] = _text(notice, SHELL_TEXT)
	_add_dock(root, out)
	var pause: Label = _text(root, SHELL_TEXT)
	pause.name = "UI-SET-086"
	pause.text = "Paused: PLAYER"
	out["pause"] = pause
	return out


func _add_resources(root: Control, out: Dictionary) -> void:
	"""UI-SET-001: a parchment panel with its SVG frame holder, a readout cell, a rate and a track."""
	var panel: Panel = _panel(root, &"UI-SET-001", &"WoodlandPanel", Vector2(16.0, 16.0))
	var frame_art: Control = Control.new()
	frame_art.name = "FrameArt"
	panel.add_child(frame_art)
	out["frame_art"] = frame_art
	var cell: Button = Button.new()
	cell.theme_type_variation = &"WoodlandReadout"
	cell.position = Vector2(8.0, 8.0)
	cell.size = Vector2(144.0, 56.0)
	panel.add_child(cell)
	out["caption"] = _text(cell, SHELL_TEXT)
	out["rate"] = _text(panel, SHELL_MUTED)
	var fill: ColorRect = ColorRect.new()
	fill.name = "TrackFill"
	fill.color = UiTheme.color_of(UiTheme.TOKEN_GOLD)
	panel.add_child(fill)
	out["fill"] = fill


func _add_dock(root: Control, out: Dictionary) -> void:
	"""The command strip, named as §4 names it, holding one command button."""
	var dock: Panel = _panel(root, &"UI-SET-026", &"WoodlandPanel", Vector2(400.0, 600.0))
	var tile: Button = Button.new()
	tile.theme_type_variation = &"WoodlandButton"
	tile.text = "Build"
	tile.position = Vector2(12.0, 12.0)
	tile.size = Vector2(112.0, 44.0)
	dock.add_child(tile)
	out["dock"] = dock
	out["tile"] = tile


func _panel(parent: Control, key: StringName, variation: StringName, at: Vector2) -> Panel:
	"""One positioned, sized, hit-testable panel."""
	var panel: Panel = Panel.new()
	panel.name = String(key)
	panel.theme_type_variation = variation
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.position = at
	panel.size = Vector2(480.0, 128.0)
	parent.add_child(panel)
	return panel


func _text(parent: Control, color: Color) -> Label:
	"""A label the way the shell writes one: its colour as a per-node override."""
	var label: Label = Label.new()
	label.text = "Ready food"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_color", color)
	parent.add_child(label)
	return label


func _geometry_of(controls: Array[Control]) -> Array:
	"""Position, size, minimum size and mouse filter of every control, in order."""
	var out: Array = []
	for control: Control in controls:
		out.append([control.name, control.position, control.size,
			control.get_combined_minimum_size(), control.mouse_filter, control.focus_mode])
	return out

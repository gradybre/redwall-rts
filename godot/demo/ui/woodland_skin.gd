extends RefCounted
## DEMO-ONLY woodland skin for the live HUD: carved wood, parchment and brass, applied in place.
##
##     WoodlandSkin.apply(hud_root)   # once, after the HUD has built
##
## It re-dresses the real HUD that `scenes/ui/hud.tscn` builds through `ui_shell.gd`, in the
## visual language of `docs/design/ui_refinement/visuals/05_woodland_art_concept.png`, WITHOUT
## editing any game file. `ui_theme.gd`, `ui_shell.gd`, `hud.gd`, `hud.tscn` and the Theme
## resource on disk are all left exactly as they are; everything happens to live objects.
##
## ---------------------------------------------------------------------------------------
## HOW IT FINDS WHAT TO DRESS. The shell builds every control in code and points it at a §2.2
## profile through `theme_type_variation` (WoodlandPanel, WoodlandButton, WoodlandToggle, ...)
## resolved against ONE Theme on the shell. So the skin works in two passes:
##
##   1. THEME. Every Control under `root` that holds a Theme gets a woodland COPY of it
##      (`woodland_theme_patch.gd`): each variation keeps its name and gets new styleboxes,
##      text colours and, for headings, Noto Serif SemiBold. The cached original is untouched.
##   2. NODES. What a theme cannot reach is fixed per node: labels the shell coloured by
##      override (their text must turn to ink on parchment), the need tracks' ColorRects, the
##      counter glyphs, the command dock and its tiles, the pause banner, the shell's own SVG
##      frame holders (faded out, since the carved frame replaces them) and the oak sprays.
##
## Targets are found by the same names the shell gives them -- §4's `UI-SET-nnn` keys and the
## child names it writes ("Icon", "TrackFill", "FrameArt"). A name that is absent is simply
## not dressed: the skin degrades to less decoration, never to an error.
##
## ---------------------------------------------------------------------------------------
## IT IS A SKIN, NOT A RELAYOUT. No position, size, anchor, offset, mouse filter or focus mode
## of an existing control is written. Replacement styleboxes carry the content margins of the
## ones they replace, so no Button's minimum size changes; frames and the focus ring draw
## outside their rectangles through expand margins, which move pixels and not hit areas. The
## only nodes added are decorative (IGNORE, FOCUS_NONE, no accessibility name).

const Palette := preload("res://demo/ui/woodland_palette.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")
const ThemePatch := preload("res://demo/ui/woodland_theme_patch.gd")
const Ornament := preload("res://demo/ui/woodland_ornament.gd")
const Banner := preload("res://demo/ui/woodland_banner.gd")
const UiTheme := preload("res://scripts/ui/ui_theme.gd")

## Set on `root` once dressed, so a second call is a no-op rather than a double skin.
const META_APPLIED: StringName = &"woodland_skin_applied"
## Set on a node the skin gave a surface of its own, so the text under it knows its ground.
const META_SURFACE: StringName = &"woodland_surface"

## `ui_frame_builder.gd`'s HOLDER_NAME: the shell's SVG frame pieces, replaced by the carving.
const FRAME_HOLDER_NAME: StringName = &"FrameArt"
## UI-SET-026, the command strip: a dark wood dock holding parchment tiles, as in the concept.
const DOCK_NAME: StringName = &"UI-SET-026"
## UI-SET-086, the pause line: a bare label on the world, seated on a lacquered banner.
const BANNER_LABELS: Array[StringName] = [&"UI-SET-086"]
## Oak sprays by panel key and the corners they grow from.
const ORNAMENT_CORNERS: Dictionary = {
	&"UI-SET-001": [Ornament.CORNER_TOP_LEFT],
	&"UI-SET-013": [Ornament.CORNER_BOTTOM_RIGHT],
	&"UI-SET-020": [Ornament.CORNER_BOTTOM_LEFT],
	&"UI-SET-036": [Ornament.CORNER_TOP_LEFT, Ornament.CORNER_BOTTOM_RIGHT],
}
## The need track's three ColorRects, by the names `ui_shell.gd` gives them.
const TRACK_EDGE_NAME: StringName = &"TrackEdge"
const TRACK_WELL_NAME: StringName = &"TrackWell"
const TRACK_FILL_NAME: StringName = &"TrackFill"
## A counter cell's line glyph.
const CELL_ICON_NAME: StringName = &"Icon"
## Icons whose path contains this are painted full-colour art, never tinted.
const PAINTED_MARK: String = "/painted/"

## The surface each §2.2 variation paints. WoodlandReadout is absent on purpose: a readout is
## transparent, so its text sits on whatever is behind it.
const VARIATION_SURFACE: Dictionary = {
	&"WoodlandPanel": Palette.SURFACE_PARCHMENT,
	&"WoodlandModal": Palette.SURFACE_PARCHMENT,
	&"WoodlandMeter": Palette.SURFACE_PARCHMENT,
	&"WoodlandNotice": Palette.SURFACE_LACQUER,
	&"WoodlandOverlay": Palette.SURFACE_MAP,
	&"WoodlandButton": Palette.SURFACE_WOOD,
	&"WoodlandToggle": Palette.SURFACE_WOOD,
	&"WoodlandRow": Palette.SURFACE_PARCHMENT,
	&"WoodlandField": Palette.SURFACE_PARCHMENT,
}

## The dock's tiles: piece and text surface per BUTTON_SLOTS state.
const TILE_PIECES: Array[StringName] = [
	Styles.PIECE_TILE, Styles.PIECE_TILE_HOVER, Styles.PIECE_BRASS, Styles.PIECE_TILE_DISABLED,
]
const TILE_SURFACES: Array[int] = [
	Palette.SURFACE_PARCHMENT, Palette.SURFACE_PARCHMENT, Palette.SURFACE_BRASS,
	Palette.SURFACE_PARCHMENT_DISABLED,
]


static func apply(root: Control) -> void:
	"""Dress the HUD under `root` in the woodland skin. Safe on a partial tree; once only."""
	if root == null or root.has_meta(META_APPLIED):
		return
	root.set_meta(META_APPLIED, true)
	var controls: Array[Control] = collect(root)
	for control: Control in controls:
		_skin_theme_of(control)
	for control: Control in controls:
		_skin_special(control)
	for control: Control in controls:
		_skin_contents(control, root)


static func is_applied(root: Control) -> bool:
	"""True once `apply()` has dressed this root."""
	return root != null and root.has_meta(META_APPLIED)


static func collect(root: Control) -> Array[Control]:
	"""Every Control under and including `root`, parents before children. Built iteratively."""
	var out: Array[Control] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Control:
			out.append(node as Control)
		for index: int in range(node.get_child_count() - 1, -1, -1):
			pending.append(node.get_child(index))
	return out


static func surface_of(node: Node, stop: Node) -> int:
	"""The surface `node` sits on: the nearest marked or styled ancestor, up to `stop`."""
	var current: Node = node
	while current != null:
		if current.has_meta(META_SURFACE):
			return int(current.get_meta(META_SURFACE))
		if current is Control and VARIATION_SURFACE.has((current as Control).theme_type_variation):
			return int(VARIATION_SURFACE[(current as Control).theme_type_variation])
		if current == stop:
			break
		current = current.get_parent()
	return Palette.SURFACE_NONE


static func ink_for(original: Color, surface: int) -> Color:
	"""The colour a label that the shell coloured `original` takes on `surface`.

	On a light surface the shell's cream becomes ink and its muted grey becomes umber; on a
	dark one the shell's own colours were chosen for a dark ground and are kept."""
	if not Palette.is_light(surface):
		return original
	if original.is_equal_approx(UiTheme.color_of(UiTheme.TOKEN_MUTED)):
		return Palette.secondary_on(surface)
	return Palette.text_on(surface)


# --- pass 1: the Theme ----------------------------------------------------------------------------

static func _skin_theme_of(control: Control) -> void:
	"""Swap a Control's own Theme for its woodland copy."""
	if control.theme != null:
		control.theme = ThemePatch.skinned(control.theme)


# --- pass 2a: nodes that get a surface of their own -----------------------------------------------

static func _skin_special(control: Control) -> void:
	"""The frame holders, the dock, the banner labels and the oak sprays."""
	if control.name == FRAME_HOLDER_NAME:
		control.modulate = Color(1.0, 1.0, 1.0, 0.0)
	elif control.name == DOCK_NAME and control is Panel:
		_skin_dock(control as Panel)
	elif control is Panel and control.clip_contents \
			and control.theme_type_variation == &"WoodlandPanel":
		_skin_clipped_panel(control as Panel)
	elif control is Label and BANNER_LABELS.has(StringName(control.name)):
		_skin_banner_label(control as Label)
	if ORNAMENT_CORNERS.has(StringName(control.name)):
		for corner: int in ORNAMENT_CORNERS[StringName(control.name)]:
			Ornament.attach(control, corner)


static func _skin_dock(dock: Panel) -> void:
	"""The command strip becomes a carved wood dock, and its buttons parchment tiles."""
	var margins: PackedFloat32Array = Styles.margins_of(dock.get_theme_stylebox(&"panel"))
	dock.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_DOCK, margins))
	dock.set_meta(META_SURFACE, Palette.SURFACE_WOOD)
	for child: Node in dock.get_children():
		if child is Button:
			_skin_tile(child as Button)


static func _skin_clipped_panel(panel: Panel) -> void:
	"""A panel that clips its children would clip an outside frame too: carve it inside."""
	var margins: PackedFloat32Array = Styles.margins_of(panel.get_theme_stylebox(&"panel"))
	panel.add_theme_stylebox_override(&"panel", Styles.box(Styles.PIECE_PANEL_TIGHT, margins))


static func _skin_tile(button: Button) -> void:
	"""One parchment tile: its four state pieces, ink text, and ink line icons."""
	for state: int in ThemePatch.BUTTON_SLOTS.size():
		var slot: StringName = ThemePatch.BUTTON_SLOTS[state]
		var margins: PackedFloat32Array = Styles.margins_of(button.get_theme_stylebox(slot))
		button.add_theme_stylebox_override(slot, Styles.box(TILE_PIECES[state], margins))
		var text: Color = Palette.text_on(TILE_SURFACES[state])
		for item: StringName in ThemePatch.FONT_COLORS_BY_STATE[state]:
			button.add_theme_color_override(item, text)
		for item: StringName in ThemePatch.ICON_COLORS_BY_STATE[state]:
			button.add_theme_color_override(item, text)
	button.set_meta(META_SURFACE, Palette.SURFACE_PARCHMENT)


static func _skin_banner_label(label: Label) -> void:
	"""A free-standing label gets a lacquered banner behind it and cream text on top."""
	label.set_meta(META_SURFACE, Palette.SURFACE_LACQUER)
	label.add_theme_color_override(&"font_color", Palette.text_on(Palette.SURFACE_LACQUER))
	Banner.attach(label)


# --- pass 2b: what sits on those surfaces ---------------------------------------------------------

static func _skin_contents(control: Control, root: Control) -> void:
	"""Recolour text, tracks and glyphs for the surface each one now sits on."""
	if control is Label:
		_skin_label(control as Label, root)
	elif control is ColorRect:
		_skin_track(control as ColorRect, root)
	elif control is TextureRect and control.name == CELL_ICON_NAME:
		_skin_cell_icon(control as TextureRect, root)
	elif control is Button:
		_skin_button_icon(control as Button)


static func _skin_label(label: Label, root: Control) -> void:
	"""Ink on parchment, cream on wood and lacquer, and the serif face on heading roles."""
	var surface: int = surface_of(label, root)
	var colored: bool = label.has_theme_color_override(&"font_color")
	if colored:
		label.add_theme_color_override(&"font_color",
			ink_for(label.get_theme_color(&"font_color"), surface))
	elif not Palette.is_light(surface):
		var ground: int = Palette.SURFACE_WOOD if surface == Palette.SURFACE_NONE else surface
		label.add_theme_color_override(&"font_color", Palette.text_on(ground))
	var serif: Font = Styles.heading_font()
	if serif != null and label.has_theme_font_override(&"font") \
			and ThemePatch.HEADING_VARIATIONS.has(label.theme_type_variation):
		label.add_theme_font_override(&"font", serif)


static func _skin_track(rect: ColorRect, root: Control) -> void:
	"""A need track on parchment: umber edge, pale well, leaf-green fill."""
	if not Palette.is_light(surface_of(rect, root)):
		return
	if rect.name == TRACK_EDGE_NAME:
		rect.color = Palette.TRACK_EDGE
	elif rect.name == TRACK_WELL_NAME:
		rect.color = Palette.track_well()
	elif rect.name == TRACK_FILL_NAME:
		rect.color = Palette.TRACK_FILL


static func _skin_cell_icon(icon: TextureRect, root: Control) -> void:
	"""A counter's cream line glyph inked for parchment. Painted art keeps its own colours."""
	if is_painted(icon.texture) or not Palette.is_light(surface_of(icon, root)):
		return
	icon.modulate = Palette.text_on(Palette.SURFACE_PARCHMENT)


static func _skin_button_icon(button: Button) -> void:
	"""A painted icon is shown untinted in every state; line glyphs keep the theme's tint."""
	if not is_painted(button.icon):
		return
	for state: int in ThemePatch.ICON_COLORS_BY_STATE.size():
		for item: StringName in ThemePatch.ICON_COLORS_BY_STATE[state]:
			button.add_theme_color_override(item, Color.WHITE)


static func is_painted(texture: Texture2D) -> bool:
	"""True for the painted full-colour icon family, which must never be tinted."""
	return texture != null and texture.resource_path.contains(PAINTED_MARK)

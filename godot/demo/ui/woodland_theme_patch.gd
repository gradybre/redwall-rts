extends RefCounted
## Makes a woodland COPY of the HUD's Theme: styleboxes, text colours, heading font, scrollbars.
##
## THE ORIGINAL IS NEVER TOUCHED. `ui_shell.gd` loads `res://ui/theme/woodland_theme.tres` with
## `load()`, which returns the one cached instance every later `load()` also gets. Editing it in
## place would restyle the test suite's shells and any other scene in the process. `skinned()`
## duplicates it and patches the duplicate, and the caller assigns the duplicate to the Control
## that held the original.
##
## Every §2.2 profile keeps its own variation name, so nothing in the shell that reads a
## variation back sees a different answer. Only the items under those names change: which piece
## a state draws, the text and icon colour for that state's surface, and the heading face.

const Palette := preload("res://demo/ui/woodland_palette.gd")
const Styles := preload("res://demo/ui/woodland_styles.gd")

## Set on a skinned copy, so a second pass never skins a skin.
const META_SKINNED: StringName = &"woodland_skinned_theme"

## Panel-type variations and the piece each wears on its `panel` slot.
const PANEL_PIECES: Dictionary = {
	&"WoodlandPanel": Styles.PIECE_PANEL,
	&"WoodlandModal": Styles.PIECE_PANEL,
	&"WoodlandMeter": Styles.PIECE_PANEL,
	&"WoodlandNotice": Styles.PIECE_NOTICE,
	&"WoodlandOverlay": Styles.PIECE_MAP,
	&"TooltipPanel": Styles.PIECE_MAP,
}

## Button slots in state order. The fifth state, focus, is the ring and is handled apart.
const BUTTON_SLOTS: Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled"]
const STATE_NORMAL: int = 0
const STATE_HOVER: int = 1
const STATE_PRESSED: int = 2
const STATE_DISABLED: int = 3

## Button-type variations: the piece for each of BUTTON_SLOTS. An empty name is a readout's
## transparent face, which draws a wash instead of a piece.
const BUTTON_PIECES: Dictionary = {
	&"Button": [&"wood", &"wood_hover", &"brass", &"wood_disabled"],
	&"WoodlandButton": [&"wood", &"wood_hover", &"brass", &"wood_disabled"],
	&"WoodlandToggle": [&"wood", &"wood_hover", &"brass", &"wood_disabled"],
	&"WoodlandRow": [&"row", &"tile_hover", &"brass", &"tile_disabled"],
	&"WoodlandField": [&"field", &"tile_hover", &"brass", &"tile_disabled"],
	&"WoodlandReadout": [&"", &"", &"", &""],
}

## The surface a button's text sits on in each of BUTTON_SLOTS' states.
const BUTTON_SURFACES: Dictionary = {
	&"Button": [Palette.SURFACE_WOOD, Palette.SURFACE_WOOD, Palette.SURFACE_BRASS,
		Palette.SURFACE_WOOD_DISABLED],
	&"WoodlandButton": [Palette.SURFACE_WOOD, Palette.SURFACE_WOOD, Palette.SURFACE_BRASS,
		Palette.SURFACE_WOOD_DISABLED],
	&"WoodlandToggle": [Palette.SURFACE_WOOD, Palette.SURFACE_WOOD, Palette.SURFACE_BRASS,
		Palette.SURFACE_WOOD_DISABLED],
	&"WoodlandRow": [Palette.SURFACE_PARCHMENT, Palette.SURFACE_PARCHMENT,
		Palette.SURFACE_BRASS, Palette.SURFACE_PARCHMENT_DISABLED],
	&"WoodlandField": [Palette.SURFACE_PARCHMENT, Palette.SURFACE_PARCHMENT,
		Palette.SURFACE_BRASS, Palette.SURFACE_PARCHMENT_DISABLED],
	&"WoodlandReadout": [Palette.SURFACE_PARCHMENT, Palette.SURFACE_PARCHMENT,
		Palette.SURFACE_PARCHMENT, Palette.SURFACE_PARCHMENT_DISABLED],
}

## Button colour items, grouped by the state whose surface decides them.
const FONT_COLORS_BY_STATE: Array = [
	[&"font_color", &"font_focus_color"], [&"font_hover_color"],
	[&"font_pressed_color", &"font_hover_pressed_color"], [&"font_disabled_color"],
]
const ICON_COLORS_BY_STATE: Array = [
	[&"icon_normal_color", &"icon_focus_color"], [&"icon_hover_color"],
	[&"icon_pressed_color", &"icon_hover_pressed_color"], [&"icon_disabled_color"],
]

## Label variations drawn in primary ink, and the one drawn in secondary umber. They sit on
## parchment unless a node says otherwise; `woodland_skin.gd` recolours the ones that do not.
const INK_LABELS: Array[StringName] = [
	&"Label", &"WoodlandBody", &"WoodlandCounter", &"WoodlandPanelTitle", &"WoodlandPageTitle",
	&"TooltipLabel",
]
const SECONDARY_LABEL: StringName = &"WoodlandSecondary"
## The variations that take Noto Serif SemiBold: counter values, the name heading, titles.
const HEADING_VARIATIONS: Array[StringName] = [
	&"WoodlandCounter", &"WoodlandPanelTitle", &"WoodlandPageTitle",
]

## Scrollbar slots and the colour each draws, as a wood grabber in a parchment track.
const SCROLL_TYPES: Array[StringName] = [&"VScrollBar", &"HScrollBar"]
const SCROLL_RADIUS: int = 4


static func skinned(original: Theme) -> Theme:
	"""A woodland copy of `original`. The original resource is left exactly as it was."""
	if original == null:
		return null
	if original.has_meta(META_SKINNED):
		return original
	var theme: Theme = original.duplicate() as Theme
	for variation: StringName in PANEL_PIECES:
		_patch_panel(theme, original, variation)
	for variation: StringName in BUTTON_PIECES:
		_patch_button(theme, original, variation)
	_patch_labels(theme)
	_patch_scrollbars(theme)
	theme.set_meta(META_SKINNED, true)
	return theme


static func original_margins(original: Theme, slot: StringName,
		type_name: StringName) -> PackedFloat32Array:
	"""The content margins a slot drew with before the skin: the theme's, else the engine's."""
	if original != null and original.has_stylebox(slot, type_name):
		return Styles.margins_of(original.get_stylebox(slot, type_name))
	var fallback: Theme = ThemeDB.get_default_theme()
	var base: StringName = type_name
	if original != null and original.get_type_variation_base(type_name) != &"":
		base = original.get_type_variation_base(type_name)
	if fallback.has_stylebox(slot, base):
		return Styles.margins_of(fallback.get_stylebox(slot, base))
	return PackedFloat32Array([0.0, 0.0, 0.0, 0.0])


static func _patch_panel(theme: Theme, original: Theme, variation: StringName) -> void:
	"""Give one panel variation its framed piece, keeping its original content margins."""
	var margins: PackedFloat32Array = original_margins(original, &"panel", variation)
	theme.set_stylebox(&"panel", variation, Styles.box(PANEL_PIECES[variation], margins))


static func _patch_button(theme: Theme, original: Theme, variation: StringName) -> void:
	"""Give one button variation its four state pieces, its focus ring and its colours."""
	var pieces: Array = BUTTON_PIECES[variation]
	for state: int in BUTTON_SLOTS.size():
		var slot: StringName = BUTTON_SLOTS[state]
		var margins: PackedFloat32Array = original_margins(original, slot, variation)
		theme.set_stylebox(slot, variation, _button_box(pieces[state], state, margins))
	var focus_margins: PackedFloat32Array = original_margins(original, &"focus", variation)
	theme.set_stylebox(&"focus", variation, Styles.ring_box(focus_margins))
	var surfaces: Array = BUTTON_SURFACES[variation]
	for state: int in surfaces.size():
		_set_state_colors(theme, variation, state, int(surfaces[state]))


static func _button_box(piece: StringName, state: int, margins: PackedFloat32Array) -> StyleBox:
	"""One state's StyleBox: a piece, or for a readout a transparent face with a faint wash."""
	if piece != &"":
		return Styles.box(piece, margins)
	if state == STATE_HOVER:
		return Styles.wash(Styles.READOUT_HOVER_ALPHA, margins)
	if state == STATE_PRESSED:
		return Styles.wash(Styles.READOUT_PRESSED_ALPHA, margins)
	return Styles.clear(margins)


static func _set_state_colors(theme: Theme, variation: StringName, state: int,
		surface: int) -> void:
	"""Text and icon colours for one state, from the surface that state draws."""
	var text: Color = Palette.text_on(surface)
	for item: StringName in FONT_COLORS_BY_STATE[state]:
		theme.set_color(item, variation, text)
	for item: StringName in ICON_COLORS_BY_STATE[state]:
		theme.set_color(item, variation, text)


static func _patch_labels(theme: Theme) -> void:
	"""Ink for labels on parchment, umber for secondary lines, serif for the headings."""
	for type_name: StringName in INK_LABELS:
		theme.set_color(&"font_color", type_name, Palette.text_on(Palette.SURFACE_PARCHMENT))
	theme.set_color(&"font_color", SECONDARY_LABEL,
		Palette.secondary_on(Palette.SURFACE_PARCHMENT))
	var serif: Font = Styles.heading_font()
	if serif == null:
		return
	for variation: StringName in HEADING_VARIATIONS:
		theme.set_font(&"font", variation, serif)


static func _patch_scrollbars(theme: Theme) -> void:
	"""A timber grabber in a pale parchment track, keeping the engine's own margins."""
	for type_name: StringName in SCROLL_TYPES:
		_scroll_slot(theme, type_name, &"scroll", Palette.track_well())
		_scroll_slot(theme, type_name, &"scroll_focus", Palette.track_well())
		_scroll_slot(theme, type_name, &"grabber", Palette.UMBER)
		_scroll_slot(theme, type_name, &"grabber_highlight", Palette.TIMBER)
		_scroll_slot(theme, type_name, &"grabber_pressed", Palette.BRASS)


static func _scroll_slot(theme: Theme, type_name: StringName, slot: StringName,
		color: Color) -> void:
	"""One flat scrollbar slot, with the margins the engine's default drew it with."""
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(SCROLL_RADIUS)
	var margins: PackedFloat32Array = original_margins(null, slot, type_name)
	style.content_margin_left = margins[0]
	style.content_margin_top = margins[1]
	style.content_margin_right = margins[2]
	style.content_margin_bottom = margins[3]
	theme.set_stylebox(slot, type_name, style)
